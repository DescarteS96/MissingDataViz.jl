# src/tests/MCARTests.jl
# MCAR Tests submodule for MissingDataViz.jl
# Provides statistical tests to evaluate the MCAR assumption
# on datasets with missing values.
#
# Exported functions:
#   test_mcar_means      — Welch t-test on group means
#   test_all_mcar_means  — Exhaustive pairwise t-tests with correction
#   test_mcar_logistic   — Logistic regression missingness model
#   test_mcar_little     — Little's (1988) global MCAR test
#
# Exported types:
#   TestResult           — Unified result struct for all tests
#   MCARMechanism        — Enum: MCAR_NOT_REJECTED / MCAR_REJECTED / INCONCLUSIVE

module MCARTests

using DataFrames

# Statistical dependencies — added to Project.toml in Step 9 Part 4
using HypothesisTests
using GLM
using Distributions 

include("types.jl")
include("synthetic_data.jl")
include("mcar_means.jl")
include("mcar_logistic.jl")
include("mcar_little.jl")
include("mcar_comparison.jl")

export TestResult, MCARMechanism
export MCAR_NOT_REJECTED, MCAR_REJECTED, INCONCLUSIVE
export test_mcar_means, test_all_mcar_means
export summary_table 
export test_mcar_logistic
export interpret_logistic_result
export test_mcar_little
export interpret_mcar_little
export generate_mcar_data, generate_mar_data, generate_mnar_data
export ValidationMetrics, describe_missing_mechanism
export compare_mcar_tests, MCARTestComparison

end # module MCARTests