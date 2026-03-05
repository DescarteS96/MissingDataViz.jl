# src/tests/mcar_means.jl
# Welch t-test based MCAR test.
#
# Principle:
#   Split observations into two groups based on whether col_missing
#   is observed or missing. Compare the means of col_complete between
#   the two groups using Welch's t-test (unequal variances).
#
#   H0 (MCAR): mean(col_complete | col_missing observed)
#            = mean(col_complete | col_missing missing)
#
#   If H0 is rejected, col_complete predicts missingness in col_missing
#   → evidence against MCAR.
#
# Limitations:
#   - Pairwise only: tests one (col_missing, col_complete) pair at a time.
#   - Assumes col_complete is numeric and has no missing values.
#   - Requires at least 3 observations per group.
#   - Only detects linear mean differences (not variance or distributional).
#   - Multiple testing correction needed when calling test_all_mcar_means.

using Statistics
using HypothesisTests

"""
    test_mcar_means(df, col_missing, col_complete; alpha=0.05) -> TestResult

Test whether missingness in `col_missing` is associated with the mean
of `col_complete` using Welch's t-test.

Splits observations into:
- Group 0: rows where `col_missing` is **observed**
- Group 1: rows where `col_missing` is **missing**

Then tests H0: mean(Group 0) = mean(Group 1).

# Arguments
- `df::DataFrame`: Input dataset.
- `col_missing::Symbol`: Column whose missingness defines the groups.
- `col_complete::Symbol`: Numeric column compared between groups.
- `alpha::Float64`: Significance level (default: 0.05).

# Returns
A `TestResult` with:
- `test_name`: `"MCAR Means Test (Welch t-test)"`
- `statistic`: Welch t-statistic
- `pvalue`: Two-sided p-value
- `degrees_of_freedom`: Welch–Satterthwaite approximation
- `details`: group sizes, means, standard deviations
- `warnings`: non-empty if assumptions may be violated

# Raises
- `ArgumentError` if columns are missing from df
- `ArgumentError` if col_complete contains missing values
- `ArgumentError` if fewer than 3 observations in either group

# Mathematical Details
The test splits observations into:
- Group 0: col_missing is **observed**
- Group 1: col_missing is **missing**

Welch's t-statistic:
    t = (mean₀ - mean₁) / √(s₀²/n₀ + s₁²/n₁)

Null hypothesis H₀: mean₀ = mean₁ (MCAR holds)

If p < alpha → reject H₀ → col_complete predicts missingness → MCAR violated.

# Interpretation
- **p < 0.01:** Strong evidence against MCAR. Investigate relationship.
- **p < 0.05:** Moderate evidence. Use caution with simple imputation.
- **p ≥ 0.05:** No evidence against MCAR for this pair.

# Limitations
- Pairwise only (does not detect multivariate patterns)
- Assumes approximate normality for small samples (n < 30)
- Only detects mean differences (not variance or distributional)
- Requires fully observed numeric predictor

# See Also
- **Full theoretical guide:** `docs/guides/mcar_means_guide.md`
- Batch testing: [`test_all_mcar_means`](@ref)
- Alternative tests: `test_mcar_logistic`, `test_mcar_little`

# Example
```julia
df = generate_mar_data(200, 4, 0.20)
result = test_mcar_means(df, :x2, :x1)
println(result)
# MCAR rejected — x1 predicts missingness in x2
```
"""
function test_mcar_means(
    df::DataFrame,
    col_missing::Symbol,
    col_complete::Symbol;
    alpha::Float64 = 0.05
)::TestResult

    # ── 1. INPUT VALIDATION ──────────────────────────────────────
    col_missing ∈ propertynames(df) ||
        throw(ArgumentError("Column $col_missing not found in DataFrame"))

    col_complete ∈ propertynames(df) ||
        throw(ArgumentError("Column $col_complete not found in DataFrame"))

    col_missing != col_complete ||
        throw(ArgumentError("col_missing and col_complete must be different columns"))

    any(ismissing, df[!, col_complete]) &&
        throw(ArgumentError(
            "col_complete ($col_complete) contains missing values. " *
            "The predictor column must be fully observed."
        ))

    # ── 2. GROUP SPLITTING ───────────────────────────────────────
    mask_missing  = ismissing.(df[!, col_missing])
    mask_observed = .!mask_missing

    # Extract col_complete values for each group (no missing possible)
    group_observed = Float64.(df[mask_observed, col_complete])
    group_missing  = Float64.(df[mask_missing,  col_complete])

    n_observed = length(group_observed)
    n_missing  = length(group_missing)

    # ── 3. EDGE CASE HANDLING ────────────────────────────────────
    warnings = String[]

    # Not enough missing values to test
    if n_missing == 0
        return TestResult(
            "MCAR Means Test (Welch t-test)",
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

    # Minimum group size
    if n_observed < 3 || n_missing < 3
        return TestResult(
            "MCAR Means Test (Welch t-test)",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed" => n_observed,
                "n_missing"  => n_missing,
                "reason"     => "Insufficient observations (min 3 per group required)"
            ),
            ["Insufficient observations: group_observed=$n_observed, " *
             "group_missing=$n_missing (min 3 required)"]
        )
    end

    # Small sample warning
    if n_observed < 10 || n_missing < 10
        push!(warnings,
            "Small sample: group_observed=$n_observed, group_missing=$n_missing. " *
            "Results may be unreliable.")
    end

    # ── 4. DESCRIPTIVE STATISTICS ────────────────────────────────
    mean_observed = mean(group_observed)
    mean_missing  = mean(group_missing)
    std_observed  = std(group_observed)
    std_missing   = std(group_missing)

    # Constant column warning (std ≈ 0)
    if std_observed < 1e-10 || std_missing < 1e-10
        return TestResult(
            "MCAR Means Test (Welch t-test)",
            NaN, NaN, alpha,
            INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "n_observed"    => n_observed,
                "n_missing"     => n_missing,
                "mean_observed" => mean_observed,
                "mean_missing"  => mean_missing,
                "reason"        => "Near-zero variance in $col_complete"
            ),
            ["Near-zero variance in $col_complete — t-test not applicable"]
        )
    end

    # Non-normality warning for small samples
    if n_observed < 30 || n_missing < 30
        push!(warnings,
            "Sample size < 30 in at least one group. " *
            "Welch t-test assumes approximate normality. " *
            "Results may be unreliable for highly skewed data.")
    end

    # ── 5. WELCH T-TEST ──────────────────────────────────────────
    # HypothesisTests.EqualVarianceTTest → pooled (Student)
    # HypothesisTests.UnequalVarianceTTest → Welch (our choice)
    t_test = UnequalVarianceTTest(group_observed, group_missing)

    t_stat   = t_test.t
    p_val    = HypothesisTests.pvalue(t_test)           # two-sided by default
    df_welch = t_test.df              # Welch–Satterthwaite degrees of freedom

    # ── 6. DECISION ──────────────────────────────────────────────
    # TestResult constructor infers decision automatically from pvalue vs alpha

    details = Dict{String, Any}(
        "n_observed"    => n_observed,
        "n_missing"     => n_missing,
        "mean_observed" => round(mean_observed, digits=4),
        "mean_missing"  => round(mean_missing,  digits=4),
        "std_observed"  => round(std_observed,  digits=4),
        "std_missing"   => round(std_missing,   digits=4),
        "mean_diff"     => round(mean_observed - mean_missing, digits=4),
        "col_missing"   => string(col_missing),
        "col_complete"  => string(col_complete)
    )

    return TestResult(
        "MCAR Means Test (Welch t-test)",
        t_stat,
        p_val,
        alpha,
        p_val < alpha ? MCAR_REJECTED : MCAR_NOT_REJECTED,
        df_welch,
        details,
        warnings
    )
end

# ================================================================
# BATCH TEST WITH MULTIPLE TESTING CORRECTION
# ================================================================

"""
    test_all_mcar_means(df; alpha=0.05, correction=:bonferroni) -> Vector{TestResult}

Run `test_mcar_means` for all valid pairs (col_missing, col_complete)
where col_missing has at least one missing value and col_complete
is fully observed and numeric.

Applies multiple testing correction to control the family-wise
error rate across all pairwise tests.

# Arguments
- `df::DataFrame`: Input dataset.
- `alpha::Float64`: Family-wise significance level (default: 0.05).
- `correction::Symbol`: Multiple testing correction method.
  - `:bonferroni` — conservative, controls FWER (default)
  - `:none` — no correction (use only for exploratory analysis)

# Returns
`Vector{TestResult}` sorted by p-value (ascending).

# Notes
Bonferroni correction divides alpha by the number of tests:
`alpha_adjusted = alpha / n_tests`

This is conservative when tests are correlated (shared columns),
but is the safest choice for confirmatory analysis.

# See Also
- **Theoretical guide:** `docs/guides/mcar_means_guide.md`
- Individual test: [`test_mcar_means`](@ref)
- Results summary: [`summary_table`](@ref)

# Example
```julia
df = generate_mar_data(200, 6, 0.20)
results = test_all_mcar_means(df)
for r in results
    println(r)
end
```
"""
function test_all_mcar_means(
    df::DataFrame;
    alpha::Float64 = 0.05,
    correction::Symbol = :bonferroni
)::Vector{TestResult}

    correction ∈ (:bonferroni, :none) ||
        throw(ArgumentError("correction must be :bonferroni or :none"))

    cols = propertynames(df)

    # Identify columns with missing values (candidates for col_missing)
    cols_with_missing = [c for c in cols if any(ismissing, df[!, c])]

    # Identify fully observed numeric columns (candidates for col_complete)
    cols_complete = [
        c for c in cols
        if !any(ismissing, df[!, c]) &&
           eltype(skipmissing(df[!, c])) <: Real
    ]

    isempty(cols_with_missing) &&
        return TestResult[]

    isempty(cols_complete) &&
        return TestResult[]

    # Build all valid pairs
    pairs = [(cm, cc)
             for cm in cols_with_missing
             for cc in cols_complete
             if cm != cc]

    isempty(pairs) && return TestResult[]

    # Apply correction
    n_tests = length(pairs)
    alpha_adjusted = correction == :bonferroni ? alpha / n_tests : alpha

    # Run all tests
    results = TestResult[]
    for (col_m, col_c) in pairs
        r = test_mcar_means(df, col_m, col_c; alpha = alpha_adjusted)
        push!(results, r)
    end

    # Sort by p-value ascending (most significant first)
    sort!(results, by = r -> isnan(r.pvalue) ? Inf : r.pvalue)

    return results
end

# ================================================================
# SUMMARY TABLE FOR DISPLAY
# ================================================================

"""
    summary_table(results::Vector{TestResult}) -> DataFrame

Convert a vector of TestResult objects into a compact summary table
suitable for quick inspection and export.

# Arguments
- `results::Vector{TestResult}`: Test results from `test_all_mcar_means` or similar.

# Returns
A `DataFrame` with columns:
- `col_missing::String`: Column being tested for missingness.
- `col_complete::String`: Predictor column.
- `statistic::Float64`: Test statistic.
- `pvalue::Float64`: p-value.
- `decision::String`: Test decision (MCAR_REJECTED / MCAR_NOT_REJECTED / INCONCLUSIVE).
- `n_observed::Int`: Number of observations where col_missing is observed.
- `n_missing::Int`: Number of observations where col_missing is missing.
- `mean_diff::Float64`: Difference in means between groups.

# Notes
This is a convenience function for display and export. The full `TestResult`
objects contain additional metadata (warnings, degrees of freedom, etc.)
that are not included in this summary table.

# Example
```julia
df = generate_mar_data(200, 6, 0.20)
results = test_all_mcar_means(df)
table = summary_table(results)
println(table)
```
"""
function summary_table(results::Vector{TestResult})::DataFrame
    isempty(results) && return DataFrame()

    # Extract fields from each TestResult
    rows = map(results) do r
        (
            col_missing  = get(r.details, "col_missing", ""),
            col_complete = get(r.details, "col_complete", ""),
            statistic    = r.statistic,
            pvalue       = r.pvalue,
            decision     = string(r.decision),
            n_observed   = get(r.details, "n_observed", missing),
            n_missing    = get(r.details, "n_missing", missing),
            mean_diff    = get(r.details, "mean_diff", missing)
        )
    end

    return DataFrame(rows)
end