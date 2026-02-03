# Error Handling Guide

## Overview

MissingDataViz uses a comprehensive error handling system to provide clear, actionable feedback when things go wrong.

## Error Types

### 1. InvalidDataFrameError

**When:** DataFrame doesn't meet basic requirements

**Example:**
```julia
julia> df = DataFrame()
julia> plot_missing_matrix(df)
ERROR: InvalidDataFrameError: DataFrame has 0 columns
💡 Suggestion: Provide a DataFrame with at least 1 column
```

**Fix:** Ensure your DataFrame has data:
```julia
df = DataFrame(A=[1,2,3], B=[4,5,6])
```

### 2. InvalidParameterError

**When:** Function parameter has invalid value

**Example:**
```julia
julia> plot_missing_matrix(df, figsize=(-100, 600))
ERROR: InvalidParameterError: Parameter 'figsize[1] (width)' = -100
❌ Invalid value
✓ Valid: Positive integer (recommended: 800-2000)
```

**Fix:** Use valid parameter values:
```julia
plot_missing_matrix(df, figsize=(1000, 600))
```

### 3. InsufficientDataError

**When:** Not enough data for requested operation

**Example:**
```julia
julia> df = DataFrame(A=["text"])
julia> plot_missing_correlation(df)
ERROR: InsufficientDataError: Cannot perform 'correlation analysis'
❌ Requires: At least 2 columns
📊 Actual: DataFrame has only 1 column
```

**Fix:** Provide sufficient data:
```julia
df = DataFrame(A=[1,2,3], B=[4,5,6])
```

## Warnings

### Large Dataset Warning
```julia
┌ Warning: Dataset contains 15000 rows. Display limited to first 5000 rows.
└ @ MissingDataViz
```

**What it means:** Your dataset is large. Visualization has been automatically sampled.

**Action:** Consider using a sample for exploration:
```julia
df_sample = first(df, 5000)
plot_missing_matrix(df_sample)
```

### Many Columns Warning
```julia
┌ Warning: DataFrame has 120 columns. Plot may be crowded.
│ Consider selecting a subset of columns.
└ @ MissingDataViz
```

**What it means:** Too many columns for clear visualization.

**Action:** Select relevant columns:
```julia
df_subset = select(df, [:col1, :col2, :col3, :col4, :col5])
plot_missing_matrix(df_subset)
```

## Best Practices

1. **Always validate data** before analysis:
```julia
   validate_dataframe(df)
```

2. **Handle edge cases** gracefully:
```julia
   if nrow(df) > 10000
       df = first(df, 10000)  # Sample large datasets
   end
```

3. **Check warnings** in logs - they often contain useful optimization hints

4. **Read error messages** carefully - they include suggestions for fixes