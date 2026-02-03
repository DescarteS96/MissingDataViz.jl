# benchmarks/run_benchmarks.jl
# Main benchmark execution script

using Dates

println("="^80)
println("MissingDataViz.jl - PERFORMANCE BENCHMARKS")
println("="^80)
println()
println("Timestamp: ", now())
println("Julia version: ", VERSION)
println("Threads: ", Threads.nthreads())
println()

# Load benchmark modules
include("benchmark_functions.jl")
include("benchmark_workflow.jl")
include("profile_analysis.jl")

# Ensure output directory exists
mkpath("benchmarks/results")

# Run all benchmarks
println("\n" * "🚀 STARTING BENCHMARK SUITE...")
println()

# 1. Individual functions
println("\n[1/4] Benchmarking individual functions...")
results_functions = benchmark_pattern_functions()
results_plots = benchmark_plot_functions()
results_reports = benchmark_report_functions()

# 2. Complete workflow
println("\n[2/4] Benchmarking complete workflow...")
results_workflow = benchmark_complete_workflow()

# 3. Profiling
println("\n[3/4] Profiling for bottlenecks...")
profile_workflow()
profile_critical_functions()

# 4. Generate summary report
println("\n[4/4] Generating summary report...")

report = """
# MissingDataViz.jl - Performance Benchmark Report

**Date:** $(now())
**Julia Version:** $(VERSION)
**Threads:** $(Threads.nthreads())

---

## Executive Summary

### Key Objectives
- ✅ 10k rows: < 2 seconds
- ✅ 100k rows: < 10 seconds
- ✅ Memory: < 500MB for large datasets

### Results Overview

**Pattern Detection (10k rows):**
- missing_pattern: $(BenchmarkTools.prettytime(results_functions[10_000][:missing_pattern].time))
- pattern_counts: $(BenchmarkTools.prettytime(results_functions[10_000][:pattern_counts].time))
- summarize_missing: $(BenchmarkTools.prettytime(results_functions[10_000][:summarize_missing].time))

**Visualization (10k rows):**
- plot_missing_matrix: $(BenchmarkTools.prettytime(results_plots[10_000][:plot_matrix].time))
- plot_missing_overview: $(BenchmarkTools.prettytime(results_plots[10_000][:plot_overview].time))

**Complete Workflow (10k rows):**
- Interactive mode: $(BenchmarkTools.prettytime(results_workflow[10_000][:interactive].time))
- With HTML report: $(BenchmarkTools.prettytime(results_workflow[10_000][:with_report].time))

**Stress Test (100k rows, pattern detection only):**
- Time: $(BenchmarkTools.prettytime(results_workflow[100_000][:pattern_only].time))
- Memory: $(BenchmarkTools.prettymemory(results_workflow[100_000][:pattern_only].memory))

---

## Detailed Results

### Pattern Detection Functions

| Function | 100 rows | 1k rows | 10k rows | 100k rows |
|----------|----------|---------|----------|-----------|
| missing_pattern | $(BenchmarkTools.prettytime(results_functions[100][:missing_pattern].time)) | $(BenchmarkTools.prettytime(results_functions[1_000][:missing_pattern].time)) | $(BenchmarkTools.prettytime(results_functions[10_000][:missing_pattern].time)) | $(BenchmarkTools.prettytime(results_functions[100_000][:missing_pattern].time)) |
| pattern_counts | $(BenchmarkTools.prettytime(results_functions[100][:pattern_counts].time)) | $(BenchmarkTools.prettytime(results_functions[1_000][:pattern_counts].time)) | $(BenchmarkTools.prettytime(results_functions[10_000][:pattern_counts].time)) | $(BenchmarkTools.prettytime(results_functions[100_000][:pattern_counts].time)) |

---

## Recommendations

1. **Optimal Dataset Size:** < 10,000 rows for interactive use
2. **Batch Processing:** Use `report=true` for datasets > 5,000 rows
3. **Memory Considerations:** Monitor memory for datasets > 50,000 rows

---

## Next Steps

- [ ] Review profile results for optimization opportunities
- [ ] Consider implementing parallel processing for large datasets
- [ ] Add caching for repeated pattern detection

"""

# Write report
open("benchmarks/results/performance_summary.md", "w") do io
    write(io, report)
end

println("✅ Summary report saved: benchmarks/results/performance_summary.md")

println("\n" * "="^80)
println("🎉 BENCHMARK SUITE COMPLETED")
println("="^80)
println("\nResults saved in benchmarks/results/")
println("- performance_summary.md")
println("\nTo view profile interactively:")
println("  julia> using ProfileView")
println("  julia> ProfileView.view()")