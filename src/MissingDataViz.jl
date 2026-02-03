# src/MissingDataViz.jl
module MissingDataViz

# ================================================================
# DEPENDENCIES
# ================================================================
using DataFrames
using Makie
using CairoMakie
using Statistics
using Dates
using Base64

# ================================================================
# INCLUDES - Load source files in dependency order
# ================================================================

# 1. Error types FIRST (no dependencies)
include("errors.jl")

# 2. Validation functions (depends on errors.jl)
include("validation.jl")

# 3. Utility functions (currently empty)
include("utils.jl")

# 4. Core pattern detection (depends on validation.jl)
include("patterns.jl")

# 5. Visualization modules (depend on patterns.jl and validation.jl)
include("plots/correlation.jl")
include("plots/matrix.jl")
include("plots/bars.jl")
include("plots/overview.jl")

# 6. Report generation (depends on plots)
include("reports/utils.jl")        
include("reports/template.jl")     
include("reports/generate.jl")  

# 7. Main diagnosis workflow (depends on everything)
include("diagnose.jl")

# ================================================================
# EXPORTS - Pattern Detection Functions
# ================================================================
export missing_pattern
export missing_percentage
export missing_count
export pattern_counts
export pattern_counts_parallel
export pattern_frequency
export PatternInfo
export row_missing_stats
export column_missing_distribution
export extreme_patterns
export summarize_missing

# ================================================================
# EXPORTS - Visualization Functions
# ================================================================
export plot_missing_matrix
export plot_missing_bars
export plot_missing_correlation
export plot_missing_overview
export missing_correlation

# ================================================================
# EXPORTS - Report Generation & Diagnosis
# ================================================================
export generate_html_report   
export diagnose_missing

# ================================================================
# EXPORTS - Validation & Error Handling (NEW - PARTIE 3)
# ================================================================

# Custom error types
export MissingDataVizError
export InvalidDataFrameError
export InvalidParameterError
export InsufficientDataError

# Validation functions
export validate_dataframe
export validate_figsize
export validate_threshold
export validate_numeric_columns

# Helper functions for checks
export check_all_missing_column
export check_all_present_column
export warn_large_dataset

end # module MissingDataViz
