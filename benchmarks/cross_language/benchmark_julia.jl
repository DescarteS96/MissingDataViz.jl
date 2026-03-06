# benchmarks/cross_language/benchmark_julia.jl
# Performance benchmark for MissingDataViz.jl (Julia).
#
# Measures on each dataset:
#   - Load + basic statistics (missing %)
#   - Matrix visualization
#   - Bar chart visualization
#   - Correlation heatmap
#
# Headless mode: CairoMakie backend (no display).
# Each operation repeated 5 times — median reported.
# Results saved as JSON for cross-language aggregation.

using MissingDataViz
using DataFrames
using CSV
using Statistics
using Dates
using Printf
using JSON3

# ── Configuration ──────────────────────────────────────────────
const N_RUNS     = 10
const SCRIPT_DIR = @__DIR__
const DATA_DIR   = joinpath(SCRIPT_DIR, "data")
const OUT_DIR    = joinpath(SCRIPT_DIR, "results")

mkpath(OUT_DIR)

# ── Benchmark helper ───────────────────────────────────────────

"""
    measure(fn; n_runs) -> (median_time_s, peak_mem_mb)

Run fn n_runs times. Return median walltime and peak memory allocation.
"""
function measure(fn::Function; n_runs::Int=N_RUNS)
    times    = Float64[]
    allocs   = Float64[]

    for _ in 1:n_runs
        GC.gc()
        stats  = @timed fn()
        push!(times,  stats.time)
        push!(allocs, stats.bytes / 1024 / 1024)
    end

    return median(times), maximum(allocs)
end

function bench_dataset(path::String, name::String)
    println("\n  Dataset: $name")
    println("  " * "─"^50)

    # Load CSV
    t_load = @elapsed df = CSV.read(path, DataFrame)
    n_rows, n_cols = size(df)
    miss_pct = round(
        sum(count(ismissing, df[!, c]) for c in names(df)) /
        (n_rows * n_cols) * 100, digits=1
    )

    println("  Rows: $(lpad(n_rows, 7)) | Cols: $n_cols | Missing: $miss_pct%")

    result = Dict{String, Any}(
        "dataset"     => name,
        "n_rows"      => n_rows,
        "n_cols"      => n_cols,
        "missing_pct" => miss_pct,
        "load_time_s" => round(t_load, digits=4),
        "tool"        => "MissingDataViz.jl (Julia)",
        "crashed"     => false
    )

    # ── Stats ──────────────────────────────────────────────────
    t, m = measure(() -> missing_percentage(df))
    result["stats_time_s"] = round(t, digits=4)
    result["stats_mem_mb"] = round(m, digits=2)
    @printf("  Stats:       %.4fs | %.1f MB\n", t, m)

    # ── Matrix visualization ───────────────────────────────────
    t, m = measure(() -> plot_missing_matrix(df))
    result["matrix_time_s"] = round(t, digits=4)
    result["matrix_mem_mb"] = round(m, digits=2)
    @printf("  Matrix:      %.4fs | %.1f MB\n", t, m)

    # ── Bar chart ──────────────────────────────────────────────
    t, m = measure(() -> plot_missing_bars(df))
    result["bar_time_s"] = round(t, digits=4)
    result["bar_mem_mb"] = round(m, digits=2)
    @printf("  Bar:         %.4fs | %.1f MB\n", t, m)

    # ── Correlation heatmap ────────────────────────────────────
    t, m = measure(() -> plot_missing_correlation(df))
    result["heatmap_time_s"] = round(t, digits=4)
    result["heatmap_mem_mb"] = round(m, digits=2)
    @printf("  Heatmap:     %.4fs | %.1f MB\n", t, m)

    return result
end

# ── Main ───────────────────────────────────────────────────────

function main()
    println("="^60)
    println("BENCHMARK: MissingDataViz.jl (Julia)")
    println("Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println("Runs per operation: $N_RUNS")
    println("="^60)

    csv_files = sort(filter(f -> endswith(f, ".csv"), readdir(DATA_DIR)))

    if isempty(csv_files)
        println("ERROR: No CSV files in $DATA_DIR")
        println("Run generate_data.py first.")
        return
    end

    # Warmup run to trigger JIT compilation
    println("\nWarming up JIT...")
    warmup_df = CSV.read(joinpath(DATA_DIR, csv_files[1]), DataFrame)
    missing_percentage(warmup_df)
    plot_missing_matrix(warmup_df)
    plot_missing_bars(warmup_df)
    plot_missing_correlation(warmup_df)
    println("  ✓ JIT warmup complete\n")

    all_results = Dict{String, Any}[]

    for filename in csv_files
        path = joinpath(DATA_DIR, filename)
        name = replace(filename, ".csv" => "")

        result = try
            bench_dataset(path, name)
        catch e
            println("  ✗ CRASH: $e")
            Dict{String, Any}(
                "dataset" => name,
                "crashed" => true,
                "error"   => string(e),
                "tool"    => "MissingDataViz.jl (Julia)"
            )
        end

        push!(all_results, result)
    end

    # Save JSON results
    out_path = joinpath(OUT_DIR, "results_julia.json")
    open(out_path, "w") do f
        JSON3.write(f, all_results)
    end
    println("\n✓ Results saved: $out_path")

    # Console summary
    println("\n" * "="^60)
    println("SUMMARY (median times, seconds)")
    println("="^60)
    @printf("  %-25s %7s %8s %8s %8s %8s\n",
        "Dataset", "Rows", "Stats", "Matrix", "Bar", "Heatmap")
    println("  " * "─"^68)

    for r in all_results
        if get(r, "crashed", false)
            @printf("  %-25s CRASHED: %s\n",
                r["dataset"], get(r, "error", "?"))
        else
            @printf("  %-25s %7d %8.4f %8.4f %8.4f %8.4f\n",
                r["dataset"], r["n_rows"],
                r["stats_time_s"], r["matrix_time_s"],
                r["bar_time_s"], r["heatmap_time_s"])
        end
    end
end

main()