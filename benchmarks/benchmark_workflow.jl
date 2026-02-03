# benchmarks/benchmark_workflow.jl
# Complete workflow benchmarks

using MissingDataViz
using BenchmarkTools
using DataFrames
using Random
using Printf

"""
Benchmark the complete diagnose_missing() workflow.
This is the most important benchmark as it represents real-world usage.
"""
function benchmark_complete_workflow()
    println("\n" * "="^80)
    println("BENCHMARK: COMPLETE WORKFLOW (diagnose_missing)")
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
        
        # Benchmark interactive mode (no report)
        print("  diagnose_missing (interactive)... ")
        b1 = @benchmark diagnose_missing($df, display=false) samples=5 seconds=15
        println("$(BenchmarkTools.prettytime(median(b1).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b1).memory))")
        
        # Benchmark batch mode (with report)
        print("  diagnose_missing (with report)... ")
        tmpfile = tempname() * ".html"
        b2 = @benchmark diagnose_missing($df, report=true, output=$tmpfile) samples=5 seconds=15
        println("$(BenchmarkTools.prettytime(median(b2).time)) | ",
                "$(BenchmarkTools.prettymemory(median(b2).memory))")
        isfile(tmpfile) && rm(tmpfile)
        
        results[n] = Dict(
            :interactive => median(b1),
            :with_report => median(b2)
        )
    end
    
    # Special test for 100k rows (patterns only, no plots)
    println("\n📊 STRESS TEST: 100,000 rows × 20 columns")
    println("-"^80)
    Random.seed!(42)
    df_large = DataFrame([
        Symbol("col$i") => rand([1.0, 2.0, 3.0, missing], 100_000) 
        for i in 1:20
    ])
    
    print("  Pattern detection only...         ")
    b_pattern = @benchmark begin
        missing_pattern($df_large)
        pattern_counts($df_large)
        summarize_missing($df_large)
    end samples=3 seconds=20
    
    median_time = median(b_pattern).time / 1e9
    println("$(BenchmarkTools.prettytime(median(b_pattern).time)) | ",
            "$(BenchmarkTools.prettymemory(median(b_pattern).memory))")
    
    if median_time < 10.0
        println("  ✅ OBJECTIVE MET: < 10 seconds")
    else
        println("  ⚠️  WARNING: > 10 seconds (objective not met)")
    end
    
    results[100_000] = Dict(:pattern_only => median(b_pattern))
    
    return results
end