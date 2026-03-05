# src/tests/mcar_little.jl
# Little's MCAR test (1988) - Simplified implementation

using DataFrames
using Statistics
using LinearAlgebra
using Distributions

"""
    test_mcar_little(df; alpha=0.05, max_patterns=50) -> TestResult

Perform Little's MCAR test (1988) - a global test for MCAR assumption.

Tests whether missing data patterns are independent of data values across
ALL variables simultaneously.

# Arguments
- `df::DataFrame`: Input dataset (numeric columns recommended)
- `alpha::Float64`: Significance level (default: 0.05)
- `max_patterns::Int`: Maximum unique patterns to process (default: 50)

# Returns
TestResult with chi-square statistic, p-value, and MCAR decision.

# Key Limitation
⚠️ LOW POWER for weak/localized MAR - Use with pairwise tests!
Always validate with test_mcar_logistic() or test_mcar_means().

See package documentation for detailed workflow examples.
"""
function test_mcar_little(
    df::DataFrame;
    alpha::Float64 = 0.05,
    max_patterns::Int = 50
)::TestResult

    # Validation
    ncol(df) < 2 && throw(ArgumentError("Need at least 2 columns"))
    nrow(df) < 10 && throw(ArgumentError("Need at least 10 rows"))

    # Select numeric columns
    numeric_cols = [c for c in propertynames(df) if eltype(df[!, c]) <: Union{Missing, Number}]
    
    isempty(numeric_cols) && return TestResult(
        "Little's MCAR Test", NaN, NaN, alpha, INCONCLUSIVE, nothing,
        Dict{String,Any}("reason" => "No numeric columns"),
        ["No numeric columns found"]
    )

    df_numeric = df[:, numeric_cols]
    n, p = nrow(df_numeric), ncol(df_numeric)
    warnings = String[]

    # Check if any numeric column actually has missing values
    numeric_with_missing = [c for c in numeric_cols if any(ismissing, df_numeric[!, c])]
    
    if isempty(numeric_with_missing)
        # All missing data is in non-numeric (categorical) columns
        # Little's test cannot assess missingness in categorical columns
        all_missing_cols = [c for c in propertynames(df) if any(ismissing, df[!, c])]
        return TestResult(
            "Little's MCAR Test", NaN, NaN, alpha, INCONCLUSIVE, nothing,
            Dict{String,Any}(
                "reason" => "No numeric columns contain missing values. " *
                            "Missing data is only in categorical columns: " *
                            join(string.(all_missing_cols), ", ") * ". " *
                            "Little's test requires missing values in numeric columns.",
                "n_rows" => n,
                "n_numeric_cols" => p,
                "categorical_cols_with_missing" => string.(all_missing_cols)
            ),
            ["Little's test not applicable: missing data is only in categorical columns. " *
             "Use test_mcar_logistic() or test_mcar_means() for these columns."]
        )
    end

    # Check complete cases
    complete_cases = completecases(df_numeric)
    n_complete = sum(complete_cases)

    n_complete == 0 && return TestResult(
        "Little's MCAR Test", NaN, NaN, alpha, INCONCLUSIVE, nothing,
        Dict{String,Any}("reason" => "No complete cases", "n_rows" => n, "n_cols" => p),
        ["No complete cases"]
    )

    n_complete < 10 && push!(warnings, "Only $n_complete complete cases — unreliable")

    # Identify patterns
    miss_matrix = Matrix(ismissing.(df_numeric))
    pattern_strings = [join(Int.(row), "") for row in eachrow(miss_matrix)]
    
    pattern_counts = Dict{String, Int}()
    pattern_indices = Dict{String, Vector{Int}}()
    
    for (i, pat) in enumerate(pattern_strings)
        pattern_counts[pat] = get(pattern_counts, pat, 0) + 1
        push!(get!(pattern_indices, pat, Int[]), i)
    end

    n_patterns = length(pattern_counts)
    n_patterns > max_patterns && push!(warnings, "$n_patterns patterns > $max_patterns — may be slow")

    # Estimate parameters from complete cases
    X_complete = Matrix{Float64}(df_numeric[complete_cases, :])
    μ_hat = vec(mean(X_complete, dims=1))
    Σ_hat = cov(X_complete)

    # Compute test statistic
    d_squared = 0.0
    total_df = 0

    for (pattern, indices) in pattern_indices
        all(c == '0' for c in pattern) && continue
        
        pattern_vec = [c == '0' for c in pattern]
        obs_vars = findall(pattern_vec)
        isempty(obs_vars) && continue

        X_pattern = Matrix{Float64}(df_numeric[indices, obs_vars])
        y_bar_j = vec(mean(X_pattern, dims=1))
        μ_j = μ_hat[obs_vars]
        Σ_j = Σ_hat[obs_vars, obs_vars] + 1e-6 * I
        
        try
            d_squared += length(indices) * dot(y_bar_j - μ_j, inv(Σ_j), y_bar_j - μ_j)
            total_df += length(obs_vars)
        catch
            push!(warnings, "Singular matrix for pattern $pattern")
        end
    end

    total_df == 0 && return TestResult(
        "Little's MCAR Test", NaN, NaN, alpha, INCONCLUSIVE, nothing,
        Dict{String,Any}(
            "reason" => "Could not compute test statistic. " *
                        "Possible causes: all patterns are complete in numeric columns, " *
                        "singular covariance matrix, or insufficient variation.",
            "n_rows" => n,
            "n_cols" => p,
            "n_patterns" => n_patterns
        ),
        vcat(warnings, ["Test statistic computation failed — check data structure"])
    )

    # P-value
    pvalue = 1 - cdf(Chisq(total_df), d_squared)
    decision = pvalue < alpha ? MCAR_REJECTED : MCAR_NOT_REJECTED

    details = Dict{String, Any}(
        "n_rows" => n,
        "n_cols" => p,
        "n_complete" => n_complete,
        "pct_complete" => round(100 * n_complete / n, digits=2),
        "n_patterns" => n_patterns,
        "chi_squared" => round(d_squared, digits=4),
        "degrees_of_freedom" => total_df,
        "pattern_counts" => sort(collect(pattern_counts), by=x->x[2], rev=true)[1:min(5, n_patterns)]
    )

    return TestResult("Little's MCAR Test", d_squared, pvalue, alpha, decision, total_df, details, warnings)
end

"""
    interpret_mcar_little(result::TestResult) -> String

Generate human-readable interpretation of Little's test results.
"""
function interpret_mcar_little(result::TestResult)::String
    io = IOBuffer()
    
    println(io, "═"^63)
    println(io, "LITTLE'S MCAR TEST - INTERPRETATION")
    println(io, "═"^63)
    println(io)
    println(io, "OVERALL DECISION: $(uppercase(string(result.decision)))")
    
    if result.decision == MCAR_REJECTED
        println(io, "Strong evidence against MCAR detected globally.")
        println(io, "Missing data mechanism is MAR or MNAR (or both).")
        println(io)
        println(io, "⚠️ IMPORTANT: Little's test tells you MCAR is violated,")
        println(io, "but NOT which variables are responsible.")
        println(io)
        println(io, "REQUIRED NEXT STEPS:")
        println(io, "  1. Run test_mcar_logistic() for each column with missing data")
        println(io, "  2. Examine significant predictors")
        println(io, "  3. Use advanced imputation (MICE, regression)")
        
    elseif result.decision == MCAR_NOT_REJECTED
        println(io, "No strong evidence against MCAR detected globally.")
        println(io)
        println(io, "⚠️ IMPORTANT: This does NOT prove MCAR.")
        println(io, "  • Test has LOW POWER for weak or localized MAR")
        println(io, "  • Pairwise tests may still detect violations")
        println(io, "  • MNAR cannot be detected by any statistical test")
        println(io)
        println(io, "REQUIRED NEXT STEPS:")
        println(io, "  1. Run test_mcar_logistic() for each column with missing data")
        println(io, "  2. If ANY pairwise test rejects MCAR → Use advanced imputation")
        println(io, "  3. Only if ALL tests pass → Consider simple imputation")
        
    else
        reason = get(result.details, "reason", "Unknown")
        println(io, "Test could not reach a conclusion. Reason: $reason")
    end
    println(io)
    
    if result.decision != INCONCLUSIVE
        println(io, "PATTERN DIAGNOSTICS:")
        println(io, "  • Total observations: $(get(result.details, "n_rows", "N/A"))")
        println(io, "  • Complete cases: $(get(result.details, "n_complete", "N/A")) ($(get(result.details, "pct_complete", "N/A"))%)")
        println(io, "  • Unique patterns: $(get(result.details, "n_patterns", "N/A"))")
        println(io, "  • Chi-square: $(get(result.details, "chi_squared", "N/A")), df: $(get(result.details, "degrees_of_freedom", "N/A")), p = $(round(result.pvalue, digits=4))")
        println(io)
        
        pattern_counts = get(result.details, "pattern_counts", [])
        if !isempty(pattern_counts)
            println(io, "Top $(min(5, length(pattern_counts))) most common patterns:")
            for (i, (pattern, count)) in enumerate(pattern_counts)
                desc = all(c == '0' for c in pattern) ? "Complete" : "Missing x" * join(findall(c -> c == '1', collect(pattern)), ", x")
                println(io, "  $i. $desc ($pattern): $count cases")
            end
        end
        println(io)
    end
    
    println(io, "RECOMMENDATION:")
    if result.decision == MCAR_REJECTED
        println(io, "Use advanced imputation: MICE, regression, or IPW")
    elseif result.decision == MCAR_NOT_REJECTED
        println(io, "Validate with pairwise tests before choosing imputation method")
    else
        println(io, "Address data quality issues first")
    end
    println(io)
    
    if !isempty(result.warnings)
        println(io, "WARNINGS:")
        for w in result.warnings
            println(io, "  ⚠ $w")
        end
    else
        println(io, "WARNINGS: ⚠ None")
    end
    
    println(io, "═"^63)
    return String(take!(io))
end