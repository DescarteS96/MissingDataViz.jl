# src/full_diagnosis.jl
# All-in-one missing data diagnosis pipeline.
#
# Pipeline:
#   1. Validate input
#   2. Detect missing patterns (statistics)
#   3. Generate visualizations (Phase 1)
#   4. Run MCAR statistical tests (Phase 2, optional)
#   5. Generate HTML report
#   6. Return structured result summary
#
# Design principles:
#   - Single entry point for the full workflow
#   - Sensible defaults (everything on, verbose off)
#   - Every step individually controllable via kwargs
#   - Graceful degradation: partial failure does not crash the pipeline
#   - Returns a structured Dict so results are programmatically accessible

"""
    full_missing_diagnosis(df::DataFrame;
                           output::String          = "missing_report.html",
                           title::String           = "Missing Data Diagnosis",
                           run_mcar_tests::Bool    = true,
                           alpha::Float64          = 0.05,
                           export_dashboard::Bool  = true,
                           dashboard_file::String  = "missing_dashboard.png",
                           verbose::Bool           = false)

Run the complete missing data diagnosis pipeline in a single call.

Executes all phases sequentially:
1. **Input validation** — checks DataFrame integrity
2. **Pattern detection** — computes missing statistics per column
3. **Visualizations** — generates all Phase 1 plots
4. **MCAR tests** — runs Little's, t-tests, and logistic regression (optional)
5. **HTML report** — assembles and saves a self-contained report
6. **Dashboard export** — saves the 2×2 diagnostic dashboard as PNG (optional)

# Arguments

## Required
- `df::DataFrame`: Input dataset to analyze

## Output control
- `output::String="missing_report.html"`: Path for the HTML report
  - Relative paths resolved from `pwd()`
  - Directory must exist
- `title::String="Missing Data Diagnosis"`: Report and dashboard title
- `export_dashboard::Bool=true`: Whether to export the 2×2 dashboard PNG
- `dashboard_file::String="missing_dashboard.png"`: Path for dashboard PNG

## Statistical tests
- `run_mcar_tests::Bool=true`: Whether to run MCAR statistical tests
  - Adds ~2-10s depending on dataset size
  - Includes Little's test, Welch t-tests, logistic regression
- `alpha::Float64=0.05`: Significance threshold for all MCAR tests

## Logging
- `verbose::Bool=false`: Whether to print step-by-step progress logs
  - `false`: Silent execution, only errors surfaced
  - `true`: Detailed logs with timing for each step

# Returns
`Dict{Symbol, Any}` with keys:

| Key               | Type                    | Description                              |
|-------------------|-------------------------|------------------------------------------|
| `:report_path`    | `String`                | Absolute path to HTML report             |
| `:dashboard_path` | `String` or `nothing`   | Absolute path to dashboard PNG           |
| `:stats`          | `Dict`                  | Missing statistics per column            |
| `:mcar_results`   | `MCARTestComparison` or `nothing` | Full MCAR test results        |
| `:n_violations`   | `Int`                   | Number of MCAR violations detected       |
| `:violated_cols`  | `Vector{Symbol}`        | Columns violating MCAR                   |
| `:recommendation` | `String`                | Top-level imputation recommendation      |
| `:elapsed_seconds`| `Float64`               | Total pipeline execution time            |

# Examples
```julia
using DataFrames, MissingDataViz

# ── Minimal call (all defaults) ──────────────────────────────
df = generate_mar_data(300, 5, 0.20)
results = full_missing_diagnosis(df)
println("Report: ", results[:report_path])
println("Violations: ", results[:violated_cols])

# ── Custom output paths ──────────────────────────────────────
results = full_missing_diagnosis(df,
    output           = "/reports/q4_analysis.html",
    dashboard_file   = "/reports/q4_dashboard.png",
    title            = "Q4 2025 Data Quality Report")

# ── Verbose mode for debugging ───────────────────────────────
results = full_missing_diagnosis(df, verbose=true)

# ── Disable MCAR tests for fast turnaround ───────────────────
results = full_missing_diagnosis(df, run_mcar_tests=false)

# ── Strict threshold ─────────────────────────────────────────
results = full_missing_diagnosis(df, alpha=0.01)

# ── Access results programmatically ──────────────────────────
results = full_missing_diagnosis(df)
if !isempty(results[:violated_cols])
    println("⚠ Investigate: ", join(results[:violated_cols], ", "))
end
```

# Performance
- Without MCAR tests: ~300-500ms for datasets <10,000 rows
- With MCAR tests:    +2-10s depending on column count and dataset size

# See Also
- [`generate_html_report`](@ref): Report only, no dashboard export
- [`plot_missing_diagnosis`](@ref): Dashboard plot only
- [`compare_mcar_tests`](@ref): MCAR tests only

# Throws
- `ArgumentError`: If DataFrame is empty or has no columns
- `ErrorException`: If output directory does not exist
"""
function full_missing_diagnosis(
    df::DataFrame;
    output::String         = "missing_report.html",
    title::String          = "Missing Data Diagnosis",
    run_mcar_tests::Bool   = true,
    alpha::Float64         = 0.05,
    export_dashboard::Bool = true,
    dashboard_file::String = "missing_dashboard.png",
    verbose::Bool          = false
)::Dict{Symbol, Any}

    # ── Timing ───────────────────────────────────────────────────
    t_start = time()

    # ── Logging helper ───────────────────────────────────────────
    # Prints only when verbose=true, with elapsed time prefix
    log = (msg) -> verbose && println("[$(round(time()-t_start, digits=2))s] $msg")

    # ── STEP 1: Input Validation ─────────────────────────────────
    log("Step 1/6 — Validating input...")

    isempty(df) &&
        throw(ArgumentError("DataFrame is empty — cannot run diagnosis"))
    ncol(df) == 0 &&
        throw(ArgumentError("DataFrame has no columns — cannot run diagnosis"))

    n_rows, n_cols = size(df)
    log("  ✓ DataFrame: $(n_rows) rows × $(n_cols) columns")

    # ── STEP 2: Pattern Detection ─────────────────────────────────
    log("Step 2/6 — Computing missing data statistics...")

    stats = Dict{String, Any}()
    for col in names(df)
        n_miss = count(ismissing, df[!, col])
        stats[col] = Dict(
            :count      => n_miss,
            :percentage => round(n_miss / n_rows * 100, digits=2)
        )
    end

    total_missing = sum(v[:count] for v in values(stats))
    overall_pct   = round(total_missing / (n_rows * n_cols) * 100, digits=2)

    log("  ✓ Total missing: $(total_missing) / $(n_rows * n_cols) cells ($(overall_pct)%)")

    # ── STEP 3: MCAR Statistical Tests (optional) ─────────────────
    log("Step 3/6 — Running MCAR statistical tests...")

    mcar_results  = nothing
    n_violations  = 0
    violated_cols = Symbol[]

    if run_mcar_tests
        mcar_results = try
            compare_mcar_tests(df; alpha = alpha, verbose = false)
        catch e
            @warn "MCAR tests failed: $(e). Continuing without test results."
            nothing
        end

        if !isnothing(mcar_results)
            # Extract violations from test results
            test_vec = _extract_test_results(mcar_results)
            for r in test_vec
                if r.decision == MCAR_REJECTED
                    parts = split(r.test_name, ": ")
                    if length(parts) == 2
                        push!(violated_cols, Symbol(strip(parts[2])))
                    end
                end
            end
            violated_cols = unique(violated_cols)
            n_violations  = length(violated_cols)

            # Handle Little's test global violation
            little_violated = any(
                r -> r.decision == MCAR_REJECTED && occursin("Little", r.test_name),
                test_vec
            )
            if little_violated && isempty(violated_cols)
                push!(violated_cols, Symbol("global (Little's test)"))
                n_violations = 1
            end

            log("  ✓ MCAR tests complete — $(n_violations) violation(s) detected")
            if !isempty(violated_cols)
                log("  ⚠ Violated columns: $(join(string.(violated_cols), ", "))")
            end
        else
            log("  ⚠ MCAR tests skipped (failed or insufficient data)")
        end
    else
        log("  — MCAR tests disabled (run_mcar_tests=false)")
    end

    # ── STEP 4: Build Recommendation ──────────────────────────────
    log("Step 4/6 — Building recommendation...")

    recommendation = if !run_mcar_tests
        "MCAR tests not run. Use domain knowledge to select imputation strategy."
    elseif isnothing(mcar_results)
        "MCAR tests failed. Inspect data quality before imputing."
    elseif n_violations == 0
        "No MCAR violations detected. Simple imputation (mean/median) is acceptable. " *
        "Multiple imputation (MICE) recommended for conservative analysis."
    else
        col_str = join(string.(violated_cols), ", ")
        "MCAR violated for: $(col_str). " *
        "Use regression-based multiple imputation (MICE). " *
        "Avoid simple mean/median imputation — it will introduce bias."
    end

    log("  ✓ Recommendation ready")

    # ── STEP 5: Export Dashboard PNG (optional) ───────────────────
    log("Step 5/6 — Exporting dashboard...")

    dashboard_path = nothing

    if export_dashboard
        dashboard_path = try
            fig = plot_missing_diagnosis(df;
                title = title,
                alpha = alpha,
                mcar_results = mcar_results
            )
            # Normalize path (same logic as report)
            d_path = isabspath(dashboard_file) ?
                dashboard_file :
                joinpath(pwd(), dashboard_file)
            save(d_path, fig)
            d_path
        catch e
            @warn "Dashboard export failed: $(e). Continuing without dashboard."
            nothing
        end

        if !isnothing(dashboard_path)
            log("  ✓ Dashboard saved: $(dashboard_path)")
        else
            log("  ⚠ Dashboard export failed — skipped")
        end
    else
        log("  — Dashboard export disabled (export_dashboard=false)")
    end

    # ── STEP 6: Generate HTML Report ──────────────────────────────
    log("Step 6/6 — Generating HTML report...")

    report_path = generate_html_report(
        df,
        output;
        title          = title,
        run_mcar_tests = run_mcar_tests,
        alpha          = alpha,
        mcar_results   = mcar_results
    )

    log("  ✓ Report saved: $(report_path)")

    # ── DONE ──────────────────────────────────────────────────────
    elapsed = round(time() - t_start, digits=2)
    log("Pipeline complete in $(elapsed)s")

    if verbose
        println()
        println("=" ^ 50)
        println("DIAGNOSIS SUMMARY")
        println("=" ^ 50)
        println("  Rows × Cols    : $(n_rows) × $(n_cols)")
        println("  Total missing  : $(total_missing) ($(overall_pct)%)")
        println("  MCAR violations: $(n_violations)")
        if !isempty(violated_cols)
            println("  Violated cols  : $(join(string.(violated_cols), ", "))")
        end
        println("  Recommendation : $(recommendation)")
        println("  Report         : $(report_path)")
        if !isnothing(dashboard_path)
            println("  Dashboard      : $(dashboard_path)")
        end
        println("  Elapsed        : $(elapsed)s")
        println("=" ^ 50)
    end

    # ── Return structured result ───────────────────────────────────
    return Dict{Symbol, Any}(
        :report_path     => report_path,
        :dashboard_path  => dashboard_path,
        :stats           => stats,
        :mcar_results    => mcar_results,
        :n_violations    => n_violations,
        :violated_cols   => violated_cols,
        :recommendation  => recommendation,
        :elapsed_seconds => elapsed
    )
end