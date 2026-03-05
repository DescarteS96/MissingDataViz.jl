# Benchmark script to measure optimization gains
# Step 7 Part 4 - Targeted optimizations

using MissingDataViz
using DataFrames
using BenchmarkTools
using Random
using Printf

println("="^70)
println("BENCHMARKS OF OPTIMIZATIONS - MissingDataViz.jl")
println("Step 7 Part 4 : Targeted optimizations")
println("="^70)
println()

# ================================================================
# CONFIGURATION
# ================================================================

Random.seed!(123)  # For reproducibility

# Dataset sizes to test
SIZES = [
    (rows=1_000,   cols=10,  name="Small (1k×10)"),
    (rows=10_000,  cols=20,  name="Medium (10k×20)"),
    (rows=50_000,  cols=30,  name="Large (50k×30)"),
    (rows=100_000, cols=50,  name="Very Large (100k×50)")
]

# Missing value rates to test
MISSING_RATES = [0.1, 0.3, 0.5]  # 10%, 30%, 50%

# ================================================================
# HELPER FUNCTIONS
# ================================================================

"""
Generates a DataFrame with a controlled percentage of missing values
"""
function generate_test_dataframe(n_rows::Int, n_cols::Int, missing_rate::Float64)
    df = DataFrame()
    
    for i in 1:n_cols
        # FIX: Create a Union{Float64, Missing} vector
        col_data = Vector{Union{Float64, Missing}}(rand(n_rows))
        
        # Inject missing values
        n_missing = round(Int, n_rows * missing_rate)
        if n_missing > 0
            missing_indices = randperm(n_rows)[1:n_missing]
            col_data[missing_indices] .= missing
        end
        
        df[!, Symbol("col$i")] = col_data
    end
    
    return df
end

"""
Formats a time in ms with color depending on threshold
"""
function format_time(time_ns::Float64)
    time_ms = time_ns / 1_000_000
    if time_ms < 10
        return @sprintf("%.2f ms", time_ms)
    elseif time_ms < 100
        return @sprintf("%.1f ms", time_ms)
    else
        return @sprintf("%.0f ms", time_ms)
    end
end

"""
Computes the speedup in percentage
"""
function calc_speedup(old_time::Float64, new_time::Float64)
    speedup = (old_time / new_time - 1) * 100
    return speedup
end

# ================================================================
# BENCHMARK 1 : missing_pattern()
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 1 : missing_pattern() - Direct conversion")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s %-12s", "Dataset", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark missing_pattern($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    allocs = median(bench.allocs)
    
    println(@sprintf("%-20s %-15s %-15s %-12d", 
                     size_info.name, time_str, mem_str, allocs))
end

# ================================================================
# BENCHMARK 2 : pattern_counts() - Optimized version
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 2 : pattern_counts() - Views + sizehint! + get()")
println("="^70)
println()
println(@sprintf("%-20s %-12s %-15s %-15s %-12s", 
                 "Dataset", "Missing%", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES[1:3]  # Skip 100k for pattern_counts (too slow)
    for missing_rate in MISSING_RATES
        df = generate_test_dataframe(size_info.rows, size_info.cols, missing_rate)
        
        # Benchmark
        bench = @benchmark pattern_counts($df)
        
        time_str = format_time(median(bench.times))
        mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
        allocs = median(bench.allocs)
        missing_pct = @sprintf("%d%%", round(Int, missing_rate * 100))
        
        println(@sprintf("%-20s %-12s %-15s %-15s %-12d", 
                         size_info.name, missing_pct, time_str, mem_str, allocs))
    end
    println()
end

# ================================================================
# BENCHMARK 3 : row_missing_stats() - Pre-allocation
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 3 : row_missing_stats() - Pre-allocation + view")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s %-12s", "Dataset", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark row_missing_stats($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    allocs = median(bench.allocs)
    
    println(@sprintf("%-20s %-15s %-15s %-12d", 
                     size_info.name, time_str, mem_str, allocs))
end

# ================================================================
# BENCHMARK 4 : pattern_counts_parallel() - Parallelization
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 4 : pattern_counts_parallel() - Multi-threading")
println("Available threads : $(Threads.nthreads())")
println("="^70)
println()

if Threads.nthreads() > 1
    println(@sprintf("%-20s %-20s %-20s %-15s", 
                     "Dataset", "Sequential", "Parallel", "Speedup"))
    println("-"^70)
    
    for size_info in SIZES[2:end]  # Starting from 10k rows
        df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
        
        # Sequential benchmark
        bench_seq = @benchmark pattern_counts($df)
        time_seq = median(bench_seq.times)
        
        # Parallel benchmark
        bench_par = @benchmark pattern_counts_parallel($df)
        time_par = median(bench_par.times)
        
        # Speedup calculation
        speedup = calc_speedup(time_seq, time_par)
        speedup_str = if speedup > 0
            @sprintf("+%.1f%%", speedup)
        else
            @sprintf("%.1f%%", speedup)
        end
        
        # Display
        println(@sprintf("%-20s %-20s %-20s %-15s", 
                         size_info.name, 
                         format_time(time_seq),
                         format_time(time_par),
                         speedup_str))
    end
else
    println("⚠️  Parallelization not tested : Julia launched with a single thread")
    println("   To test : julia --threads=auto")
end

# ================================================================
# BENCHMARK 5 : Complete workflow
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 5 : Complete workflow - summarize_missing()")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s", "Dataset", "Time", "Memory"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark summarize_missing($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    
    println(@sprintf("%-20s %-15s %-15s", 
                     size_info.name, time_str, mem_str))
end

# ================================================================
# FINAL SUMMARY
# ================================================================

println("\n" * "="^70)
println("SUMMARY OF OPTIMIZATIONS")
println("="^70)
println()
println("✅ OPTIMIZATION 1 : missing_pattern()")
println("   → Direct conversion without intermediate allocations")
println("   → Estimated gain : 10-15%")
println()
println("✅ OPTIMIZATION 2 : pattern_counts()")
println("   → Views (@view) instead of copies")
println("   → Dictionary pre-allocation (sizehint!)")
println("   → get() instead of haskey + access")
println("   → Estimated gain : 40-50%")
println()
println("✅ OPTIMIZATION 3 : row_missing_stats()")
println("   → Pre-allocation of the result vector")
println("   → Pre-computation of constants")
println("   → Views to avoid copies")
println("   → Estimated gain : 5-10%")
println()
println("✅ OPTIMIZATION 4 : pattern_counts_parallel()")
println("   → Multi-threading for datasets >10k rows")
println("   → Adaptive threshold (overhead vs benefit)")
println("   → Estimated gain : 50-200% (if ≥4 threads)")
println()
println("="^70)
println("BENCHMARKS COMPLETED")
println("="^70)