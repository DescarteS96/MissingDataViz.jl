# MissingDataViz.jl

**Missing data diagnosis, statistical testing, and visualization for Julia DataFrames**

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://DescarteS96.github.io/MissingDataViz.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://DescarteS96.github.io/MissingDataViz.jl/dev/)
[![Build Status](https://github.com/DescarteS96/MissingDataViz.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/DescarteS96/MissingDataViz.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/DescarteS96/MissingDataViz.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/DescarteS96/MissingDataViz.jl)

---

## What is MissingDataViz.jl?

MissingDataViz.jl is a **diagnostic-first** Julia package for missing data analysis. It goes beyond visualization to help you understand *why* data is missing — distinguishing between MCAR, MAR, and MNAR mechanisms — before any imputation decision is made.

### Why Julia? Why not missingno or naniar?

| Feature | MissingDataViz.jl | missingno (Python) | naniar (R) |
|---------|:-----------------:|:------------------:|:----------:|
| Visualization | ✓ | ✓ | ✓ |
| Little's MCAR test | ✓ | ✗ | ✓ |
| Pairwise Welch t-tests | ✓ | ✗ | ✗ |
| Logistic regression test | ✓ | ✗ | ✗ |
| Multi-test consensus | ✓ | ✗ | ✗ |
| Auto mechanism recommendation | ✓ | ✗ | ✗ |
| Unified pipeline | ✓ | ✗ | ✗ |
| 100k+ rows (no sampling) | ✓ | ⚠ Slow | ✗ Requires sampling |

**Performance** (matrix visualization, 10 runs median, headless):

| Dataset | Rows | Julia | Python | Speedup |
|---------|------|-------|--------|---------|
| real_adult | 32,560 | 0.057s | 0.528s | **9x** |
| real_diabetic | 101,766 | 0.074s | 1.460s | **20x** |
| real_online_retail | 541,910 | 0.061s | 4.526s | **74x** |

> On a 541,910-row dataset, MissingDataViz.jl completes matrix visualization in 0.06s vs 4.53s for missingno — a **74x speedup** from Julia's JIT compilation.

---

## Installation

```julia
using Pkg
Pkg.add("MissingDataViz")
```

---

> **Julia compatibility:** MissingDataViz.jl requires **Julia 1.9–1.11**. Julia 1.12 is not yet supported due to a CairoMakie incompatibility. Use Julia 1.11.5 (recommended).

## Quick Start

### One-line diagnosis

```julia
using MissingDataViz, DataFrames

df = DataFrame(
    age    = [25, missing, 30, missing, 35],
    income = [50000, 60000, missing, 70000, missing],
    score  = [missing, 8, 7, missing, 9]
)

# Full pipeline: visualize + test + recommend
results = full_missing_diagnosis(df)
# → 2×2 dashboard saved as PNG
# → MCAR test results with consensus
# → Mechanism recommendation (MCAR / MAR / MNAR)
```

### MCAR statistical tests

```julia
# Three complementary tests
r_little   = test_mcar_little(df)
r_welch    = test_mcar_means(df, :income, :age)
r_logistic = test_mcar_logistic(df, :income)

# Multi-test consensus with automatic recommendation
consensus = compare_mcar_tests(df)
println(consensus.recommendation)
# → "MAR — Missing At Random detected"
```

### Visualizations

```julia
plot_missing_matrix(df)       # Heatmap of missing patterns
plot_missing_bars(df)         # Bar chart of missing percentages
plot_missing_correlation(df)  # Correlation between missingness patterns
plot_missing_diagnosis(df)    # 2×2 integrated dashboard
```

---

## Statistical Tests (Phase 2)

MissingDataViz.jl implements three complementary MCAR tests:

### Welch t-test (`test_mcar_means`)
Tests whether the mean of a complete variable differs between observations where another variable is missing vs. present. Perfectly calibrated Type I error (0.0%) across all conditions tested.

### Logistic regression (`test_mcar_logistic`)
Models the probability of missingness as a function of observed variables. Handles both numeric and categorical predictors via GLM.jl.

### Little's chi-square test (`test_mcar_little`)
Classic multivariate test (Little 1988). Note: exhibits inflated Type I error at high missingness rates (>20%) — use as confirmation test only.

### Multi-test consensus (`compare_mcar_tests`)
Runs all three tests and returns a weighted consensus decision with automatic MCAR/MAR/MNAR recommendation.

---

## Calibration Results

Simulation study (1000 iterations, n=1000, seeds fixed):

| Test | Type I @ 10% missing | Type I @ 30% missing | Power (MAR) |
|------|:--------------------:|:--------------------:|:-----------:|
| Welch t-test | **0.0%** ✓ | **0.0%** ✓ | 100% |
| Logistic regression | 19.1% ✗ | 0.0% ✓ | 100% |
| Little's test | 9.7% ✗ | 38.6% ✗ | 100% |

**Recommendation:** Use Welch t-test as primary test. Little's test and logistic regression as confirmation only.

---

## Validated Datasets

MissingDataViz.jl has been validated on 5 public datasets:

| Dataset | Rows | Cols | Missing % |
|---------|------|------|-----------|
| Adult Census | 32,560 | 15 | 0.0% (post-clean) |
| Diabetes 130-US | 101,766 | 50 | 7.4% |
| Melbourne Housing | 13,580 | 21 | 4.6% |
| NYC Airbnb | 48,895 | 16 | 2.6% |
| Online Retail | 541,910 | 8 | 3.2% |

---

## API Reference

### Diagnosis Pipeline

```julia
full_missing_diagnosis(df; output_dir=".", verbose=true)
```
End-to-end pipeline: visualization + MCAR tests + recommendation + dashboard export.

```julia
diagnose_missing(df; report=false, output="missing_report.html")
```
Phase 1 pipeline: visualizations + HTML report.

### MCAR Tests

```julia
test_mcar_little(df; alpha=0.05)
test_mcar_means(df, col_missing, col_complete; alpha=0.05)
test_mcar_logistic(df, col_missing; alpha=0.05)
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

- 📖 [User Guide](docs/USER_GUIDE.md)
- 📚 [Getting Started](docs/src/getting-started.md)
- 💡 [Examples Gallery](examples/)
- 🔬 [MCAR Welch t-test Guide](docs/guides/mcar_means_guide.md)
- 🔬 [MCAR Logistic Regression Guide](docs/guides/mcar_logistic_guide.md)
- 📊 [Scalability Guide](docs/PERFORMANCE.md)

---

## Performance Notes

- **JIT warmup:** First call in a session takes 10–50s (Julia compilation). Subsequent calls are fast.
- **Column scaling:** Logistic regression runs once per column with missing data. Datasets with 20+ columns with missing values benefit from column subsetting.
- **Memory:** Julia stays well below Python at scale (32 MB vs 182 MB at 541k rows for matrix visualization).

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
@article{ballamou2026missingdataviz,
  author  = {Ballamou, Rene Fassou and Yenilmez, Ismail},
  title   = {MissingDataViz.jl: A Diagnostic-First Framework for Missing Data Analysis in Julia},
  journal = {Journal of Open Source Software},
  year    = {2026},
  url     = {https://github.com/DescarteS96/MissingDataViz.jl},
  affiliation = {Eskişehir Technical University, Department of Statistics}
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

- **Issues:** [GitHub Issues](https://github.com/DescarteS96/MissingDataViz.jl/issues)
- **Discussions:** [GitHub Discussions](https://github.com/DescarteS96/MissingDataViz.jl/discussions)