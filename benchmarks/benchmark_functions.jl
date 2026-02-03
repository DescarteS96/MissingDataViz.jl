# benchmarks/benchmark_functions.jl
# Individual function benchmarks

using MissingDataViz
using BenchmarkTools
using DataFrames
using Random
using Printf

"""
Benchmark individual pattern detection functions across different dataset sizes.
"""
function benchmark_pattern_functions()
    println("="^80)
    println("BENCHMARK: PATTERN DETECTION FUNCTIONS")
    println("="^80)
    
    sizes = [100, 1_000, 10_000, 100_000]
    results = Dict()
    
    for n in sizes
        println("\n📊 Dataset size: $n rows × 10 columns")
        println("-"^80)
        
        # Generate test data
        Random.seed!(42)
        df = DataFrame([
            Symbol("col$i") => rand([1.0, 2.0, 3.0, missing], n) 
            for i in 1:10
        ])
        
        # Benchmark missing_pattern()
        print("  missing_pattern()...        ")
        b1 = @benchmark missing_pattern($df) samples=10 seconds=5
        println("$(BenchmarkTools.prettytime(median(b1).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b1).memory))")
        
        # Benchmark missing_percentage()
        print("  missing_percentage()...     ")
        b2 = @benchmark missing_percentage($df) samples=10 seconds=5
        println("$(BenchmarkTools.prettytime(median(b2).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b2).memory))")
        
        # Benchmark missing_count()
        print("  missing_count()...          ")
        b3 = @benchmark missing_count($df) samples=10 seconds=5
        println("$(BenchmarkTools.prettytime(median(b3).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b3).memory))")
        
        # Benchmark pattern_counts()
        print("  pattern_counts()...         ")
        b4 = @benchmark pattern_counts($df) samples=10 seconds=5
        println("$(BenchmarkTools.prettytime(median(b4).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b4).memory))")
        
        # Benchmark summarize_missing()
        print("  summarize_missing()...      ")
        b5 = @benchmark summarize_missing($df) samples=10 seconds=5
        println("$(BenchmarkTools.prettytime(median(b5).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b5).memory))")
        
        # Store results
        results[n] = Dict(
            :missing_pattern => median(b1),
            :missing_percentage => median(b2),
            :missing_count => median(b3),
            :pattern_counts => median(b4),
            :summarize_missing => median(b5)
        )
    end
    
    return results
end

"""
Benchmark visualization functions (plots).
"""
function benchmark_plot_functions()
    println("\n" * "="^80)
    println("BENCHMARK: VISUALIZATION FUNCTIONS")
    println("="^80)
    
    sizes = [100, 1_000, 10_000]  # Skip 100k for plots (too slow)
    results = Dict()
    
    for n in sizes
        println("\n📊 Dataset size: $n rows × 10 columns")
        println("-"^80)
        
        Random.seed!(42)
        df = DataFrame([
            Symbol("col$i") => rand([1.0, 2.0, missing], n) 
            for i in 1:10
        ])
        
        # Benchmark plot_missing_matrix()
        print("  plot_missing_matrix()...    ")
        b1 = @benchmark plot_missing_matrix($df) samples=5 seconds=10
        println("$(BenchmarkTools.prettytime(median(b1).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b1).memory))")
        
        # Benchmark plot_missing_bars()
        print("  plot_missing_bars()...      ")
        b2 = @benchmark plot_missing_bars($df) samples=5 seconds=10
        println("$(BenchmarkTools.prettytime(median(b2).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b2).memory))")
        
        # Benchmark plot_missing_correlation()
        print("  plot_missing_correlation()...")
        b3 = @benchmark plot_missing_correlation($df) samples=5 seconds=10
        println("$(BenchmarkTools.prettytime(median(b3).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b3).memory))")
        
        # Benchmark plot_missing_overview()
        print("  plot_missing_overview()...  ")
        b4 = @benchmark plot_missing_overview($df) samples=5 seconds=10
        println("$(BenchmarkTools.prettytime(median(b4).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b4).memory))")
        
        results[n] = Dict(
            :plot_matrix => median(b1),
            :plot_bars => median(b2),
            :plot_correlation => median(b3),
            :plot_overview => median(b4)
        )
    end
    
    return results
end

"""
Benchmark report generation functions.
"""
function benchmark_report_functions()
    println("\n" * "="^80)
    println("BENCHMARK: REPORT GENERATION")
    println("="^80)
    
    sizes = [100, 1_000, 10_000]
    results = Dict()
    
    for n in sizes
        println("\n📊 Dataset size: $n rows × 10 columns")
        println("-"^80)
        
        Random.seed!(42)
        df = DataFrame([
            Symbol("col$i") => rand([1.0, 2.0, missing], n) 
            for i in 1:10
        ])
        
        # Benchmark generate_html_report()
        print("  generate_html_report()...   ")
        tmpfile = tempname() * ".html"
        b1 = @benchmark generate_html_report($df, $tmpfile) samples=5 seconds=10
        println("$(BenchmarkTools.prettytime(median(b1).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b1).memory))")
        isfile(tmpfile) && rm(tmpfile)
        
        results[n] = Dict(:generate_report => median(b1))
    end
    
    return results
end