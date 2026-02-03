# Getting Started

This guide will help you install MissingDataViz.jl and create your first visualization in under 5 minutes.

---

## Installation

### Method 1: From Julia General Registry (Recommended)

Once the package is registered (after v0.1.0 release):
```julia
using Pkg
Pkg.add("MissingDataViz")
```

### Method 2: From GitHub (Current)

For the latest development version:
```julia
using Pkg
Pkg.add(url="https://github.com/DescarteS96/MissingDataViz.jl")
```

### Method 3: Local Development

If you've cloned the repository:
```julia
using Pkg
Pkg.activate("/path/to/MissingDataViz")
Pkg.instantiate()
```

---

## Quick Start: Your First Plot in 5 Minutes

### Step 1: Load the package
```julia
using MissingDataViz
using DataFrames
```

### Step 2: Create sample data with missing values
```julia
# Create a DataFrame with some missing values
df = DataFrame(
    PatientID = 1:10,
    Age = [25, missing, 35, 42, missing, 28, 31, missing, 45, 38],
    Weight = [70, 65, missing, 80, 75, missing, 68, 72, missing, 77],
    BloodPressure = [120, 118, missing, 135, missing, 122, missing, 128, 140, 125],
    Cholesterol = [missing, 180, 195, missing, 210, 185, missing, 200, 220, 190]
)
```

### Step 3: Generate complete analysis
```julia
# One-line complete diagnosis
results = diagnose_missing(df)
```

**What happens:**
- Four plots are automatically displayed:
  1. **Missing data matrix** (heatmap showing pattern)
  2. **Bar chart** (percentage missing per column)
  3. **Correlation matrix** (which columns tend to be missing together)
  4. **Overview dashboard** (all three combined)

### Step 4: Access statistics
```julia
# Get detailed statistics
stats = results[:stats]

println("Total missing values: ", stats[:total_missing])
println("Overall percentage: ", stats[:overall_percentage], "%")

# Per-column breakdown
for (col, info) in stats[:columns]
    println("$col: $(info[:percentage])% missing ($(info[:count]) values)")
end
```

**Output:**
```
Total missing values: 13
Overall percentage: 32.5%
PatientID: 0.0% missing (0 values)
Age: 30.0% missing (3 values)
Weight: 30.0% missing (3 values)
BloodPressure: 30.0% missing (3 values)
Cholesterol: 40.0% missing (4 values)
```

---

## Save Your Work

### Export individual plots
```julia
using CairoMakie

# Save the matrix plot
save("missing_matrix.png", results[:figures][:matrix])

# Save the overview dashboard
save("overview.pdf", results[:figures][:overview])
```

### Generate HTML report
```julia
# Create standalone HTML report
diagnose_missing(df, report=true, output="analysis_report.html")

# Open it in your browser manually, or:
# Windows: run(`cmd /c start analysis_report.html`)
# macOS: run(`open analysis_report.html`)
# Linux: run(`xdg-open analysis_report.html`)
```

---

## Next Steps

### Explore Individual Visualizations

Instead of `diagnose_missing()`, you can create plots individually:
```julia
# Just the matrix heatmap
fig1 = plot_missing_matrix(df)

# Just the bar chart
fig2 = plot_missing_bars(df)

# Just the correlation matrix
fig3 = plot_missing_correlation(df)

# Combined overview
fig4 = plot_missing_overview(df)
```

### Customize Your Plots

All plotting functions accept customization options:
```julia
# Custom size and threshold
plot_missing_bars(df, 
    figsize=(1000, 700),
    threshold=25.0  # Show line at 25% missing
)

# Horizontal orientation for many columns
plot_missing_bars(df, orientation=:horizontal)

# Hide sparkline in matrix plot
plot_missing_matrix(df, show_sparkline=false)
```

### Pattern Detection

Get detailed pattern analysis:
```julia
# Summary of all missing data patterns
summary = summarize_missing(df)

println("Total cells: ", summary.total_cells)
println("Missing cells: ", summary.n_missing)
println("Top 5 patterns:")
for (pattern, count) in summary.top_patterns
    println("  Pattern: ", pattern, " → ", count, " rows")
end
```

---

## Common Use Cases

### 1. Quick Data Quality Check
```julia
# Load your data
df = CSV.read("mydata.csv", DataFrame)

# Instant visual diagnosis
diagnose_missing(df)
```

### 2. Pre-Processing for Machine Learning
```julia
# Check missing data before training
results = diagnose_missing(df, display=false)

# Identify problematic columns
high_missing = [
    col for (col, stats) in results[:stats][:columns]
    if stats[:percentage] > 30.0
]

println("Consider removing or imputing: ", high_missing)
```

### 3. Generate Report for Stakeholders
```julia
# Create professional HTML report
diagnose_missing(df, 
    report=true, 
    output="data_quality_report_$(Dates.today()).html"
)
```

---

## Troubleshooting

### Plots not displaying

If plots don't appear automatically:
```julia
using CairoMakie
CairoMakie.activate!()

results = diagnose_missing(df)
```

### Out of memory with large datasets

For very large datasets (>100k rows):
```julia
# Compute statistics without rendering plots
results = diagnose_missing(df, display=false)

# Access stats without creating figures
println(results[:stats])
```

### File path issues on Windows

Use double backslashes or raw strings:
```julia
# Method 1: Double backslashes
diagnose_missing(df, report=true, output="C:\\Users\\Name\\report.html")

# Method 2: Raw string
diagnose_missing(df, report=true, output=raw"C:\Users\Name\report.html")

# Method 3: Forward slashes (works on Windows too)
diagnose_missing(df, report=true, output="C:/Users/Name/report.html")
```

---

## What You've Learned

✅ Install MissingDataViz.jl  
✅ Create basic visualizations with one line of code  
✅ Access detailed statistics programmatically  
✅ Export plots and generate reports  
✅ Customize visualizations for your needs  

---

## Where to Go Next

- **[API Reference](api.md)**: Complete function documentation
- **[User Guide](guide.md)**: Advanced workflows and batch processing
- **[Examples](https://github.com/DescarteS96/MissingDataViz.jl/tree/master/examples)**: Real-world use cases

---

## Need Help?

- 📖 [Full Documentation](https://DescarteS96.github.io/MissingDataViz.jl)
- 🐛 [Report a Bug](https://github.com/DescarteS96/MissingDataViz.jl/issues)
- 💬 [Ask a Question](https://github.com/DescarteS96/MissingDataViz.jl/discussions)