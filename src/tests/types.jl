# src/tests/types.jl
# Common interface for all MCAR tests in MissingDataViz.jl
# All test functions return a TestResult struct for consistent downstream use.

"""
    MCARMechanism

Enum representing the inferred missing data mechanism based on test results.

- `MCAR_NOT_REJECTED`: No significant evidence of MCAR violation detected.
- `MCAR_REJECTED`: Significant evidence that MCAR assumption is violated.
- `INCONCLUSIVE`: Test could not reach a conclusion (insufficient data, etc.).
"""
@enum MCARMechanism begin
    MCAR_NOT_REJECTED
    MCAR_REJECTED
    INCONCLUSIVE
end

"""
    TestResult

Unified result structure returned by all MCAR test functions.

# Fields
- `test_name::String`: Name of the statistical test performed.
- `statistic::Float64`: Value of the test statistic (t, chi2, F, etc.).
- `pvalue::Float64`: p-value of the test.
- `alpha::Float64`: Significance threshold used (default 0.05).
- `decision::MCARMechanism`: Inferred mechanism based on pvalue vs alpha.
- `degrees_of_freedom::Union{Float64, Nothing}`: Degrees of freedom if applicable.
- `details::Dict{String, Any}`: Additional test-specific information.
- `warnings::Vector{String}`: Non-fatal warnings (small sample, non-normality, etc.).

# Notes
A `decision` of `MCAR_NOT_REJECTED` does NOT confirm MCAR.
It only indicates no significant dependence was detected among observed variables.
Distinguishing MAR from MNAR requires domain knowledge and cannot be inferred
from statistical tests alone.
"""
struct TestResult
    test_name::String
    statistic::Float64
    pvalue::Float64
    alpha::Float64
    decision::MCARMechanism
    degrees_of_freedom::Union{Float64, Nothing}
    details::Dict{String, Any}
    warnings::Vector{String}
end

"""
    TestResult(test_name, statistic, pvalue; alpha=0.05, degrees_of_freedom=nothing,
               details=Dict{String,Any}(), warnings=String[])

Convenience constructor for `TestResult` with automatic decision inference.

Decision logic:
- `pvalue < alpha` → `MCAR_REJECTED`
- `pvalue >= alpha` → `MCAR_NOT_REJECTED`
- `isnan(pvalue)` → `INCONCLUSIVE`
"""
function TestResult(
    test_name::String,
    statistic::Float64,
    pvalue::Float64;
    alpha::Float64 = 0.05,
    degrees_of_freedom::Union{Float64, Nothing} = nothing,
    details::Dict{String, Any} = Dict{String, Any}(),
    warnings::Vector{String} = String[]
)
    decision = if isnan(pvalue)
        INCONCLUSIVE
    elseif pvalue < alpha
        MCAR_REJECTED
    else
        MCAR_NOT_REJECTED
    end

    return TestResult(
        test_name,
        statistic,
        pvalue,
        alpha,
        decision,
        degrees_of_freedom,
        details,
        warnings
    )
end

"""
    Base.show(io::IO, result::TestResult)

Human-readable display of a TestResult.
Formats output to clearly communicate decision with appropriate epistemic caution.
"""
function Base.show(io::IO, result::TestResult)
    println(io, "─────────────────────────────────────────")
    println(io, "MCAR Test: $(result.test_name)")
    println(io, "─────────────────────────────────────────")
    println(io, "  Statistic : $(round(result.statistic, digits=4))")
    println(io, "  p-value   : $(round(result.pvalue, digits=4))")
    println(io, "  Alpha     : $(result.alpha)")
    println(io, "  Decision  : $(format_decision(result.decision))")
    if !isnothing(result.degrees_of_freedom)
        println(io, "  df        : $(result.degrees_of_freedom)")
    end
    if !isempty(result.warnings)
        println(io, "  ⚠ Warnings:")
        for w in result.warnings
            println(io, "    - $w")
        end
    end
    println(io, "─────────────────────────────────────────")
end

"""
    format_decision(decision::MCARMechanism) -> String

Returns a human-readable string for a MCARMechanism value,
with explicit epistemic framing to avoid overinterpretation.
"""
function format_decision(decision::MCARMechanism)::String
    if decision == MCAR_NOT_REJECTED
        return "MCAR not rejected (no significant dependence detected among observed variables)"
    elseif decision == MCAR_REJECTED
        return "MCAR rejected (significant dependence detected — further investigation recommended)"
    else
        return "Inconclusive (insufficient data or numerical instability)"
    end
end