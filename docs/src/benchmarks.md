# Benchmarks & Validation

This page consolidates the performance benchmarks, statistical calibration
study, and real-dataset validation results for MissingDataViz.jl.

## Comparison with Existing Tools

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

## Cross-Language Performance

Matrix visualization, 10 runs median, headless rendering:

| Dataset | Rows | Julia | Python | Speedup |
|---------|------|-------|--------|---------|
| real_adult | 32,560 | 0.057s | 0.528s | **9x** |
| real_diabetic | 101,766 | 0.074s | 1.460s | **20x** |
| real_online_retail | 541,910 | 0.061s | 4.526s | **74x** |

On the 541,910-row dataset, MissingDataViz.jl completes matrix
visualization in 0.06s versus 4.53s for missingno — a 74x speedup
attributable to Julia's JIT-compiled execution.

Memory also scales favorably: 32 MB versus 182 MB at 541k rows for the
same operation.

## Statistical Calibration Study

Monte Carlo simulation, 1000 iterations per condition,
n ∈ {1000, 5000}, seeds fixed, α = 0.05:

| Test | Type I @ 10% | Type I @ 20% | Type I @ 30% | Power (MAR) |
|------|:------------:|:------------:|:------------:|:-----------:|
| Welch t-test | 5.5% ✓ | 4.3% ✓ | 4.0% ✓ | 100% |
| Logistic regression | 5.6% ✓ | 5.5% ✓ | 4.1% ✓ | ~100% |
| Little's test | 10.0% ✗ | 17.5% ✗ | 32.0% ✗ | 98–100% |

**Key finding:** Little's test exhibits systematic Type I error
inflation that increases monotonically with the missingness rate and
persists at n = 5000. The Welch t-test and the logistic regression
test (via a global likelihood ratio test) maintain nominal Type I
error across every condition tested. Because of this, Little's test
should be treated as a confirmation test rather than a primary
diagnostic — see [`test_mcar_little`](@ref) for details on the
mechanism behind the inflation.

## Validation on Real Datasets

MissingDataViz.jl has been validated end-to-end on five public
datasets spanning medical, financial, and marketing domains:

| Dataset | Rows | Cols | Missing % |
|---------|------|------|-----------|
| Adult Census | 32,561 | 15 | 0.9% |
| Diabetes 130-US | 101,766 | 50 | 3.8% |
| Melbourne Housing | 13,580 | 21 | 4.6% |
| NYC Airbnb | 48,895 | 16 | 2.6% |
| Online Retail | 541,910 | 8 | 3.2% |

## Practical Notes

- **JIT warmup:** the first call to any MissingDataViz.jl function in
  a session takes 10–50s (Julia compilation). Subsequent calls are
  fast.
- **Column scaling:** [`test_mcar_logistic`](@ref) fits one model per
  column with missing data. Datasets with 20+ such columns benefit
  from subsetting to relevant predictors via the `exclude_cols` or
  `max_levels` keyword arguments.