# Custom error types for MissingDataViz

"""
    MissingDataVizError

Abstract base type for all MissingDataViz-specific errors.
"""
abstract type MissingDataVizError <: Exception end

"""
    InvalidDataFrameError <: MissingDataVizError

Thrown when a DataFrame is invalid for processing.

# Fields
- `message::String`: Description of the validation failure
- `suggestion::String`: Actionable suggestion to fix the issue
"""
struct InvalidDataFrameError <: MissingDataVizError
    message::String
    suggestion::String
end

function Base.showerror(io::IO, e::InvalidDataFrameError)
    print(io, "InvalidDataFrameError: ", e.message)
    if !isempty(e.suggestion)
        print(io, "\n💡 Suggestion: ", e.suggestion)
    end
end

"""
    InvalidParameterError <: MissingDataVizError

Thrown when a function parameter has an invalid value.

# Fields
- `parameter::String`: Name of the invalid parameter
- `value::Any`: The invalid value provided
- `constraint::String`: Description of valid values
"""
struct InvalidParameterError <: MissingDataVizError
    parameter::String
    value::Any
    constraint::String
end

function Base.showerror(io::IO, e::InvalidParameterError)
    print(io, "InvalidParameterError: Parameter '", e.parameter, "' = ", e.value)
    print(io, "\n❌ Invalid value")
    print(io, "\n✓ Valid: ", e.constraint)
end

"""
    InsufficientDataError <: MissingDataVizError

Thrown when a DataFrame doesn't have enough data for the requested operation.

# Fields
- `operation::String`: The operation that requires more data
- `required::String`: Description of minimum requirements
- `actual::String`: Description of actual data available
"""
struct InsufficientDataError <: MissingDataVizError
    operation::String
    required::String
    actual::String
end

function Base.showerror(io::IO, e::InsufficientDataError)
    print(io, "InsufficientDataError: Cannot perform '", e.operation, "'")
    print(io, "\n❌ Requires: ", e.required)
    print(io, "\n📊 Actual: ", e.actual)
end