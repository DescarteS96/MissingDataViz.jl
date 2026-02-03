# Required imports for correlation calculations and formatting
using Statistics  # For cor(), std()
using Printf      # For @sprintf formatting

"""
    missing_correlation(df::DataFrame)

Calculate the Pearson correlation matrix between missing data patterns across columns.

This function converts the DataFrame to a binary matrix (1 = missing, 0 = present) and
computes pairwise correlations between columns. Positive correlations indicate columns
that tend to have missing values together, while negative correlations suggest opposite
patterns.

# Arguments
- `df::DataFrame`: Input DataFrame to analyze

# Returns
- `Matrix{Float64}`: Correlation matrix (n_cols × n_cols) where each entry (i,j) 
  represents the correlation between missingness patterns of columns i and j

# Examples
```julia
using DataFrames, MissingDataViz

df = DataFrame(
    A = [1, missing, 3, missing, 5],
    B = [missing, 2, 3, missing, 5],      # Correlates with A
    C = [1, 2, missing, 4, missing]       # Different pattern
)

corr_matrix = missing_correlation(df)
# corr_matrix[1,2] will be high (A and B missing together)
```

# Notes
- Returns NaN for columns with no missing values (constant pattern, no variance)
- Diagonal elements are always 1.0 (perfect self-correlation)
- Correlation ranges from -1.0 (opposite patterns) to 1.0 (identical patterns)
"""
function missing_correlation(df::DataFrame)
    # Get binary missing pattern matrix (reuse existing function)
    binary_matrix = missing_pattern(df)  # Returns BitMatrix: true = missing
    
    # Convert BitMatrix to Float64 for correlation calculation
    # true (missing) → 1.0, false (present) → 0.0
    float_matrix = Float64.(binary_matrix)
    
    n_cols = size(float_matrix, 2)
    corr_matrix = zeros(Float64, n_cols, n_cols)
    
    # Calculate pairwise correlations
    for i in 1:n_cols
        for j in 1:n_cols
            if i == j
                corr_matrix[i, j] = 1.0  # Perfect self-correlation
            else
                col_i = @view float_matrix[:, i]
                col_j = @view float_matrix[:, j]
                
                # Calculate Pearson correlation
                # Handle case where column has no variance (all same value)
                if std(col_i) == 0.0 || std(col_j) == 0.0
                    corr_matrix[i, j] = NaN
                else
                    corr_matrix[i, j] = cor(col_i, col_j)
                end
            end
        end
    end
    
    return corr_matrix
end


"""
    plot_missing_correlation(df::DataFrame; figsize::Tuple{Int,Int}=(800, 800), 
                             show_values::Bool=:auto)

Create a heatmap visualization of the missing data pattern correlation matrix.

# Arguments
- `df::DataFrame`: Input DataFrame to analyze
- `figsize::Tuple{Int,Int}=(800, 800)`: Figure dimensions (width, height)
- `show_values::Bool=:auto`: Display correlation values in cells. Auto shows values if ≤10 columns

# Returns
- `Figure`: Makie Figure object containing the correlation heatmap

# Examples
```julia
using DataFrames, MissingDataViz

df = DataFrame(
    A = [1, missing, 3, missing, 5],
    B = [missing, 2, 3, missing, 5],
    C = [1, 2, missing, 4, missing]
)

fig = plot_missing_correlation(df)
fig = plot_missing_correlation(df, show_values=true)  # Force display values
```

# Interpretation
- **Red (positive correlation)**: Columns tend to have missing values together
- **Blue (negative correlation)**: When one column is missing, the other tends to be present
- **White (zero correlation)**: No relationship between missing patterns
- **Diagonal = 1.0**: Each column perfectly correlates with itself
"""
function plot_missing_correlation(df::DataFrame; 
                                  figsize::Tuple{Int,Int}=(800, 800),
                                  show_values::Union{Bool,Symbol}=:auto)
    
    # ========================================
    # VALIDATION
    # ========================================
    
    validate_dataframe(df)
    validate_figsize(figsize)
    
    # Special validation: need at least 2 columns for correlation
    if ncol(df) < 2
        throw(InsufficientDataError(
            "correlation analysis",
            "At least 2 columns",
            "DataFrame has only $(ncol(df)) column"
        ))
    end
    
    if !(show_values in [:auto, true, false])
        throw(InvalidParameterError(
            "show_values",
            show_values,
            ":auto, true, or false"
        ))
    end
    
    # ========================================
    # GRACEFUL DEGRADATION
    # ========================================
    
    # Warn for many columns (correlation matrix grows O(n²))
    if ncol(df) > 50
        @warn "DataFrame has $(ncol(df)) columns. " *
              "Correlation matrix will be large ($(ncol(df))×$(ncol(df))). " *
              "Consider selecting a subset of columns." maxlog=1
    end
    
    # Check if enough variation in missing patterns
    pattern = missing_pattern(df)
    n_unique_patterns = length(unique(eachrow(pattern)))
    
    if n_unique_patterns == 1
        @info "All rows have identical missing pattern. Correlation matrix will be uniform." maxlog=1
    end
    
    # ========================================
    # EXISTING IMPLEMENTATION
    # ========================================
    
    # Calculate correlation matrix
    corr_matrix = missing_correlation(df)
    col_names = names(df)
    n_cols = length(col_names)
    
    # Determine if we should show values in cells
    display_values = if show_values == :auto
        n_cols <= 10
    elseif show_values isa Bool
        show_values
    else
        error("show_values must be :auto, true, or false")
    end
    
    # Create figure
    fig = Figure(size=figsize)
    ax = Axis(fig[1, 1],
              xlabel="Columns",
              ylabel="Columns",
              title="Missing Data Pattern Correlation",
              aspect=DataAspect())
    
    # Create heatmap with diverging colormap
    # Use :balance colormap: RED = positive, BLUE = negative
    hm = heatmap!(ax, corr_matrix,
                  colormap=:balance,  
                  colorrange=(-1, 1))
    
    # Set column labels
    ax.xticks = (1:n_cols, col_names)
    ax.yticks = (1:n_cols, col_names)
    ax.xticklabelrotation = π/4
    
    # Add colorbar
    Colorbar(fig[1, 2], hm,
             label="Correlation",
             ticks=[-1.0, -0.5, 0.0, 0.5, 1.0])
    
    # Display correlation values in cells if requested
    if display_values
        for i in 1:n_cols
            for j in 1:n_cols
                val = corr_matrix[i, j]
                
                # Choose text color based on background
                text_color = abs(val) > 0.5 ? :white : :black
                
                # Format value
                val_text = if isnan(val)
                    "N/A"
                else
                    @sprintf("%.2f", val)
                end
                
                text!(ax, j, i,
                      text=val_text,
                      color=text_color,
                      fontsize=10,
                      align=(:center, :center))
            end
        end
    end
    
    return fig
end