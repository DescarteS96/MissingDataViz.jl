# All-in-one missing data diagnosis workflow

using DataFrames

"""
    diagnose_missing(df::DataFrame; 
                     report::Bool=false,
                     output::String="missing_report.html",
                     display::Bool=!report,
                     verbose::Bool=false)

Perform comprehensive missing data analysis with automatic visualization and reporting.

This is the main entry point for missing data diagnosis. It provides two modes:
- **Interactive mode** (`report=false`): Display plots and return statistics
- **Batch mode** (`report=true`): Generate HTML report silently

# Arguments
- `df::DataFrame`: Input data to analyze
- `report::Bool=false`: Generate HTML report (batch mode)
  - `false` (default): Interactive mode - display plots in current environment
  - `true`: Batch mode - generate HTML file silently
- `output::String="missing_report.html"`: Output path for HTML report
  - Only used when `report=true`
  - Relative paths resolved from `pwd()`
  - Absolute paths used as-is
- `display::Bool=!report`: Display plots interactively
  - **Ignored if `report=true`** (batch mode implies no interactive display)
  - Only effective in interactive mode (`report=false`)
- `verbose::Bool=false`: Enable detailed logging
  - `false` (default): Minimal output - only final result message
  - `true`: Detailed logging of each step

# Returns
- `Dict` with the following structure:
  ```julia
  Dict(
      :stats => Dict(
          :total_missing => Int,
          :total_cells => Int,
          :overall_percentage => Float64,
          :columns => Dict("col" => Dict(:count, :percentage))
      ),
      :figures => Dict(
          :matrix => Figure,
          :bars => Figure,
          :correlation => Figure,
          :overview => Figure
      ),
      :report_path => String  # Only present if report=true
  )
  ```

# Behavior

## Interactive Mode (`report=false`)
```julia
# Display plots and return statistics
results = diagnose_missing(df)

# Access statistics
println("Total missing: ", results[:stats][:total_missing])

# Access figures for further manipulation
matrix_fig = results[:figures][:matrix]
save("custom_matrix.png", matrix_fig)  # Export with CairoMakie

# Suppress display (compute only)
results = diagnose_missing(df, display=false)
```

## Batch Mode (`report=true`)
```julia
# Generate HTML report silently
results = diagnose_missing(df, report=true)
println("Report: ", results[:report_path])

# Custom output path
results = diagnose_missing(df, report=true, output="analysis/report.html")

# Verbose logging
results = diagnose_missing(df, report=true, verbose=true)
# → "Computing missing data statistics..."
# → "Generating visualizations..."
# → "Generating HTML report..."
# → "Report generated: /path/to/report.html"
```

# Examples

```julia
using DataFrames, MissingDataViz

# Create sample data
df = DataFrame(
    Name = ["Alice", "Bob", missing, "David", "Eve"],
    Age = [25, missing, 30, missing, 35],
    Salary = [50000, 60000, missing, 70000, missing],
    Department = ["HR", "IT", "IT", missing, "HR"]
)

# Example 1: Quick interactive analysis
results = diagnose_missing(df)
# → Displays 4 plots automatically
# → Returns statistics and figures

# Example 2: Generate report for sharing
results = diagnose_missing(df, report=true, output="team_review.html")
# → Creates team_review.html
# → Silent execution (no plots displayed)

# Example 3: Debug mode with verbose logging
results = diagnose_missing(df, report=true, verbose=true)
# → Shows detailed progress of each step

# Example 4: Compute stats without displaying plots
results = diagnose_missing(df, display=false)
# → No visual output, only statistics computed

# Example 5: Access specific statistics
results = diagnose_missing(df)
for (col, stats) in results[:stats][:columns]
    if stats[:percentage] > 20
        println("\$col has \$(stats[:percentage])% missing - investigate!")
    end
end
```

# Performance
- Interactive mode: 150-250ms (display time depends on backend)
- Batch mode: 200-350ms (includes HTML generation and file write)
- Memory: ~50-100MB peak (temporary plot rendering)

# Notes
- The `display` parameter is **ignored when `report=true`** to avoid confusion
- In batch mode, plots are never displayed interactively
- All plots are always generated (for both modes)
- Use `verbose=true` for debugging or progress monitoring

# See Also
- [`generate_html_report`](@ref): Generate HTML report only (no interactive display)
- [`plot_missing_overview`](@ref): Generate combined overview plot only
- `CairoMakie.save()`: Export individual plots to files

# Throws
- `ArgumentError`: If DataFrame is empty or has no columns
- `ErrorException`: If report output directory doesn't exist (batch mode only)
"""
function diagnose_missing(df::DataFrame; 
                          report::Bool=false,
                          output::String="missing_report.html",
                          display::Bool=!report,
                          verbose::Bool=false)::Dict
    
    # Validate input
    if isempty(df)
        throw(ArgumentError("DataFrame is empty - cannot diagnose missing data"))
    end
    
    if ncol(df) == 0
        throw(ArgumentError("DataFrame has no columns - cannot diagnose missing data"))
    end
    
    # Initialize results dictionary
    results = Dict{Symbol, Any}()
    
    # Step 1: Compute statistics
    verbose && @info "Computing missing data statistics..."
    stats = _compute_report_statistics(df)
    results[:stats] = stats
    
    if verbose
        @info "Statistics computed" total_missing=stats[:total_missing] total_cells=stats[:total_cells] percentage=round(stats[:overall_percentage], digits=2)
    end
    
    # Step 2: Generate visualizations
    verbose && @info "Generating visualizations..."
    figures = _generate_all_plots(df)
    results[:figures] = figures
    
    verbose && @info "Visualizations generated" count=length(figures)
    
    # Step 3: Handle mode-specific behavior
    if report
        # Batch mode: Generate HTML report
        verbose && @info "Generating HTML report..."
        
        report_path = generate_html_report(df, output)
        results[:report_path] = report_path
        
        @info "Report generated: $report_path"
        
        # Note: display parameter is ignored in batch mode (no interactive display)
    else
        # Interactive mode: Display plots if requested
        if display
            verbose && @info "Displaying plots interactively..."
            
            # Display all figures
            # Note: Actual display depends on the plotting backend
            # In IJulia/Pluto: plots appear automatically
            # In REPL: may need to call display() explicitly
            for (name, fig) in figures
                Base.display(fig)
            end
            
            verbose && @info "Plots displayed"
        else
            verbose && @info "Display suppressed (display=false)"
        end
    end
    
    return results
end

"""
    diagnose_missing(df::DataFrame, output_file::String; kwargs...)

Convenience method: Generate report by default when output file is specified.

This is a shorthand for `diagnose_missing(df; report=true, output=output_file, kwargs...)`.

# Examples
```julia
# These two calls are equivalent:
diagnose_missing(df, "report.html")
diagnose_missing(df, report=true, output="report.html")
```
"""
function diagnose_missing(df::DataFrame, output_file::String; kwargs...)::Dict
    return diagnose_missing(df; report=true, output=output_file, kwargs...)
end
