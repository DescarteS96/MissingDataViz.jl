# benchmarks/benchmark_mcar.jl
# Step 13, Part 2D — Performance benchmarks for MCAR tests
#
# Measures execution time of each MCAR component at different dataset sizes.
# Generates a Markdown report with results and scalability analysis.

using MissingDataViz
using DataFrames
using Statistics
using Printf
using Dates

# ══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════

const SIZES = [1_000, 5_000, 10_000, 50_000, 100_000]
const N_COLS = 8          # Fixed number of columns
const MISSING_RATE = 0.15 # 15% missing
const N_REPEATS = 3       # Repeat each benchmark 3 times (median)
const ALPHA = 0.05

const RESULTS_DIR = joinpath(@__DIR__, "results")
mkpath(RESULTS_DIR)

# ══════════════════════════════════════════════════════════════════
# DATA GENERATION
# ══════════════════════════════════════════════════════════════════

"""Generate a DataFrame with controlled missing pattern for benchmarking."""
function generate_benchmark_data(n_rows::Int, n_cols::Int, miss_rate::Float64)
    # All numeric columns (so Little's test can run)
    df = DataFrame()
    for i in 1:n_cols
        df[!, Symbol("x$i")] = Vector{Union{Missing, Float64}}(randn(n_rows))
    end
    
    # Introduce MAR missing in columns 2 through n_cols
    # Missingness in col j depends on col 1 (MAR pattern)
    for j in 2:n_cols
        threshold = quantile(df[!, :x1], 1.0 - miss_rate)
        for i in 1:n_rows
            if df[i, :x1] > threshold && rand() < 0.6
                df[i, Symbol("x$j")] = missing
            end
        end
    end
    
    return df
end

# ══════════════════════════════════════════════════════════════════
# BENCHMARK FUNCTIONS
# ══════════════════════════════════════════════════════════════════

struct BenchmarkResult
    size::Int
    component::String
    times::Vector{Float64}    # All repeat timings
    median_time::Float64
    min_time::Float64
    max_time::Float64
    success::Bool
    error_msg::String
end

"""Benchmark a single component on a single dataset."""
function bench_component(name::String, f::Function, df::DataFrame, n_repeats::Int)
    times = Float64[]
    success = true
    error_msg = ""
    
    for rep in 1:n_repeats
        t = try
            GC.gc()  # Clean GC before each run
            elapsed = @elapsed f(df)
            elapsed
        catch e
            success = false
            error_msg = string(typeof(e))
            NaN
        end
        push!(times, t)
    end
    
    valid_times = filter(!isnan, times)
    med = isempty(valid_times) ? NaN : median(valid_times)
    mn  = isempty(valid_times) ? NaN : minimum(valid_times)
    mx  = isempty(valid_times) ? NaN : maximum(valid_times)
    
    return BenchmarkResult(0, name, times, med, mn, mx, success, error_msg)
end

"""Run all benchmarks for a given dataset size."""
function run_benchmarks_for_size(n_rows::Int)
    println("\n  Generating data: $n_rows rows × $N_COLS cols...")
    df = generate_benchmark_data(n_rows, N_COLS, MISSING_RATE)
    
    actual_missing = round(count(ismissing, Matrix(df)) / (nrow(df) * ncol(df)) * 100, digits=1)
    println("  Actual missing: $actual_missing%")
    
    results = BenchmarkResult[]
    
    # ── Component 1: Little's test ────────────────────────────
    print("    Little's test... ")
    r = bench_component("Little's test", 
        d -> test_mcar_little(d; alpha=ALPHA), df, N_REPEATS)
    r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
    push!(results, r)
    println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
    
    # ── Component 2: Single logistic regression ───────────────
    cols_missing = [c for c in propertynames(df) if any(ismissing, df[!, c])]
    if !isempty(cols_missing)
        print("    Single logistic ($(cols_missing[1]))... ")
        r = bench_component("Logistic (single)",
            d -> test_mcar_logistic(d, cols_missing[1]; alpha=ALPHA), df, N_REPEATS)
        r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
        push!(results, r)
        println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
    end
    
    # ── Component 3: Single t-test ────────────────────────────
    if !isempty(cols_missing)
        complete_numeric = [c for c in propertynames(df) 
                           if c != cols_missing[1] && 
                              eltype(df[!, c]) <: Union{Missing, Number} &&
                              !any(ismissing, df[!, c])]
        if !isempty(complete_numeric)
            print("    Single t-test ($(cols_missing[1]) vs $(complete_numeric[1]))... ")
            r = bench_component("t-test (single)",
                d -> test_mcar_means(d, cols_missing[1], complete_numeric[1]; alpha=ALPHA), df, N_REPEATS)
            r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
            push!(results, r)
            println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
        end
    end
    
    # ── Component 4: compare_mcar_tests (full pipeline) ───────
    print("    compare_mcar_tests (full)... ")
    r = bench_component("compare_mcar_tests",
        d -> compare_mcar_tests(d; alpha=ALPHA, verbose=false), df, N_REPEATS)
    r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
    push!(results, r)
    println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
    
    # ── Component 5: Visualizations (matrix + bars + correlation) ─
    print("    Visualizations (3 plots)... ")
    r = bench_component("Visualizations",
        d -> begin
            plot_missing_matrix(d)
            plot_missing_bars(d)
            plot_missing_correlation(d)
        end, df, N_REPEATS)
    r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
    push!(results, r)
    println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
    
    # ── Component 6: full_missing_diagnosis ────────────────────
    print("    full_missing_diagnosis... ")
    outdir = mktempdir()
    r = bench_component("full_diagnosis",
        d -> full_missing_diagnosis(d;
            output = joinpath(outdir, "report.html"),
            dashboard_file = joinpath(outdir, "dash.png"),
            verbose = false
        ), df, N_REPEATS)
    r = BenchmarkResult(n_rows, r.component, r.times, r.median_time, r.min_time, r.max_time, r.success, r.error_msg)
    push!(results, r)
    println(r.success ? @sprintf("%.3fs (median)", r.median_time) : "FAILED: $(r.error_msg)")
    
    return results
end

# ══════════════════════════════════════════════════════════════════
# REPORT GENERATION
# ══════════════════════════════════════════════════════════════════

function generate_benchmark_report(all_results::Vector{Vector{BenchmarkResult}})
    io = IOBuffer()
    
    println(io, "# MissingDataViz.jl — Performance Benchmark Report")
    println(io, "")
    println(io, "Generated: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))")
    println(io, "")
    println(io, "## Configuration")
    println(io, "")
    println(io, "| Parameter | Value |")
    println(io, "|-----------|-------|")
    println(io, "| Columns | $N_COLS |")
    println(io, "| Missing rate | $(Int(MISSING_RATE*100))% |")
    println(io, "| Repeats per benchmark | $N_REPEATS |")
    println(io, "| Alpha | $ALPHA |")
    println(io, "| Sizes tested | $(join(SIZES, ", ")) |")
    println(io, "")
    
    # ── Summary table ──────────────────────────────────────────
    println(io, "## Summary: Median Time (seconds)")
    println(io, "")
    
    # Get all unique components
    components = unique([r.component for results in all_results for r in results])
    
    # Header
    print(io, "| Component |")
    for s in SIZES
        print(io, " $(s ÷ 1000)k |")
    end
    println(io, "")
    
    # Separator
    print(io, "|-----------|")
    for _ in SIZES
        print(io, "------|")
    end
    println(io, "")
    
    # Data rows
    for comp in components
        print(io, "| $comp |")
        for (i, s) in enumerate(SIZES)
            if i <= length(all_results)
                matching = filter(r -> r.component == comp, all_results[i])
                if !isempty(matching) && matching[1].success
                    t = matching[1].median_time
                    print(io, " $(@sprintf("%.3f", t)) |")
                else
                    print(io, " FAIL |")
                end
            else
                print(io, " — |")
            end
        end
        println(io, "")
    end
    println(io, "")
    
    # ── Scalability analysis ──────────────────────────────────
    println(io, "## Scalability Analysis")
    println(io, "")
    println(io, "Time per 10k rows (seconds):")
    println(io, "")
    
    print(io, "| Component |")
    for s in SIZES
        print(io, " $(s ÷ 1000)k |")
    end
    println(io, "")
    
    print(io, "|-----------|")
    for _ in SIZES
        print(io, "------|")
    end
    println(io, "")
    
    for comp in components
        print(io, "| $comp |")
        for (i, s) in enumerate(SIZES)
            if i <= length(all_results)
                matching = filter(r -> r.component == comp, all_results[i])
                if !isempty(matching) && matching[1].success
                    per_10k = matching[1].median_time / (s / 10_000)
                    print(io, " $(@sprintf("%.3f", per_10k)) |")
                else
                    print(io, " — |")
                end
            else
                print(io, " — |")
            end
        end
        println(io, "")
    end
    println(io, "")
    
    # ── Performance targets ───────────────────────────────────
    println(io, "## Performance Targets")
    println(io, "")
    println(io, "| Target | Threshold | Status |")
    println(io, "|--------|-----------|--------|")
    
    # Check compare_mcar_tests at 10k
    results_10k = length(all_results) >= 3 ? all_results[3] : nothing
    if !isnothing(results_10k)
        cmp = filter(r -> r.component == "compare_mcar_tests", results_10k)
        if !isempty(cmp) && cmp[1].success
            t = cmp[1].median_time
            status = t < 5.0 ? "✓ PASS" : "✗ FAIL"
            println(io, "| compare_mcar_tests @ 10k | < 5s | $status ($(@sprintf("%.2f", t))s) |")
        end
        
        viz = filter(r -> r.component == "Visualizations", results_10k)
        if !isempty(viz) && viz[1].success
            t = viz[1].median_time
            status = t < 2.0 ? "✓ PASS" : "✗ FAIL"
            println(io, "| Visualizations @ 10k | < 2s | $status ($(@sprintf("%.2f", t))s) |")
        end
        
        fd = filter(r -> r.component == "full_diagnosis", results_10k)
        if !isempty(fd) && fd[1].success
            t = fd[1].median_time
            status = t < 10.0 ? "✓ PASS" : "✗ FAIL"
            println(io, "| full_diagnosis @ 10k | < 10s | $status ($(@sprintf("%.2f", t))s) |")
        end
    end
    println(io, "")
    
    # ── Detailed results ──────────────────────────────────────
    println(io, "## Detailed Results")
    println(io, "")
    
    for (i, s) in enumerate(SIZES)
        if i > length(all_results)
            break
        end
        println(io, "### $(s ÷ 1000)k rows")
        println(io, "")
        println(io, "| Component | Median | Min | Max | Status |")
        println(io, "|-----------|--------|-----|-----|--------|")
        
        for r in all_results[i]
            if r.success
                println(io, "| $(r.component) | $(@sprintf("%.3f", r.median_time))s | $(@sprintf("%.3f", r.min_time))s | $(@sprintf("%.3f", r.max_time))s | ✓ |")
            else
                println(io, "| $(r.component) | — | — | — | ✗ $(r.error_msg) |")
            end
        end
        println(io, "")
    end
    
    return String(take!(io))
end

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════

function main()
    println("╔══════════════════════════════════════════════════════════════════╗")
    println("║  MissingDataViz.jl — PERFORMANCE BENCHMARKS                    ║")
    println("║  Step 13, Part 2D                                              ║")
    println("╚══════════════════════════════════════════════════════════════════╝")
    println()
    println("Configuration:")
    println("  Columns:      $N_COLS")
    println("  Missing rate: $(Int(MISSING_RATE*100))%")
    println("  Repeats:      $N_REPEATS")
    println("  Sizes:        $(join(SIZES, ", "))")
    println()
    
    # Warmup run (JIT compilation)
    println("Warming up (JIT compilation)...")
    df_warmup = generate_benchmark_data(100, N_COLS, MISSING_RATE)
    try
        compare_mcar_tests(df_warmup; alpha=ALPHA, verbose=false)
        full_missing_diagnosis(df_warmup; 
            output=joinpath(mktempdir(), "w.html"),
            dashboard_file=joinpath(mktempdir(), "w.png"),
            verbose=false)
    catch end
    println("  ✓ Warmup complete")
    println()
    
    # Run benchmarks
    all_results = Vector{BenchmarkResult}[]
    
    for (i, size) in enumerate(SIZES)
        println("═"^50)
        println("BENCHMARK $i/$(length(SIZES)): $size rows")
        println("═"^50)
        
        results = run_benchmarks_for_size(size)
        push!(all_results, results)
    end
    
    # Generate report
    println()
    println("═"^50)
    println("GENERATING REPORT")
    println("═"^50)
    
    report = generate_benchmark_report(all_results)
    report_path = joinpath(RESULTS_DIR, "benchmark_report.md")
    open(report_path, "w") do f
        write(f, report)
    end
    
    println("\n📄 Report saved: $report_path")
    println()
    
    # Quick summary to console
    println("═"^50)
    println("QUICK SUMMARY")
    println("═"^50)
    
    for (i, size) in enumerate(SIZES)
        if i > length(all_results)
            break
        end
        cmp = filter(r -> r.component == "compare_mcar_tests", all_results[i])
        if !isempty(cmp) && cmp[1].success
            @printf("  %6dk rows → compare_mcar_tests: %.3fs\n", size ÷ 1000, cmp[1].median_time)
        end
    end
end

main()