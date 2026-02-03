"""
    plot_missing_overview(df::DataFrame; 
                          figsize::Tuple{Int,Int}=(1800, 600),
                          layout::Symbol=:horizontal,
                          threshold::Union{Nothing,Float64}=nothing,
                          show_correlation_values::Union{Bool,Symbol}=:auto)

Create a comprehensive overview dashboard combining all three missing data visualizations.

Combines:
- Missing data matrix (left/top): Shows where missing values occur row-by-row
- Bar chart (center): Shows percentage of missing values per column
- Correlation matrix (right/bottom): Shows relationships between missing patterns

# Arguments
- `df::DataFrame`: Input DataFrame to analyze
- `figsize::Tuple{Int,Int}=(1800, 600)`: Figure dimensions (width, height)
- `layout::Symbol=:horizontal`: Layout (`:horizontal` = 1×3 grid, `:vertical` = 3×1 grid)
- `threshold::Union{Nothing,Float64}=nothing`: Optional threshold line for bar chart
- `show_correlation_values::Union{Bool,Symbol}=:auto`: Show values in correlation heatmap

# Returns
- `Figure`: Makie Figure containing all three plots in unified layout

# Examples
```julia
using DataFrames, MissingDataViz

df = DataFrame(
    A = [1, missing, 3, missing, 5],
    B = [missing, missing, missing, 4, 5],
    C = [1, 2, 3, 4, 5]
)

# Default horizontal layout
fig = plot_missing_overview(df)

# Vertical layout
fig = plot_missing_overview(df, layout=:vertical, figsize=(1000, 1800))

# With threshold line on bar chart
fig = plot_missing_overview(df, threshold=30.0)
```

# Use Cases
- **Quick audit**: Complete picture of missing data in single view
- **Executive reports**: Comprehensive visual for presentations
- **Exploratory analysis**: Identify patterns, severity, and correlations simultaneously
- **Before imputation**: Understand data structure before choosing imputation strategy
"""
function plot_missing_overview(df::DataFrame; 
                              figsize::Tuple{Int,Int}=(1800, 600),
                              layout::Symbol=:horizontal,
                              threshold::Union{Nothing,Float64}=nothing,
                              show_correlation_values::Union{Bool,Symbol}=:auto)
    # Validate layout parameter
    if !(layout in [:horizontal, :vertical])
        error("layout must be :horizontal or :vertical")
    end
    
    n_cols = ncol(df)
    col_names = names(df)
    
    # Create main figure
    fig = Figure(size=figsize)
    
    if layout == :horizontal
        # ============================================================
        # HORIZONTAL LAYOUT: [Matrix | Bars | Correlation]
        # ============================================================
        
        # 1. MISSING DATA MATRIX (left panel)
        ax_matrix = Axis(fig[1, 1],
                        title="Missing Data Matrix",
                        xlabel="Columns",
                        ylabel="Rows (sampled)")
        
        binary_matrix = missing_pattern(df)
        n_rows = size(binary_matrix, 1)
        
        # Sample rows if dataset is large
        max_display_rows = 5000
        if n_rows > max_display_rows
            row_indices = Int.(round.(range(1, n_rows, length=max_display_rows)))
            display_matrix = binary_matrix[row_indices, :]
            ax_matrix.ylabel = "Rows (sampled, n=$(n_rows))"
        else
            display_matrix = binary_matrix
        end
        
        heatmap!(ax_matrix, Float64.(display_matrix'),
                colormap=[:white, :black],
                colorrange=(0, 1))
        
        ax_matrix.xticks = (1:n_cols, col_names)
        ax_matrix.xticklabelrotation = π/4
        ax_matrix.xticklabelsize = 10
        
        # 2. BAR CHART (center panel)
        ax_bars = Axis(fig[1, 2],
                      title="Missing % by Column",
                      xlabel="Columns",
                      ylabel="Missing (%)",
                      xticklabelrotation=π/4)
        
        missing_pcts = missing_percentage(df)
        sorted_indices = sortperm(missing_pcts, rev=true)
        sorted_names = col_names[sorted_indices]
        sorted_pcts = missing_pcts[sorted_indices]
        
        colors = map(sorted_pcts) do pct
            pct >= 50.0 ? :red : (pct >= 20.0 ? :orange : :steelblue)
        end
        
        barplot!(ax_bars, 1:n_cols, sorted_pcts,
                color=colors,
                strokewidth=1,
                strokecolor=:black)
        
        ax_bars.xticks = (1:n_cols, sorted_names)
        ax_bars.xticklabelsize = 10
        ylims!(ax_bars, 0, 105)
        
        # Add threshold line if specified
        if !isnothing(threshold)
            hlines!(ax_bars, [threshold], color=:black, linestyle=:dash, linewidth=2)
            
            above_threshold = findall(sorted_pcts .>= threshold)
            for idx in above_threshold
                text!(ax_bars, idx, threshold + 2,
                     text="▲",
                     fontsize=10,
                     color=:black,
                     align=(:center, :bottom))
            end
        end
        
        # 3. CORRELATION MATRIX (right panel)
        ax_corr = Axis(fig[1, 3],
                      title="Pattern Correlation",
                      xlabel="Columns",
                      ylabel="Columns",
                      aspect=DataAspect())
        
        corr_matrix = missing_correlation(df)
        
        heatmap!(ax_corr, corr_matrix,
                colormap=:balance,
                colorrange=(-1, 1))
        
        ax_corr.xticks = (1:n_cols, col_names)
        ax_corr.yticks = (1:n_cols, col_names)
        ax_corr.xticklabelrotation = π/4
        ax_corr.xticklabelsize = 10
        ax_corr.yticklabelsize = 10
        
        # Show correlation values if requested
        display_values = if show_correlation_values == :auto
            n_cols <= 10
        elseif show_correlation_values isa Bool
            show_correlation_values
        else
            false
        end
        
        if display_values
            for i in 1:n_cols
                for j in 1:n_cols
                    val = corr_matrix[i, j]
                    text_color = abs(val) > 0.5 ? :white : :black
                    val_text = isnan(val) ? "N/A" : @sprintf("%.2f", val)
                    
                    text!(ax_corr, j, i,
                         text=val_text,
                         color=text_color,
                         fontsize=8,
                         align=(:center, :center))
                end
            end
        end
        
        # Add colorbar for correlation
        Colorbar(fig[1, 4], limits=(-1, 1), colormap=:balance,
                label="Correlation", ticks=[-1, -0.5, 0, 0.5, 1])
        
    else  # vertical layout
        # ============================================================
        # VERTICAL LAYOUT: [Matrix]
        #                  [Bars]
        #                  [Correlation]
        # ============================================================
        
        # 1. MISSING DATA MATRIX (top row)
        ax_matrix = Axis(fig[1, 1],
                        title="Missing Data Matrix",
                        xlabel="Columns",
                        ylabel="Rows")
        
        binary_matrix = missing_pattern(df)
        n_rows = size(binary_matrix, 1)
        
        max_display_rows = 5000
        if n_rows > max_display_rows
            row_indices = Int.(round.(range(1, n_rows, length=max_display_rows)))
            display_matrix = binary_matrix[row_indices, :]
            ax_matrix.ylabel = "Rows (sampled, n=$(n_rows))"
        else
            display_matrix = binary_matrix
        end
        
        heatmap!(ax_matrix, Float64.(display_matrix'),
                colormap=[:white, :black],
                colorrange=(0, 1))
        
        ax_matrix.xticks = (1:n_cols, col_names)
        ax_matrix.xticklabelrotation = π/4
        
        # 2. BAR CHART (middle row)
        ax_bars = Axis(fig[2, 1],
                      title="Missing % by Column",
                      xlabel="Columns",
                      ylabel="Missing (%)",
                      xticklabelrotation=π/4)
        
        missing_pcts = missing_percentage(df)
        sorted_indices = sortperm(missing_pcts, rev=true)
        sorted_names = col_names[sorted_indices]
        sorted_pcts = missing_pcts[sorted_indices]
        
        colors = map(sorted_pcts) do pct
            pct >= 50.0 ? :red : (pct >= 20.0 ? :orange : :steelblue)
        end
        
        barplot!(ax_bars, 1:n_cols, sorted_pcts,
                color=colors,
                strokewidth=1,
                strokecolor=:black)
        
        ax_bars.xticks = (1:n_cols, sorted_names)
        ylims!(ax_bars, 0, 105)
        
        if !isnothing(threshold)
            hlines!(ax_bars, [threshold], color=:black, linestyle=:dash, linewidth=2)
            
            above_threshold = findall(sorted_pcts .>= threshold)
            for idx in above_threshold
                text!(ax_bars, idx, threshold + 2,
                     text="▲",
                     fontsize=10,
                     color=:black,
                     align=(:center, :bottom))
            end
        end
        
        # 3. CORRELATION MATRIX (bottom row)
        ax_corr = Axis(fig[3, 1],
                      title="Pattern Correlation",
                      xlabel="Columns",
                      ylabel="Columns",
                      aspect=DataAspect())
        
        corr_matrix = missing_correlation(df)
        
        heatmap!(ax_corr, corr_matrix,
                colormap=:balance,
                colorrange=(-1, 1))
        
        ax_corr.xticks = (1:n_cols, col_names)
        ax_corr.yticks = (1:n_cols, col_names)
        ax_corr.xticklabelrotation = π/4
        
        display_values = if show_correlation_values == :auto
            n_cols <= 10
        elseif show_correlation_values isa Bool
            show_correlation_values
        else
            false
        end
        
        if display_values
            for i in 1:n_cols
                for j in 1:n_cols
                    val = corr_matrix[i, j]
                    text_color = abs(val) > 0.5 ? :white : :black
                    val_text = isnan(val) ? "N/A" : @sprintf("%.2f", val)
                    
                    text!(ax_corr, j, i,
                         text=val_text,
                         color=text_color,
                         fontsize=8,
                         align=(:center, :center))
                end
            end
        end
        
        Colorbar(fig[3, 2], limits=(-1, 1), colormap=:balance,
                label="Correlation", ticks=[-1, -0.5, 0, 0.5, 1])
    end
    
    return fig
end

