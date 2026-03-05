# src/tests/mcar_comparison.jl
# Comparison and validation of multiple MCAR tests
#
# Provides utilities to run and compare different MCAR tests
# (means, logistic, Little) on the same dataset.

using DataFrames
using Statistics

"""
    MCARTestComparison

Stores results from multiple MCAR tests for comparison.

# Fields
- `little_result::Union{TestResult, Nothing}`: Little's test result
- `means_results::Dict{Symbol, TestResult}`: Pairwise t-test results
- `logistic_results::Dict{Symbol, TestResult}`: Logistic regression results
- `summary::String`: Text summary of all results
- `recommendation::String`: Recommended approach based on results
"""
struct MCARTestComparison
    little_result::Union{TestResult, Nothing}
    means_results::Dict{Symbol, TestResult}
    logistic_results::Dict{Symbol, TestResult}
    summary::String
    recommendation::String
end

"""
    compare_mcar_tests(df; alpha=0.05, verbose=true) -> MCARTestComparison

Run and compare all three MCAR tests on a dataset.

Executes Little's test (global), pairwise t-tests, and logistic regression
tests, then provides a comprehensive comparison and recommendation.

# Arguments
- `df::DataFrame`: Input dataset
- `alpha::Float64`: Significance level (default: 0.05)
- `verbose::Bool`: Print detailed comparison (default: true)

# Returns
`MCARTestComparison` struct containing all test results and recommendations.

# Example
```julia
comparison = compare_mcar_tests(df)

# Access individual results
comparison.little_result
comparison.logistic_results[:age]
comparison.means_results[:age]

# View summary
println(comparison.summary)
println(comparison.recommendation)
```

# Interpretation Guide

The function identifies three scenarios:

1. **Agreement (all tests aligned)**
   - All reject OR all accept MCAR
   - Recommendation: Trust the consensus

2. **Partial disagreement**
   - Little accepts, but some pairwise tests reject
   - Indicates: Weak or localized MAR
   - Recommendation: Use pairwise results (more sensitive)

3. **Complete disagreement**
   - Mixed results across tests
   - Indicates: Complex missing mechanism
   - Recommendation: Use most conservative approach (assume MAR/MNAR)
"""
function compare_mcar_tests(
    df::DataFrame;
    alpha::Float64 = 0.05,
    verbose::Bool = true
)::MCARTestComparison
    
    # ── 0. SANITIZE COLUMN NAMES ─────────────────────────────────
    # Real-world datasets often have spaces, special chars, or names
    # starting with digits (e.g. "Customer ID", "2024_revenue").
    # GLM.jl's @formula macro cannot parse these. We rename columns
    # in a copy of the DataFrame and track the mapping to report
    # original names in results.
    
    original_names = propertynames(df)
    clean_names = Symbol[]
    name_mapping = Dict{Symbol, Symbol}()  # clean => original
    
    for name in original_names
        clean = Symbol(replace(string(name), r"[^a-zA-Z0-9_]" => "_"))
        # Prefix with underscore if starts with digit
        if occursin(r"^[0-9]", string(clean))
            clean = Symbol("_" * string(clean))
        end
        push!(clean_names, clean)
        name_mapping[clean] = name
    end
    
    # Only copy if names actually changed
    if clean_names != collect(original_names)
        df = rename(copy(df), [old => new for (old, new) in zip(original_names, clean_names)]...)
    end

    # Identify columns with missing data
    cols_with_missing = [col for col in propertynames(df) 
                         if any(ismissing, df[!, col])]
    
    if isempty(cols_with_missing)
        summary = "No missing data detected in dataset."
        recommendation = "No MCAR testing needed - dataset is complete."
        
        if verbose
            println("═"^70)
            println("MCAR TEST COMPARISON")
            println("═"^70)
            println(summary)
            println(recommendation)
            println("═"^70)
        end
        
        return MCARTestComparison(
            nothing,
            Dict{Symbol, TestResult}(),
            Dict{Symbol, TestResult}(),
            summary,
            recommendation
        )
    end
    
    # ── 1. RUN LITTLE'S TEST (GLOBAL) ──────────────────────────
    little_result = try
        test_mcar_little(df, alpha=alpha)
    catch e
        @warn "Little's test failed: $e"
        nothing
    end
    
    # ── 2. RUN PAIRWISE TESTS ────────────────────────────────────
    means_results = Dict{Symbol, TestResult}()
    logistic_results = Dict{Symbol, TestResult}()
    
    for col in cols_with_missing
        # Pairwise t-tests (test against all other numeric columns)
        numeric_cols = [c for c in propertynames(df) 
                    if c != col && 
                        eltype(df[!, c]) <: Union{Missing, Number} &&
                        !any(ismissing, df[!, c])]  # ← AJOUT : colonne complète

        if !isempty(numeric_cols)
            # Use first complete numeric predictor for means test
            try
                means_results[col] = test_mcar_means(df, col, numeric_cols[1], alpha=alpha)
            catch e
                @warn "t-test for $col failed: $e"
            end
        end
        
        # Logistic regression
        try
            logistic_results[col] = test_mcar_logistic(df, col, alpha=alpha)
        catch e
            @warn "Logistic test for $col failed: $e"
        end
    end
    
    # ── 3. COMPARE RESULTS ────────────────────────────────────────
    summary, recommendation = _generate_comparison_summary(
        little_result,
        means_results,
        logistic_results,
        alpha
    )
    
    if verbose
        println(summary)
        println()
        println(recommendation)
    end
    
    # ── 4. RESTORE ORIGINAL COLUMN NAMES IN RESULTS ──────────────
    # Re-key the result dicts using original column names so that
    # users see the names they expect, not the sanitized versions.
    
    restored_means = Dict{Symbol, TestResult}()
    for (clean_col, result) in means_results
        orig_col = get(name_mapping, clean_col, clean_col)
        restored_means[orig_col] = result
    end
    
    restored_logistic = Dict{Symbol, TestResult}()
    for (clean_col, result) in logistic_results
        orig_col = get(name_mapping, clean_col, clean_col)
        restored_logistic[orig_col] = result
    end

    return MCARTestComparison(
        little_result,
        restored_means,
        restored_logistic,
        summary,
        recommendation
    )
end

"""
    _generate_comparison_summary(little, means, logistic, alpha) -> (String, String)

Internal function to generate summary and recommendation from test results.
"""
function _generate_comparison_summary(
    little_result::Union{TestResult, Nothing},
    means_results::Dict{Symbol, TestResult},
    logistic_results::Dict{Symbol, TestResult},
    alpha::Float64
)::Tuple{String, String}
    
    io_summary = IOBuffer()
    io_rec = IOBuffer()
    
    println(io_summary, "═"^70)
    println(io_summary, "MCAR TEST COMPARISON - COMPREHENSIVE ANALYSIS")
    println(io_summary, "═"^70)
    println(io_summary)
    
    # ── LITTLE'S TEST RESULT ──────────────────────────────────────
    println(io_summary, "1. LITTLE'S TEST (Global, all variables)")
    println(io_summary, "─"^70)
    
    if !isnothing(little_result)
        println(io_summary, "   Decision: $(uppercase(string(little_result.decision)))")
        println(io_summary, "   p-value:  $(round(little_result.pvalue, digits=4))")
        println(io_summary, "   Chi²:     $(round(little_result.statistic, digits=2)), df = $(little_result.degrees_of_freedom)")
        
        if little_result.decision == MCAR_REJECTED
            println(io_summary, "   ⚠️  MCAR violated globally")
        else
            println(io_summary, "   ✓  No strong evidence against MCAR")
        end
    else
        println(io_summary, "   ❌ Test failed or not applicable")
    end
    println(io_summary)
    
    # ── LOGISTIC REGRESSION RESULTS ───────────────────────────────
    println(io_summary, "2. LOGISTIC REGRESSION (Pairwise, multivariate)")
    println(io_summary, "─"^70)
    
    if !isempty(logistic_results)
        logistic_rejected = [col for (col, result) in logistic_results 
                            if result.decision == MCAR_REJECTED]
        logistic_accepted = [col for (col, result) in logistic_results 
                            if result.decision == MCAR_NOT_REJECTED]
        logistic_inconclusive = [col for (col, result) in logistic_results 
                                if result.decision == INCONCLUSIVE]

        println(io_summary, "   Variables tested: $(length(logistic_results))")
        println(io_summary, "   MCAR rejected:    $(length(logistic_rejected))")
        println(io_summary, "   MCAR accepted:    $(length(logistic_accepted))")
        println(io_summary, "   INCONCLUSIVE:     $(length(logistic_inconclusive))")

        if !isempty(logistic_inconclusive)
            println(io_summary)
            println(io_summary, "   ⚠️  INCONCLUSIVE (insufficient predictors):")
            for col in logistic_inconclusive[1:min(3, length(logistic_inconclusive))]
                println(io_summary, "      • $col")
            end
            if length(logistic_inconclusive) > 3
                println(io_summary, "      ... and $(length(logistic_inconclusive) - 3) more")
            end
        end
        
        if !isempty(logistic_rejected)
            println(io_summary, "   ⚠️  MCAR VIOLATED for:")
            for col in logistic_rejected
                result = logistic_results[col]
                println(io_summary, "      • $col (p = $(round(result.pvalue, digits=4)))")
                
                # Show significant predictors
                sig_preds = get(result.details, "significant_predictors", [])
                if !isempty(sig_preds)
                    pred_names = [p["variable"] for p in sig_preds[1:min(3, length(sig_preds))]]
                    println(io_summary, "        Predictors: $(join(pred_names, ", "))")
                end
            end
        end
        
        if !isempty(logistic_accepted)
            println(io_summary, "   ✓  MCAR ACCEPTED for:")
            for col in logistic_accepted
                println(io_summary, "      • $col (p = $(round(logistic_results[col].pvalue, digits=4)))")
            end
        end
    else
        println(io_summary, "   ❌ No logistic tests completed")
    end
    println(io_summary)
    
    # ── PAIRWISE T-TESTS RESULTS ──────────────────────────────────
    println(io_summary, "3. PAIRWISE T-TESTS (Simple, univariate)")
    println(io_summary, "─"^70)
    
    if !isempty(means_results)
        means_rejected = [col for (col, result) in means_results 
                         if result.decision == MCAR_REJECTED]
        means_accepted = [col for (col, result) in means_results 
                         if result.decision == MCAR_NOT_REJECTED]
        
        println(io_summary, "   Variables tested: $(length(means_results))")
        println(io_summary, "   MCAR rejected:    $(length(means_rejected))")
        println(io_summary, "   MCAR accepted:    $(length(means_accepted))")
        println(io_summary)
        
        if !isempty(means_rejected)
            println(io_summary, "   ⚠️  MCAR VIOLATED for:")
            for col in means_rejected
                println(io_summary, "      • $col (p = $(round(means_results[col].pvalue, digits=4)))")
            end
        end
        
        if !isempty(means_accepted)
            println(io_summary, "   ✓  MCAR ACCEPTED for:")
            for col in means_accepted
                println(io_summary, "      • $col (p = $(round(means_results[col].pvalue, digits=4)))")
            end
        end
    else
        println(io_summary, "   ❌ No t-tests completed")
    end
    println(io_summary)
    
    # ── CONSENSUS ANALYSIS ─────────────────────────────────────────
    println(io_summary, "4. CONSENSUS ANALYSIS")
    println(io_summary, "─"^70)
    
    # Count rejections
    little_rejects = !isnothing(little_result) && little_result.decision == MCAR_REJECTED
    logistic_rejections = count(r -> r.decision == MCAR_REJECTED, values(logistic_results))
    means_rejections = count(r -> r.decision == MCAR_REJECTED, values(means_results))
    
    total_pairwise = length(logistic_results) + length(means_results)
    total_rejections = logistic_rejections + means_rejections
    
    if little_rejects && total_rejections > 0
        consensus = "STRONG AGREEMENT"
        println(io_summary, "   ✓ $consensus: All tests reject MCAR")
        println(io_summary, "   Confidence: HIGH")
        
    elseif !little_rejects && total_rejections == 0
        consensus = "FULL AGREEMENT"
        println(io_summary, "   ✓ $consensus: All tests accept MCAR")
        println(io_summary, "   Confidence: MODERATE")
        println(io_summary, "   ⚠️  Remember: Little's test has low power for weak MAR")
        
    elseif !little_rejects && total_rejections > 0
        consensus = "PARTIAL DISAGREEMENT"
        println(io_summary, "   ⚠️  $consensus: Little accepts, pairwise tests reject")
        println(io_summary, "   Interpretation: Weak or localized MAR detected")
        println(io_summary, "   $total_rejections out of $total_pairwise pairwise tests reject MCAR")
        
    else
        consensus = "MIXED RESULTS"
        println(io_summary, "   ⚠️  $consensus: Inconsistent findings")
        println(io_summary, "   Requires careful interpretation")
    end
    
    println(io_summary)
    println(io_summary, "═"^70)
    
    # ── RECOMMENDATION ─────────────────────────────────────────────
    println(io_rec, "═"^70)
    println(io_rec, "RECOMMENDATION")
    println(io_rec, "═"^70)
    println(io_rec)
    
    if consensus == "STRONG AGREEMENT"
        println(io_rec, "✓ CLEAR VERDICT: MCAR is VIOLATED")
        println(io_rec)
        println(io_rec, "Recommended actions:")
        println(io_rec, "1. Use ADVANCED IMPUTATION methods:")
        println(io_rec, "   • Multiple Imputation (MICE)")
        println(io_rec, "   • Regression imputation")
        println(io_rec, "   • Inverse probability weighting")
        println(io_rec)
        println(io_rec, "2. Include identified predictors in imputation model")
        println(io_rec, "3. Perform sensitivity analysis")
        
    elseif consensus == "FULL AGREEMENT"
        println(io_rec, "✓ TENTATIVE VERDICT: MCAR may hold")
        println(io_rec)
        println(io_rec, "⚠️  CAUTION: Little's test has LOW POWER for weak MAR")
        println(io_rec)
        println(io_rec, "Recommended actions:")
        println(io_rec, "1. CONSERVATIVE APPROACH: Use advanced imputation anyway")
        println(io_rec, "   (MICE works well even under MCAR)")
        println(io_rec)
        println(io_rec, "2. OPTIMISTIC APPROACH: Simple imputation acceptable")
        println(io_rec, "   BUT validate with:")
        println(io_rec, "   • Compare results across imputation methods")
        println(io_rec, "   • Check robustness of conclusions")
        println(io_rec, "   • Use domain knowledge to assess MNAR risk")
        
    elseif consensus == "PARTIAL DISAGREEMENT"
        println(io_rec, "⚠️  VERDICT: MCAR likely VIOLATED (weak or localized MAR)")
        println(io_rec)
        println(io_rec, "Interpretation:")
        println(io_rec, "• Little's test missed violations due to low power")
        println(io_rec, "• Pairwise tests detected weak/localized relationships")
        println(io_rec, "• TRUST the pairwise tests (more sensitive)")
        println(io_rec)
        println(io_rec, "Recommended actions:")
        println(io_rec, "1. Use ADVANCED IMPUTATION")
        println(io_rec, "2. Focus on variables where pairwise tests rejected MCAR")
        println(io_rec, "3. Include identified predictors in imputation")
        
    else
        println(io_rec, "⚠️  VERDICT: INCONCLUSIVE - Complex missing mechanism")
        println(io_rec)
        println(io_rec, "Recommended actions:")
        println(io_rec, "1. Investigate further:")
        println(io_rec, "   • Check data quality")
        println(io_rec, "   • Look for outliers or subgroups")
        println(io_rec, "   • Consider non-linear relationships")
        println(io_rec)
        println(io_rec, "2. Use CONSERVATIVE APPROACH:")
        println(io_rec, "   • Assume MAR/MNAR")
        println(io_rec, "   • Use advanced imputation")
        println(io_rec, "   • Perform extensive sensitivity analysis")
    end
    
    println(io_rec)
    println(io_rec, "═"^70)
    
    return String(take!(io_summary)), String(take!(io_rec))
end

"""
    Base.show(io::IO, comp::MCARTestComparison)

Pretty-print MCARTestComparison results.
"""
function Base.show(io::IO, comp::MCARTestComparison)
    println(io, comp.summary)
    println(io)
    println(io, comp.recommendation)
end