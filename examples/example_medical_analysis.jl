# ============================================================================
# COMPLETE EXAMPLE - Medical Data Analysis
# ============================================================================
# Scenario: Patient data analysis to identify data quality issues
# before a clinical study
# ============================================================================

using MissingDataViz
using DataFrames

println("="^70)
println("COMPLETE EXAMPLE - Medical Data Analysis")
println("="^70)

# ============================================================================
# STEP 1: Data Loading
# ============================================================================

println("\n📁 STEP 1: Loading data")
println("-"^70)

# Simulation of realistic medical data
df_medical = DataFrame(
    PatientID = 1:50,
    Age = vcat([25, 30, missing, 45, 28, 32, missing, 38, 42, 29],
               [35, missing, 41, 27, 33, missing, 39, 31, 26, 44],
               [37, 43, missing, 34, 40, 36, missing, 30, 28, 33],
               [31, missing, 42, 38, 29, 35, missing, 41, 27, 34],
               [39, 32, missing, 36, 40, 28, missing, 37, 33, 30]),
    
    Gender = vcat(["M", "F", "M", missing, "F", "M", "F", missing, "M", "F"],
                  ["M", "F", missing, "M", "F", "M", missing, "F", "M", "F"],
                  ["F", "M", "F", missing, "M", "F", "M", missing, "F", "M"],
                  ["F", missing, "M", "F", "M", missing, "F", "M", "F", "M"],
                  ["M", "F", missing, "M", "F", missing, "M", "F", "M", "F"]),
    
    BloodPressure_Systolic = vcat([120, 135, missing, 128, 122, 140, missing, 126, 132, 124],
                                   [130, missing, 125, 138, 121, 136, missing, 127, 123, 142],
                                   [129, 133, missing, 131, 137, 128, missing, 125, 134, 126],
                                   [135, missing, 130, 127, 139, 124, missing, 132, 128, 141],
                                   [126, 131, missing, 136, 129, 133, missing, 127, 138, 125]),
    
    Cholesterol_Total = vcat([180, missing, 195, 188, missing, 205, 192, missing, 198, 185],
                             [190, 202, missing, 187, 199, missing, 193, 186, 208, missing],
                             [194, missing, 189, 203, 191, missing, 197, 188, 200, missing],
                             [196, 184, missing, 206, 190, missing, 195, 192, 201, missing],
                             [189, missing, 198, 185, 204, missing, 193, 187, 199, missing]),
    
    BMI = vcat([22.5, 28.3, missing, 25.1, missing, 30.2, 24.8, missing, 27.5, 23.9],
               [26.4, missing, 24.2, 29.1, missing, 25.7, 28.8, missing, 23.4, 31.5],
               [25.9, 27.8, missing, 26.2, missing, 24.5, 29.6, missing, 25.3, 28.1],
               [24.9, missing, 27.2, 26.8, missing, 25.4, 30.1, missing, 24.1, 28.9],
               [26.5, missing, 25.8, 27.4, missing, 26.1, 29.3, missing, 25.2, 27.9]),
    
    Glucose_Fasting = vcat([95, 102, missing, 98, 105, missing, 92, 108, missing, 96],
                           [100, missing, 94, 110, 97, missing, 103, 99, missing, 93],
                           [101, 106, missing, 98, 104, missing, 95, 107, missing, 99],
                           [102, missing, 97, 109, 96, missing, 100, 98, missing, 94],
                           [105, 101, missing, 99, 103, missing, 98, 106, missing, 97]),
    
    Diagnosis = vcat(["Normal", "Pre-diabetic", missing, "Normal", "At Risk", 
                      "Pre-diabetic", missing, "At Risk", "Normal", missing],
                     ["Normal", "At Risk", missing, "Pre-diabetic", "Normal",
                      missing, "At Risk", "Normal", "Pre-diabetic", missing],
                     ["Normal", missing, "At Risk", "Pre-diabetic", "Normal",
                      missing, "At Risk", "Normal", missing, "Pre-diabetic"],
                     ["At Risk", missing, "Normal", "Pre-diabetic", "At Risk",
                      missing, "Normal", "At Risk", missing, "Pre-diabetic"],
                     ["Normal", "At Risk", missing, "Pre-diabetic", "Normal",
                      missing, "At Risk", "Pre-diabetic", missing, "Normal"])
)

println("✅ Data loaded: ", nrow(df_medical), " patients × ", ncol(df_medical), " variables")
println("   Variables: ", join(names(df_medical), ", "))

# ============================================================================
# STEP 2: Quick analysis with diagnose_missing
# ============================================================================

println("\n📊 STEP 2: Quick data quality analysis")
println("-"^70)

results = diagnose_missing(df_medical, display=false, verbose=true)

# Display key statistics
stats = results[:stats]
println("\n📈 Overall statistics:")
println("   • Total cells: ", stats[:total_cells])
println("   • Total missing: ", stats[:total_missing])
println("   • Overall percentage: ", round(stats[:overall_percentage], digits=2), "%")

# Analyze by variable
println("\n📋 Detail by variable:")
for (col, col_stats) in sort(collect(stats[:columns]), by=x->x[2][:percentage], rev=true)
    pct = round(col_stats[:percentage], digits=1)
    count = col_stats[:count]
    
    # Severity badge
    badge = if pct == 0
        "✅"
    elseif pct < 10
        "⚠️ "
    elseif pct < 25
        "⚠️⚠️ "
    else
        "🔴"
    end
    
    println("   $badge $col: $count/$(nrow(df_medical)) ($pct%)")
end

# ============================================================================
# STEP 3: Generate complete HTML report
# ============================================================================

println("\n📄 STEP 3: HTML report generation")
println("-"^70)

report_results = diagnose_missing(
    df_medical,
    report=true,
    output="medical_data_quality_report.html",
    verbose=true
)

println("\n✅ Report generated: ", report_results[:report_path])
println("   Size: ", round(filesize(report_results[:report_path]) / 1024, digits=2), " KB")

# ============================================================================
# STEP 4: Decisions based on analysis
# ============================================================================

println("\n🎯 STEP 4: Action recommendations")
println("-"^70)

# Identify problematic variables
problematic_vars = [
    col for (col, col_stats) in stats[:columns]
    if col_stats[:percentage] > 20
]

if !isempty(problematic_vars)
    println("\n⚠️  Variables with >20% missing data:")
    for var in problematic_vars
        pct = round(stats[:columns][var][:percentage], digits=1)
        println("   • $var ($pct%)")
    end
    println("\n   Recommendations:")
    println("   1. Check collection protocols for these variables")
    println("   2. Consider imputation or exclusion of these variables")
    println("   3. Consult medical team about importance of these measurements")
else
    println("✅ No variables with >20% missing data")
end

# Check if some patients have a lot of missing data
println("\n👥 Patient analysis:")
row_missing = [count(ismissing, row) for row in eachrow(df_medical)]
max_missing = maximum(row_missing)
patients_high_missing = sum(row_missing .> (ncol(df_medical) * 0.3))

if patients_high_missing > 0
    println("   ⚠️  $patients_high_missing patients with >30% missing data")
    println("   Recommendation: Examine these cases individually")
else
    println("   ✅ All patients have <30% missing data")
end

# ============================================================================
# STEP 5: Export individual visualizations
# ============================================================================

println("\n💾 STEP 5: Export individual visualizations")
println("-"^70)

using CairoMakie

# Export each visualization
figs = results[:figures]

save("medical_matrix.png", figs[:matrix])
println("   ✅ Saved: medical_matrix.png")

save("medical_bars.png", figs[:bars])
println("   ✅ Saved: medical_bars.png")

save("medical_correlation.png", figs[:correlation])
println("   ✅ Saved: medical_correlation.png")

save("medical_overview.pdf", figs[:overview])  # PDF for high quality
println("   ✅ Saved: medical_overview.pdf (high quality)")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

println("\n" * "="^70)
println("ANALYSIS COMPLETED")
println("="^70)

println("\n📁 Files generated:")
println("   • medical_data_quality_report.html (complete report)")
println("   • medical_matrix.png")
println("   • medical_bars.png")
println("   • medical_correlation.png")
println("   • medical_overview.pdf")

println("\n🎯 Next steps:")
println("   1. Open medical_data_quality_report.html for complete review")
println("   2. Share PNG visualizations with team")
println("   3. Use PDF for presentation")
println("   4. Decide on corrective actions based on analysis")

println("\n" * "="^70)
println("To open the report:")
if Sys.iswindows()
    println("  julia> run(`cmd /c start medical_data_quality_report.html`)")
elseif Sys.isapple()
    println("  julia> run(`open medical_data_quality_report.html`)")
else
    println("  julia> run(`xdg-open medical_data_quality_report.html`)")
end
println("="^70)
println()
