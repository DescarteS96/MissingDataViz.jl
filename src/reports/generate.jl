# Main report generation functionality

using DataFrames
using CairoMakie
using Dates

"""
    generate_html_report(df::DataFrame, output_file::String;
                         title::String="Missing Data Analysis Report",
                         run_mcar_tests::Bool=false,
                         alpha::Float64=0.05,
                         mcar_results=nothing)

Generate a comprehensive HTML report with missing data analysis and visualizations.

Creates a standalone HTML file containing:
- Summary statistics table (missing count and percentage per column)
- Missing data matrix heatmap
- Bar chart of missing percentages
- Correlation matrix of missingness patterns
- Combined overview dashboard
- Optional: MCAR diagnostic section with test results and recommendations

All plots are embedded as base64-encoded PNG images, making the report a single
self-contained file with no external dependencies.

# Arguments
- `df::DataFrame`: Input data to analyze
- `output_file::String`: Path where HTML report will be saved
  - **Relative paths** are resolved from current working directory (`pwd()`)
  - **Absolute paths** are used as-is
- `title::String="Missing Data Analysis Report"`: Report title displayed in header
- `run_mcar_tests::Bool=false`: Whether to run MCAR tests and add diagnostic section
  - `false` (default): Basic report only — faster, no statistical tests
  - `true`: Full report with MCAR diagnostic section (adds a few seconds)
- `alpha::Float64=0.05`: Significance threshold for MCAR tests (only used if `run_mcar_tests=true`)
- `mcar_results=nothing`: Pre-computed MCAR results (`MCARTestComparison`) to inject directly.
  - `nothing` (default): Results are computed internally when `run_mcar_tests=true`
  - Provide a pre-computed value to avoid double execution when called from `full_missing_diagnosis`
  - When provided, `run_mcar_tests` must also be `true` for the section to render

# Returns
- `String`: Absolute path to the generated HTML file

# Output File Path Behavior
```julia
# Relative path → saved in current directory
generate_html_report(df, "report.html")
# → Saved at: pwd()/report.html

# Absolute path → saved at specified location
generate_html_report(df, "/home/user/reports/analysis.html")
# → Saved at: /home/user/reports/analysis.html

# Check current directory
pwd()  # See where relative paths will be saved
```

# Examples
```julia
using DataFrames, MissingDataViz

# Create sample data with missing values
df = DataFrame(
    Age    = [25, missing, 30, missing, 35],
    Income = [50000, 60000, missing, 70000, missing],
    Score  = [85, 90, missing, missing, 95]
)

# Generate basic report (no MCAR tests)
path = generate_html_report(df, "missing_analysis.html")
println("Report saved to: \$path")

# Generate full report with MCAR diagnostic section
path = generate_html_report(df, "full_report.html",
                             title="Q4 2024 Data Quality Report",
                             run_mcar_tests=true)

# Generate report with custom significance threshold
path = generate_html_report(df, "strict_report.html",
                             run_mcar_tests=true,
                             alpha=0.01)

# Inject pre-computed results (avoids double execution)
mcar = compare_mcar_tests(df)
path = generate_html_report(df, "fast_report.html",
                             run_mcar_tests=true,
                             mcar_results=mcar)

# Open in browser (cross-platform)
if Sys.iswindows()
    run(`cmd /c start \$path`)
elseif Sys.isapple()
    run(`open \$path`)
else
    run(`xdg-open \$path`)
end
```

# Performance
- Basic report (run_mcar_tests=false):            150-300ms for datasets with <10,000 rows
- Full report  (run_mcar_tests=true):             +2-10s depending on dataset size and column count
- Full report  (mcar_results pre-computed):       ~same as basic — no test re-execution
- Report file size: ~500KB - 2MB depending on data size
- Memory usage: ~50MB peak (temporary plot rendering)

# Note
This function generates all visualizations automatically. Plots are always
embedded as base64 PNG images for maximum portability.

# See Also
- [`full_missing_diagnosis`](@ref): All-in-one pipeline (recommended entry point)
- [`diagnose_missing`](@ref): Legacy all-in-one analysis workflow
- [`plot_missing_diagnosis`](@ref): Interactive dashboard (Phase 1 + Phase 2)
- `CairoMakie.save()`: For exporting individual plots to PNG/PDF/SVG

# Throws
- `ErrorException`: If output directory doesn't exist or is not writable
- `ArgumentError`: If DataFrame is empty or has no columns
"""
function generate_html_report(df::DataFrame,
                              output_file::String;
                              title::String        = "Missing Data Analysis Report",
                              run_mcar_tests::Bool = false,
                              alpha::Float64       = 0.05,
                              mcar_results         = nothing)::String

    # Validate inputs
    if isempty(df)
        throw(ArgumentError("DataFrame is empty - cannot generate report"))
    end

    if ncol(df) == 0
        throw(ArgumentError("DataFrame has no columns - cannot generate report"))
    end

    # Validate and normalize output path
    output_path = _validate_output_path(output_file)

    # Step 1: Compute missing data statistics
    stats = _compute_report_statistics(df)

    # Step 2: Generate all visualizations
    figures = _generate_all_plots(df)

    # Step 2b: Run MCAR tests if requested (opt-in — adds a few seconds)
    #
    # Optimization: if mcar_results are passed in (pre-computed by full_missing_diagnosis),
    # skip re-execution entirely. This avoids the ~10s double execution cost when
    # generate_html_report is called from within the full pipeline.
    mcar_html = ""
    if run_mcar_tests
        computed_results = if !isnothing(mcar_results)
            # Use pre-computed results — no re-execution
            mcar_results
        else
            # Compute fresh — standalone call without pre-computed results
            @info "Running MCAR tests (this may take a few seconds)..."
            try
                compare_mcar_tests(df; alpha = alpha, verbose = false)
            catch e
                @warn "MCAR tests failed: $(e). Skipping MCAR section."
                nothing
            end
        end

        if !isnothing(computed_results)
            # Add MCAR plot to figures dict for base64 conversion
            figures[:mcar] = plot_mcar_test_results(computed_results; alpha = alpha)
            # Generate MCAR HTML section
            mcar_html = _generate_mcar_section(computed_results, alpha)
        end
    end

    # Step 3: Convert plots to base64 for embedding
    plots_b64 = _convert_plots_to_base64(figures)

    # Step 4: Generate HTML components
    summary_html = _generate_summary_table(df, stats)
    plots_html   = _generate_plots_section(
        plots_b64[:matrix],
        plots_b64[:bars],
        plots_b64[:correlation],
        plots_b64[:overview]
    )

    # Step 5: Assemble complete HTML document
    timestamp    = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    html_content = _generate_html_template(
        title,
        summary_html,
        plots_html,
        mcar_html,      # empty string if run_mcar_tests=false → section not rendered
        timestamp
    )

    # Step 6: Write HTML to file
    open(output_path, "w") do io
        write(io, html_content)
    end

    return output_path
end

"""
    _compute_report_statistics(df::DataFrame)::Dict

Compute comprehensive missing data statistics for report generation.

# Arguments
- `df::DataFrame`: Input data

# Returns
- `Dict`: Statistics dictionary with structure:
```julia
  Dict(
      :total_missing => Int,           # Total count of missing values
      :total_cells => Int,             # Total number of cells
      :overall_percentage => Float64,  # Overall missing percentage
      :columns => Dict(                # Per-column statistics
          "col1" => Dict(:count => Int, :percentage => Float64),
          "col2" => Dict(:count => Int, :percentage => Float64),
          ...
      )
  )
```
"""
function _compute_report_statistics(df::DataFrame)::Dict
    n_rows, n_cols = size(df)
    total_cells    = n_rows * n_cols

    # Initialize statistics dictionary
    stats = Dict(
        :total_missing      => 0,
        :total_cells        => total_cells,
        :overall_percentage => 0.0,
        :columns            => Dict{String, Dict{Symbol, Any}}()
    )

    # Compute per-column statistics
    for col in names(df)
        missing_count = count(ismissing, df[!, col])
        missing_pct   = (missing_count / n_rows) * 100.0

        stats[:columns][col] = Dict(
            :count      => missing_count,
            :percentage => missing_pct
        )

        stats[:total_missing] += missing_count
    end

    # Compute overall percentage
    stats[:overall_percentage] = (stats[:total_missing] / total_cells) * 100.0

    return stats
end

"""
    _generate_all_plots(df::DataFrame)::Dict

Generate all visualization figures for the report.

# Arguments
- `df::DataFrame`: Input data

# Returns
- `Dict`: Dictionary of Makie figures
```julia
  Dict(
      :matrix      => Figure,   # Missing data matrix heatmap
      :bars        => Figure,   # Bar chart of missing percentages
      :correlation => Figure,   # Correlation matrix of missingness
      :overview    => Figure    # Combined overview dashboard
  )
```

# Note
- The `:mcar` key is added dynamically by `generate_html_report` when
  `run_mcar_tests=true`. It is NOT generated here to keep concerns separated.
"""
function _generate_all_plots(df::DataFrame)::Dict
    return Dict(
        :matrix      => plot_missing_matrix(df),
        :bars        => plot_missing_bars(df),
        :correlation => plot_missing_correlation(df),
        :overview    => plot_missing_overview(df)
    )
end

"""
    _convert_plots_to_base64(figures::Dict)::Dict

Convert all figures to base64-encoded PNG strings for HTML embedding.

# Arguments
- `figures::Dict`: Dictionary of Makie figures (keys: :matrix, :bars,
  :correlation, :overview, and optionally :mcar)

# Returns
- `Dict`: Dictionary of base64 data URIs (same keys as input)

# Note
- Unknown keys fall back to (800, 600) resolution
- The :mcar key is handled automatically if present
"""
function _convert_plots_to_base64(figures::Dict)::Dict
    # Resolution optimized for web display (not print quality)
    # Larger plots get higher resolution for readability
    resolutions = Dict(
        :matrix      => (1000, 600),   # Wide format for observation rows
        :bars        => (800,  500),   # Standard bar chart
        :correlation => (700,  700),   # Square format for matrix
        :overview    => (1200, 800),   # Largest - combined dashboard
        :mcar        => (900,  500),   # MCAR test results bar chart
    )

    plots_b64 = Dict{Symbol, String}()

    for (key, fig) in figures
        resolution     = get(resolutions, key, (800, 600))
        plots_b64[key] = _plot_to_base64(fig, resolution = resolution)
    end

    return plots_b64
end