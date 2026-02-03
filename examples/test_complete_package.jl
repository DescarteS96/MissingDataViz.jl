# ============================================================================
# COMPLETE TEST - MissingDataViz.jl
# ============================================================================
# This script tests all package functionalities
# Execute it from the package directory with:
# julia test_complete_package.jl
# ============================================================================

println("="^70)
println("COMPLETE TEST - MissingDataViz.jl")
println("="^70)

# Step 1: Package activation
println("\n[1/6] Activating package...")
using Pkg
Pkg.activate(".")
Pkg.instantiate()  # Install dependencies if needed
println("✅ Package activated")

# Step 2: Import package
println("\n[2/6] Importing package...")
try
    using MissingDataViz
    using DataFrames
    using CairoMakie
    println("✅ Package imported successfully")
catch e
    println("❌ ERROR during import:")
    println(e)
    exit(1)
end

# Step 3: Create test data
println("\n[3/6] Creating test data...")
df_test = DataFrame(
    Patient_ID = 1:20,
    Name = ["Alice", "Bob", missing, "David", "Eve", 
            "Frank", missing, "Helen", "Ivan", "Jane",
            "Kevin", "Laura", missing, "Mike", "Nina",
            "Oscar", "Paula", missing, "Quinn", "Rachel"],
    Age = [25, missing, 30, missing, 35, 
           28, 32, missing, 27, 31,
           missing, 29, 33, missing, 26,
           30, missing, 34, 28, missing],
    Weight = [65.5, 70.2, missing, 68.0, missing,
              72.5, 69.0, missing, 71.5, 67.0,
              missing, 66.5, 73.0, missing, 64.0,
              68.5, missing, 70.0, 69.5, missing],
    BloodPressure = [120, 130, 125, missing, 128,
                     122, missing, 126, 124, missing,
                     121, 127, missing, 129, 123,
                     missing, 125, 128, missing, 126],
    Cholesterol = [180, missing, 190, 185, missing,
                   195, 188, missing, 192, 187,
                   missing, 189, 193, missing, 186,
                   191, missing, 188, 190, missing],
    Diagnosis = ["Healthy", "At Risk", missing, "Healthy", "At Risk",
                 "Healthy", missing, "At Risk", "Healthy", missing,
                 "At Risk", "Healthy", missing, "At Risk", "Healthy",
                 missing, "At Risk", "Healthy", missing, "At Risk"]
)

println("✅ Test data created (20 rows × 7 columns)")
println("   Total cells: ", nrow(df_test) * ncol(df_test))
println("   Missing values: ", sum(ismissing.(Matrix(df_test))))

# Step 4: Test individual visualizations
println("\n[4/6] Testing individual visualizations...")

try
    println("   • Testing plot_missing_matrix...")
    fig1 = plot_missing_matrix(df_test)
    save("test_output_matrix.png", fig1)
    println("     ✅ Matrix plot created and saved")
    
    println("   • Testing plot_missing_bars...")
    fig2 = plot_missing_bars(df_test)
    save("test_output_bars.png", fig2)
    println("     ✅ Bar chart created and saved")
    
    println("   • Testing plot_missing_correlation...")
    fig3 = plot_missing_correlation(df_test)
    save("test_output_correlation.png", fig3)
    println("     ✅ Correlation matrix created and saved")
    
    println("   • Testing plot_missing_overview...")
    fig4 = plot_missing_overview(df_test)
    save("test_output_overview.png", fig4)
    println("     ✅ Overview dashboard created and saved")
    
    println("✅ All visualizations working")
catch e
    println("❌ ERROR while creating visualizations:")
    println(e)
    exit(1)
end

# Step 5: Test diagnose_missing workflow (interactive mode)
println("\n[5/6] Testing diagnose_missing workflow (interactive mode)...")

try
    results = diagnose_missing(df_test, display=false)
    
    # Verify result structure
    @assert haskey(results, :stats) "Missing :stats key"
    @assert haskey(results, :figures) "Missing :figures key"
    @assert !haskey(results, :report_path) "Should not have :report_path in interactive mode"
    
    # Verify statistics
    stats = results[:stats]
    println("   • Total missing: ", stats[:total_missing])
    println("   • Overall percentage: ", round(stats[:overall_percentage], digits=2), "%")
    
    # Verify figures
    @assert length(results[:figures]) == 4 "Should have 4 figures"
    
    println("✅ Interactive mode working correctly")
catch e
    println("❌ ERROR during interactive test:")
    println(e)
    exit(1)
end

# Step 6: Test HTML report generation
println("\n[6/6] Testing HTML report generation...")

try
    # Test with diagnose_missing
    println("   • Generating with diagnose_missing...")
    results = diagnose_missing(df_test, report=true, output="test_report_diagnose.html")
    
    @assert haskey(results, :report_path) "Missing :report_path"
    @assert isfile(results[:report_path]) "Report file not created"
    
    report_size = filesize(results[:report_path])
    println("     ✅ Report generated: ", results[:report_path])
    println("     ✅ Size: ", round(report_size / 1024, digits=2), " KB")
    
    # Test with direct generate_html_report
    println("   • Generating with generate_html_report...")
    path = generate_html_report(df_test, "test_report_direct.html", 
                                title="Test Report - Direct Generation")
    
    @assert isfile(path) "Direct report file not created"
    
    report_size2 = filesize(path)
    println("     ✅ Report generated: ", path)
    println("     ✅ Size: ", round(report_size2 / 1024, digits=2), " KB")
    
    println("✅ HTML report generation working")
catch e
    println("❌ ERROR during report generation:")
    println(e)
    exit(1)
end

# ============================================================================
# FINAL SUMMARY
# ============================================================================

println("\n" * "="^70)
println("TEST SUMMARY")
println("="^70)

println("\n✅ ALL TESTS PASSED SUCCESSFULLY!")
println("\nFiles created:")
println("  📊 Individual visualizations:")
println("     • test_output_matrix.png")
println("     • test_output_bars.png")
println("     • test_output_correlation.png")
println("     • test_output_overview.png")
println("\n  📄 HTML reports:")
println("     • test_report_diagnose.html")
println("     • test_report_direct.html")

println("\n" * "="^70)
println("PACKAGE VALIDATED - READY TO USE! 🎉")
println("="^70)

println("\nTo open an HTML report:")
if Sys.iswindows()
    println("  > run(`cmd /c start test_report_diagnose.html`)")
elseif Sys.isapple()
    println("  > run(`open test_report_diagnose.html`)")
else
    println("  > run(`xdg-open test_report_diagnose.html`)")
end

println("\nNext steps:")
println("  1. Open test_report_diagnose.html in your browser")
println("  2. Examine the created visualizations")
println("  3. Try with your own data!")
println()



