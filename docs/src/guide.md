# User Guide
```@meta
CurrentModule = MissingDataViz
```

This guide is automatically generated from the comprehensive USER_GUIDE.md.

For the most up-to-date information, see [USER_GUIDE.md](https://github.com/DescarteS96/MissingDataViz.jl/blob/master/docs/USER_GUIDE.md) in the repository.

---
```@contents
Pages = ["guide.md"]
Depth = 3
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

## Workflows

### Interactive Analysis
```julia
using MissingDataViz, DataFrames

df = # your data loading

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

### Batch Reporting
```julia
# Generate standalone HTML report
results = diagnose_missing(df, report=true, output="analysis.html")

println("Report saved to: ", results[:report_path])
# → Report saved to: /absolute/path/to/analysis.html
```

---

## Exporting Plots

All plotting functions return `Makie.Figure` objects. Export them using `CairoMakie.save()`.
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

# High-resolution PNG for publications
save("high_res.png", fig, px_per_unit=3)  # 900 DPI equivalent
```

---

## Troubleshooting

### Plots not displaying in REPL

**Solution:** Activate the CairoMakie backend explicitly
```julia
using CairoMakie
CairoMakie.activate!()

results = diagnose_missing(df)
```

### "Directory does not exist" error

**Solution:** Create the output directory before generating reports
```julia
output_dir = "reports"
!isdir(output_dir) && mkdir(output_dir)

results = diagnose_missing(df, report=true, output="reports/analysis.html")
```

### Out of memory with large datasets

**Solution:** Use `display=false` to skip plot rendering
```julia
# For very large datasets (>100K rows)
results = diagnose_missing(df, display=false)

# Access statistics only
println(results[:stats])
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

---

## Complete Reference

For the full user guide with all examples, workflows, and advanced usage, see:

**[USER_GUIDE.md](https://github.com/DescarteS96/MissingDataViz.jl/blob/master/docs/USER_GUIDE.md)**