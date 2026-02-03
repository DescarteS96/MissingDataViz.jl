# ==============================================================================
# EXAMPLE 3: COMPLETE ANALYSIS WORKFLOW
# ==============================================================================
# Demonstrates: End-to-end workflow from data to report
# Audience: Advanced users, production use
# Time to run: < 20 seconds
# ==============================================================================

using MissingDataViz
using DataFrames
using CairoMakie
using Dates

println("=" ^ 80)
println("EXAMPLE 3: COMPLETE WORKFLOW - Production-Ready Analysis Pipeline")
println("=" ^ 80)

# Simulate multi-source data integration scenario
println("\n📥 STEP 1: DATA LOADING")
println("-" ^ 80)

df_survey = DataFrame(
    ResponseID = 1:100,
    Q1_Satisfaction = rand([1, 2, 3, 4, 5, missing], 100),
    Q2_Recommendation = rand([1, 2, 3, 4, 5, missing], 100),
    Q3_Quality = rand([1, 2, 3, 4, 5, missing], 100),
    Q4_Support = rand([1, 2, 3, 4, 5, missing], 100),
    Q5_ValueForMoney = rand([1, 2, 3, 4, 5, missing], 100),
    Demographics_Age = rand([18, 25, 35, 45, 55, 65, missing], 100),
    Demographics_Income = rand([30000, 50000, 75000, 100000, missing], 100)
)

println("✓ Loaded survey data: ", nrow(df_survey), " responses, ", ncol(df_survey), " variables")

# Preliminary quality check
println("\n🔍 STEP 2: PRELIMINARY QUALITY CHECK")
println("-" ^ 80)

quick_stats = summarize_missing(df_survey)
println("  Total completeness: ", round(100 - quick_stats.pct_missing, digits=1), "%")

if quick_stats.pct_missing > 20.0
    println("  ⚠️  WARNING: High overall missingness detected")
    println("  → Proceeding with detailed analysis...")
end

# Detailed visual analysis
println("\n📊 STEP 3: VISUAL PATTERN ANALYSIS")
println("-" ^ 80)

results = diagnose_missing(df_survey, display=false)

println("✓ Generated 4 diagnostic plots")
println("✓ Computed missing data statistics")
println("✓ Identified ", length(results[:stats][:columns]), " variables")

# Pattern detection
println("\n🔎 STEP 4: PATTERN DETECTION")
println("-" ^ 80)

patterns = pattern_frequency(df_survey)
println("  Unique missing patterns detected: ", length(patterns))
println("\n  Top 3 most common patterns:")
for (i, (pattern, count)) in enumerate(patterns[1:min(3, length(patterns))])
    pct = round(count / nrow(df_survey) * 100, digits=1)
    pattern_str = join(Int.(pattern), "")
    println("    $i. Pattern $pattern_str: $count rows ($pct%)")
end

# Correlation analysis
println("\n🔗 STEP 5: CORRELATION ANALYSIS")
println("-" ^ 80)

corr_matrix = missing_correlation(df_survey)
max_corr = maximum(filter(!isnan, corr_matrix[corr_matrix .< 1.0]))
min_corr = minimum(filter(!isnan, corr_matrix[corr_matrix .< 1.0]))

println("  Correlation range: [", round(min_corr, digits=2), ", ", round(max_corr, digits=2), "]")

if max_corr > 0.5
    println("  ⚠️  Strong positive correlation detected (>0.5)")
    println("  → Variables tend to be missing together")
elseif min_corr < -0.5
    println("  ⚠️  Strong negative correlation detected (<-0.5)")
    println("  → Non-random missing pattern suspected")
else
    println("  ✓ Weak correlations suggest random missingness (MCAR)")
end

# Decision making
println("\n⚙️  STEP 6: AUTOMATED DECISION LOGIC")
println("-" ^ 80)

high_missing_cols = [
    col for (col, info) in results[:stats][:columns]
    if info[:percentage] > 40.0
]

if !isempty(high_missing_cols)
    println("  ⚠️  CRITICAL: Variables with >40% missing:")
    for col in high_missing_cols
        pct = round(results[:stats][:columns][col][:percentage], digits=1)
        println("    - $col ($pct%) → RECOMMEND EXCLUSION")
    end
else
    println("  ✓ All variables have <40% missing")
    println("  → Dataset suitable for analysis with imputation")
end

# Generate comprehensive outputs
println("\n📤 STEP 7: GENERATING OUTPUTS")
println("-" ^ 80)

# Save all plots
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
save("workflow_overview_$timestamp.png", results[:figures][:overview])
println("✓ Overview plot: workflow_overview_$timestamp.png")

save("workflow_matrix_$timestamp.png", results[:figures][:matrix])
println("✓ Matrix plot: workflow_matrix_$timestamp.png")

# Generate executive report
report_filename = "executive_report_$timestamp.html"
generate_html_report(df_survey, report_filename, title="Data Quality Executive Report")
println("✓ Executive report: $report_filename")

# Export statistics for downstream processing
stats_df = DataFrame(
    variable = collect(keys(results[:stats][:columns])),
    n_missing = [info[:count] for info in values(results[:stats][:columns])],
    pct_missing = [info[:percentage] for info in values(results[:stats][:columns])]
)
sort!(stats_df, :pct_missing, rev=true)

# Could save to CSV here if needed
# CSV.write("missing_stats_$timestamp.csv", stats_df)
println("✓ Statistics table prepared (", nrow(stats_df), " variables)")

println("\n" * "=" ^ 80)
println("✅ COMPLETE WORKFLOW FINISHED SUCCESSFULLY")
println("=" ^ 80)
println("\n📋 SUMMARY:")
println("  • Data analyzed: ", nrow(df_survey), " rows × ", ncol(df_survey), " columns")
println("  • Overall missingness: ", round(quick_stats.pct_missing, digits=1), "%")
println("  • Plots generated: 4 (matrix, bars, correlation, overview)")
println("  • Reports created: 1 HTML executive report")
println("  • Critical variables: ", length(high_missing_cols))
println("\n📂 OUTPUT FILES:")
println("  - workflow_overview_$timestamp.png")
println("  - workflow_matrix_$timestamp.png")
println("  - $report_filename")
println("\n🚀 NEXT STEPS:")
println("  1. Review HTML report for detailed findings")
println("  2. Decide on imputation strategy for critical variables")
println("  3. Document missing data handling in analysis plan")