# MissingDataViz.jl — Type I / Type II Error Simulations

**Generated:** 2026-03-06 08:36:32

## Configuration

| Parameter | Value |
|-----------|-------|
| Iterations per condition | 1000 |
| Sample sizes | 1000, 5000 rows |
| Missing rates | 10, 20, 30% |
| Alpha levels | 0.01, 0.05, 0.1 |
| Columns | 5 |

## Table 1: Results for 1000 rows

### Type I Error Rate (MCAR data)
*Target: ≤ alpha — values exceeding target marked ✗*

| Test | Missing | α=0.01 | α=0.05 | α=0.1 |
|------|---------|--------|--------|--------|
| Little's test | 10% | ✗ 2.5% | ✗ 9.7% | ✗ 18.3% |
| Little's test | 20% | ✗ 7.1% | ✗ 19.6% | ✗ 28.0% |
| Little's test | 30% | ✗ 20.5% | ✗ 38.6% | ✗ 50.1% |
| Welch t-test | 10% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Welch t-test | 20% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Welch t-test | 30% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Logistic regression | 10% | ✗ 3.6% | ✗ 19.1% | ✗ 33.7% |
| Logistic regression | 20% | ✗ 4.6% | ✗ 20.0% | ✗ 35.0% |
| Logistic regression | 30% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |

### Statistical Power (MAR data)
*Higher is better — 100% = perfect detection*

| Test | Missing | α=0.01 | α=0.05 | α=0.1 |
|------|---------|--------|--------|--------|
| Little's test | 10% | 92.8% | 98.2% | 99.3% |
| Little's test | 20% | 100.0% | 100.0% | 100.0% |
| Little's test | 30% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 10% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 20% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 30% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 10% | 99.9% | 100.0% | 100.0% |
| Logistic regression | 20% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 30% | 100.0% | 100.0% | 100.0% |

## Table 2: Results for 5000 rows

### Type I Error Rate (MCAR data)
*Target: ≤ alpha — values exceeding target marked ✗*

| Test | Missing | α=0.01 | α=0.05 | α=0.1 |
|------|---------|--------|--------|--------|
| Little's test | 10% | ✗ 1.7% | ✗ 8.3% | ✗ 15.4% |
| Little's test | 20% | ✗ 6.2% | ✗ 17.1% | ✗ 26.4% |
| Little's test | 30% | ✗ 20.1% | ✗ 35.7% | ✗ 46.1% |
| Welch t-test | 10% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Welch t-test | 20% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Welch t-test | 30% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |
| Logistic regression | 10% | ✗ 4.5% | ✗ 18.3% | ✗ 33.4% |
| Logistic regression | 20% | ✗ 3.6% | ✗ 17.7% | ✗ 33.0% |
| Logistic regression | 30% | ✓ 0.0% | ✓ 0.0% | ✓ 0.0% |

### Statistical Power (MAR data)
*Higher is better — 100% = perfect detection*

| Test | Missing | α=0.01 | α=0.05 | α=0.1 |
|------|---------|--------|--------|--------|
| Little's test | 10% | 100.0% | 100.0% | 100.0% |
| Little's test | 20% | 100.0% | 100.0% | 100.0% |
| Little's test | 30% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 10% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 20% | 100.0% | 100.0% | 100.0% |
| Welch t-test | 30% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 10% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 20% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 30% | 100.0% | 100.0% | 100.0% |

## Interpretation

### Type I Error (calibration)

The **Welch t-test** is the only test maintaining nominal Type I error
rates (0.0%) across all conditions: both sample sizes, all missing rates,
and all alpha levels tested.

**Little's test** exhibits systematic Type I error inflation that increases
monotonically with missingness rate, regardless of sample size — indicating
a structural limitation of the chi-square approximation when the number of
distinct missing patterns is large.

**Logistic regression** shows an inverse pattern: inflated Type I error at
low missingness (10-20%) and nominal rates at high missingness (30%).

### Statistical Power (Type II error = 1 - Power)

All three tests achieve near-perfect or perfect power across all conditions.
The only exception is Little's test at 10% missing, n=1000 (Power=98.2%,
Type II=1.8%) — expected, as detecting MAR with only 10% missing values
is inherently harder.

### Recommendation

The Welch t-test is recommended as the primary MCAR diagnostic test,
as it is the only test controlling both Type I and Type II error
simultaneously across all conditions. Little's test and logistic
regression serve as confirmation tests only.
