# MissingDataViz.jl - Examples Gallery

This directory contains working examples demonstrating MissingDataViz.jl capabilities.

---

## Quick Start

All examples are self-contained and can be run directly:
```julia
# From Julia REPL
include("examples/01_basic_usage.jl")
```

---

## Example 1: Basic Usage

**File:** `01_basic_usage.jl`  
**Level:** Beginner  
**Time:** < 10 seconds  
**Use case:** Quick start with synthetic data

**What it demonstrates:**
- Creating a simple DataFrame with missing values
- Running `diagnose_missing()` for instant analysis
- Accessing statistics programmatically
- Saving individual plots

**Generated outputs:**
- `basic_usage_matrix.png`
- `basic_usage_bars.png`
- `basic_usage_correlation.png`
- `basic_usage_overview.png`

---

## Example 2: Medical Dataset Analysis

**File:** `02_medical_dataset.jl`  
**Level:** Intermediate  
**Time:** < 15 seconds  
**Use case:** Clinical data quality assessment

**What it demonstrates:**
- Realistic medical dataset simulation
- Comprehensive data quality reporting
- Identifying critical variables (>30% missing)
- Generating HTML reports for stakeholders

**Generated outputs:**
- `medical_overview.png`
- `medical_correlation.png`
- `medical_data_quality_report.html`

**Key insights:**
- Automated variable-level quality assessment
- Pattern detection in clinical measurements
- Decision support for data preprocessing

---

## Example 3: Complete Workflow

**File:** `03_complete_workflow.jl`  
**Level:** Advanced  
**Time:** < 20 seconds  
**Use case:** Production-ready analysis pipeline

**What it demonstrates:**
- Multi-step analysis workflow
- Pattern detection and correlation analysis
- Automated decision logic
- Timestamped outputs for versioning
- Executive reporting

**Generated outputs:**
- `workflow_overview_YYYYMMDD_HHMMSS.png`
- `workflow_matrix_YYYYMMDD_HHMMSS.png`
- `executive_report_YYYYMMDD_HHMMSS.html`

**Key features:**
- End-to-end pipeline from data to decision
- Automated quality thresholds
- Reproducible analysis with timestamps
- Export-ready visualizations

---

## Running All Examples
```julia
# Run all examples sequentially
for example_file in ["01_basic_usage.jl", "02_medical_dataset.jl", "03_complete_workflow.jl"]
    println("\n" * "=" ^ 80)
    println("Running: $example_file")
    println("=" ^ 80)
    include(example_file)
end
```

---

## Customization Tips

### Adjust Figure Sizes
```julia
# In any example, before diagnose_missing():
plot_missing_matrix(df, figsize=(1200, 800))
```

### Change Output Directory
```julia
# Save to specific folder
save("outputs/my_analysis.png", results[:figures][:overview])
```

### Suppress Console Output
```julia
# Silent mode (only generate files)
results = diagnose_missing(df, display=false, verbose=false)
```

---

## Need Help?

- 📖 [Full Documentation](https://DescarteS96.github.io/MissingDataViz.jl)
- 📚 [Getting Started Guide](../docs/src/getting-started.md)
- 🐛 [Report Issues](https://github.com/DescarteS96/MissingDataViz.jl/issues)