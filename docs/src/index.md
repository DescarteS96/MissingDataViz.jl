```@meta
CurrentModule = MissingDataViz
```

# MissingDataViz.jl

*Professional missing data visualization and diagnosis for Julia DataFrames*

---

## Overview

MissingDataViz.jl provides comprehensive tools for analyzing and visualizing missing data patterns in tabular datasets. It combines intuitive visualizations with robust pattern detection to help you understand the structure of missingness in your data.

**Key Features:**
- 🔍 **Pattern Detection**: Identify unique missing data patterns and their frequencies
- 📊 **Multiple Visualizations**: Matrix heatmaps, bar charts, correlation matrices, overview dashboards
- 📄 **HTML Reports**: Generate standalone reports with embedded visualizations
- 💾 **Export Flexibility**: Save plots as PNG, PDF, or SVG
- ⚡ **One-Line Diagnosis**: Complete analysis with `diagnose_missing()`

---

## Installation
```julia
using Pkg
Pkg.add("MissingDataViz")
```

**Development version:**
```julia
using Pkg
Pkg.add(url="https://github.com/DescarteS96/MissingDataViz.jl")
```

---

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

# Generate HTML report for sharing
diagnose_missing(df, report=true, output="analysis.html")
# → Creates standalone HTML file
```

---

## Visualizations

### Missing Data Matrix
```julia
fig = plot_missing_matrix(df)
```

**Shows:** Binary heatmap of missing values (black = missing, white = present) with optional sparkline showing % missing per row.

### Bar Chart
```julia
fig = plot_missing_bars(df)
```

**Shows:** Percentage of missing values per column, color-coded by severity (blue < 20%, orange 20-50%, red ≥ 50%).

### Correlation Matrix
```julia
fig = plot_missing_correlation(df)
```

**Shows:** Correlation between missing data patterns across columns to detect co-occurrence.

### Overview Dashboard
```julia
fig = plot_missing_overview(df)
```

**Shows:** Combined view of all three plots above in a single figure.

---

## Workflows

### Interactive Analysis
```julia
# Display plots and access statistics
results = diagnose_missing(df)

# Access statistics
println("Total missing: ", results[:stats][:total_missing])
println("Overall %: ", results[:stats][:overall_percentage])

# Save individual plots
using CairoMakie
save("matrix.png", results[:figures][:matrix])
save("overview.pdf", results[:figures][:overview])
```

### Batch Reporting
```julia
# Generate HTML report (no interactive display)
results = diagnose_missing(df, report=true, output="report.html")

# Open in browser
path = results[:report_path]
# Windows: run(`cmd /c start $path`)
# macOS: run(`open $path`)
# Linux: run(`xdg-open $path`)
```

---

## Navigation
```@contents
Pages = ["api.md", "guide.md"]
Depth = 2
```

- **[API Reference](api.md)**: Complete function documentation
- **[User Guide](guide.md)**: Detailed workflows, troubleshooting, and examples

---

## Performance

- **Interactive mode**: 150-250ms for typical datasets (1000 rows × 10 columns)
- **Batch mode**: 200-350ms (includes HTML generation)
- **Maximum recommended size**: 100k rows × 100 columns

---

## Support

- **GitHub**: [github.com/DescarteS96/MissingDataViz.jl](https://github.com/DescarteS96/MissingDataViz.jl)
- **Issues**: [Report bugs or request features](https://github.com/DescarteS96/MissingDataViz.jl/issues)
- **Documentation**: [Online docs](https://DescarteS96.github.io/MissingDataViz.jl)

---

## Citation

If you use MissingDataViz.jl in your research, please cite:
```bibtex
@software{missingdataviz2025,
  author = {Ballamou, Rene Fassou},
  title = {MissingDataViz.jl: Missing Data Visualization for Julia},
  year = {2025},
  url = {https://github.com/DescarteS96/MissingDataViz.jl}
}
```

---

## Index
```@index
```