# =============================================================================
# STEP 13 — PART 1: Validation on Real Datasets
# =============================================================================
# This script validates MissingDataViz.jl on 5 public datasets with real
# missing values. It runs the full pipeline (patterns + visualizations +
# MCAR tests) and produces a structured comparison report.
#
# DATASETS:
#   1. Adult/Census Income   (~48k rows)  — UCI  — Marketing/Demographics
#   2. Diabetes 130-US       (~100k rows) — UCI  — Medical
#   3. Online Retail II      (~500k rows) — UCI  — Finance/Commerce
#   4. NYC Airbnb            (~49k rows)  — Kaggle — Marketing/Real Estate
#   5. Melbourne Housing     (~34k rows)  — Kaggle — Finance/Real Estate
#
# USAGE:
#   cd MissingDataViz/
#   julia --project=test examples/validation/validate_real_datasets.jl
#
# PREREQUISITES:
#   - CSV.jl in test/Project.toml
#   - All 5 datasets in data/ folder (see download guide)
# =============================================================================

using CSV
using DataFrames
using MissingDataViz
using CairoMakie
using Statistics
using Dates

# ─── CONFIGURATION ───────────────────────────────────────────────────────────

const DATA_DIR   = joinpath(@__DIR__, "..", "..", "data")
const OUTPUT_DIR = joinpath(@__DIR__, "results")

# Create output directory if it doesn't exist
mkpath(OUTPUT_DIR)

# ─── DATASET DEFINITIONS ────────────────────────────────────────────────────
# Each dataset has specific loading requirements (headers, missing strings,
# separators). Getting these wrong = silent failure (strings instead of missing).

struct DatasetConfig
    name::String
    filename::String
    domain::String
    description::String
    missingstrings::Vector{String}
    header::Bool                      # false = no header row in file
    colnames::Vector{String}          # manual column names (if header=false)
    separator::Char
    decimal::Char                     # decimal separator ('.' or ',')
    max_rows::Union{Int, Nothing}     # limit rows for very large datasets
    notes::String
end

const DATASETS = [
    DatasetConfig(
        "Adult/Census Income",
        "adult.csv",
        "Marketing/Demographics",
        "US Census data. Missing in workclass, occupation, native_country.",
        ["?", " ?"],       # UCI uses "?" with optional leading space
        false,             # NO header row
        ["age", "workclass", "fnlwgt", "education", "education_num",
         "marital_status", "occupation", "relationship", "race", "sex",
         "capital_gain", "capital_loss", "hours_per_week", "native_country",
         "income"],
        ',',
        '.',
        nothing,
        "Leading spaces in values — CSV.jl strips them if missingstring includes ' ?'"
    ),

    DatasetConfig(
        "Diabetes 130-US Hospitals",
        "diabetic_data.csv",
        "Medical",
        "Hospital readmission data. Missing in weight, payer_code, medical_specialty, diag_3.",
        ["?"],
        true,
        String[],
        ',',
        '.',
        nothing,           # Full dataset (~100k rows)
        "Many '?' encoded missing values. Some columns nearly 100% missing (weight ~97%)."
    ),

    DatasetConfig(
        "Online Retail II",
        "online_retail.csv",
        "Finance/Commerce",
        "UK retailer transactions. Missing in CustomerID, Description.",
        ["", "NA"],
        true,
        String[],
        '\t',              # Tab-separated (exported from XLSX)
        ',',               # European decimal comma (2,55 = 2.55)
        100_000,           # Limit to 100k rows (full dataset is ~500k+)
        "Tab-separated file. Price uses European decimal comma. Limit to 100k rows."
    ),

    DatasetConfig(
        "NYC Airbnb",
        "nyc_airbnb.csv",
        "Marketing/Real Estate",
        "Airbnb listings NYC 2019. Missing in reviews_per_month, last_review, name, host_name.",
        ["", "NA"],
        true,
        String[],
        ',',
        '.',
        nothing,
        "reviews_per_month missing = listing has 0 reviews (structural missing)."
    ),

    DatasetConfig(
        "Melbourne Housing",
        "melbourne_housing.csv",
        "Finance/Real Estate",
        "Melbourne property sales. Missing in BuildingArea, YearBuilt, CouncilArea, etc.",
        ["", "NA"],
        true,
        String[],
        ',',
        '.',
        nothing,
        "Multiple columns with varying missing rates. Good test for pattern diversity."
    )
]

# ─── LOADING FUNCTION ───────────────────────────────────────────────────────

"""
    load_dataset(config::DatasetConfig) -> DataFrame

Load a dataset from CSV with correct missing value handling.
Returns the DataFrame ready for MissingDataViz analysis.
"""
function load_dataset(config::DatasetConfig)::DataFrame
    filepath = joinpath(DATA_DIR, config.filename)

    if !isfile(filepath)
        error("File not found: $(filepath)\n" *
              "Download it following the guide in examples/validation/README.md")
    end

    println("  Loading $(config.filename)...")

    # Build CSV.read kwargs based on config
    kwargs = Dict{Symbol, Any}(
        :missingstring => config.missingstrings,
        :delim         => config.separator,
        :decimal       => config.decimal,
    )

    # Handle files without headers
    if !config.header
        kwargs[:header] = false
    end

    # Limit rows for very large datasets
    if !isnothing(config.max_rows)
        kwargs[:limit] = config.max_rows
    end

    df = CSV.read(filepath, DataFrame; kwargs...)

    # Apply manual column names if no header
    if !config.header && !isempty(config.colnames)
        if ncol(df) == length(config.colnames)
            rename!(df, Symbol.(config.colnames))
        else
            @warn "Column count mismatch: file has $(ncol(df)), " *
                  "expected $(length(config.colnames)). Using default names."
        end
    end

    # Sanitize column names: replace spaces and special chars with underscores
    # This prevents @formula parsing errors in GLM.jl (e.g. "Customer ID" → "Customer_ID")
    for col in names(df)
        clean_name = replace(col, r"[^a-zA-Z0-9_]" => "_")
        if clean_name != col
            rename!(df, col => clean_name)
        end
    end

    # Warn if suspiciously few columns (likely CSV parsing issue)
    if ncol(df) < 5 && config.name != ""
        @warn "$(config.name): Only $(ncol(df)) columns detected. " *
              "Check CSV separator and quoting. Expected 5+ columns for most datasets."
    end

    println("  ✓ Loaded: $(nrow(df)) rows × $(ncol(df)) columns")
    return df
end

# ─── ANALYSIS FUNCTION ──────────────────────────────────────────────────────

"""
    ValidationResult

Stores all analysis results for a single dataset.
"""
struct ValidationResult
    name::String
    domain::String
    n_rows::Int
    n_cols::Int
    total_missing_pct::Float64
    columns_with_missing::Vector{Tuple{String, Float64}}  # (name, pct)
    n_unique_patterns::Int
    mcar_comparison::Union{MCARTestComparison, Nothing}
    little_pvalue::Union{Float64, Nothing}
    little_decision::String
    n_mcar_violations::Int
    violated_columns::Vector{String}
    elapsed_seconds::Float64
    notes::String
end

"""
    analyze_dataset(config::DatasetConfig) -> ValidationResult

Run the full MissingDataViz pipeline on a dataset and collect results.
"""
function analyze_dataset(config::DatasetConfig)::ValidationResult
    t_start = time()
    println("\n" * "="^70)
    println("ANALYZING: $(config.name) [$(config.domain)]")
    println("="^70)

    # ── Load data ──────────────────────────────────────────────
    df = load_dataset(config)

    # ── Missing statistics ─────────────────────────────────────
    println("  Computing missing statistics...")
    n_rows, n_cols = size(df)

    # Per-column missing percentages
    col_missing = Tuple{String, Float64}[]
    for col in names(df)
        n_miss = count(ismissing, df[!, col])
        pct = round(n_miss / n_rows * 100, digits=2)
        if n_miss > 0
            push!(col_missing, (col, pct))
        end
    end

    # Sort by missing percentage (descending)
    sort!(col_missing, by=x -> x[2], rev=true)

    total_cells = n_rows * n_cols
    total_missing = sum(count(ismissing, df[!, col]) for col in names(df))
    total_pct = round(total_missing / total_cells * 100, digits=2)

    println("  ✓ Overall missing: $(total_pct)%")
    println("  ✓ Columns with missing: $(length(col_missing)) / $(n_cols)")

    # ── Pattern detection ──────────────────────────────────────
    println("  Detecting patterns...")
    n_patterns = 0
    try
        patterns = pattern_counts(df)
        n_patterns = length(patterns)
        println("  ✓ Unique missing patterns: $(n_patterns)")
    catch e
        @warn "pattern_counts failed: $e"
    end

    # ── MCAR tests ─────────────────────────────────────────────
    println("  Running MCAR tests...")
    mcar_comp = nothing
    little_pval = nothing
    little_dec = "NOT RUN"
    n_violations = 0
    violated = String[]

    try
        mcar_comp = compare_mcar_tests(df; alpha=0.05, verbose=false)

        # Extract Little's test result
        if !isnothing(mcar_comp.little_result)
            little_pval = mcar_comp.little_result.pvalue
            little_dec = string(mcar_comp.little_result.decision)
        else
            little_dec = "FAILED"
        end

        # Extract violations from logistic + means
        for (col, result) in mcar_comp.logistic_results
            if result.decision == MCAR_REJECTED
                push!(violated, string(col))
            end
        end
        for (col, result) in mcar_comp.means_results
            if result.decision == MCAR_REJECTED && !(string(col) in violated)
                push!(violated, string(col))
            end
        end
        n_violations = length(violated)

        println("  ✓ MCAR tests complete")
        println("    Little's p-value: $(isnothing(little_pval) ? "N/A" : round(little_pval, digits=6))")
        println("    Little's decision: $(little_dec)")
        println("    Violations detected: $(n_violations)")
    catch e
        @warn "MCAR tests failed for $(config.name): $e"
        little_dec = "ERROR: $(sprint(showerror, e))"
    end

    # ── Visualizations (save to output dir) ────────────────────
    println("  Generating visualizations...")
    safe_name = replace(lowercase(config.name), r"[^a-z0-9]" => "_")

    try
        fig_matrix = plot_missing_matrix(df)
        save(joinpath(OUTPUT_DIR, "$(safe_name)_matrix.png"), fig_matrix)
        println("  ✓ Matrix plot saved")
    catch e
        @warn "Matrix plot failed: $e"
    end

    try
        fig_bars = plot_missing_bars(df)
        save(joinpath(OUTPUT_DIR, "$(safe_name)_bars.png"), fig_bars)
        println("  ✓ Bar chart saved")
    catch e
        @warn "Bar chart failed: $e"
    end

    try
        fig_corr = plot_missing_correlation(df)
        save(joinpath(OUTPUT_DIR, "$(safe_name)_correlation.png"), fig_corr)
        println("  ✓ Correlation plot saved")
    catch e
        @warn "Correlation plot failed: $e"
    end

    elapsed = round(time() - t_start, digits=2)
    println("\n  ✅ Analysis complete in $(elapsed)s")

    return ValidationResult(
        config.name,
        config.domain,
        n_rows,
        n_cols,
        total_pct,
        col_missing,
        n_patterns,
        mcar_comp,
        little_pval,
        little_dec,
        n_violations,
        violated,
        elapsed,
        config.notes
    )
end

# ─── REPORT GENERATION ──────────────────────────────────────────────────────

"""
    generate_validation_report(results::Vector{ValidationResult})

Generate a Markdown report summarizing validation across all datasets.
"""
function generate_validation_report(results::Vector{ValidationResult})
    report_path = joinpath(OUTPUT_DIR, "validation_report.md")
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")

    open(report_path, "w") do io
        println(io, "# MissingDataViz.jl — Validation Report (Step 13, Part 1)")
        println(io, "")
        println(io, "Generated: $(timestamp)")
        println(io, "")

        # ── Summary table ──────────────────────────────────────
        println(io, "## 1. Dataset Summary")
        println(io, "")
        println(io, "| Dataset | Domain | Rows | Cols | Missing % | Cols w/ Missing | Patterns | Time (s) |")
        println(io, "|---------|--------|------|------|-----------|-----------------|----------|----------|")

        for r in results
            println(io, "| $(r.name) | $(r.domain) | $(r.n_rows) | $(r.n_cols) | " *
                        "$(r.total_missing_pct)% | $(length(r.columns_with_missing)) | " *
                        "$(r.n_unique_patterns) | $(r.elapsed_seconds) |")
        end
        println(io, "")

        # ── MCAR test results ──────────────────────────────────
        println(io, "## 2. MCAR Test Results")
        println(io, "")
        println(io, "| Dataset | Little's p-value | Little's Decision | Violations | Violated Columns |")
        println(io, "|---------|------------------|-------------------|------------|------------------|")

        for r in results
            pval_str = isnothing(r.little_pvalue) ? "N/A" : string(round(r.little_pvalue, digits=6))
            violated_str = isempty(r.violated_columns) ? "—" : join(r.violated_columns, ", ")
            println(io, "| $(r.name) | $(pval_str) | $(r.little_decision) | " *
                        "$(r.n_mcar_violations) | $(violated_str) |")
        end
        println(io, "")

        # ── Per-dataset details ────────────────────────────────
        println(io, "## 3. Per-Dataset Details")
        println(io, "")

        for r in results
            println(io, "### $(r.name) ($(r.domain))")
            println(io, "")
            println(io, "**Size**: $(r.n_rows) rows × $(r.n_cols) columns")
            println(io, "")
            println(io, "**Missing columns** (sorted by % missing):")
            println(io, "")
            println(io, "| Column | Missing % |")
            println(io, "|--------|-----------|")
            for (col, pct) in r.columns_with_missing
                println(io, "| $(col) | $(pct)% |")
            end
            println(io, "")
            println(io, "**MCAR diagnosis**: $(r.little_decision)")
            if !isempty(r.violated_columns)
                println(io, "")
                println(io, "**Violations**: $(join(r.violated_columns, ", "))")
            end
            println(io, "")
            println(io, "**Notes**: $(r.notes)")
            println(io, "")
            println(io, "---")
            println(io, "")
        end

        # ── Comparison placeholder ─────────────────────────────
        println(io, "## 4. Comparison with R/Python (Manual)")
        println(io, "")
        println(io, "Fill in after running equivalent analyses in R (naniar) and Python (missingno).")
        println(io, "")
        println(io, "| Dataset | Metric | MissingDataViz.jl | R (naniar) | Python (missingno) | Divergence? |")
        println(io, "|---------|--------|-------------------|------------|--------------------| ------------|")
        for r in results
            println(io, "| $(r.name) | Missing % | $(r.total_missing_pct)% | — | — | — |")
            pval_str = isnothing(r.little_pvalue) ? "N/A" : string(round(r.little_pvalue, digits=4))
            println(io, "| $(r.name) | Little's p | $(pval_str) | — | — | — |")
        end
        println(io, "")
        println(io, "### How to Compare")
        println(io, "")
        println(io, "**R (naniar + mice)**:")
        println(io, "```r")
        println(io, "library(naniar)")
        println(io, "library(mice)")
        println(io, "# Load dataset")
        println(io, "df <- read.csv(\"data/adult.csv\", header=FALSE, na.strings=c(\"?\", \" ?\"))")
        println(io, "# Missing summary")
        println(io, "miss_var_summary(df)")
        println(io, "# Little's MCAR test")
        println(io, "mcar_test(df)  # from naniar")
        println(io, "```")
        println(io, "")
        println(io, "**Python (missingno + scipy)**:")
        println(io, "```python")
        println(io, "import pandas as pd")
        println(io, "import missingno as msno")
        println(io, "# Load dataset")
        println(io, "df = pd.read_csv('data/adult.csv', header=None, na_values=['?', ' ?'])")
        println(io, "# Missing summary")
        println(io, "df.isnull().sum() / len(df) * 100")
        println(io, "# Visualizations")
        println(io, "msno.matrix(df)")
        println(io, "msno.heatmap(df)")
        println(io, "```")
        println(io, "")

        # ── Known divergence sources ───────────────────────────
        println(io, "## 5. Expected Divergence Sources")
        println(io, "")
        println(io, "When comparing results across Julia/R/Python, expect these differences:")
        println(io, "")
        println(io, "1. **Little's test p-values**: Small numerical differences due to different ")
        println(io, "   chi-squared implementations and EM convergence criteria. Differences <0.01 ")
        println(io, "   in p-value are normal. Decisions (reject/accept) should agree.")
        println(io, "")
        println(io, "2. **Logistic regression coefficients**: GLM.jl vs R glm() vs Python ")
        println(io, "   statsmodels may use different optimization algorithms (IRLS vs Newton). ")
        println(io, "   p-values should be close but not identical.")
        println(io, "")
        println(io, "3. **Missing percentages**: Should be IDENTICAL. Any divergence here means ")
        println(io, "   different missing value encoding (e.g., '?' not recognized as missing).")
        println(io, "")
        println(io, "4. **Welch t-test results**: Should match closely. R uses `t.test()`, ")
        println(io, "   Python uses `scipy.stats.ttest_ind(equal_var=False)`. Differences in ")
        println(io, "   degrees of freedom rounding may cause minor p-value differences.")
        println(io, "")
    end

    println("\n📄 Report saved: $(report_path)")
    return report_path
end

# ─── MAIN EXECUTION ─────────────────────────────────────────────────────────

function main()
    println("╔══════════════════════════════════════════════════════════════════╗")
    println("║  MissingDataViz.jl — VALIDATION ON REAL DATASETS               ║")
    println("║  Step 13, Part 1                                                ║")
    println("╚══════════════════════════════════════════════════════════════════╝")
    println()

    # Check data directory
    if !isdir(DATA_DIR)
        error("Data directory not found: $(DATA_DIR)\n" *
              "Create it and download the 5 datasets first.")
    end

    # Validate all files exist before starting
    println("Checking dataset files...")
    all_found = true
    for config in DATASETS
        filepath = joinpath(DATA_DIR, config.filename)
        if isfile(filepath)
            size_mb = round(filesize(filepath) / 1024^2, digits=1)
            println("  ✓ $(config.filename) ($(size_mb) MB)")
        else
            println("  ✗ $(config.filename) — NOT FOUND")
            all_found = false
        end
    end

    if !all_found
        error("Missing dataset files. Download them before running validation.")
    end
    println()

    # Run analysis on each dataset
    results = ValidationResult[]

    for config in DATASETS
        try
            result = analyze_dataset(config)
            push!(results, result)
        catch e
            println("\n  ❌ FAILED: $(config.name)")
            println("  Error: $(e)")
            println("  Continuing with next dataset...\n")
        end
    end

    # Generate report
    println("\n" * "="^70)
    println("GENERATING VALIDATION REPORT")
    println("="^70)

    if isempty(results)
        println("No datasets analyzed successfully. Cannot generate report.")
        return
    end

    report_path = generate_validation_report(results)

    # Final summary
    println("\n" * "="^70)
    println("VALIDATION COMPLETE")
    println("="^70)
    println("  Datasets analyzed: $(length(results)) / $(length(DATASETS))")
    println("  Report: $(report_path)")
    println("  Plots: $(OUTPUT_DIR)/")
    println()

    total_time = sum(r.elapsed_seconds for r in results)
    println("  Total time: $(round(total_time, digits=1))s")
    println()

    # Quick summary
    println("  QUICK RESULTS:")
    for r in results
        status = r.n_mcar_violations > 0 ? "⚠️  MCAR VIOLATED" : "✓ MCAR OK"
        println("    $(rpad(r.name, 30)) $(status) ($(r.elapsed_seconds)s)")
    end
end

# Run
main()