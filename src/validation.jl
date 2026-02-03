# Centralized validation functions for MissingDataViz

using DataFrames

"""
    validate_dataframe(df)

Validate that `df` is a valid DataFrame for processing.

# Throws
- `ArgumentError`: If `df` is not a DataFrame
- `InvalidDataFrameError`: If DataFrame is empty or has no columns

# Returns
Nothing if validation passes.
"""
function validate_dataframe(df)
    # Check type
    if !isa(df, DataFrame)
        throw(ArgumentError(
            "Expected DataFrame, got $(typeof(df)). " *
            "Please pass a DataFrames.DataFrame object."
        ))
    end
    
    # Check for rows
    if nrow(df) == 0
        throw(InvalidDataFrameError(
            "DataFrame has 0 rows",
            "Provide a DataFrame with at least 1 row of data"
        ))
    end
    
    # Check for columns
    if ncol(df) == 0
        throw(InvalidDataFrameError(
            "DataFrame has 0 columns",
            "Provide a DataFrame with at least 1 column"
        ))
    end
    
    return nothing
end

"""
    validate_figsize(figsize::Tuple{Int, Int})

Validate figure size parameters.

# Arguments
- `figsize`: Tuple of (width, height) in pixels

# Throws
- `InvalidParameterError`: If dimensions are invalid

# Returns
Nothing if validation passes.
"""
function validate_figsize(figsize::Tuple{Int, Int})
    width, height = figsize
    
    if width <= 0
        throw(InvalidParameterError(
            "figsize[1] (width)",
            width,
            "Positive integer (recommended: 800-2000)"
        ))
    end
    
    if height <= 0
        throw(InvalidParameterError(
            "figsize[2] (height)",
            height,
            "Positive integer (recommended: 600-1200)"
        ))
    end
    
    # Warn if unusually large (may cause performance issues)
    if width > 5000 || height > 5000
        @warn "Figure size $(figsize) is very large. This may cause rendering issues or slow performance." maxlog=1
    end
    
    # Warn if unusually small (may be unreadable)
    if width < 200 || height < 200
        @warn "Figure size $(figsize) is very small. Plot may be difficult to read." maxlog=1
    end
    
    return nothing
end

"""
    validate_threshold(threshold::Real)

Validate threshold parameter (percentage).

# Arguments
- `threshold`: Percentage value (0-100)

# Throws
- `InvalidParameterError`: If threshold is outside [0, 100]

# Returns
Nothing if validation passes.
"""
function validate_threshold(threshold::Real)
    if threshold < 0 || threshold > 100
        throw(InvalidParameterError(
            "threshold",
            threshold,
            "Value between 0 and 100 (percentage)"
        ))
    end
    
    return nothing
end

"""
    validate_numeric_columns(df::DataFrame, min_required::Int=1)

Check if DataFrame has sufficient numeric columns for correlation analysis.

# Arguments
- `df`: DataFrame to check
- `min_required`: Minimum number of numeric columns required (default: 1)

# Throws
- `InsufficientDataError`: If not enough numeric columns

# Returns
Vector of numeric column names if validation passes.
"""
function validate_numeric_columns(df::DataFrame, min_required::Int=1)
    numeric_cols = [col for col in names(df) if eltype(df[!, col]) <: Union{Number, Missing}]
    
    if length(numeric_cols) < min_required
        throw(InsufficientDataError(
            "correlation analysis",
            "At least $min_required numeric column(s)",
            "Found $(length(numeric_cols)) numeric column(s) out of $(ncol(df)) total"
        ))
    end
    
    return numeric_cols
end

"""
    warn_large_dataset(df::DataFrame, operation::String, limit::Int)

Issue warning if dataset exceeds recommended size for an operation.

# Arguments
- `df`: DataFrame being processed
- `operation`: Name of the operation (for warning message)
- `limit`: Recommended maximum size

# Returns
`true` if dataset is large (warning issued), `false` otherwise.
"""
function warn_large_dataset(df::DataFrame, operation::String, limit::Int)
    n = nrow(df)
    
    if n > limit
        @warn "Dataset contains $n rows. $operation may be slow or memory-intensive. " *
              "Consider using a sample of your data for exploration." maxlog=1
        return true
    end
    
    return false
end

"""
    check_all_missing_column(df::DataFrame, col::Symbol)

Check if a column is entirely missing values.

# Returns
`true` if column is 100% missing, `false` otherwise.
"""
function check_all_missing_column(df::DataFrame, col::Symbol)
    return all(ismissing, df[!, col])
end

"""
    check_all_present_column(df::DataFrame, col::Symbol)

Check if a column has no missing values.

# Returns
`true` if column is 0% missing, `false` otherwise.
"""
function check_all_present_column(df::DataFrame, col::Symbol)
    return all(!ismissing, df[!, col])
end