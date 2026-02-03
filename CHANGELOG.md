# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/DescarteS96/MissingDataViz.jl/releases/tag/v0.1.0
