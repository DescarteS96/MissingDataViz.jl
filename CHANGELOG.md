# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  - Decision tree: which test to use based on dataset characteristics
  - Post-diagnostic actions: imputation strategies by scenario
  - Common pitfalls to avoid
  - 10 annotated academic references
- Scalability limits guide (`benchmarks/results/SCALABILITY.md`)
  - Row scaling, column scaling, data type impact
  - JIT overhead, I/O bottleneck, memory considerations
  - Parallelization status and roadmap

#### Benchmarks
- Performance benchmark script: `benchmarks/benchmark_mcar.jl`
- Benchmark report: `benchmarks/results/benchmark_report.md`
- Tested sizes: 1k, 5k, 10k, 50k, 100k rows × 8 columns
- All performance targets met:
  - `compare_mcar_tests` @ 10k rows: 0.124s (target: < 5s)
  - Visualizations @ 10k rows: 0.247s (target: < 2s)
  - `full_missing_diagnosis` @ 10k rows: 1.486s (target: < 10s)

### Fixed

- **Double MCAR execution** (Fix 2A): `full_missing_diagnosis` called `compare_mcar_tests` twice — once directly, once via `plot_missing_diagnosis`. Added `mcar_results` parameter to pass pre-computed results. **Result: 81% reduction in pipeline time** (12.52s → 2.35s on 1k-row test).
- **Little's test silent NaN** (Fix 2B): When missing data exists only in categorical columns, the test now returns INCONCLUSIVE with a descriptive message identifying the affected columns and recommending alternative tests, instead of a silent NaN p-value.
- **Column name sanitization** (Fix 2C): Column names with spaces (`Customer ID`), special characters (`région (%)`), or leading digits (`2024_score`) caused `ParseError` in logistic regression formula construction. Names are now auto-sanitized in `compare_mcar_tests` with original names restored in results.

### Changed

- `plot_missing_diagnosis` now accepts optional `mcar_results` kwarg to avoid re-running MCAR tests
- `_draw_mcar_panel!` now accepts optional `mcar_results` kwarg
- HTML report generation accepts pre-computed `mcar_results` from pipeline

### Dependencies Added
- GLM.jl (logistic regression)
- Distributions.jl (chi-squared distribution for Little's test)
- HypothesisTests.jl (Welch t-tests)
- CSV.jl (validation script dependency)

### Technical Details
- **New modules**: `MCARTests` (encapsulates all MCAR test functionality)
- **New files**: `src/tests/mcar_little.jl`, `src/tests/mcar_means.jl`, `src/tests/mcar_logistic.jl`, `src/tests/mcar_comparison.jl`, `src/tests/mcar_types.jl`, `src/plots/dashboard.jl`, `src/full_diagnosis.jl`, `src/generators.jl`
- **Julia Compatibility**: 1.9+ (tested on 1.11.5; CairoMakie incompatible with 1.12 at time of release)
- **Performance**: Sub-linear scaling — 100k rows processed in < 1s for MCAR tests
- **Scalability bottleneck**: Column count (not row count) — datasets with > 20 columns with missing data may be slow

---

## [0.1.0] - 2025-02-03

### Added

#### Core Functionality
- Pattern detection module with 11 functions for missing data analysis
  - `missing_pattern()`: Convert DataFrame to binary matrix
  - `missing_percentage()`: Calculate percentage of missing values per column
  - `missing_count()`: Count absolute missing values
  - `pattern_counts()`: Identify and count distinct patterns
  - `pattern_frequency()`: Rank patterns by frequency
  - `summarize_missing()`: Aggregate all statistics

#### Visualizations
- Heatmap visualization (`plot_missing_matrix`) with customizable options
  - Automatic sparklines showing missing percentage per row
  - Smart column label rotation for large datasets
  - Configurable color schemes and dimensions
- Bar chart visualization (`plot_missing_bars`)
  - Percentage of missing values per column
  - Automatic sorting and color-coded thresholds
  - Horizontal/vertical orientation support
- Correlation matrix (`plot_missing_correlation`)
  - Pearson correlation between missing data patterns
  - Diverging colormap for negative/positive correlations
  - Numeric annotations for small matrices
- Overview function (`plot_missing_overview`) combining all visualizations

#### Export & Reporting
- Multi-format export support (PNG, PDF, SVG)
- Automatic HTML report generation with embedded plots
- One-line diagnosis function (`diagnose_missing`)
- Base64-encoded images in HTML reports

#### Quality & Performance
- 95 automated tests with ~90% code coverage
- Performance optimization: 98% fewer allocations, 79% faster execution
- Benchmark: <1s for 10k rows, <3s for 100k rows
- 11 validation and error handling functions
- 3 custom error types with actionable messages

#### Documentation
- Complete API documentation with Documenter.jl
- "Getting Started" tutorial
- 10+ working examples in `examples/` directory
- Gallery of visual outputs
- FAQ and troubleshooting guide

#### Infrastructure
- CI/CD with GitHub Actions (Julia 1.9, 1.10+)
- Codecov integration for coverage tracking
- Automated documentation deployment
- Comprehensive test suite with edge cases

### Technical Details
- **Dependencies**: DataFrames.jl, Makie.jl, CairoMakie.jl
- **Julia Compatibility**: 1.9+
- **Test Coverage**: ~90%
- **Performance Target**: <2s for standard datasets (10k rows)

[0.2.0]: https://github.com/DescarteS96/MissingDataViz.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DescarteS96/MissingDataViz.jl/releases/tag/v0.1.0