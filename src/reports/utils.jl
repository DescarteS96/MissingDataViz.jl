# Utility functions for HTML report generation (private)

using Base64
using CairoMakie

"""
    _plot_to_base64(fig::Figure; resolution=(800,600))::String

Convert a Makie Figure to a base64-encoded PNG data URI.
"""
function _plot_to_base64(fig::Figure; resolution=(800,600))::String
    tmpfile = tempname() * ".png"
    
    try
        save(tmpfile, fig; px_per_unit=2, size=resolution)
        png_data = read(tmpfile)
        base64_data = base64encode(png_data)
        return "data:image/png;base64," * base64_data
    finally
        isfile(tmpfile) && rm(tmpfile)
    end
end

"""
    _validate_output_path(output_file::String)::String

Validate and normalize output file path.
"""
function _validate_output_path(output_file::String)::String
    # Convert to absolute path
    abs_path = isabspath(output_file) ? output_file : abspath(output_file)
    
    # Check parent directory exists
    parent_dir = dirname(abs_path)
    if !isdir(parent_dir)
        error("Output directory does not exist: $parent_dir")
    end
    
    # Simplified - just return the path
    # Don't check writability because OneDrive causes issues
    return abs_path
end