# src/tests/mcar_logistic.jl
# Logistic regression based MCAR test.
#
# Principle:
#   Create a binary outcome variable indicating whether col_missing
#   is missing (1) or observed (0). Fit a logistic regression model
#   predicting this outcome from all other sufficiently observed columns.
#
#   H0 (MCAR): all predictor coefficients are zero — missingness is
#   not predictable from the observed variables.
#
#   The decision is based on a GLOBAL likelihood ratio test comparing
#   the fitted model against the intercept-only model. Individual
#   predictor p-values are reported for interpretation but do NOT
#   drive the decision: selecting on min(p) across k predictors
#   inflates Type I error to 1 - (1-alpha)^k.
#
# Advantages over test_mcar_means:
#   - Handles categorical predictors (via dummy coding)
#   - Tests multiple predictors simultaneously in a single global test
#   - Controls for confounding (adjusted effects)
#
# Limitations:
#   - Requires at least 1 predictor column with ≥80% observed values
#   - Small sample issues if n_missing or n_observed < 10
#   - Assumes correct model specification (no interactions unless specified)

using DataFrames
using GLM
using CategoricalArrays
using Statistics
using Distributions

"""
    test_mcar_logistic(df, col_missing; alpha=0.05, exclude_cols=Symbol[]) -> TestResult

Test whether missingness in `col_missing` can be predicted by other
columns using logistic regression.

Creates a binary outcome y:
- y = 1 if col_missing is missing
- y = 0 if col_missing is observed

Then fits: logit(P(y=1)) = β₀ + β₁*x₁ + β₂*x₂ + ...

where x₁, x₂, ... are all other columns with ≥80% observed values.
Rows where a predictor is missing are dropped (complete case analysis).

The MCAR decision comes from a global likelihood ratio test of
H0: β₁ = β₂ = ... = βₖ = 0, comparing the fitted model against the
intercept-only model. The LR statistic follows a chi-squared
distribution with k degrees of freedom under H0, where k is the
number of estimated predictor coefficients.

# Arguments
- `df::DataFrame`: Input dataset.
- `col_missing::Symbol`: Column whose missingness is being tested.
- `alpha::Float64`: Significance level (default: 0.05).
- `exclude_cols::Vector{Symbol}`: Columns to exclude as predictors (default: empty).

# Returns
A `TestResult` with:
- `test_name`: `"MCAR Logistic Regression Test"`
- `statistic`: Likelihood ratio statistic (null deviance − model deviance)
- `pvalue`: Global p-value from the likelihood ratio test
- `degrees_of_freedom`: Number of estimated predictor coefficients
- `details`: Coefficient table, significant predictors, model summary,
  and `min_pvalue` (reported for interpretation only)
- `warnings`: Warnings for small samples, separation issues, dropped rows, etc.

# Raises
- `ArgumentError` if `col_missing` is not in `df`
- `ArgumentError` if `df` has fewer than 10 rows

Edge cases (no missing values, all values missing, no usable predictors,
model fitting failure) return an `INCONCLUSIVE` `TestResult` rather than
throwing.

# Interpretation
- Global LR test p < alpha → MCAR rejected
- Global LR test p ≥ alpha → MCAR not rejected

Individual predictor p-values in `details["significant_predictors"]`
identify *which* variables are associated with missingness — useful for
building an imputation model — but are not used to decide.

# Example
```julia
df = generate_mar_data(200, 5, 0.20)
result = test_mcar_logistic(df, :x2)
println(result)
# Check which variables predict missingness:
for pred in result.details["significant_predictors"]
    println("⚠️  \$(pred["variable"]) predicts missingness (p=\$(pred["pvalue"]))")
end
```
"""
function test_mcar_logistic(
    df::DataFrame,
    col_missing::Symbol;
    alpha::Float64 = 0.05,
    exclude_cols::Vector{Symbol} = Symbol[],
    max_levels::Int = 20,
    min_epv::Float64 = 10.0
)::TestResult

    # ── 1. INPUT VALIDATION ──────────────────────────────────────
    col_missing ∈ propertynames(df) ||
        throw(ArgumentError("Column $col_missing not found in DataFrame"))

    nrow(df) < 10 &&
        throw(ArgumentError(
            "Insufficient data: DataFrame has only $(nrow(df)) rows. " *
            "Logistic regression requires at least 10 observations."
        ))

    # ── 2. CREATE BINARY OUTCOME ─────────────────────────────────
    y = Float64.(ismissing.(df[!, col_missing]))  # 1=missing, 0=observed

    n_missing  = sum(y .== 1)
    n_observed = sum(y .== 0)

    # ── 3. EDGE CASE HANDLING ────────────────────────────────────
    warnings = String[]

    # No missing values
    if n_missing == 0
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => n_observed,
                "n_missing"  => 0,
                "reason"     => "No missing values in $col_missing"
            ),
            ["No missing values in $col_missing — test not applicable"]
        )
    end

    # All missing
    if n_observed == 0
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => 0,
                "n_missing"  => n_missing,
                "reason"     => "All values missing in $col_missing"
            ),
            ["All values missing in $col_missing — test not applicable"]
        )
    end

    # Small sample warnings
    if n_missing < 10 || n_observed < 10
        push!(warnings,
            "Small sample: n_missing=$n_missing, n_observed=$n_observed. " *
            "Results may be unreliable (recommend at least 10 per group).")
    end

    # ── 4. IDENTIFY PREDICTOR COLUMNS ────────────────────────────
    # All columns except col_missing and exclude_cols
    all_cols            = propertynames(df)
    predictor_candidates = filter(c -> c != col_missing && c ∉ exclude_cols, all_cols)

    # Accept columns with ≥80% observed values (relaxed from 100% fully observed).
    # This prevents the test from failing on MCAR data where missing values are
    # spread across all columns and no column is fully complete.
    # Rows where a predictor is still missing will be dropped in Step 5
    # (complete case analysis at the row level, not column level).
    #
    # NOTE: this threshold determines how many predictors enter the model,
    # which in turn sets the degrees of freedom of the global LR test.
    # It is a deliberate trade-off between model richness and the number
    # of complete cases retained.
    MIN_OBS_RATIO = 0.80

        constant_cols = Symbol[]
    high_card     = Symbol[]

    predictors = filter(predictor_candidates) do col
        v = df[!, col]
        count(!ismissing, v) / nrow(df) >= MIN_OBS_RATIO || return false
        u = unique(skipmissing(v))
        # Zero-variance predictors produce a one-level factor, which GLM
        # cannot contrast ("only one level found"). A constant column
        # carries no information about missingness anyway.
        if length(u) < 2
            push!(constant_cols, col)
            return false
        end
        # Categorical predictors with many levels generate one dummy column per
        # level, inflating the degrees of freedom of the LR test until it has
        # no power. ICD-9 diagnosis codes are a typical case (~700 levels).
        if !(nonmissingtype(eltype(v)) <: Number) && length(u) > max_levels
            push!(high_card, col)
            return false
        end
        return true
    end

    if !isempty(constant_cols)
        push!(warnings,
            "$(length(constant_cols)) constant column(s) excluded from predictors: " *
            join(string.(constant_cols), ", "))
    end

    if !isempty(high_card)
        push!(warnings,
            "$(length(high_card)) high-cardinality categorical predictor(s) excluded " *
            "(> $(max_levels) levels): " * join(string.(high_card), ", ") *
            ". Raise `max_levels` to include them, at the cost of test power.")
    end

    if isempty(predictors)
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => n_observed,
                "n_missing"  => n_missing,
                "reason"     => "No predictor columns with ≥80% observed values"
            ),
            ["No sufficiently observed predictor columns available — cannot fit logistic model"]
        )
    end

    # ── 5. BUILD MODEL FRAME (rows first, then formula) ──────────
    # Complete-case analysis must happen BEFORE the formula is built:
    # a predictor that is non-constant on the full data can become
    # single-valued once incomplete rows are dropped, which makes GLM
    # fail with "only one level found".
    df_model   = df[:, predictors]
    df_model.y = y

    complete_rows = completecases(df_model)
    df_model      = df_model[complete_rows, :]

    if nrow(df_model) < 10
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => n_observed,
                "n_missing"  => n_missing,
                "reason"     => "Too few complete cases after dropping missing predictors " *
                                "($(nrow(df_model)) < 10)"
            ),
            ["Insufficient complete cases for model fitting — $(nrow(df_model)) rows available"]
        )
    end

    n_dropped = sum(.!complete_rows)
    if n_dropped > 0
        push!(warnings,
            "$(n_dropped) rows dropped due to missing predictor values (complete case analysis).")
    end

    # Re-check constancy on the retained rows
    degenerate = Symbol[]
    for col in predictors
        length(unique(df_model[!, col])) < 2 && push!(degenerate, col)
    end

    if !isempty(degenerate)
        push!(warnings,
            "$(length(degenerate)) predictor(s) became single-valued after " *
            "complete-case filtering and were excluded: " *
            join(string.(degenerate), ", "))
        predictors = filter(c -> c ∉ degenerate, predictors)
        select!(df_model, [predictors; :y])
    end

    if isempty(predictors)
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed"   => n_observed,
                "n_missing"    => n_missing,
                "n_model_rows" => nrow(df_model),
                "reason"       => "All candidate predictors were constant on the retained rows"
            ),
            ["No usable predictor remains after complete-case filtering"]
        )
    end

    # Events must be counted on the retained rows, not on the full data.
    # A predictor whose missingness overlaps that of the target column will,
    # after complete-case filtering, remove nearly every row where the target
    # is missing — leaving an outcome with almost no variation.
    n_events_retained    = sum(df_model.y .== 1)
    n_nonevents_retained = sum(df_model.y .== 0)

    # Only bail out when a binary model is literally unfittable. A merely
    # small number of retained events is handled at decision time by the
    # events-per-variable check, which preserves the accumulated warnings
    # and details.
    if n_events_retained < 2 || n_nonevents_retained < 2
        overlapping = [c for c in predictors
                       if sum(ismissing.(df[!, c]) .& (y .== 1)) > 0.5 * n_missing]
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed"   => n_observed,
                "n_missing"    => n_missing,
                "n_model_rows" => nrow(df_model),
                "reason"       => "Only $(n_events_retained) missing / " *
                                  "$(n_nonevents_retained) observed cases remain after " *
                                  "complete-case filtering" *
                                  (isempty(overlapping) ? "" :
                                   "; missingness overlaps with predictor(s): " *
                                   join(string.(overlapping), ", "))
            ),
            ["Outcome has too little variation after complete-case filtering — " *
             "missingness in this column largely co-occurs with missingness in its predictors"]
        )
    end

        if n_events_retained < 10 || n_nonevents_retained < 10
        push!(warnings,
            "Only $(n_events_retained) missing / $(n_nonevents_retained) observed " *
            "cases remain after complete-case filtering (from $(n_missing) / " *
            "$(n_observed)). Missingness in this column may overlap with " *
            "missingness in its predictors.")
    end

    formula_str = "y ~ " * join(string.(predictors), " + ")
    formula_obj = eval(Meta.parse("@formula($formula_str)"))

    # Convert String and non-numeric non-Float columns to CategoricalArray for GLM dummy coding
    for col in names(df_model)
        if col != "y"
            col_type = eltype(df_model[!, col])
            if col_type <: Union{String, AbstractString} || col_type <: Union{Missing, String, AbstractString}
                df_model[!, col] = categorical(df_model[!, col])
            elseif nonmissingtype(col_type) <: CategoricalValue
                df_model[!, col] = categorical(df_model[!, col])
            end
        end
    end

    # Fit logistic regression
    model = try
        glm(formula_obj, df_model, Binomial(), LogitLink())
    catch e
        # Common failures: perfect separation, multicollinearity
        return TestResult(
            "MCAR Logistic Regression Test",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => n_observed,
                "n_missing"  => n_missing,
                "predictors" => string.(predictors),
                "formula"    => formula_str,
                "reason"     => "Model fitting failed: " * first(sprint(showerror, e), 300)
            ),
            ["Model fitting failed — possible perfect separation or collinearity"]
        )
    end

    # ── 6. EXTRACT COEFFICIENTS WITH CONFIDENCE INTERVALS ────────
    coef_table = coeftable(model)

    # coeftable structure: rows = coefficients, columns = [Estimate, Std.Error, z, Pr(>|z|)]
    coef_names   = coef_table.rownms
    coef_values  = coef_table.cols[1]     # Coefficients
    std_errors   = coef_table.cols[2]     # Standard Errors
    coef_pvalues = coef_table.cols[4]     # p-values

    # Filter out intercept
    predictor_indices      = findall(i -> coef_names[i] != "(Intercept)", 1:length(coef_names))
    predictor_pvalues      = coef_pvalues[predictor_indices]
    predictor_names_actual = coef_names[predictor_indices]

    # Minimum p-value — reported for interpretation only, NOT used to decide.
    min_pvalue = isempty(predictor_pvalues) ? NaN : minimum(predictor_pvalues)

    # Identify significant predictors with 95% confidence intervals
    significant_predictors = []
    z_critical = 1.96  # 95% CI (z-distribution for large samples)

    for (i, idx) in enumerate(predictor_indices)
        if predictor_pvalues[i] < alpha
            # Extract coefficient and standard error
            coef_val = coef_values[idx]
            std_err  = std_errors[idx]

            # Calculate 95% CI for coefficient
            ci_lower_coef = coef_val - z_critical * std_err
            ci_upper_coef = coef_val + z_critical * std_err

            # Transform to odds ratio and CI
            or_val      = exp(coef_val)
            ci_lower_or = exp(ci_lower_coef)
            ci_upper_or = exp(ci_upper_coef)

            push!(significant_predictors, Dict(
                "variable"      => predictor_names_actual[i],
                "coefficient"   => coef_val,
                "std_error"     => std_err,
                "pvalue"        => predictor_pvalues[i],
                "odds_ratio"    => or_val,
                "ci_lower_coef" => ci_lower_coef,
                "ci_upper_coef" => ci_upper_coef,
                "ci_lower_or"   => ci_lower_or,
                "ci_upper_or"   => ci_upper_or
            ))
        end
    end

    # ── 7. GLOBAL LIKELIHOOD RATIO TEST ──────────────────────────
    deviance_stat = deviance(model)
    df_lr = length(predictor_indices)

    # Warn when the model is over-parameterised relative to the number of
    # events. High-cardinality categorical predictors (e.g. diagnosis codes)
    # can produce thousands of dummy columns, inflating df and leaving the
    # test with almost no power.
    events = min(n_events_retained, n_nonevents_retained)
    if df_lr > 0 && df_lr > events / 10
        push!(warnings,
            "Model estimates $(df_lr) coefficients for $(events) events " *
            "(events per variable = $(round(events / df_lr, digits=1))). " *
            "High-cardinality categorical predictors inflate the degrees of freedom " *
            "and sharply reduce the power of the likelihood ratio test. " *
            "Consider excluding them via `exclude_cols`.")
    end

    lr_stat, global_pvalue = if df_lr == 0
        push!(warnings, "No predictor coefficients estimated — global test undefined.")
        (NaN, NaN)
    else
        try
            d0 = nulldeviance(model)
            s  = d0 - deviance_stat
            if s < -1e-6
                # Model deviance exceeds null deviance: the fit did not converge.
                # Clamping to zero would silently yield p = 1 and a spurious
                # "MCAR not rejected" decision.
                push!(warnings,
                    "Model deviance ($(round(deviance_stat, digits=2))) exceeds null " *
                    "deviance ($(round(d0, digits=2))): the fit did not converge. " *
                    "Result reported as inconclusive.")
                (NaN, NaN)
            else
                s = max(s, 0.0)
                (s, ccdf(Chisq(df_lr), s))
            end
        catch
            push!(warnings,
                "Null deviance unavailable; falling back to minimum predictor p-value. " *
                "Type I error may be inflated.")
            (NaN, min_pvalue)
        end
    end
 
    # ── 8. DECISION ──────────────────────────────────────────────
        decision = if isnan(global_pvalue)
        INCONCLUSIVE
    elseif df_lr > 0 && events / df_lr < min_epv
        # Fewer events than estimated coefficients: the model is saturated and
        # the chi-squared approximation of the LR statistic does not hold.
        # Returning a p-value here would produce fabricated rejections.
        push!(warnings,
            "Only $(events) events for $(df_lr) estimated coefficients " *
            "(EPV = $(round(events / df_lr, digits=1)), threshold = $(min_epv)). " *
            "Below roughly 10 events per variable, logistic regression estimates " *
            "and their standard errors are unreliable (Peduzzi et al., 1996). " *
            "Reduce the predictor set via `exclude_cols`, or lower `min_epv` " *
            "to accept the result. Reported as inconclusive.")
        INCONCLUSIVE
    elseif global_pvalue < alpha
        MCAR_REJECTED
    else
        MCAR_NOT_REJECTED
    end

    # ── 9. DETAILS ───────────────────────────────────────────────
    details = Dict{String, Any}(
        "n_observed"             => n_observed,
        "n_missing"              => n_missing,
        "n_model_rows"           => nrow(df_model),
        "col_missing"            => string(col_missing),
        "constant_cols_excluded"    => string.(constant_cols),
        "high_cardinality_excluded" => string.(high_card),
        "predictors"             => string.(predictors),
        "lr_statistic"           => isnan(lr_stat) ? NaN : round(lr_stat, digits=4),
        "global_pvalue"          => isnan(global_pvalue) ? NaN : round(global_pvalue, digits=6),
        "df"                     => df_lr,
        "events"                 => events,
        "epv"                    => df_lr > 0 ? round(events / df_lr, digits=2) : NaN,
        "min_pvalue"             => isnan(min_pvalue) ? NaN : round(min_pvalue, digits=4),
        "significant_predictors" => significant_predictors,
        "n_significant"          => length(significant_predictors),
        "model_deviance"         => round(deviance_stat, digits=4),
        "formula"                => formula_str
    )

    return TestResult(
        "MCAR Logistic Regression Test",
        lr_stat,
        global_pvalue,
        alpha,
        decision,
        Float64(df_lr),
        details,
        warnings
    )
end

# ================================================================
# INTERPRETATION HELPERS
# ================================================================

"""
    interpret_logistic_result(result::TestResult) -> String

Generate a human-readable interpretation of logistic regression test results.

Returns a formatted text summary including:
- Overall MCAR decision (from the global LR test) with MAR/MNAR distinction
- List of significant predictors with odds ratio interpretation
- Recommended imputation strategy
- Sensitivity analysis guidance
- Warnings if applicable

# Example
```julia
result = test_mcar_logistic(df, :age)
interpretation = interpret_logistic_result(result)
println(interpretation)
```
"""
function interpret_logistic_result(result::TestResult)::String
    io = IOBuffer()

    # Header
    println(io, "═"^63)
    println(io, "MCAR LOGISTIC REGRESSION TEST - INTERPRETATION")
    println(io, "═"^63)
    println(io)

    # Global test summary
    if !isnan(result.pvalue)
        lr  = get(result.details, "lr_statistic", NaN)
        dfr = get(result.details, "df", "N/A")
        println(io, "GLOBAL LIKELIHOOD RATIO TEST:")
        println(io, "  LR statistic = $lr, df = $dfr, p = $(round(result.pvalue, digits=4))")
        println(io)
    end

    # Overall Decision
    println(io, "OVERALL DECISION: $(uppercase(string(result.decision)))")

    if result.decision == MCAR_REJECTED
        col_name = get(result.details, "col_missing", "target column")
        println(io, "MCAR assumption is VIOLATED.")
        println(io, "Missingness in '$col_name' is predicted by other observed variables.")
        println(io)
        println(io, "Possible mechanisms:")
        println(io, "  • MAR (Missing At Random):")
        println(io, "    Missingness depends on OBSERVED variables")
        println(io, "    → Evidence: global model is significant")
        println(io, "  • MNAR (Missing Not At Random):")
        println(io, "    Missingness may ALSO depend on UNOBSERVED values")
        println(io, "    → Cannot be detected or ruled out by statistical tests")
        println(io)
        println(io, "IMPORTANT: Statistical tests can only REJECT MCAR.")
        println(io, "They CANNOT distinguish between MAR and MNAR.")
        println(io, "Both mechanisms may be present simultaneously.")
        println(io)
        println(io, "Next steps:")
        println(io, "  • MAR: Use advanced imputation (MICE, regression) - see RECOMMENDATION")
        println(io, "  • MNAR: Requires domain knowledge + sensitivity analysis")
        println(io, "  • Consider: Could unobserved values also predict missingness?")

    elseif result.decision == MCAR_NOT_REJECTED
        println(io, "No significant evidence against MCAR detected.")
        println(io, "The global model does not predict missingness better than chance.")
        println(io)
        println(io, "IMPORTANT: This does NOT prove MCAR.")
        println(io, "Three possible explanations:")
        println(io, "  1. MCAR: Missingness is truly random (ideal case)")
        println(io, "  2. MAR: Missingness depends on variables NOT included in this test")
        println(io, "  3. MNAR: Missingness depends on UNOBSERVED values")
        println(io, "     → Statistical tests CANNOT detect MNAR")
        println(io)
        println(io, "Recommended validation:")
        println(io, "  • Test with different/additional predictor sets")
        println(io, "  • Compare with Little's test (global MCAR test)")
        println(io, "  • Use domain knowledge:")
        println(io, "    - Could missing values depend on the variable itself?")
        println(io, "    - Are there unmeasured confounders?")
        println(io, "  • Perform sensitivity analysis under MNAR assumptions")

    else  # INCONCLUSIVE
        reason = get(result.details, "reason", "Unknown")
        println(io, "Test could not reach a conclusion.")
        println(io, "Reason: $reason")
        println(io)
        println(io, "Cannot determine missing data mechanism.")
        println(io, "Address data quality issues before interpreting results.")
    end
    println(io)

    # Significant Predictors
    sig_preds = get(result.details, "significant_predictors", [])

    if !isempty(sig_preds)
        println(io, "PREDICTORS ASSOCIATED WITH MISSINGNESS (p < $(result.alpha)):")
        println(io, "Reported for interpretation and imputation model building.")
        println(io, "These individual p-values are NOT corrected for multiple testing")
        println(io, "and do not drive the decision above.")
        println(io, "─"^63)

        for pred in sig_preds
            var_name = pred["variable"]
            coef     = pred["coefficient"]
            pval     = pred["pvalue"]
            or       = pred["odds_ratio"]

            # CI values (may not exist in older results)
            ci_lower_coef = get(pred, "ci_lower_coef", nothing)
            ci_upper_coef = get(pred, "ci_upper_coef", nothing)
            ci_lower_or   = get(pred, "ci_lower_or",   nothing)
            ci_upper_or   = get(pred, "ci_upper_or",   nothing)

            println(io, "  • $var_name (p = $(round(pval, digits=4)))")

            # Coefficient with CI
            if !isnothing(ci_lower_coef)
                println(io, "    - Coefficient: $(round(coef, digits=4)) " *
                            "[95% CI: $(round(ci_lower_coef, digits=4)), " *
                            "$(round(ci_upper_coef, digits=4))]")
            else
                println(io, "    - Coefficient: $(round(coef, digits=4))")
            end

            # Odds Ratio with CI (show more decimals if close to 1.0)
            or_display = abs(or - 1.0) < 0.1 ? round(or, digits=4) : round(or, digits=2)

            if !isnothing(ci_lower_or)
                # Apply same precision logic to CI bounds
                ci_lower_display = abs(ci_lower_or - 1.0) < 0.1 ?
                                round(ci_lower_or, digits=4) : round(ci_lower_or, digits=2)
                ci_upper_display = abs(ci_upper_or - 1.0) < 0.1 ?
                                round(ci_upper_or, digits=4) : round(ci_upper_or, digits=2)

                println(io, "    - Odds Ratio: $or_display " *
                            "[95% CI: $ci_lower_display, $ci_upper_display]")
            else
                println(io, "    - Odds Ratio: $or_display")
            end

            println(io, "    - Interpretation: $(interpret_odds_ratio(or, var_name))")

            # Add CI interpretation for OR
            if !isnothing(ci_lower_or)
                ci_interpretation = interpret_ci_or(ci_lower_or, ci_upper_or)
                println(io, "    - CI Interpretation: $ci_interpretation")
            end

            println(io, "    - Effect: $(effect_direction(or))")
            println(io)
        end
    else
        println(io, "PREDICTORS ASSOCIATED WITH MISSINGNESS: None")
        println(io, "No individual predictor reached significance.")
        println(io)
    end

    # Recommendation
    println(io, "RECOMMENDATION:")

    if result.decision == MCAR_REJECTED
        println(io, "Use advanced imputation methods that account for MAR:")
        println(io, "  • Multiple Imputation by Chained Equations (MICE)")
        println(io, "  • Regression imputation using significant predictors:")

        if !isempty(sig_preds)
            pred_names = [p["variable"] for p in sig_preds]
            println(io, "    → Include: $(join(pred_names, ", "))")
        end

        println(io, "  • Inverse probability weighting")
        println(io)
        println(io, "Consider MNAR sensitivity analysis:")
        println(io, "  • Pattern-mixture models")
        println(io, "  • Selection models")
        println(io, "  • Tipping point analysis")
        println(io, "  • Expert elicitation on unobserved mechanisms")
        println(io)
        println(io, "Avoid: Simple mean/median imputation (will introduce bias)")

    elseif result.decision == MCAR_NOT_REJECTED
        println(io, "Simple imputation methods may be acceptable IF MCAR truly holds:")
        println(io, "  • Mean/median imputation (numeric variables)")
        println(io, "  • Mode imputation (categorical variables)")
        println(io, "  • Hot-deck imputation")
        println(io)
        println(io, "However, validate MCAR assumption:")
        println(io, "  • Test with additional predictor sets")
        println(io, "  • Perform sensitivity analysis")
        println(io, "  • Compare results across imputation methods")
        println(io, "  • Use domain knowledge to assess MNAR plausibility")
        println(io)
        println(io, "If in doubt, use robust methods:")
        println(io, "  • Multiple imputation (works well even under MAR)")
        println(io, "  • Document assumptions and limitations")

    else
        println(io, "Cannot provide recommendation due to inconclusive test.")
        println(io, "Address data quality issues first:")
        println(io, "  • Ensure sufficient sample size (n ≥ 50 recommended)")
        println(io, "  • Verify at least one predictor column with ≥80% observed values")
        println(io, "  • Check for perfect separation or collinearity")
        println(io, "  • Review warnings for specific guidance")
    end
    println(io)

    # Warnings
    if !isempty(result.warnings)
        println(io, "WARNINGS:")
        for w in result.warnings
            println(io, "  ⚠ $w")
        end
    else
        println(io, "WARNINGS:")
        println(io, "  ⚠ None")
    end

    println(io, "═"^63)

    return String(take!(io))
end

"""
    interpret_odds_ratio(or::Float64, var_name::String) -> String

Generate natural language interpretation of an odds ratio.

# Examples
```julia
interpret_odds_ratio(1.5, "income")
# "For each unit increase in income, the odds of being missing increase by 50.0%."

interpret_odds_ratio(0.7, "education")
# "For each unit increase in education, the odds of being missing decrease by 30.0%."

interpret_odds_ratio(1.0, "gender")
# "gender has negligible effect on the odds of being missing."
```
"""
function interpret_odds_ratio(or::Float64, var_name::String)::String
    if abs(or - 1.0) < 0.05
        return "$var_name has negligible effect on the odds of being missing."
    elseif or > 1.0
        pct_increase = round((or - 1.0) * 100, digits=1)
        return "For each unit increase in $var_name, the odds of being missing increase by $pct_increase%."
    else  # or < 1.0
        pct_decrease = round((1.0 - or) * 100, digits=1)
        return "For each unit increase in $var_name, the odds of being missing decrease by $pct_decrease%."
    end
end

"""
    effect_direction(or::Float64) -> String

Summarize the direction of effect based on odds ratio.

Returns one of:
- "Higher X → MUCH MORE likely to be missing" (OR > 2.0)
- "Higher X → MORE likely to be missing" (1.0 < OR ≤ 2.0)
- "No effect" (OR ≈ 1.0)
- "Higher X → LESS likely to be missing" (0.5 ≤ OR < 1.0)
- "Higher X → MUCH LESS likely to be missing" (OR < 0.5)
"""
function effect_direction(or::Float64)::String
    if abs(or - 1.0) < 0.05
        return "No effect"
    elseif or > 2.0
        return "Higher X → MUCH MORE likely to be missing"
    elseif or > 1.0
        return "Higher X → MORE likely to be missing"
    elseif or >= 0.5
        return "Higher X → LESS likely to be missing"
    else
        return "Higher X → MUCH LESS likely to be missing"
    end
end

"""
    interpret_ci_or(ci_lower::Float64, ci_upper::Float64) -> String

Interpret the confidence interval of an odds ratio.

Provides insight into:
- Precision of the estimate (narrow vs wide CI)
- Whether the effect is statistically significant (CI excludes 1.0)
- Direction consistency (both bounds > 1 or both < 1)

# Examples
```julia
interpret_ci_or(1.02, 1.08)
# "Effect is statistically significant (CI excludes 1.0). Relatively precise estimate."

interpret_ci_or(0.5, 2.5)
# "CI includes 1.0 — effect not statistically significant. Wide interval suggests high uncertainty."
```
"""
function interpret_ci_or(ci_lower::Float64, ci_upper::Float64)::String
    # Check if CI includes 1.0
    includes_one = (ci_lower <= 1.0 <= ci_upper)

    # Measure width (on log scale for OR)
    ci_width_log = log(ci_upper) - log(ci_lower)

    # Classify precision
    # Narrow: width < 0.5 on log scale (e.g., [0.9, 1.1] or [1.8, 2.2])
    # Moderate: 0.5 ≤ width < 1.0
    # Wide: width ≥ 1.0
    precision = if ci_width_log < 0.5
        "Relatively precise estimate"
    elseif ci_width_log < 1.0
        "Moderate precision"
    else
        "Wide interval suggests high uncertainty"
    end

    if includes_one
        return "CI includes 1.0 — effect not statistically significant. $precision."
    else
        return "Effect is statistically significant (CI excludes 1.0). $precision."
    end
end