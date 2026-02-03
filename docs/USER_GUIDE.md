# MissingDataViz.jl - User Guide

## Quick Start

```julia
using MissingDataViz
using DataFrames

# Create sample data with missing values
df = DataFrame(
    Name = ["Alice", "Bob", missing, "David", "Eve"],
    Age = [25, missing, 30, missing, 35],
    Salary = [50000, 60000, missing, 70000, missing],
    Department = ["HR", "IT", "IT", missing, "HR"]
)

# One-line complete analysis
results = diagnose_missing(df)
# → Displays 4 plots automatically
# → Returns statistics and figures
```

---

## Table of Contents

1. [Installation](#installation)
2. [Core Functions](#core-functions)
3. [Workflow: Interactive Analysis](#workflow-interactive-analysis)
4. [Workflow: Batch Reporting](#workflow-batch-reporting)
5. [Exporting Individual Plots](#exporting-individual-plots)
6. [Advanced Usage](#advanced-usage)
7. [Troubleshooting](#troubleshooting)

---

## Installation

```julia
# From Julia REPL
using Pkg
Pkg.add("MissingDataViz")

# Or activate from local directory
Pkg.activate(".")
Pkg.instantiate()
```

---

## Core Functions

### Pattern Detection

```julia
# Get missing data pattern matrix (boolean)
pattern = missing_pattern(df)

# Get percentage of missing values per column
percentages = missing_percentage(df)

# Get count of missing values per column
counts = missing_count(df)

# Get correlation matrix of missingness patterns
corr = missing_correlation(df)
```

### Visualizations

```julia
# Missing data matrix heatmap
fig1 = plot_missing_matrix(df)

# Bar chart of missing percentages
fig2 = plot_missing_bars(df)

# Correlation matrix of missingness
fig3 = plot_missing_correlation(df)

# Combined overview dashboard
fig4 = plot_missing_overview(df)
```

### All-in-One Analysis

```julia
# Interactive mode (default)
results = diagnose_missing(df)

# Batch mode (generate HTML report)
results = diagnose_missing(df, report=true, output="report.html")
```

---

## Workflow: Interactive Analysis

### Basic Usage

```julia
using MissingDataViz, DataFrames

df = load_data()  # Your data loading function

# Automatic analysis with plot display
results = diagnose_missing(df)

# Access statistics
println("Total missing: ", results[:stats][:total_missing])
println("Overall percentage: ", results[:stats][:overall_percentage], "%")

# Access per-column statistics
for (col, stats) in results[:stats][:columns]
    println("$col: $(stats[:percentage])% missing")
end
```

### Without Plot Display

```julia
# Compute statistics without displaying plots
results = diagnose_missing(df, display=false)

# Manually display specific plot later
display(results[:figures][:matrix])
```

### Verbose Logging

```julia
# Enable detailed logging for debugging
results = diagnose_missing(df, verbose=true)
# Output:
# ┌ Info: Computing missing data statistics...
# ┌ Info: Statistics computed
# │   total_missing = 42
# │   total_cells = 1000
# │   percentage = 4.2
# ┌ Info: Generating visualizations...
# ┌ Info: Visualizations generated
# │   count = 4
# ┌ Info: Displaying plots interactively...
# └ Info: Plots displayed
```

---

## Workflow: Batch Reporting

### Generate HTML Report

```julia
using MissingDataViz, DataFrames

df = load_data()

# Generate standalone HTML report
results = diagnose_missing(df, report=true, output="analysis.html")

println("Report saved to: ", results[:report_path])
# → Report saved to: /absolute/path/to/analysis.html
```

### File Path Handling

```julia
# Relative path (saved in current working directory)
results = diagnose_missing(df, report=true, output="report.html")
# → Saved at: pwd()/report.html

# Check current directory
pwd()
# → "/home/user/projects/analysis"

# Absolute path (saved at specified location)
results = diagnose_missing(df, report=true, 
                           output="/home/user/reports/Q4_analysis.html")
# → Saved at: /home/user/reports/Q4_analysis.html

# Subdirectory (must exist)
mkpath("reports")  # Create directory if needed
results = diagnose_missing(df, report=true, output="reports/analysis.html")
# → Saved at: pwd()/reports/analysis.html
```

### Custom Report Title

```julia
# Generate report with custom title
path = generate_html_report(
    df, 
    "quarterly_report.html",
    title="Q4 2024 Data Quality Report"
)
```

### Open Report in Browser

```julia
# Cross-platform browser opening
results = diagnose_missing(df, report=true)
path = results[:report_path]

# Windows
if Sys.iswindows()
    run(`cmd /c start $path`)
# macOS
elseif Sys.isapple()
    run(`open $path`)
# Linux
else
    run(`xdg-open $path`)
end
```

### Convenience Syntax

```julia
# These two are equivalent:
results = diagnose_missing(df, report=true, output="report.html")
results = diagnose_missing(df, "report.html")  # Shorthand
```

---

## Exporting Individual Plots

All plotting functions return `Makie.Figure` objects. Export them using `CairoMakie.save()`.

### Supported Formats

```julia
using CairoMakie

# Generate a plot
fig = plot_missing_matrix(df)

# PNG (default 300 DPI)
save("output.png", fig)

# PDF (vector format, high quality)
save("output.pdf", fig)

# SVG (vector format, editable)
save("output.svg", fig)
```

### Custom Resolution

```julia
# High-resolution PNG for publications
save("high_res.png", fig, px_per_unit=3)  # 900 DPI equivalent

# Custom size
save("custom.png", fig, size=(1920, 1080))

# Both resolution and size
save("presentation.png", fig, px_per_unit=2, size=(1600, 900))
```

### Export All Plots

```julia
results = diagnose_missing(df, display=false)

for (name, fig) in results[:figures]
    save("$(name)_plot.png", fig)
end
# Creates: matrix_plot.png, bars_plot.png, correlation_plot.png, overview_plot.png
```

### Advanced CairoMakie Options

For more control over exports, see the [CairoMakie documentation](https://docs.makie.org/stable/explanations/backends/cairomakie/).

```julia
# Example: PNG with transparency
save("transparent.png", fig, px_per_unit=2, transparent=true)

# Example: PDF with specific page size
save("a4.pdf", fig, pt_per_unit=1, size=(595, 842))  # A4 in points
```

---

## Converting HTML Report to PDF

The HTML report can be converted to PDF using your browser's Print to PDF feature:

### Browser Method (Recommended)

1. Open the HTML report in your browser
2. Press `Ctrl+P` (Windows/Linux) or `Cmd+P` (macOS)
3. Select "Save as PDF" as the destination
4. Click "Save"

**Advantages:**
- No additional dependencies
- Works on all platforms
- Preserves formatting perfectly

### Command-Line Tools (Optional)

For automated batch PDF generation, you can use external tools:

```bash
# Using wkhtmltopdf (install separately)
wkhtmltopdf report.html report.pdf

# Using pandoc (install separately)
pandoc report.html -o report.pdf

# Using Chrome headless (if Chrome installed)
google-chrome --headless --print-to-pdf=report.pdf report.html
```

**Note:** These tools are NOT required for normal usage. The browser method is sufficient for most users.

---

## Advanced Usage

### Analyzing Specific Columns

```julia
# Select subset of columns
df_subset = select(df, [:Age, :Salary, :Score])
results = diagnose_missing(df_subset)
```

### Filtering Data Before Analysis

```julia
# Analyze only rows from a specific department
df_filtered = filter(row -> row.Department == "IT", df)
results = diagnose_missing(df_filtered)
```

### Combining with DataFrames.jl

```julia
using DataFrames

# Identify columns with high missingness
results = diagnose_missing(df, display=false)

high_missing_cols = [
    col for (col, stats) in results[:stats][:columns]
    if stats[:percentage] > 20.0
]

println("Columns with >20% missing: ", high_missing_cols)
```

### Custom Analysis Pipeline

```julia
# Step 1: Analyze missing data
results = diagnose_missing(df, display=false)

# Step 2: Generate report if missingness is high
if results[:stats][:overall_percentage] > 10.0
    @warn "High missingness detected ($(results[:stats][:overall_percentage])%)"
    diagnose_missing(df, "high_missing_report.html")
end

# Step 3: Export specific plots
if haskey(results[:stats][:columns], "critical_column")
    save("critical_missing.png", results[:figures][:matrix])
end
```

---

## Troubleshooting

### Issue: Plots not displaying in REPL

**Solution:** Activate the CairoMakie backend explicitly

```julia
using CairoMakie
CairoMakie.activate!()

results = diagnose_missing(df)
```

### Issue: "Directory does not exist" error

**Solution:** Create the output directory before generating reports

```julia
# Create directory if needed
output_dir = "reports"
!isdir(output_dir) && mkdir(output_dir)

# Then generate report
results = diagnose_missing(df, report=true, output="reports/analysis.html")
```

### Issue: Out of memory with large datasets

**Solution:** Use `display=false` to skip plot rendering

```julia
# For very large datasets (>100K rows)
results = diagnose_missing(df, display=false)

# Access statistics only
println(results[:stats])
```

### Issue: Special characters in filenames

**Solution:** Use ASCII-safe filenames or absolute paths

```julia
# Avoid: "rapport données.html" (spaces, accents)
# Use:   "rapport_donnees.html"

results = diagnose_missing(df, report=true, output="rapport_donnees.html")
```

### Issue: Report doesn't open in browser

**Solution:** Use absolute path or navigate manually

```julia
results = diagnose_missing(df, report=true)
path = results[:report_path]

println("Open this file manually: ", path)
```

---

## Performance Tips

### For Large Datasets (>10K rows)

```julia
# Skip interactive display
results = diagnose_missing(df, display=false)

# Generate report directly
results = diagnose_missing(df, "report.html", verbose=true)
```

### For Repeated Analysis

```julia
# Cache pattern detection results
pattern = missing_pattern(df)
percentages = missing_percentage(df)

# Use pattern for custom analysis
# (Avoids recomputing on each plot call)
```

---

## Examples

See the `examples/` directory for complete working examples:

- `examples/01_basic_usage.jl` - Quick start guide
- `examples/02_batch_reporting.jl` - Automated report generation
- `examples/03_custom_analysis.jl` - Advanced filtering and analysis
- `examples/04_export_plots.jl` - Exporting plots in multiple formats

---

## API Reference

For detailed function signatures and parameters, see the [API Documentation](api.md).

---

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/MissingDataViz.jl/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/MissingDataViz.jl/discussions)
- **Documentation:** [Online Docs](https://yourusername.github.io/MissingDataViz.jl)