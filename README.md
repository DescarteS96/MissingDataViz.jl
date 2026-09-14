# MissingDataViz.jl

**Missing data diagnosis, statistical testing, and visualization for Julia DataFrames**

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://DescarteS96.github.io/MissingDataViz.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://DescarteS96.github.io/MissingDataViz.jl/dev/)
[![Build Status](https://github.com/DescarteS96/MissingDataViz.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/DescarteS96/MissingDataViz.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/DescarteS96/MissingDataViz.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/DescarteS96/MissingDataViz.jl)

---

## What is MissingDataViz.jl?

MissingDataViz.jl is a **diagnostic-first** Julia package for missing data analysis. It goes beyond visualization to help you understand *why* data is missing — testing the MCAR (Missing Completely At Random) assumption with three complementary statistical tests — before any imputation decision is made.

No existing tool combines visualization, multiple MCAR tests, and a multi-test consensus in a single Julia-native pipeline. See [Benchmarks & Validation](https://DescarteS96.github.io/MissingDataViz.jl/stable/benchmarks/) for a full comparison with missingno (Python) and naniar (R), cross-language performance numbers, and the statistical calibration study.

---

## Installation

```julia
using Pkg
Pkg.add("MissingDataViz")
```

**Requirements:** Julia 1.10 or later. Continuously tested on 1.10, 1.11, and 1.12.

---

## Quick Start

```julia
using MissingDataViz, DataFrames, Random

Random.seed!(42)
n = 50
df = DataFrame(
    age    = rand(20:65, n),                                     # fully observed
    income = [rand() < 0.20 ? missing : rand(30000:90000) for _ in 1:n],
    score  = [rand() < 0.15 ? missing : rand(1:10)        for _ in 1:n]
)

# Full pipeline: patterns + visualizations + MCAR tests + recommendation
results = full_missing_diagnosis(df)
println(results[:recommendation])
# → dashboard saved to missing_dashboard.png
# → report saved to missing_report.html
```

### MCAR statistical tests

```julia
# Three complementary tests
r_little   = test_mcar_little(df)
r_welch    = test_mcar_means(df, :income, :age)   # :age must be fully observed
r_logistic = test_mcar_logistic(df, :income)

# Multi-test consensus
consensus = compare_mcar_tests(df)
println(consensus.summary)         # per-test breakdown
println(consensus.recommendation)  # verdict and next-step guidance
```

`consensus.recommendation` reports one of: **STRONG AGREEMENT** (all
tests reject MCAR), **FULL AGREEMENT** (all tests fail to reject),
**PARTIAL DISAGREEMENT**, **MIXED RESULTS**, or **INSUFFICIENT DATA**
when the dataset is too small or degenerate for any test to reach a
conclusion — that last case is deliberately never reported as
evidence for MCAR.

### Visualizations

```julia
plot_missing_matrix(df)       # Heatmap of missing patterns
plot_missing_bars(df)         # Bar chart of missing percentages
plot_missing_correlation(df)  # Correlation between missingness patterns
plot_missing_diagnosis(df)    # 2×2 integrated dashboard (viz + MCAR tests)
```

---

## Statistical Tests

MissingDataViz.jl implements three complementary MCAR tests, combined
by `compare_mcar_tests` into a consensus decision:

- **`test_mcar_means`** — Welch t-test comparing a fully observed
  variable's mean between rows where another column is missing vs.
  present.
- **`test_mcar_logistic`** — models the probability of missingness
  from observed predictors (numeric or categorical) via a global
  likelihood ratio test.
- **`test_mcar_little`** — classic multivariate chi-squared test
  (Little, 1988).

The Welch t-test and the logistic regression test maintain nominal
Type I error across all conditions in our calibration study; Little's
test shows inflation at higher missingness rates and should be used
as a confirmation test rather than the primary diagnostic. Full
methodology and numbers: [Benchmarks & Validation](https://DescarteS96.github.io/MissingDataViz.jl/stable/benchmarks/).

---

## API Reference

Full documentation with examples: [API Reference](https://DescarteS96.github.io/MissingDataViz.jl/stable/api/).

### Diagnosis Pipeline

```julia
full_missing_diagnosis(df;
    output           = "missing_report.html",
    dashboard_file   = "missing_dashboard.png",
    run_mcar_tests   = true,
    alpha            = 0.05,
    export_dashboard = true,
    verbose          = false)
```
End-to-end pipeline: pattern statistics + visualizations + MCAR tests + HTML report + dashboard PNG.

```julia
diagnose_missing(df; report=false, output="missing_report.html")
```
Phase 1 pipeline (visualizations + HTML report only, no statistical tests).

### MCAR Tests

```julia
test_mcar_little(df; alpha=0.05)
test_mcar_means(df, col_missing, col_complete; alpha=0.05)
test_mcar_logistic(df, col_missing; alpha=0.05, max_levels=20, min_epv=10.0)
compare_mcar_tests(df; alpha=0.05, verbose=true)
```

### Visualizations

```julia
plot_missing_matrix(df)
plot_missing_bars(df)
plot_missing_correlation(df)
plot_missing_overview(df)
plot_missing_diagnosis(df)
plot_mcar_test_results(results)
```

### Synthetic Data Generators

```julia
generate_mcar_data(n_rows, n_cols, miss_rate; seed=42)
generate_mar_data(n_rows, n_cols, miss_rate; seed=42)
generate_mnar_data(n_rows, n_cols, miss_rate; seed=42)
```

---

## Documentation

On the versioned documentation site:

- [Getting Started](https://DescarteS96.github.io/MissingDataViz.jl/stable/getting-started/)
- [User Guide](https://DescarteS96.github.io/MissingDataViz.jl/stable/guide/)
- [Benchmarks & Validation](https://DescarteS96.github.io/MissingDataViz.jl/stable/benchmarks/)
- [API Reference](https://DescarteS96.github.io/MissingDataViz.jl/stable/api/)

Additional resources (repository only, not yet part of the versioned docs):

- [Examples Gallery](examples/)
- [MCAR Welch t-test Guide](docs/guides/mcar_means_guide.md)
- [MCAR Logistic Regression Guide](docs/guides/mcar_logistic_guide.md)

---

## License

MIT License — see [LICENSE](LICENSE).

---

## Authors

**Rene Fassou Ballamou**
MSc Student
Eskişehir Technical University
Science Faculty
Department of Statistics
ORCID: 0009-0006-9251-4982

**Dr. İsmail YENİLMEZ**
Associate Professor
Eskişehir Technical University
Science Faculty
Department of Statistics

---

## Citation

If you use MissingDataViz.jl in your research, please cite:

```bibtex
@software{ballamou2026missingdataviz,
  author    = {Ballamou, Rene Fassou and Yenilmez, İsmail},
  title     = {MissingDataViz.jl: A Diagnostic-First Framework for Missing Data Analysis in Julia},
  year      = {2026},
  version   = {0.2.1},
}
```

---

## Acknowledgments

Built with [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl),
[Makie.jl](https://github.com/MakieOrg/Makie.jl),
[GLM.jl](https://github.com/JuliaStats/GLM.jl), and
[HypothesisTests.jl](https://github.com/JuliaStats/HypothesisTests.jl).

---

## Support

Bug reports and feature requests: [GitHub Issues](https://github.com/DescarteS96/MissingDataViz.jl/issues).