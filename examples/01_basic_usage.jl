# ==============================================================================
# EXAMPLE 1: BASIC USAGE
# ==============================================================================
# Demonstrates: Quick start with synthetic data
# Audience: Beginners, first-time users
# Time to run: < 10 seconds
# ==============================================================================

using MissingDataViz
using DataFrames
using CairoMakie

println("=" ^ 80)
println("EXAMPLE 1: BASIC USAGE - Quick Start with Synthetic Data")
println("=" ^ 80)

# Create simple DataFrame with missing values
df = DataFrame(
    ID = 1:10,
    Age = [25, missing, 35, 42, missing, 28, 31, missing, 45, 38],
    Salary = [50000, 60000, missing, 75000, 55000, missing, 62000, 68000, missing, 71000],
    Department = ["HR", "IT", missing, "Sales", "HR", "IT", missing, "Sales", "HR", "IT"]
)

println("\nDataset overview:")
println("Rows: ", nrow(df))
println("Columns: ", ncol(df))
println("\nFirst 5 rows:")
println(first(df, 5))

# Quick diagnosis
println("\n" * "=" ^ 80)
println("RUNNING DIAGNOSIS...")
println("=" ^ 80)

results = diagnose_missing(df, display=false)

# Print statistics
stats = results[:stats]
println("\n📊 STATISTICS:")
println("  Total cells: ", stats[:total_cells])
println("  Missing cells: ", stats[:total_missing])
println("  Overall percentage: ", round(stats[:overall_percentage], digits=2), "%")

println("\n📋 PER-COLUMN BREAKDOWN:")
total_rows = nrow(df)
for (col, info) in stats[:columns]
    pct = round(info[:percentage], digits=1)
    count = info[:count]
    println("  $col: $pct% missing ($count/$total_rows values)")
end

# Save individual plots
println("\n" * "=" ^ 80)
println("SAVING VISUALIZATIONS...")
println("=" ^ 80)

save("basic_usage_matrix.png", results[:figures][:matrix])
println("✓ Saved: basic_usage_matrix.png")

save("basic_usage_bars.png", results[:figures][:bars])
println("✓ Saved: basic_usage_bars.png")

save("basic_usage_correlation.png", results[:figures][:correlation])
println("✓ Saved: basic_usage_correlation.png")

save("basic_usage_overview.png", results[:figures][:overview])
println("✓ Saved: basic_usage_overview.png")

println("\n" * "=" ^ 80)
println("✅ EXAMPLE 1 COMPLETED SUCCESSFULLY")
println("=" ^ 80)
println("\nGenerated files:")
println("  - basic_usage_matrix.png")
println("  - basic_usage_bars.png")
println("  - basic_usage_correlation.png")
println("  - basic_usage_overview.png")