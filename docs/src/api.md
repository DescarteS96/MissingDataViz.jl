# API Reference

This page provides detailed documentation for all public functions in MissingDataViz.jl.

---

## Pattern Detection

Functions for detecting and analyzing missing data patterns.
```@docs
missing_pattern
missing_count
missing_percentage
pattern_counts
pattern_counts_parallel
pattern_frequency
row_missing_stats
column_missing_distribution
extreme_patterns
summarize_missing
missing_correlation
```

---

## Visualizations

### Matrix Heatmap
```@docs
plot_missing_matrix
```

### Bar Charts
```@docs
plot_missing_bars
```

### Correlation Matrix
```@docs
plot_missing_correlation
```

### Overview Dashboard
```@docs
plot_missing_overview
```

### MCAR Diagnostic Dashboard
```@docs
plot_missing_diagnosis
plot_mcar_test_results
```

---

## MCAR Statistical Tests

Functions to test the MCAR (Missing Completely At Random) assumption.
Each test returns a [`TestResult`](@ref); `compare_mcar_tests` runs all
three and produces a consensus.
```@docs
test_mcar_little
test_mcar_means
test_all_mcar_means
test_mcar_logistic
compare_mcar_tests
summary_table
```

### Interpretation Helpers

Human-readable interpretation of individual test results.
```@docs
interpret_mcar_little
interpret_logistic_result
```

### Result Types
```@docs
TestResult
MCARMechanism
MCARTestComparison
```

---

## Synthetic Data Generators

Generators with known ground truth, used to validate the MCAR tests
and to demonstrate expected behavior under each missingness mechanism.
```@docs
generate_mcar_data
generate_mar_data
generate_mnar_data
describe_missing_mechanism
ValidationMetrics
```

---

## Reports and Workflows

Functions for generating reports and complete workflows.
```@docs
generate_html_report
diagnose_missing
full_missing_diagnosis
```

---

## Data Structures
```@docs
PatternInfo
```

---

## Error Types

Custom exceptions raised on invalid input or insufficient data.
```@docs
MissingDataVizError
InvalidDataFrameError
InvalidParameterError
InsufficientDataError
```

---

## Utility Functions
```@docs
validate_dataframe
```

---

## Index
```@index
```