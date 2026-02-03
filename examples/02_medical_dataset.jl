# ==============================================================================
# EXAMPLE 2: MEDICAL DATASET ANALYSIS
# ==============================================================================
# Demonstrates: Real-world scenario with clinical data
# Audience: Intermediate users, data scientists
# Time to run: < 15 seconds
# ==============================================================================

using MissingDataViz
using DataFrames
using CairoMakie
using Random

println("=" ^ 80)
println("EXAMPLE 2: MEDICAL DATASET - Clinical Data Quality Assessment")
println("=" ^ 80)

# Simulate realistic medical dataset
Random.seed!(42)
n_patients = 50

# Generate realistic medical data with missing patterns
df_medical = DataFrame(
    PatientID = 1:n_patients,
    Age = vcat(rand(25:65, 45), fill(missing, 5)),
    Weight = vcat(rand(50:100, 42), fill(missing, 8)),
    Height = vcat(rand(150:190, 40), fill(missing, 10)),
    BloodPressureSystolic = vcat(rand(110:140, 38), fill(missing, 12)),
    BloodPressureDiastolic = vcat(rand(70:90, 35), fill(missing, 15)),
    Cholesterol = vcat(rand(150:250, 33), fill(missing, 17)),
    Glucose = vcat(rand(70:120, 30), fill(missing, 20)),
    Diagnosis = vcat(rand(["Healthy", "Pre-diabetic", "Diabetic"], 45), fill(missing, 5))
)

println("\n🏥 MEDICAL DATASET OVERVIEW:")
println("  Total patients: ", nrow(df_medical))
println("  Clinical variables: ", ncol(df_medical))
println("\n  Sample data (first 3 patients):")
println(first(df_medical, 3))

# Comprehensive analysis
println("\n" * "=" ^ 80)
println("PERFORMING CLINICAL DATA QUALITY ASSESSMENT...")
println("=" ^ 80)

results = diagnose_missing(df_medical, display=false)

# Detailed statistics
stats = results[:stats]
println("\n📊 DATA COMPLETENESS REPORT:")
println("  Total data points: ", stats[:total_cells])
println("  Complete data points: ", stats[:total_cells] - stats[:total_missing])
println("  Missing data points: ", stats[:total_missing])
println("  Overall completeness: ", round(100 - stats[:overall_percentage], digits=1), "%")

println("\n🔍 VARIABLE-LEVEL ANALYSIS:")
sorted_cols = sort(collect(stats[:columns]), by = x -> x[2][:percentage], rev=true)
for (col, info) in sorted_cols
    pct = round(info[:percentage], digits=1)
    status = pct > 30 ? "⚠️  CRITICAL" : pct > 15 ? "⚠️  WARNING" : "✓ OK"
    println("  $status  $col: $pct% missing")
end

# Identify problematic variables
critical_vars = [col for (col, info) in stats[:columns] if info[:percentage] > 30.0]
if !isempty(critical_vars)
    println("\n⚠️  CRITICAL VARIABLES (>30% missing):")
    for var in critical_vars
        println("  - $var: Recommend imputation or exclusion")
    end
end

# Generate comprehensive report
println("\n" * "=" ^ 80)
println("GENERATING CLINICAL REPORT...")
println("=" ^ 80)

report_path = generate_html_report(
    df_medical, 
    "medical_data_quality_report.html",
    title="Clinical Data Quality Assessment"
)

println("✓ HTML Report saved: $report_path")

# Save key visualizations for presentation
save("medical_overview.png", results[:figures][:overview])
println("✓ Overview plot saved: medical_overview.png")

save("medical_correlation.png", results[:figures][:correlation])
println("✓ Correlation matrix saved: medical_correlation.png")

println("\n" * "=" ^ 80)
println("✅ MEDICAL DATA QUALITY ASSESSMENT COMPLETED")
println("=" ^ 80)
println("\n📋 RECOMMENDATIONS:")
println("  1. Review variables with >30% missing data")
println("  2. Check correlation matrix for non-random missingness patterns")
println("  3. Consider Multiple Imputation for critical variables")
println("  4. Document missing data handling in study protocol")
println("\n📄 Full report: medical_data_quality_report.html")