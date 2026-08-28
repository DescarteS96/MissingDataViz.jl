# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-08-27

### Fixed

- **Simulation generator asymmetry** (`generate_mcar_data`): The MCAR generator
  put missing values in ALL columns, leaving no complete column for the Welch
  t-test wrapper. The test returned INCONCLUSIVE every iteration, producing a
  spurious 0.0% Type I error. Fixed by adding `n_complete_cols` kwarg (default=0
  for backward compatibility); simulation script updated to use `n_complete_cols=1`
  to match the geometry of `generate_mar_data`.

- **Logistic regression decision criterion** (`test_mcar_logistic`): The MCAR
  decision was based on `min(p-value)` across predictor coefficients without
  multiple testing correction, inflating Type I error to `1-(1-α)^k`
  (measured: 21.6% at 10% missing with k=4 predictors, α=0.05). Replaced by a
  global likelihood ratio test (LRT) comparing the fitted model against the
  intercept-only model: `LR ~ Chisq(k)`. Individual predictor p-values are
  retained in `details` for imputation model building but no longer drive the
  decision. Type I error after fix: nominally calibrated (5.6/5.5/4.1% at
  α=0.05, n=1000).

- **Four silent failure modes in `test_mcar_logistic`**, found while validating
  on real datasets:
  - Constant columns produced a one-level factor; GLM raised "only one level
    found" and the test failed for every column of the dataset.
  - Predictors becoming single-valued only after complete-case filtering caused
    the same failure. Constancy is now re-checked on the retained rows, and the
    formula is built afterwards.
  - High-cardinality categorical predictors (ICD-9 diagnosis codes, ~700 levels;
    Airbnb listing names, 47,905 levels) produced design matrices of thousands
    of columns: `OutOfMemoryError` on three of the five validation datasets, and
    no power on Diabetes (df = 2321 for 3197 events, so `medical_specialty`
    returned p = 1.000 instead of p < 1e-300).
  - A negative deviance difference from a non-converged fit was clamped to zero
    by `max(., 0.0)`, yielding p = 1.0 and a spurious "MCAR not rejected". Now
    reported as `INCONCLUSIVE`, with both deviances in the warning.

- **Overlapping missingness** now detected: when complete-case filtering leaves
  no events to model, the result is `INCONCLUSIVE` and the warning names the
  overlapping predictor. In the Adult dataset, `workclass` is missing on exactly
  the same 1,836 rows as `occupation`.

- **`max_levels` and `min_epv` were unreachable** from `compare_mcar_tests` and
  `full_missing_diagnosis`, which is how most users call the test. Now forwarded.

### Added

#### Reliability guards in `test_mcar_logistic`
- `max_levels` kwarg (default 20): categorical predictors with more levels are
  excluded before fitting, with a warning.
- `min_epv` kwarg (default 10.0, per Peduzzi et al., 1996): models with fewer
  than 10 events per estimated coefficient return `INCONCLUSIVE` rather than an
  unreliable p-value.
- New `details` fields: `events`, `epv`, `n_model_rows`,
  `constant_cols_excluded`, `high_cardinality_excluded`.
- Validation outcome across the five public datasets: 7 rejections, 1
  non-rejection, 12 inconclusive over the 20 columns containing missing values.
  Verdicts unchanged — all five violate MCAR.

#### Type I / Type II Error Simulations
- Simulation script `benchmarks/simulations_type1_type2.jl`
  - 1000 iterations per condition, seeds fixed for reproducibility
  - Sample sizes: n ∈ {1000, 5000}
  - Missing rates: 10%, 20%, 30%
  - Alpha levels: α ∈ {0.01, 0.05, 0.10}
- Key findings (corrected after bug fixes — see Fixed section above):
  - Welch t-test: Type I nominally calibrated (5.5/4.3/4.0% at α=0.05, n=1000)
  - Logistic regression: Type I nominally calibrated (5.6/5.5/4.1% at α=0.05, n=1000) after LRT fix
  - Little's test: Type I inflation 10.0/17.5/32.0% at α=0.05, n=1000 — increases monotonically, persists at n=5000
  - All tests: Power ≥ 98.2% across all conditions
- Reports: `benchmarks/results/type1_type2_report.md` + `.docx`

#### Cross-Language Performance Benchmarks
- Benchmark suite `benchmarks/cross_language/`
  - `generate_data.py`: generates 8 shared CSV datasets (3 synthetic + 5 real)
  - `benchmark_julia.jl`: MissingDataViz.jl measurements
  - `benchmark_python.py`: missingno measurements
  - `benchmark_r.R`: naniar measurements
  - `aggregate_results.py`: aggregates JSON results into comparative report
  - `run_all.sh`: single-command execution of full suite
- 10 runs per operation, median reported, Julia JIT warmup excluded
- Key findings (matrix visualization):
  - real_adult (32k rows): Julia 9.3x faster than Python
  - real_diabetic (101k rows): Julia 19.7x faster than Python
  - real_online_retail (541k rows): Julia **74.4x** faster than Python
  - Memory at 541k rows: Julia 32 MB vs Python 182 MB
- Documented naniar sampling limitation: `vis_miss` capped at 10k rows
- Reports: `benchmarks/cross_language/results/cross_language_report.md` + `.docx`

#### Synthetic Data Generator Extended
- Added `generate_mnar_data()` for Missing Not At Random datasets
- Validation with real datasets extended to 541,910-row Online Retail dataset

#### Documentation
- `README.md` rewritten for Phase 2:
  - Feature comparison table (Julia vs Python vs R)
  - Performance benchmark table with real numbers
  - Calibration study results
  - Complete API reference for Phase 2 functions
- `paper.md` drafted for JOSS submission
- `paper.bib` with 10 academic references
- `docs/article/notes_results.md`: article draft notes with key sentences

---

## [0.2.0] - 2026-03-04

### Added

#### MCAR Statistical Testing (Phase 2 — New)
- **Little's MCAR Test** (`test_mcar_little`): Global chi-squared test for MCAR hypothesis
  - Automatic numeric column filtering
  - Informative INCONCLUSIVE result when missing data is only in categorical columns (instead of silent NaN)
  - Returns structured `TestResult` with statistic, p-value, degrees of freedom, and decision
- **Pairwise Welch t-tests** (`test_mcar_means`): Univariate comparison of means between missing/observed groups
  - One test per column with missing data
  - Robust to unequal variances (Welch correction)
- **Logistic Regression** (`test_mcar_logistic`): Multivariate prediction of missingness
  - Fits GLM per column with missing data using all other columns as predictors
  - Identifies significant predictors of missingness with odds ratios
  - Handles both numeric and categorical predictors via `@formula` and GLM.jl
- **Test Comparison Pipeline** (`compare_mcar_tests`): Runs all three tests and produces consensus analysis
  - Automatic column name sanitization for names with spaces, special characters, or leading digits
  - Four consensus scenarios: STRONG AGREEMENT, FULL AGREEMENT, PARTIAL DISAGREEMENT, MIXED RESULTS
  - Actionable recommendation based on consensus (imputation strategy guidance)
  - Original column names preserved in returned results via bidirectional mapping

#### Integrated Diagnostic Dashboard
- **2×2 Dashboard** (`plot_missing_diagnosis`): Combined visualization with 4 panels
  - Top-left: Missing data matrix (heatmap)
  - Top-right: Missing percentage bar chart
  - Bottom-left: Missing correlation heatmap
  - Bottom-right: MCAR test results (-log₁₀ p-value bar chart)
  - Footer annotation with violated columns
  - Accepts pre-computed MCAR results to avoid redundant computation

#### Full Diagnostic Pipeline
- **One-call pipeline** (`full_missing_diagnosis`): Complete diagnosis in a single function call
  - Steps: validation → pattern detection → MCAR tests → recommendation → dashboard → HTML report
  - Structured `Dict` return with all results programmatically accessible
  - Verbose mode with step-by-step timing
  - Graceful degradation: partial failures don't crash the pipeline
  - All steps individually controllable via kwargs

#### Test Infrastructure
- `TestResult` struct for standardized test output across all MCAR tests
- `MCARTestComparison` struct for multi-test comparison results
- `MCARDecision` enum: `MCAR_REJECTED`, `MCAR_NOT_REJECTED`, `INCONCLUSIVE`
- Internal `_extract_test_results` utility for dashboard integration

#### Data Generators
- `generate_mcar_data()`: Generate datasets with truly random missing values
- `generate_mar_data()`: Generate datasets with Missing At Random patterns (missingness depends on observed variables)

#### Validation on Real Datasets
- Validated on 5 public datasets (10k–100k rows):
  - Adult/Census Income (32,561 × 15)
  - Diabetes 130-US Hospitals (101,766 × 50)
  - Online Retail II (100,000 × 8)
  - NYC Airbnb (48,895 × 16)
  - Melbourne Housing (13,580 × 21)
- Validation script: `examples/validation/validate_real_datasets.jl`
- Validation report: `examples/validation/results/validation_report.md`

#### Documentation (Phase 2)
- Interpreting MCAR Tests guide for non-statisticians (`docs/interpreting_mcar_tests.md`)
- Scalability limits guide (`benchmarks/results/SCALABILITY.md`)

#### Benchmarks
- Performance benchmark script: `benchmarks/benchmark_mcar.jl`
- Benchmark report: `benchmarks/results/benchmark_report.md`
- All performance targets met:
  - `compare_mcar_tests` @ 10k rows: 0.124s (target: < 5s)
  - Visualizations @ 10k rows: 0.247s (target: < 2s)
  - `full_missing_diagnosis` @ 10k rows: 1.486s (target: < 10s)

### Fixed

- **Double MCAR execution** (Fix 2A): 81% reduction in pipeline time (12.52s → 2.35s)
- **Little's test silent NaN** (Fix 2B): Returns INCONCLUSIVE with descriptive message
- **Column name sanitization** (Fix 2C): Auto-sanitization in `compare_mcar_tests`

### Changed

- `plot_missing_diagnosis` now accepts optional `mcar_results` kwarg
- HTML report generation accepts pre-computed `mcar_results` from pipeline

### Dependencies Added
- GLM.jl, Distributions.jl, HypothesisTests.jl, CSV.jl

---

## [0.1.0] - 2025-02-03

### Added

#### Core Functionality
- Pattern detection module with 11 functions for missing data analysis
  - `missing_pattern()`, `missing_percentage()`, `missing_count()`
  - `pattern_counts()`, `pattern_frequency()`, `summarize_missing()`

#### Visualizations
- `plot_missing_matrix()` — heatmap with sparklines
- `plot_missing_bars()` — bar chart with color-coded thresholds
- `plot_missing_correlation()` — Pearson correlation between patterns
- `plot_missing_overview()` — combined dashboard

#### Export & Reporting
- Multi-format export (PNG, PDF, SVG)
- HTML report generation with embedded plots
- One-line diagnosis function (`diagnose_missing`)

#### Quality & Performance
- 95 automated tests, ~90% code coverage
- 98% fewer allocations vs naive implementation
- Benchmark: < 1s for 10k rows, < 3s for 100k rows

#### Infrastructure
- CI/CD with GitHub Actions
- Codecov integration
- Documenter.jl API docs

### Technical Details
- **Dependencies**: DataFrames.jl, Makie.jl, CairoMakie.jl
- **Julia Compatibility**: 1.9+

[Unreleased]: https://github.com/DescarteS96/MissingDataViz.jl/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/DescarteS96/MissingDataViz.jl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/DescarteS96/MissingDataViz.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DescarteS96/MissingDataViz.jl/releases/tag/v0.1.0