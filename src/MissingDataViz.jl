# src/MissingDataViz.jl
module MissingDataViz

# ================================================================
# CI WORKAROUND: Set headless mode BEFORE loading Makie
# ================================================================
if get(ENV, "CI", "false") == "true"
    ENV["GKSwstype"] = "nul"
    ENV["MPLBACKEND"] = "Agg"
    ENV["JULIA_DEBUG"] = ""
end

# ================================================================
# DEPENDENCIES
# ================================================================
using DataFrames
using Makie
using CairoMakie
using Statistics
using Dates
using Base64
using Base.Threads

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

# 8. MCAR statistical tests submodule (Phase 2)
include("tests/MCARTests.jl")
using .MCARTests

# 9. MCAR results visualization (depends on MCARTests types)
include("plots/mcar_results.jl")
include("plots/dashboard.jl")

# 10. All-in-one diagnosis pipeline (depends on everything above)
include("full_diagnosis.jl")

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
export plot_mcar_test_results
export missing_correlation
export plot_missing_diagnosis

# ================================================================
# EXPORTS - Report Generation & Diagnosis
# ================================================================
export generate_html_report   
export diagnose_missing
export full_missing_diagnosis

# ================================================================
# EXPORTS - Validation & Error Handling
# ================================================================

# Custom error types
export MissingDataVizError
export InvalidDataFrameError
export InvalidParameterError
export InsufficientDataError

# Validation functions
export validate_dataframe

# Internal validation functions (NOT exported - used internally only)
# - validate_figsize
# - validate_threshold
# - validate_numeric_columns
# - check_all_missing_column
# - check_all_present_column
# - warn_large_dataset

# ================================================================
# EXPORTS - MCAR Statistical Tests 
# ================================================================

# Result types
export TestResult, MCARMechanism
export MCAR_NOT_REJECTED, MCAR_REJECTED, INCONCLUSIVE

# Test functions 
export test_mcar_means, test_all_mcar_means
export summary_table 
export test_mcar_logistic
export test_mcar_little
export generate_mcar_data, generate_mar_data, generate_mnar_data
export ValidationMetrics, describe_missing_mechanism
export compare_mcar_tests, MCARTestComparison


end # module MissingDataViz