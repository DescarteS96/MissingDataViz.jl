---
title: 'MissingDataViz.jl: A Diagnostic-First Framework for Missing Data Analysis in Julia'
tags:
  - Julia
  - missing data
  - MCAR
  - MAR
  - MNAR
  - statistical testing
  - data visualization
  - data quality
authors:
  - name: Rene Fassou Ballamou
    affiliation: 1
    orcid: 0009-0006-9251-4982
  - name: Dr. İsmail YENİLMEZ
    affiliation: 1
    orcid: 0000-0002-3357-3898
affiliations:
  - index: 1
    name: Eskişehir Technical University, Science Faculty, Department of Statistics
date: 2026-03-06
bibliography: paper.bib
---

# Summary

Missing data is a pervasive challenge in empirical research. Before any
imputation strategy can be applied, analysts must determine the underlying
missingness mechanism: Missing Completely At Random (MCAR), Missing At Random
(MAR), or Missing Not At Random (MNAR) [@rubin1976inference]. Existing software
tools either provide visualization without statistical testing (missingno,
@bilogur2018missingno), or statistical testing without a unified pipeline
(naniar, @tierney2023naniar). Neither supports large datasets above 100,000
rows without performance degradation or manual sampling.

`MissingDataViz.jl` fills this gap by providing a **diagnostic-first** framework
that combines visualization, three complementary MCAR statistical tests, multi-test
consensus, and automated mechanism recommendation in a single Julia package. Built
on Julia's JIT compilation infrastructure, it processes a 541,910-row real-world
dataset in 0.06 seconds for matrix visualization — a 74x speedup over the
Python equivalent.

# Statement of Need

The typical analyst workflow for missing data begins with visualization (identifying
patterns), proceeds to statistical testing (determining mechanism), and concludes
with an imputation decision. Current tools fragment this workflow across languages
and packages:

- **missingno** [@bilogur2018missingno]: Python visualization library. No
  statistical tests. Becomes slow above 100k rows (4.53s for 541k-row matrix
  visualization in our benchmarks).

- **naniar** [@tierney2023naniar]: R package with visualization and Little's test.
  No pairwise tests or logistic regression. The `vis_miss` function requires
  sampling to 10,000 rows for large datasets, making direct performance comparison
  with full-data tools invalid.

- **VIM** [@kowarik2016imputation]: R package focused on visualization. No
  consensus testing or automated recommendation.

- **mice** [@vanbuuren2011mice]: R imputation package. Assumes the mechanism is
  already known; does not perform diagnostic testing.

`MissingDataViz.jl` addresses this gap by providing the complete diagnostic
pipeline in a single package, validated on datasets ranging from 1,000 to
541,910 rows across five public real-world datasets.

# Implementation

## Architecture

The package is structured around three layers:

1. **Visualization layer** (`src/plots/`): Four plot types implemented with
   CairoMakie.jl — missing matrix, bar chart, correlation heatmap, and
   integrated 2×2 dashboard.

2. **Statistical testing layer** (`src/tests/`): Three MCAR tests with a
   unified `MCARTestResult` return type and a consensus function.

3. **Pipeline layer** (`src/pipeline/`): `full_missing_diagnosis` orchestrates
   visualization, testing, and recommendation in a single call.

## Statistical Tests

### Welch t-test (`test_mcar_means`)

For each column $X_j$ with missing values, the test compares the mean of a
complete numeric variable $X_k$ between two groups: observations where $X_j$
is missing vs. present [@little2019statistical]:

$$H_0: \mu_{X_k | X_j \text{ missing}} = \mu_{X_k | X_j \text{ present}}$$

Implemented via `HypothesisTests.jl` with Welch's correction for unequal
variances.

### Logistic regression test (`test_mcar_logistic`)

For each column $X_j$ with missing values, a binary logistic regression model
predicts the missingness indicator $R_j \in \{0,1\}$ from all other observed
variables [@sterne2009multiple]:

$$\text{logit}(P(R_j = 1)) = \beta_0 + \beta_1 X_1 + \cdots + \beta_p X_p$$

A significant likelihood ratio test ($p < \alpha$) rejects MCAR. Implemented
via `GLM.jl` with automatic column name sanitization for non-standard identifiers.

### Little's chi-square test (`test_mcar_little`)

The classic multivariate MCAR test [@little1988test] based on the chi-square
statistic comparing observed pattern means to the grand mean under the MCAR
assumption. **Note:** Our simulation study reveals inflated Type I error rates
at high missingness (32.0% at 30% missing, $\alpha=0.05$, $n=1000$), consistent with
known limitations of the chi-square approximation when the number of distinct
missing patterns is large relative to sample size.

### Multi-test consensus (`compare_mcar_tests`)

All three tests are run and a weighted consensus decision is returned. The 
Welch t-test and logistic regression test are given primary weight as the
two tests with nominally calibrated Type I error across all conditions tested.

# Calibration Study

A simulation study (1,000 iterations per condition, $n \in \{1000, 5000\}$,
missing rates $\in \{10\%, 20\%, 30\%\}$, $\alpha \in \{0.01, 0.05, 0.10\}$,
seeds fixed for reproducibility) evaluated Type I error and statistical power
for all three tests.

**Type I error** (target: $\leq \alpha$, MCAR data, $\alpha = 0.05$, $n = 1000$):

| Test | 10% missing | 20% missing | 30% missing |
|------|:-----------:|:-----------:|:-----------:|
| Welch t-test | **5.5%** | **4.3%** | **4.0%** |
| Logistic regression | **5.6%** | **5.5%** | **4.1%** |
| Little's test | 10.0% | 17.5% | 32.0% |

Results at $\alpha = 0.05$, $n = 1000$. Little's test inflation persists at
$n = 5000$ (7.5%, 15.1%, 29.6% respectively), confirming the issue is
structural. The Welch t-test and logistic regression maintain nominal Type I
error rates across all 18 tested conditions ($n \in \{1000, 5000\}$,
missing rate $\in \{10\%, 20\%, 30\%\}$, $\alpha \in \{0.01, 0.05, 0.10\}$).

**Statistical power** (MAR data, $\beta = 2.0$ logistic signal): All three
tests achieve $\geq 99\%$ power at missing rates $\geq 20\%$. The only
exception is Little's test at 10% missing, $n=1000$ (power = 98.2%).
Note: the MAR generator uses a strong linear signal; power results should be
interpreted as an upper bound under the conditions tested.

Little's test is the only test exhibiting systematic Type I error inflation
and should be used as confirmation only. Welch t-test and logistic regression
are both recommended as primary diagnostic tests.

# Performance Benchmarks

Cross-language benchmarks were conducted on identical CSV datasets using
headless rendering (no display), 10 runs per operation (median reported),
with Julia's JIT warmup excluded from measurements.

**Matrix visualization execution time (seconds):**

| Dataset | Rows | Julia | Python (missingno) | Speedup |
|---------|------|-------|-------------------|---------|
| real_adult | 32,560 | 0.057 | 0.528 | 9.3x |
| real_diabetic | 101,766 | 0.074 | 1.460 | 19.7x |
| real_online_retail | 541,910 | 0.061 | 4.526 | **74.4x** |

**Peak memory usage (MB) — matrix operation:**

| Dataset | Rows | Julia | Python |
|---------|------|-------|--------|
| real_diabetic | 101,766 | 60.2 | 150.9 |
| real_online_retail | 541,910 | 32.1 | 182.2 |

Julia's memory footprint grows sub-linearly with dataset size due to efficient
BitArray-based missing pattern representation, while Python's numpy-based
approach scales linearly.

**Note on naniar (R):** The `vis_miss` function internally samples to 10,000
rows for large datasets, making direct performance comparison invalid for
full-data workloads.

# Acknowledgements

The author thanks the Julia community and the developers of
DataFrames.jl [@bouchet2023dataframes],
Makie.jl [@danisch2021makie],
GLM.jl, and
HypothesisTests.jl.

# References