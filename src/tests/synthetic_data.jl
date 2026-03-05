# src/tests/synthetic_data.jl
# Synthetic dataset generators for MCAR/MAR/MNAR validation.
# Used exclusively to validate statistical test implementations
# in Steps 10 and 11.
#
# Ground truth is known by construction:
#   - MCAR data → tests should NOT reject H0
#   - MAR data  → tests SHOULD reject H0
#   - MNAR data → tests SHOULD reject H0 (when detectable)
#
# Note: MNAR is theoretically undetectable from observed data alone.
# Our tests can only detect MNAR when the missingness correlates
# with observed variables (indirect signal).

using DataFrames
using Random
using Statistics

# ================================================================
# VALIDATION METRICS
# ================================================================

"""
    ValidationMetrics

Stores validation results for a batch of MCAR test runs
on synthetic datasets with known ground truth.

# Fields
- `n_runs::Int`: Total number of test runs.
- `n_correct::Int`: Number of runs where test decision matched ground truth.
- `n_false_positive::Int`: MCAR rejected when data truly is MCAR.
- `n_false_negative::Int`: MCAR not rejected when data is MAR or MNAR.
- `true_positive_rate::Float64`: Sensitivity (correctly detected violations).
- `false_positive_rate::Float64`: Type I error rate (should be ≤ alpha).
- `alpha::Float64`: Significance threshold used.

# Notes
For MCAR data: correct decision = NOT rejected (true negative).
For MAR/MNAR data: correct decision = rejected (true positive).
"""
struct ValidationMetrics
    n_runs::Int
    n_correct::Int
    n_false_positive::Int
    n_false_negative::Int
    true_positive_rate::Float64
    false_positive_rate::Float64
    alpha::Float64
end

"""
    ValidationMetrics(decisions, ground_truth; alpha=0.05)

Convenience constructor that computes all metrics automatically.

# Arguments
- `decisions::Vector{MCARMechanism}`: Test decisions for each run.
- `ground_truth::Symbol`: True mechanism (:MCAR, :MAR, or :MNAR).
- `alpha::Float64`: Significance threshold used in tests.

# Example
```julia
decisions = [MCAR_NOT_REJECTED, MCAR_REJECTED, MCAR_NOT_REJECTED]
metrics = ValidationMetrics(decisions, :MAR)
```
"""
function ValidationMetrics(
    decisions::Vector{MCARMechanism},
    ground_truth::Symbol;
    alpha::Float64 = 0.05
)
    n_runs = length(decisions)
    n_rejected = count(d -> d == MCAR_REJECTED, decisions)
    n_not_rejected = n_runs - n_rejected

    if ground_truth == :MCAR
        # Correct = not rejected
        n_correct = n_not_rejected
        n_false_positive = n_rejected          # Wrongly rejected MCAR
        n_false_negative = 0                   # No false negatives possible here
        fpr = n_false_positive / n_runs
        tpr = 0.0                              # Not applicable for MCAR ground truth
    else
        # MAR or MNAR: correct = rejected
        n_correct = n_rejected
        n_false_positive = 0                   # Not applicable
        n_false_negative = n_not_rejected      # Failed to detect violation
        fpr = 0.0
        tpr = n_correct / n_runs
    end

    return ValidationMetrics(
        n_runs,
        n_correct,
        n_false_positive,
        n_false_negative,
        tpr,
        fpr,
        alpha
    )
end

"""
    Base.show(io::IO, m::ValidationMetrics)

Human-readable display of ValidationMetrics.
"""
function Base.show(io::IO, m::ValidationMetrics)
    println(io, "─────────────────────────────────────────")
    println(io, "Validation Metrics ($(m.n_runs) runs, α=$(m.alpha))")
    println(io, "─────────────────────────────────────────")
    println(io, "  Correct decisions   : $(m.n_correct)/$(m.n_runs)")
    println(io, "  Accuracy            : $(round(m.n_correct/m.n_runs*100, digits=1))%")
    if m.false_positive_rate > 0
        println(io, "  False positive rate : $(round(m.false_positive_rate*100, digits=1))% (target: ≤$(m.alpha*100)%)")
    end
    if m.true_positive_rate > 0
        println(io, "  True positive rate  : $(round(m.true_positive_rate*100, digits=1))%")
    end
    if m.n_false_negative > 0
        println(io, "  False negatives     : $(m.n_false_negative)")
    end
    println(io, "─────────────────────────────────────────")
end

# ================================================================
# MCAR GENERATOR
# ================================================================

"""
    generate_mcar_data(n_rows, n_cols, missing_rate; seed=42) -> DataFrame

Generate a dataset where missingness is MCAR:
values are missing completely at random, independent of all variables.

# Arguments
- `n_rows::Int`: Number of observations.
- `n_cols::Int`: Number of columns (all numeric, normally distributed).
- `missing_rate::Float64`: Proportion of missing values per column (0.0–1.0).
- `seed::Int`: Random seed for reproducibility.

# Returns
A `DataFrame` where each column independently has `missing_rate`
fraction of values replaced by `missing` at random positions.

# Ground truth
Tests on this data should NOT reject MCAR (H0 not rejected).
Expected false positive rate ≤ alpha across many runs.

# Example
```julia
df = generate_mcar_data(200, 5, 0.20)
```
"""
function generate_mcar_data(
    n_rows::Int,
    n_cols::Int,
    missing_rate::Float64;
    seed::Int = 42
)::DataFrame
    @assert 0.0 < missing_rate < 1.0 "missing_rate must be between 0 and 1"
    @assert n_rows >= 30 "n_rows must be at least 30 for reliable testing"
    @assert n_cols >= 2 "n_cols must be at least 2"

    rng = MersenneTwister(seed)

    # Generate base data: each column ~ N(0,1), independent
    data = Dict{Symbol, Vector{Union{Float64, Missing}}}()

    for j in 1:n_cols
        col_name = Symbol("x$j")
        values = randn(rng, n_rows)
        col = Vector{Union{Float64, Missing}}(values)

        # Randomly select positions to make missing (MCAR: pure random)
        n_missing = round(Int, n_rows * missing_rate)
        missing_idx = randperm(rng, n_rows)[1:n_missing]
        col[missing_idx] .= missing

        data[col_name] = col
    end

    return DataFrame(data)
end

# ================================================================
# MAR GENERATOR
# ================================================================

"""
    generate_mar_data(n_rows, n_cols, missing_rate; seed=42) -> DataFrame

Generate a dataset where missingness is MAR:
values in column x2 are missing depending on the observed value of x1.
High values of x1 increase the probability that x2 is missing.

# Arguments
- `n_rows::Int`: Number of observations.
- `n_cols::Int`: Number of columns (minimum 2).
- `missing_rate::Float64`: Average proportion of missing values in x2.
- `seed::Int`: Random seed for reproducibility.

# Returns
A `DataFrame` where x2 has missing values that depend on x1
(MAR mechanism). x1 is always complete (it's the predictor).
Other columns are MCAR with the same missing_rate.

# Ground truth
Tests on x2 (using x1 as predictor) SHOULD reject MCAR.
The dependence is deliberate and detectable.

# Example
```julia
df = generate_mar_data(200, 4, 0.20)
```
"""
function generate_mar_data(
    n_rows::Int,
    n_cols::Int,
    missing_rate::Float64;
    seed::Int = 42
)::DataFrame
    @assert 0.0 < missing_rate < 1.0 "missing_rate must be between 0 and 1"
    @assert n_rows >= 30 "n_rows must be at least 30 for reliable testing"
    @assert n_cols >= 2 "n_cols must be at least 2"

    rng = MersenneTwister(seed)

    data = Dict{Symbol, Vector{Union{Float64, Missing}}}()

    # x1: complete predictor variable (never missing)
    x1 = randn(rng, n_rows)
    data[:x1] = Vector{Union{Float64, Missing}}(x1)

    # x2: MAR — probability of missing increases with x1
    # logistic model: P(R=1 | x1) = sigmoid(beta * x1)
    # beta calibrated so that average missing rate ≈ missing_rate
    beta = 2.0
    prob_missing = 1.0 ./ (1.0 .+ exp.(-beta .* x1))

    # Rescale to match target missing_rate
    scale = missing_rate / mean(prob_missing)
    prob_missing_scaled = clamp.(prob_missing .* scale, 0.0, 1.0)

    x2_base = randn(rng, n_rows)
    x2 = Vector{Union{Float64, Missing}}(x2_base)
    for i in 1:n_rows
        if rand(rng) < prob_missing_scaled[i]
            x2[i] = missing
        end
    end
    data[:x2] = x2

    # Additional columns: MCAR with same missing_rate
    for j in 3:n_cols
        col_name = Symbol("x$j")
        values = randn(rng, n_rows)
        col = Vector{Union{Float64, Missing}}(values)
        n_missing = round(Int, n_rows * missing_rate)
        missing_idx = randperm(rng, n_rows)[1:n_missing]
        col[missing_idx] .= missing
        data[col_name] = col
    end

    return DataFrame(data)
end

# ================================================================
# MNAR GENERATOR
# ================================================================

"""
    generate_mnar_data(n_rows, n_cols, missing_rate; seed=42) -> DataFrame

Generate a dataset where missingness is MNAR:
values in x2 are missing depending on the (unobserved) value of x2 itself.
High values of x2 are more likely to be missing.

# Arguments
- `n_rows::Int`: Number of observations.
- `n_cols::Int`: Number of columns (minimum 2).
- `missing_rate::Float64`: Average proportion of missing values in x2.
- `seed::Int`: Random seed for reproducibility.

# Returns
A `DataFrame` where x2 has missing values that depend on x2's own value
(MNAR mechanism). This is the hardest mechanism to detect.

# Ground truth
MNAR is theoretically undetectable from observed data alone.
Tests may or may not reject MCAR depending on correlation structure.
This generator is provided for stress-testing and documentation purposes.

# Important limitation
Our MCAR tests CANNOT reliably distinguish MNAR from MAR.
A rejection of MCAR on MNAR data is possible but not guaranteed.

# Example
```julia
df = generate_mnar_data(200, 4, 0.20)
```
"""
function generate_mnar_data(
    n_rows::Int,
    n_cols::Int,
    missing_rate::Float64;
    seed::Int = 42
)::DataFrame
    @assert 0.0 < missing_rate < 1.0 "missing_rate must be between 0 and 1"
    @assert n_rows >= 30 "n_rows must be at least 30 for reliable testing"
    @assert n_cols >= 2 "n_cols must be at least 2"

    rng = MersenneTwister(seed)

    data = Dict{Symbol, Vector{Union{Float64, Missing}}}()

    # x1: complete predictor (NOT the cause of missingness here)
    x1 = randn(rng, n_rows)
    data[:x1] = Vector{Union{Float64, Missing}}(x1)

    # x2: MNAR — probability of missing depends on x2's own value
    x2_base = randn(rng, n_rows)
    beta = 2.0
    prob_missing = 1.0 ./ (1.0 .+ exp.(-beta .* x2_base))

    scale = missing_rate / mean(prob_missing)
    prob_missing_scaled = clamp.(prob_missing .* scale, 0.0, 1.0)

    x2 = Vector{Union{Float64, Missing}}(x2_base)
    for i in 1:n_rows
        if rand(rng) < prob_missing_scaled[i]
            x2[i] = missing
        end
    end
    data[:x2] = x2

    # Additional columns: MCAR
    for j in 3:n_cols
        col_name = Symbol("x$j")
        values = randn(rng, n_rows)
        col = Vector{Union{Float64, Missing}}(values)
        n_missing = round(Int, n_rows * missing_rate)
        missing_idx = randperm(rng, n_rows)[1:n_missing]
        col[missing_idx] .= missing
        data[col_name] = col
    end

    return DataFrame(data)
end

# ================================================================
# GROUND TRUTH TESTING HELPER
# ================================================================

"""
    describe_missing_mechanism(df) -> Nothing

Print a diagnostic summary of the missing data structure in a DataFrame.
Used to verify synthetic datasets before running tests.

# Example
```julia
df = generate_mar_data(200, 4, 0.20)
describe_missing_mechanism(df)
```
"""
function describe_missing_mechanism(df::DataFrame)::Nothing
    println("Missing Data Structure:")
    println("  Rows: $(nrow(df)), Cols: $(ncol(df))")
    for col in names(df)
        n_miss = count(ismissing, df[!, col])
        pct = round(n_miss / nrow(df) * 100, digits=1)
        println("  $col: $n_miss missing ($pct%)")
    end
    return nothing
end