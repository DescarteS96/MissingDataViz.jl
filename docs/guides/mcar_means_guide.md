# MCAR Means Test — User Guide

## Overview

The **MCAR Means Test** (Welch t-test) detects whether missingness in one column is associated with the mean value of another column. This is a **pairwise test** that helps identify violations of the Missing Completely At Random (MCAR) assumption.

---

## Mathematical Principle

### Test Statistic

The Welch t-test is defined as:

$$
t = \frac{\bar{x}_{\text{obs}} - \bar{x}_{\text{miss}}}{\sqrt{\frac{s^2_{\text{obs}}}{n_{\text{obs}}} + \frac{s^2_{\text{miss}}}{n_{\text{miss}}}}}
$$

Where:
- $\bar{x}_{\text{obs}}$ = mean of `col_complete` when `col_missing` is **observed**
- $\bar{x}_{\text{miss}}$ = mean of `col_complete` when `col_missing` is **missing**
- $s^2_{\text{obs}}, s^2_{\text{miss}}$ = variances in each group
- $n_{\text{obs}}, n_{\text{miss}}$ = sample sizes in each group

### Degrees of Freedom (Welch–Satterthwaite)

$$
\nu \approx \frac{\left(\frac{s^2_{\text{obs}}}{n_{\text{obs}}} + \frac{s^2_{\text{miss}}}{n_{\text{miss}}}\right)^2}{\frac{(s^2_{\text{obs}}/n_{\text{obs}})^2}{n_{\text{obs}}-1} + \frac{(s^2_{\text{miss}}/n_{\text{miss}})^2}{n_{\text{miss}}-1}}
$$

This accounts for **unequal variances** between groups (unlike Student's t-test).

### Null Hypothesis

$$
H_0: \mu_{\text{obs}} = \mu_{\text{miss}}
$$

**Translation:** The mean of `col_complete` is the same whether `col_missing` is observed or missing.

If $H_0$ is **rejected** ($p < \alpha$), missingness is **not random** with respect to `col_complete`.

---

## Interpretation Guide

### What does p < 0.05 mean concretely?

| **p-value** | **Interpretation** | **Action** |
|-------------|-------------------|-----------|
| **p < 0.01** | Strong evidence that `col_complete` **predicts** missingness in `col_missing`. MCAR is **violated**. | ⚠️ **Investigate relationship** between columns. Consider imputation methods that account for this dependency (e.g., regression imputation, MICE). |
| **p < 0.05** | Moderate evidence against MCAR. `col_complete` is associated with missingness. | ⚠️ **Caution:** Simple mean imputation may introduce bias. Check other tests (logistic regression, Little's test). |
| **p ≥ 0.05** | No significant evidence against MCAR **for this pair**. | ✅ Missingness in `col_missing` appears random with respect to `col_complete`. Simple imputation may be acceptable. |
| **p = NaN** | Test inconclusive (insufficient data, zero variance). | ℹ️ Check warnings. May need more data or different test. |

### Example Scenario
```julia
df = DataFrame(
    age = [25, 30, missing, 40, missing, 50],
    income = [30k, 35k, 45k, 50k, 55k, 60k]
)

result = test_mcar_means(df, :age, :income)
# p-value = 0.008 → MCAR_REJECTED
```

**Interpretation:**
- People with **missing age** have significantly **higher income** (mean_missing > mean_observed).
- This suggests age is **MAR** (Missing At Random), dependent on income.
- **Action:** Do NOT use simple mean imputation for age. Instead, use regression imputation predicting age from income.

---

## Assumptions and Limitations

### ✅ Assumptions

1. **Independence:** Observations are independent (no repeated measures, no time series).
2. **Approximate normality (for small samples):**
   - For $n < 30$ per group, the test assumes data are approximately normal.
   - For $n ≥ 30$, Central Limit Theorem applies — normality less critical.
3. **Numeric data:** `col_complete` must be numeric (continuous or discrete).
4. **No missing values in predictor:** `col_complete` must be fully observed.

### ⚠️ Limitations

| **Limitation** | **Consequence** | **Solution** |
|----------------|-----------------|-------------|
| **Pairwise only** | Tests only one (col_missing, col_complete) pair. Misses multivariate patterns. | Use `test_all_mcar_means()` + logistic regression test. |
| **Mean differences only** | Does not detect variance or distributional differences. | Complement with Kolmogorov-Smirnov test (future feature). |
| **Multiple testing** | Running 100 tests inflates false positive rate. | Use Bonferroni correction (default in `test_all_mcar_means`). |
| **Small samples** | Unreliable for $n < 10$ per group. | Check warnings. Consider non-parametric tests (Mann-Whitney U). |
| **Non-linearity** | Cannot detect non-linear relationships. | Use logistic regression test as complement. |

### When Assumptions Are Violated

- **Non-normal data + small sample:** Warnings will appear. Consider Mann-Whitney U test (non-parametric alternative).
- **Correlated observations:** Results invalid. Use mixed-effects models or account for clustering.
- **Missing values in predictor:** Error raised. Choose a different `col_complete` or impute first.

---

## Decision Tree: When to Use This Test
```
START
  │
  ├─ Do you have missing values in at least ONE column?
  │   NO → STOP (no missing data to test)
  │   YES ↓
  │
  ├─ Do you have at least ONE fully observed numeric column?
  │   NO → Use logistic regression test (categorical predictors OK)
  │   YES ↓
  │
  ├─ Is your sample size ≥ 10 per group (observed vs missing)?
  │   NO → ⚠️ Results unreliable. Collect more data or use exact tests.
  │   YES ↓
  │
  ├─ Is your goal to test MCAR for a SINGLE pair of columns?
  │   YES → Use test_mcar_means(df, col_missing, col_complete)
  │   NO ↓
  │
  ├─ Do you want to test ALL possible pairs?
      YES → Use test_all_mcar_means(df, correction=:bonferroni)
```

### Choosing Between Tests

| **Scenario** | **Best Test** | **Reason** |
|--------------|---------------|------------|
| Single pair, numeric predictor | `test_mcar_means` | Simple, interpretable, fast. |
| Multiple pairs, exploratory | `test_all_mcar_means` | Automatic correction, identifies worst violations. |
| Categorical predictors | Logistic regression test | Handles non-numeric predictors. |
| Multivariate dependencies | Little's test | Tests overall MCAR globally. |
| Small samples (<30) | Mann-Whitney U (future) | Non-parametric, no normality assumption. |

---

## Common Pitfalls and Debugging

### 🚫 Pitfall 1: Ignoring Multiple Testing

**Problem:**
```julia
# Running 50 tests without correction
for col in cols_missing
    test_mcar_means(df, col, :age, alpha=0.05)
end
# → ~2.5 false positives expected even under MCAR!
```

**Solution:**
```julia
# Use batch function with Bonferroni correction
results = test_all_mcar_means(df, alpha=0.05, correction=:bonferroni)
# → alpha adjusted to 0.05/50 = 0.001 per test
```

### 🚫 Pitfall 2: Misinterpreting p ≥ 0.05

**Wrong:** "p = 0.30 means MCAR is TRUE."

**Correct:** "p = 0.30 means we have **no evidence against MCAR** for this pair. This does NOT prove MCAR — other pairs may still violate it."

**Action:** Always run multiple tests and triangulate results.

### 🚫 Pitfall 3: Using with Non-Numeric Predictors

**Problem:**
```julia
test_mcar_means(df, :age, :gender)  # gender is categorical!
# → Error or nonsensical results
```

**Solution:**
```julia
# Use logistic regression test instead
test_mcar_logistic(df, :age)  # can handle categorical predictors
```

---

## Validation Criteria

Before trusting results, verify:

- [ ] **Sample size:** At least 10 observations per group (observed vs missing).
- [ ] **No warnings:** Check `result.warnings` — empty means assumptions likely met.
- [ ] **Multiple tests agree:** If `test_mcar_means` rejects but logistic test does not → investigate further.
- [ ] **Biological plausibility:** Does the result make sense? (e.g., income predicting missing age is plausible).
- [ ] **Sensitivity analysis:** Try different `alpha` levels (0.01, 0.05, 0.10) — robust results should be consistent.

---

## References

1. **Little, R. J. A. (1988).** "A Test of Missing Completely at Random for Multivariate Data with Missing Values." *Journal of the American Statistical Association*, 83(404), 1198-1202.

2. **Welch, B. L. (1947).** "The generalization of 'Student's' problem when several different population variances are involved." *Biometrika*, 34(1-2), 28-35.

3. **Rubin, D. B. (1976).** "Inference and missing data." *Biometrika*, 63(3), 581-592.

4. **Van Buuren, S. (2018).** *Flexible Imputation of Missing Data* (2nd ed.). CRC Press. [Chapter 2: MCAR, MAR, MNAR]

---

## See Also

- `test_all_mcar_means()` — Batch testing with multiple testing correction
- `test_mcar_logistic()` — Logistic regression test (handles categorical predictors)
- `test_mcar_little()` — Multivariate MCAR test (global assessment)
- `summary_table()` — Convert results to DataFrame for export