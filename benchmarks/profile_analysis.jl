# benchmarks/profile_analysis.jl
# Profiling to identify bottlenecks

using MissingDataViz
using Profile
using DataFrames
using Random

"""
Profile the complete workflow to identify performance bottlenecks.
"""
function profile_workflow()
    println("\n" * "="^80)
    println("PROFILING: Identifying Bottlenecks")
    println("="^80)
    
    # Generate medium dataset
    println("\n📊 Profiling dataset: 10,000 rows × 20 columns")
    println("-"^80)
    
    Random.seed!(42)
    df = DataFrame([
        Symbol("col$i") => rand([1.0, 2.0, 3.0, missing], 10_000) 
        for i in 1:20
    ])
    
    # Warm-up (compile functions)
    println("  Warm-up run...")
    diagnose_missing(df, display=false)
    
    # Clear previous profile data
    Profile.clear()
    
    # Profile the workflow
    println("  Running profiler...")
    @profile begin
        for _ in 1:10
            diagnose_missing(df, display=false)
        end
    end
    
    # Print profile results
    println("\n📈 PROFILE RESULTS (Top 20 functions by exclusive time):")
    println("-"^80)
    Profile.print(format=:flat, sortedby=:count, maxdepth=15)
    
    println("\n💡 ANALYSIS:")
    println("-"^80)
    println("  Look for:")
    println("  1. Functions from MissingDataViz.jl with high sample counts")
    println("  2. Repeated allocations (type instability)")
    println("  3. Unnecessary copying of data")
    println("\n  To view interactive flamegraph, use:")
    println("    using ProfileView")
    println("    ProfileView.view()")
end

"""
Profile individual critical functions.
"""
function profile_critical_functions()
    println("\n" * "="^80)
    println("PROFILING: Critical Functions")
    println("="^80)
    
    Random.seed!(42)
    df = DataFrame([
        Symbol("col$i") => rand([1.0, 2.0, missing], 10_000) 
        for i in 1:20
    ])
    
    # Profile pattern_counts (often the slowest)
    println("\n🔍 Profiling: pattern_counts()")
    println("-"^80)
    
    Profile.clear()
    @profile begin
        for _ in 1:50
            pattern_counts(df)
        end
    end
    
    Profile.print(format=:flat, sortedby=:count, maxdepth=10)
    
    # Profile missing_correlation
    println("\n🔍 Profiling: missing_correlation()")
    println("-"^80)
    
    Profile.clear()
    @profile begin
        for _ in 1:50
            missing_correlation(df)
        end
    end
    
    Profile.print(format=:flat, sortedby=:count, maxdepth=10)
end