
using CairoMakie
using DataFrames
using Statistics

# Import validation functions (assumes they're already loaded in main module)
# If not, uncomment:
# include("../validation.jl")
# include("../errors.jl")

"""
    plot_missing_matrix(df::DataFrame; kwargs...)

Create a heatmap visualizing missing data patterns in a DataFrame with customization options.

# Arguments
- `df::DataFrame`: DataFrame to visualize

# Keyword Arguments
- `figsize::Tuple{Int,Int}`: Figure dimensions in pixels. Default: `(1000, 600)`
- `colormap::Symbol`: Color scheme for the heatmap. Default: `:grays`
- `show_sparkline::Bool`: Display sparkline showing % missing per row. Default: `true`
- `max_rows_display::Int`: Maximum number of rows to display. Use `-1` for no limit. Default: `5000`
- `labels::NamedTuple`: Custom labels for plot elements. Default labels in English.
  - `xlabel`: X-axis label (default: "Variables")
  - `ylabel`: Y-axis label (default: "Observations")
  - `title`: Plot title (default: "Missing Data Pattern")
  - `colorbar_label`: Colorbar label (default: "Data Status")
  - `colorbar_present`: Label for present values (default: "Present")
  - `colorbar_missing`: Label for missing values (default: "Missing")
  - `sparkline_ylabel`: Sparkline Y-axis label (default: "% Missing")

# Returns
- `Figure`: Makie Figure object containing the heatmap

# Examples
```julia
using MissingDataViz
using DataFrames

df = DataFrame(
    A = [1, missing, 3, 4, missing],
    B = [missing, 2, 3, missing, 5],
    C = [1, 2, 3, 4, 5]
)

# Basic usage
fig = plot_missing_matrix(df)

# French labels
fig = plot_missing_matrix(df; labels=(
    xlabel = "Variables",
    ylabel = "Observations",
    title = "Motif de Données Manquantes",
    colorbar_label = "Statut",
    colorbar_present = "Présent",
    colorbar_missing = "Manquant",
    sparkline_ylabel = "% Manquant"
))

# Medical context
fig = plot_missing_matrix(df; labels=(
    xlabel = "Clinical Variables",
    ylabel = "Patients",
    title = "Missing Data in Patient Records"
))

# Custom size without sparkline
fig = plot_missing_matrix(df; figsize=(800, 600), show_sparkline=false)

# Colorblind-friendly colormap
fig = plot_missing_matrix(df; colormap=:viridis)

# Display more rows
fig = plot_missing_matrix(df; max_rows_display=10000)

# Combined customization
fig = plot_missing_matrix(df; 
    figsize=(1200, 800), 
    colormap=:thermal,
    show_sparkline=true,
    max_rows_display=3000,
    labels=(xlabel="Features", ylabel="Samples")
)
```

# Notes
- Black = missing value (with default `:grays` colormap)
- White = present value (with default `:grays` colormap)
- For datasets >50 columns, only the first 50 columns are displayed
- Available colormaps: `:grays`, `:viridis`, `:plasma`, `:thermal`, `:RdBu`, etc.
- Partial label override is supported (only specify labels you want to change)
"""
function plot_missing_matrix(
    df::DataFrame;
    figsize::Tuple{Int,Int} = (1000, 600),
    colormap::Symbol = :grays,
    show_sparkline::Bool = true,
    max_rows_display::Int = 5000,
    labels::NamedTuple = (
        xlabel = "Variables",
        ylabel = "Observations",
        title = "Missing Data Pattern",
        colorbar_label = "Data Status",
        colorbar_present = "Present",
        colorbar_missing = "Missing",
        sparkline_ylabel = "% Missing"
    )
)
    # ========================================
    # VALIDATION LAYER
    # ========================================
    
    # Validate DataFrame
    validate_dataframe(df)
    
    # Validate parameters
    validate_figsize(figsize)
    
    if max_rows_display != -1 && max_rows_display <= 0
        throw(InvalidParameterError(
            "max_rows_display",
            max_rows_display,
            "Positive integer or -1 for unlimited (recommended: 1000-10000)"
        ))
    end
    
    # ========================================
    # GRACEFUL DEGRADATION LAYER
    # ========================================
    
    n_rows = nrow(df)
    n_cols = ncol(df)
    
    # Handle single row case
    if n_rows == 1
        @info "DataFrame has only 1 row. Pattern visualization may be limited." maxlog=1
    end
    
    # Handle many columns case
    if n_cols > 100
        @warn "DataFrame has $n_cols columns. Plot may be crowded. " *
              "Consider selecting a subset of columns." maxlog=1
    end
    
    # Check for all-missing columns
    all_missing_cols = [col for col in names(df) if check_all_missing_column(df, Symbol(col))]
    if !isempty(all_missing_cols) && length(all_missing_cols) < ncol(df)
        @warn "Columns with 100% missing values: $(join(all_missing_cols, ", ")). " *
              "Consider removing these columns." maxlog=1
    end
    
    # Check for all-present columns (informational, not critical)
    all_present_cols = [col for col in names(df) if check_all_present_column(df, Symbol(col))]
    if !isempty(all_present_cols) && length(all_present_cols) == ncol(df)
        @info "No missing values detected in DataFrame. Matrix will be entirely light-colored." maxlog=1
    end
    
    # ========================================
    # EXISTING IMPLEMENTATION
    # ========================================
    
    # Merge user labels with defaults (allows partial override)
    default_labels = (
        xlabel = "Variables",
        ylabel = "Observations",
        title = "Missing Data Pattern",
        colorbar_label = "Data Status",
        colorbar_present = "Present",
        colorbar_missing = "Missing",
        sparkline_ylabel = "% Missing"
    )
    final_labels = merge(default_labels, labels)
    
    # Get binary matrix (1 = missing, 0 = present)
    mat = missing_pattern(df)
    
    # Limit display if too many rows
    n_rows_orig = n_rows
    n_cols_orig = n_cols
    max_display_cols = 50
    
    # Apply row limit (unless max_rows_display = -1 for unlimited)
    if max_rows_display != -1 && n_rows > max_rows_display
        mat = mat[1:max_rows_display, :]
        @warn "Dataset contains $n_rows_orig rows. Display limited to first $max_rows_display rows." maxlog=1
    end
    
    # Apply column limit
    if n_cols > max_display_cols
        mat = mat[:, 1:max_display_cols]
        @warn "Dataset contains $n_cols_orig columns. Display limited to first $max_display_cols columns." maxlog=1
        col_names = names(df)[1:max_display_cols]
    else
        col_names = names(df)
    end
    
    # Update dimensions after potential truncation
    n_rows_display, n_cols_display = size(mat)
    
    # Calculate missing percentage per row (for sparkline)
    missing_pct_per_row = vec(sum(mat, dims=2) ./ n_cols_display .* 100)
    
    # Determine label rotation based on column count and name length
    avg_name_length = mean(length.(col_names))
    if n_cols_display > 15 || avg_name_length > 15
        rotation_angle = π/2  # 90 degrees
        label_size = 8
    else
        rotation_angle = π/4  # 45 degrees
        label_size = 10
    end
    
    # Create figure with custom size
    fig = Figure(size = figsize)
    
    # Main heatmap axis with custom labels
    ax = Axis(fig[1, 1],
              xlabel = final_labels.xlabel,
              ylabel = final_labels.ylabel,
              title = final_labels.title,
              xticklabelsize = label_size,
              yticklabelsize = 10)
    
    # Create heatmap (inverted colormap: 0=light/present, 1=dark/missing)
    # TRANSPOSE matrix so DataFrame rows = Y axis and DataFrame columns = X axis
    hm = heatmap!(ax, transpose(mat),
                  colormap = Reverse(colormap),
                  colorrange = (0, 1))
    
    # Set axis limits to match data dimensions exactly
    xlims!(ax, 0.5, n_cols_display + 0.5)
    ylims!(ax, 0.5, n_rows_display + 0.5)
    
    # Configure X axis with column names
    ax.xticks = (1:n_cols_display, col_names)
    ax.xticklabelrotation = rotation_angle
    
    # Configure Y axis
    n_yticks = min(10, n_rows_display)
    ytick_positions = range(1, n_rows_display, length = n_yticks)
    ytick_labels = string.(round.(Int, ytick_positions))
    ax.yticks = (ytick_positions, ytick_labels)
    
    # Conditional sparkline display
    if show_sparkline
        # Sparkline axis (right side) with custom label
        ax_spark = Axis(fig[1, 2],
                        ylabel = final_labels.sparkline_ylabel,
                        xlabel = "",
                        width = 80,
                        yticklabelsize = 8)
        
        # Plot sparkline (horizontal bars)
        barplot!(ax_spark, 
                 1:n_rows_display,
                 missing_pct_per_row,
                 direction = :x,
                 color = :gray,
                 strokewidth = 0)
        
        # Configure sparkline axis
        ax_spark.yticks = (ytick_positions, ytick_labels)
        xlims!(ax_spark, 0, 100)
        
        # Colorbar (legend) - position 3 when sparkline is shown
        cb = Colorbar(fig[1, 3], 
                      hm,
                      label = final_labels.colorbar_label,
                      width = 20,
                      ticksize = 8,
                      ticks = ([0, 1], [final_labels.colorbar_present, final_labels.colorbar_missing]))
    else
        # Colorbar (legend) - position 2 when sparkline is hidden
        cb = Colorbar(fig[1, 2], 
                      hm,
                      label = final_labels.colorbar_label,
                      width = 20,
                      ticksize = 8,
                      ticks = ([0, 1], [final_labels.colorbar_present, final_labels.colorbar_missing]))
    end
    
    return fig
end