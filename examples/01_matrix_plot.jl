# ============================================================================
# MissingDataViz.jl - Matrix Plot Examples
# ============================================================================
# This file demonstrates various use cases of plot_missing_matrix()
# Run each example independently or execute the entire file

using MissingDataViz
using DataFrames
using Random
using CairoMakie

println("="^70)
println("EXAMPLE 1: Basic Usage (Beginner)")
println("="^70)
println("Simple dataset with a few missing values")
println()

# Create simple dataset
df_simple = DataFrame(
    A = [1, missing, 3, 4, 5],
    B = [missing, 2, 3, missing, 5],
    C = [1, 2, 3, 4, 5],
    D = [missing, missing, 3, 4, 5]
)

println("Dataset preview:")
println(df_simple)
println()

# Generate basic plot
fig1 = plot_missing_matrix(df_simple)
display(fig1)

# Save figure
mkpath("docs/images")
save("docs/images/example1_basic.png", fig1, px_per_unit=2)
println("✓ Saved to docs/images/example1_basic.png")
println()

# ============================================================================
println("="^70)
println("EXAMPLE 2: Visual Customization (Intermediate)")
println("="^70)
println("Same dataset with custom appearance")
println()

# Custom visualization options
fig2 = plot_missing_matrix(df_simple;
    figsize = (1200, 700),
    colormap = :viridis,
    show_sparkline = false
)
display(fig2)

save("docs/images/example2_custom.png", fig2, px_per_unit=2)
println("✓ Saved to docs/images/example2_custom.png")
println("✓ Features: larger size, viridis colormap, no sparkline")
println()

# ============================================================================
println("="^70)
println("EXAMPLE 3: Medical Context (Real-world Use Case)")
println("="^70)
println("Patient health records with custom labels")
println()

# Medical dataset
df_medical = DataFrame(
    PatientID = 1:8,
    Age = [25, missing, 45, 60, missing, 35, 50, 42],
    BloodPressure = [120, 130, missing, 150, 140, missing, 135, 128],
    Cholesterol = [200, missing, 220, missing, 250, 210, missing, 195],
    HeartRate = [70, 75, 80, missing, 90, 85, missing, 78],
    BMI = [22.5, 28.3, missing, 31.2, 27.8, missing, 29.5, 24.1]
)

println("Medical dataset preview:")
println(df_medical)
println()

# Plot with medical context labels
fig3 = plot_missing_matrix(df_medical;
    figsize = (1100, 600),
    labels = (
        xlabel = "Clinical Variables",
        ylabel = "Patient ID",
        title = "Missing Medical Data - Quality Assessment",
        colorbar_label = "Record Status",
        colorbar_present = "Recorded",
        colorbar_missing = "Not Recorded",
        sparkline_ylabel = "% Missing"
    )
)
display(fig3)

save("docs/images/example3_medical.png", fig3, px_per_unit=2)
println("✓ Saved to docs/images/example3_medical.png")
println("✓ Features: medical terminology, custom labels")
println()

# ============================================================================
println("="^70)
println("EXAMPLE 4: Large Dataset Performance Test")
println("="^70)
println("Testing performance on 1000×50 dataset")
println()

# Generate large dataset
using Random
Random.seed!(42)
df_large = DataFrame([
    Symbol("var$i") => rand([1.0, 2.0, 3.0, missing], 1000) 
    for i in 1:50
])

println("Dataset size: $(size(df_large))")
println("Generating plot and measuring time...")
println()

# Benchmark
time_start = time()
fig4 = plot_missing_matrix(df_large;
    labels = (title = "Performance Test: 1000×50 Dataset",)
)
time_elapsed = time() - time_start

display(fig4)

save("docs/images/example4_large.png", fig4, px_per_unit=2)
println("✓ Saved to docs/images/example4_large.png")
println("✓ Execution time: $(round(time_elapsed, digits=3)) seconds")

if time_elapsed < 2.0
    println("✓ PASSED: Performance criterion (<2s) met!")
else
    println("⚠ WARNING: Performance slower than target (>2s)")
end
println()

# ============================================================================
println("="^70)
println("EXAMPLE 5: Structured Missing Patterns (Insight)")
println("="^70)
println("Demonstrating MCAR vs MAR patterns")
println()

# Create dataset with different missing mechanisms
Random.seed!(123)
n = 100

df_pattern = DataFrame(
    FullyObserved = rand(n),
    MissingStart = [i <= 30 ? missing : rand() for i in 1:n],  # MAR: missing in first 30%
    RandomMissing = [rand() > 0.7 ? missing : rand() for i in 1:n],  # MCAR: 30% random
    MissingEnd = [i > 70 ? missing : rand() for i in 1:n],  # MAR: missing in last 30%
    SparseObserved = [rand() > 0.85 ? rand() : missing for i in 1:n]  # Only 15% observed
)

println("Pattern dataset statistics:")
println("- FullyObserved: 0% missing")
println("- MissingStart: ~30% missing (beginning rows)")
println("- RandomMissing: ~30% missing (random MCAR)")
println("- MissingEnd: ~30% missing (end rows)")
println("- SparseObserved: ~85% missing")
println()

fig5 = plot_missing_matrix(df_pattern;
    figsize = (1000, 700),
    colormap = :thermal,
    labels = (
        title = "Missing Data Patterns: MCAR vs MAR Comparison",
        xlabel = "Variables (Different Missing Mechanisms)",
        ylabel = "Observation Index"
    )
)
display(fig5)

save("docs/images/example5_pattern.png", fig5, px_per_unit=2)
println("✓ Saved to docs/images/example5_pattern.png")
println("✓ Visual insight: Clear difference between MCAR (random) and MAR (structured)")
println()

# ============================================================================
# ============================================================================
println("="^70)
println("BONUS: Testing on Real Dataset (if RDatasets available)")
println("="^70)

try
    using RDatasets
    
    # Test on Titanic dataset
    println("Loading Titanic dataset...")
    titanic = dataset("datasets", "Titanic")
    
    println("Titanic dataset size: $(size(titanic))")
    
    # Check for missing data
    has_missing = false
    println("Columns with missing data:")
    for col in names(titanic)
        n_missing = count(ismissing, titanic[!, col])
        if n_missing > 0
            pct = round(n_missing / nrow(titanic) * 100, digits=1)
            println("  - $col: $n_missing ($pct%)")
            has_missing = true
        end
    end
    
    if !has_missing
        println("  (No missing data found in Titanic dataset)")
    end
    println()
    
    fig_titanic = plot_missing_matrix(titanic;
        labels = (
            title = "Titanic Dataset - Missing Data Analysis",
            ylabel = "Records"
        )
    )
    display(fig_titanic)
    
    save("docs/images/example6_titanic.png", fig_titanic, px_per_unit=2)
    println("✓ Saved to docs/images/example6_titanic.png")
    println()
    
    # Test on Iris with injected missing
    println("Loading Iris dataset and injecting 20% missing values...")
    iris = dataset("datasets", "iris")
    
    # Create copy with nullable columns
    iris_missing = DataFrame()
    for col in names(iris)
        if eltype(iris[!, col]) <: Number
            # Convert to Union{Float64, Missing}
            iris_missing[!, col] = Vector{Union{Float64, Missing}}(iris[!, col])
        else
            iris_missing[!, col] = iris[!, col]
        end
    end
    
    # Inject 20% missing randomly (only in numeric columns)
    Random.seed!(456)
    for col in names(iris_missing)
        if eltype(iris_missing[!, col]) <: Union{Number, Missing}
            for i in 1:nrow(iris_missing)
                if rand() < 0.2
                    iris_missing[i, col] = missing
                end
            end
        end
    end
    
    println("Injected missing values in $(nrow(iris_missing)) rows")
    println()
    
    fig_iris = plot_missing_matrix(iris_missing;
        labels = (
            title = "Iris Dataset - 20% Missing Injected (MCAR)",
            xlabel = "Iris Features",
            ylabel = "Sample Index"
        ),
        colormap = :plasma
    )
    display(fig_iris)
    
    save("docs/images/example7_iris.png", fig_iris, px_per_unit=2)
    println("✓ Saved to docs/images/example7_iris.png")
    println()
    
catch e
    println("⚠ RDatasets error: $e")
    println("  This is expected if RDatasets not installed or dataset format changed.")
end

# ============================================================================
# ============================================================================
# ============================================================================
println("="^70)
println("PERFORMANCE SUMMARY")
println("="^70)
println()

# Detailed benchmark (if BenchmarkTools available)
benchmark_available = false
try
    # Import BenchmarkTools at module level
    @eval using BenchmarkTools
    benchmark_available = true
catch e
    println("⚠ BenchmarkTools not available or failed to load.")
    println("  Error: $e")
end

if benchmark_available
    try
        println("Running detailed benchmark (this may take a moment)...")
        println()
        
        # Small dataset (10×5)
        df_small = DataFrame([Symbol("col$i") => rand([1,2,missing], 10) for i in 1:5])
        bench_small = @benchmark plot_missing_matrix($df_small) seconds=5
        
        # Medium dataset (100×20)
        df_medium = DataFrame([Symbol("col$i") => rand([1,2,missing], 100) for i in 1:20])
        bench_medium = @benchmark plot_missing_matrix($df_medium) seconds=5
        
        # Large dataset (1000×50)
        df_large_bench = DataFrame([Symbol("col$i") => rand([1,2,missing], 1000) for i in 1:50])
        bench_large = @benchmark plot_missing_matrix($df_large_bench) seconds=5
        
        println("Benchmark Results:")
        println("─"^70)
        println("Small (10×5):")
        println("  Median time: $(round(median(bench_small).time / 1e6, digits=2)) ms")
        println("  Memory: $(round(median(bench_small).memory / 1024^2, digits=2)) MB")
        println()
        println("Medium (100×20):")
        println("  Median time: $(round(median(bench_medium).time / 1e6, digits=2)) ms")
        println("  Memory: $(round(median(bench_medium).memory / 1024^2, digits=2)) MB")
        println()
        println("Large (1000×50):")
        println("  Median time: $(round(median(bench_large).time / 1e6, digits=2)) ms")
        println("  Memory: $(round(median(bench_large).memory / 1024^2, digits=2)) MB")
        println()
        
        # Check performance criterion
        large_time_seconds = median(bench_large).time / 1e9
        if large_time_seconds < 2.0
            println("✓ PERFORMANCE CRITERION MET: $(round(large_time_seconds, digits=3))s < 2.0s")
        else
            println("⚠ PERFORMANCE CRITERION NOT MET: $(round(large_time_seconds, digits=3))s > 2.0s")
        end
        
    catch e
        println("⚠ Benchmark execution failed: $e")
        benchmark_available = false
    end
end

if !benchmark_available
    println("Using simple @time measurement instead:")
    println()
    
    # Fallback to simple timing
    df_test = DataFrame([Symbol("col$i") => rand([1,2,missing], 1000) for i in 1:50])
    println("Timing 1000×50 dataset (3 runs):")
    for i in 1:3
        print("Run $i: ")
        @time plot_missing_matrix(df_test)
    end
    
    println()
    println("Note: Install BenchmarkTools for more accurate measurements:")
    println("  using Pkg; Pkg.add(\"BenchmarkTools\")")
end

println()
println("="^70)
println("ALL EXAMPLES COMPLETED!")
println("="^70)
println()
println("Generated images in docs/images/:")
println("  - example1_basic.png")
println("  - example2_custom.png")
println("  - example3_medical.png")
println("  - example4_large.png")
println("  - example5_pattern.png")
println("  - example6_titanic.png")
println("  - example7_iris.png")
println()
println("Next step: Update README.md with these images!")


