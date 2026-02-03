"""
    plot_missing_bars(df::DataFrame; sort::Bool=true, figsize::Tuple{Int,Int}=(800, 600), 
                      threshold::Union{Nothing,Float64}=nothing, orientation::Symbol=:auto)

Create a bar chart showing the percentage of missing values for each column.

# Arguments
- `df::DataFrame`: Input DataFrame to analyze
- `sort::Bool=true`: Sort columns by missing percentage (descending)
- `figsize::Tuple{Int,Int}=(800, 600)`: Figure dimensions (width, height)
- `threshold::Union{Nothing,Float64}=nothing`: Display horizontal threshold line at specified percentage (0-100)
- `orientation::Symbol=:auto`: Bar orientation (`:vertical`, `:horizontal`, or `:auto` which uses horizontal if >20 columns)

# Returns
- `Figure`: Makie Figure object containing the bar chart

# Examples
```julia
using DataFrames, MissingDataViz

df = DataFrame(
    A = [1, missing, 3, missing, 5],
    B = [missing, missing, missing, 4, 5],
    C = [1, 2, 3, 4, 5]
)

# Basic bar chart
fig = plot_missing_bars(df)

# With custom threshold line at 30%
fig = plot_missing_bars(df, threshold=30.0)

# Horizontal bars for many columns
fig = plot_missing_bars(df, orientation=:horizontal)
```

# Color coding
- Blue: < 20% missing
- Orange: 20-50% missing
- Red: >= 50% missing

# Notes
- **Vertical orientation** (default for ≤20 columns): No label overlap issues
- **Horizontal orientation** (automatic for >20 columns): If column labels overlap, 
  increase figure height: `figsize=(800, 1200)` or use `figsize=(1000, 50*n_cols)`
- For very wide datasets (>50 columns), consider filtering to most relevant columns first
"""
function plot_missing_bars(df::DataFrame; 
                           sort::Bool=true, 
                           figsize::Tuple{Int,Int}=(800, 600),
                           threshold::Union{Nothing,Float64}=nothing,
                           orientation::Symbol=:auto)
    
    # ========================================
    # VALIDATION
    # ========================================
    
    validate_dataframe(df)
    validate_figsize(figsize)
    
    if !isnothing(threshold)
        validate_threshold(threshold)
    end
    
    if !(orientation in [:auto, :vertical, :horizontal])
        throw(InvalidParameterError(
            "orientation",
            orientation,
            ":auto, :vertical, or :horizontal"
        ))
    end
    
    # ========================================
    # GRACEFUL DEGRADATION
    # ========================================
    
    # Warn for large number of columns
    if ncol(df) > 50
        @warn "DataFrame has $(ncol(df)) columns. Bar chart may be crowded. " *
              "Consider filtering columns with threshold parameter or selecting subset." maxlog=1
    end
    
    # Calculate missing percentages using existing function
    missing_pcts = missing_percentage(df)
    
    # Check if all columns are 0% missing
    if all(missing_pcts .== 0.0)
        @info "No missing values detected. All bars will show 0%." maxlog=1
    end
    
    # Check if all columns are 100% missing
    if all(missing_pcts .== 100.0)
        @warn "All columns are 100% missing. Consider checking data quality." maxlog=1
    end
    
    # ========================================
    # EXISTING IMPLEMENTATION
    # ========================================
    
    col_names = names(df)
    
    # Determine orientation
    n_cols = length(col_names)
    is_horizontal = if orientation == :auto
        n_cols > 20
    elseif orientation == :horizontal
        true
    elseif orientation == :vertical
        false
    else
        error("orientation must be :auto, :vertical, or :horizontal")
    end
    
    # Sort if requested
    if sort
        sorted_indices = sortperm(missing_pcts, rev=true)
        col_names = col_names[sorted_indices]
        missing_pcts = missing_pcts[sorted_indices]
    end
    
    # Determine colors based on thresholds
    colors = map(missing_pcts) do pct
        if pct >= 50.0
            :red          # >= 50%: Critical (majority missing)
        elseif pct >= 20.0
            :orange       # >= 20% and < 50%: Warning (significant missing)
        else
            :steelblue    # < 20%: Acceptable (minor missing)
        end
    end
    
    # Create figure
    fig = Figure(size=figsize)
    
    if is_horizontal
        # Horizontal bar plot
        ax = Axis(fig[1, 1],
                  ylabel="Columns",
                  xlabel="Missing (%)",
                  title="Missing Data Percentage by Column")
        
        barplot!(ax, missing_pcts, 1:length(col_names),
                 direction=:x,
                 color=colors,
                 strokewidth=1,
                 strokecolor=:black)
        
        # Adjust label font size based on number of columns
        label_fontsize = if n_cols > 30
            9
        elseif n_cols > 20
            11
        else
            13
        end
        
        ax.yticks = (1:length(col_names), col_names)
        ax.yticklabelsize = label_fontsize
        xlims!(ax, 0, 105)
        
        # Add threshold line if specified
        if !isnothing(threshold)
            vlines!(ax, [threshold], color=:black, linestyle=:dash, linewidth=2)
            
            # Annotate columns above threshold
            above_threshold = findall(missing_pcts .>= threshold)
            for idx in above_threshold
                text!(ax, threshold + 2, idx, 
                      text="▶", 
                      fontsize=10, 
                      color=:black)
            end
        end
        
    else  
        # Vertical bar plot
        ax = Axis(fig[1, 1],
                  xlabel="Columns",
                  ylabel="Missing (%)",
                  title="Missing Data Percentage by Column",
                  xticklabelrotation=π/4)
        
        barplot!(ax, 1:length(col_names), missing_pcts, 
                 color=colors,
                 strokewidth=1,
                 strokecolor=:black)
        
        ax.xticks = (1:length(col_names), col_names)
        ylims!(ax, 0, 105)
        
        # Add threshold line if specified
        if !isnothing(threshold)
            hlines!(ax, [threshold], color=:black, linestyle=:dash, linewidth=2)
            
            # Annotate columns above threshold
            above_threshold = findall(missing_pcts .>= threshold)
            for idx in above_threshold
                text!(ax, idx, threshold + 2, 
                      text="▲", 
                      fontsize=12, 
                      color=:black,
                      align=(:center, :bottom))
            end
        end
    end
    
    # Add color legend
    Legend(fig[1, 2],
           [PolyElement(color=:steelblue, strokecolor=:black),
            PolyElement(color=:orange, strokecolor=:black),
            PolyElement(color=:red, strokecolor=:black)],
           ["< 20% (Acceptable)", "20-50% (Warning)", "≥ 50% (Critical)"],
           "Missing Data Severity")
    
    return fig
end