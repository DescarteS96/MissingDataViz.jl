# MissingDataViz.jl — Scalability Limits and Performance Guide

> **Version:** 0.2.0  
> **Last updated:** 2026-03-04  
> **Based on:** Benchmark results (Julia 1.11.5, single-threaded)

---

## Quick Reference

| Dataset Size | Columns | Expected Time (full_diagnosis) | Interactive? |
|-------------|---------|-------------------------------|-------------|
| < 1,000 rows | < 20 | < 2s | Yes |
| 1k–10k rows | < 20 | < 3s | Yes |
| 10k–50k rows | < 20 | < 3s | Yes |
| 50k–100k rows | < 20 | < 3s | Yes (batch recommended) |
| > 100k rows | < 20 | 3–10s | Batch only |
| Any size | > 20 with missing | Variable — see Column Scaling | Depends |

---

## 1. Row Scaling (Primary Dimension)

The MCAR testing pipeline scales **sub-linearly** with row count.

### Measured Times: `compare_mcar_tests` (8 numeric columns, ~8% MAR)

| Rows | Absolute Time | Time per 10k rows | Scaling Factor |
|------|--------------|-------------------|----------------|
| 1,000 | 0.018s | 0.180s | baseline |
| 5,000 | 0.068s | 0.136s | 3.8× for 5× rows |
| 10,000 | 0.124s | 0.124s | 6.9× for 10× rows |
| 50,000 | 0.541s | 0.108s | 30× for 50× rows |
| 100,000 | 0.908s | 0.091s | 50× for 100× rows |

**Interpretation:** Doubling the row count increases execution time by approximately 1.7×, not 2×. The fixed costs (formula compilation, GLM model setup, matrix allocation) are amortized over more rows, producing sub-linear behavior.

**Practical limit:** 100,000 rows completes in under 1 second for MCAR tests alone. The theoretical row limit before hitting 10 seconds is approximately 1,000,000 rows (extrapolated), though this has not been empirically verified.

---

## 2. Column Scaling (Critical Dimension)

Column count is the **primary scalability bottleneck**, not row count. The logistic regression in `compare_mcar_tests` runs once per column with missing data, with all other columns as predictors.

### Complexity Model

For a dataset with `n` rows, `p` total columns, and `k` columns with missing data:

- **Little's test:** O(n × p) — single pass, all numeric columns
- **t-test:** O(n × k) — one test per missing column
- **Logistic regression:** O(n × k × p) — one GLM per missing column, with (p-1) predictors each
- **Total compare_mcar_tests:** O(n × k × p) — dominated by logistic regression

### Observed Impact (Real Datasets)

| Dataset | Rows | Total Cols | Cols with Missing | Time |
|---------|------|-----------|-------------------|------|
| Benchmark (synthetic) | 10,000 | 8 | 7 | 0.124s |
| NYC Airbnb | 48,895 | 16 | 4 | 4.92s |
| Melbourne Housing | 13,580 | 21 | 4 | 18.65s |
| Diabetes 130-US | 101,766 | 50 | 7 | 12.80s |

**Key observation:** Melbourne (13.5k rows, 21 columns) takes 18.65s, while the synthetic benchmark at 100k rows (8 columns) takes only 0.908s. The 21-column dataset is **20× slower** than the 8-column dataset despite having 7× fewer rows.

### Recommendations by Column Count

| Total Columns | Columns with Missing | Expected Behavior |
|--------------|---------------------|-------------------|
| < 10 | Any | Fast (< 1s at 100k rows) |
| 10–20 | < 5 | Acceptable (< 5s) |
| 10–20 | > 10 | Slow (5–30s depending on rows) |
| 20–50 | < 5 | Acceptable but verify |
| 20–50 | > 10 | Consider subsetting columns |
| > 50 | Any | Subset columns before analysis |

### Mitigation: Column Subsetting

For datasets with many columns, subset to relevant columns before running MCAR tests:

```julia
# Instead of testing all 50 columns:
# compare_mcar_tests(df_full)  # slow

# Subset to columns of interest:
relevant_cols = [:age, :income, :weight, :blood_pressure, :diagnosis]
df_subset = df_full[:, relevant_cols]
compare_mcar_tests(df_subset)  # fast
```

---

## 3. Data Type Impact

### Numeric vs. Categorical Columns

| Scenario | Little's Test | Logistic Regression | t-test |
|----------|--------------|--------------------| -------|
| All numeric columns | Full functionality | Full functionality | Full functionality |
| Mixed numeric + categorical | Tests numeric only | Tests all (via @formula) | Tests numeric only |
| Missing only in categorical | Returns INCONCLUSIVE | Full functionality | May have no valid predictor |
| Missing only in numeric | Full functionality | Full functionality | Full functionality |

**Critical limitation:** Little's MCAR test requires missing values in at least one numeric column. If all missing data resides in categorical columns (strings), the test returns `INCONCLUSIVE` with an explanatory message. This is a fundamental statistical limitation, not a bug — Little's chi-squared statistic is undefined without numeric data.

**Affected datasets:** Any dataset where missingness occurs exclusively in categorical fields (e.g., survey responses, diagnostic codes, occupational categories).

**Workaround:** Rely on `test_mcar_logistic()` and `test_mcar_means()` for these datasets. The logistic regression test handles categorical predictors through `@formula` and `GLM.jl`.

---

## 4. JIT Compilation Overhead

Julia compiles code on first execution. This affects the first call to any MissingDataViz function in a session.

### Measured JIT Overhead

| Component | First Call | Second Call | JIT Cost |
|-----------|-----------|-------------|----------|
| compare_mcar_tests (1k rows) | ~2.8s | 0.018s | ~2.8s |
| full_diagnosis (1k rows) | ~12.5s | 1.8s | ~10.7s |
| Visualizations (CairoMakie) | ~8s | 0.25s | ~7.8s |

**Total first-call overhead:** 10–50 seconds depending on which functions are used.

### Mitigation Strategies

1. **Precompilation:** MissingDataViz.jl uses Julia's package precompilation. After installation, run `using MissingDataViz` once — subsequent loads are faster.

2. **Warmup pattern:** For benchmarking or latency-sensitive applications:
   ```julia
   # Warmup with small dataset
   df_warmup = generate_mar_data(100, 3, 0.10)
   compare_mcar_tests(df_warmup; verbose=false)
   
   # Now run on real data (no JIT overhead)
   compare_mcar_tests(df_real; verbose=false)
   ```

3. **Session persistence:** Keep the Julia session open between analyses. JIT cost is paid only once per session.

---

## 5. I/O Bottleneck in full_diagnosis

The `full_diagnosis` pipeline has an approximately constant ~1.1-second floor regardless of dataset size, caused by:

| I/O Component | Estimated Time | Cause |
|--------------|---------------|-------|
| CairoMakie figure creation | ~0.3s | Backend initialization |
| PNG dashboard export (save) | ~0.4s | Rasterization + file write |
| HTML report generation | ~0.4s | Template rendering + file write |
| **Total I/O floor** | **~1.1s** | **Not reducible without architecture change** |

### Measured Evidence

| Dataset Size | MCAR Tests | Visualizations | I/O (computed) | Total |
|-------------|-----------|----------------|---------------|-------|
| 1,000 rows | 0.018s | 0.258s | ~1.5s | 1.785s |
| 100,000 rows | 0.908s | 0.165s | ~1.1s | 2.212s |

At 1k rows, I/O is 84% of total time. At 100k rows, I/O is 51%. The I/O component is constant; only the MCAR test time grows with dataset size.

### Optimization Options

- **Disable dashboard export:** `full_missing_diagnosis(df, export_dashboard=false)` saves ~0.7s
- **Disable MCAR tests:** `full_missing_diagnosis(df, run_mcar_tests=false)` saves the MCAR computation time
- **Use components individually:** Call `compare_mcar_tests` and `plot_missing_matrix` separately if you don't need the HTML report

---

## 6. Memory Considerations

### Estimated Memory Usage

Memory consumption is dominated by the DataFrame copy and the missing pattern BitMatrix.

| Dataset Size | Approximate Memory | Notes |
|-------------|-------------------|-------|
| 1,000 × 8 | ~1 MB | Negligible |
| 10,000 × 8 | ~5 MB | Negligible |
| 100,000 × 8 | ~50 MB | Comfortable |
| 100,000 × 50 | ~200 MB | Monitor with larger datasets |
| 1,000,000 × 50 | ~2 GB | May require 8+ GB system RAM |

**CairoMakie adds ~100–300 MB** at first load (shared across all plots).

### Recommendation

For systems with < 4 GB RAM, consider:
- Limiting datasets to < 50,000 rows
- Subsetting columns before analysis
- Using `plot_missing_bars` (lightest) instead of `plot_missing_matrix` (heaviest) for initial exploration

---

## 7. Column Name Requirements

### Supported Column Names

| Column Name Type | Example | Status |
|-----------------|---------|--------|
| Simple alphanumeric | `age`, `x1`, `income` | Fully supported |
| With underscores | `blood_pressure`, `col_1` | Fully supported |
| With spaces | `Customer ID` | Supported via compare_mcar_tests (auto-sanitized) |
| With special chars | `région (%)` | Supported via compare_mcar_tests (auto-sanitized) |
| Starting with digit | `2024_score` | Supported via compare_mcar_tests (auto-sanitized) |

### Limitation

Column name sanitization is applied automatically **only** in `compare_mcar_tests`. Direct calls to `test_mcar_logistic` with unsanitized names will fail:

```julia
# Works (sanitization applied internally):
compare_mcar_tests(df)

# May fail if column names contain spaces:
test_mcar_logistic(df, Symbol("Customer ID"))

# Workaround: rename columns manually before direct calls:
rename!(df, "Customer ID" => "Customer_ID")
test_mcar_logistic(df, :Customer_ID)
```

This limitation is documented for v0.2.0 and will be addressed in v0.3.0 by adding sanitization directly in `test_mcar_logistic`.

---

## 8. Parallelization Status

**Current status:** Single-threaded (v0.2.0)

### Where Parallelization Would Help

The logistic regression loop in `compare_mcar_tests` iterates sequentially over each column with missing data. With `k` columns with missing, this is `k` independent GLM fits that could be parallelized:

```
# Current (sequential):
for col in cols_with_missing
    logistic_results[col] = test_mcar_logistic(df, col)  # independent
end

# Potential (parallel):
Threads.@threads for col in cols_with_missing
    logistic_results[col] = test_mcar_logistic(df, col)
end
```

### Expected Benefit

| Columns with Missing | Threads | Expected Speedup |
|---------------------|---------|-----------------|
| 1–3 | Any | Negligible (overhead > gain) |
| 4–7 | 4 | ~2–3× |
| 8–20 | 8 | ~4–6× |
| > 20 | 8+ | ~5–7× (memory-bound) |

### Decision

Parallelization is **not implemented in v0.2.0** because:
1. For 8 columns, compare_mcar_tests completes in < 1s — no user-facing benefit
2. Thread-safety of GLM.jl has not been verified
3. Added complexity for marginal gain on typical datasets

**Planned for v0.3.0** if real-world usage reveals datasets with 20+ columns with missing data as a common pattern.

---

## 9. Summary: When to Worry

| Situation | Worried? | Action |
|-----------|----------|--------|
| < 100k rows, < 20 columns | No | Use as-is |
| > 100k rows, < 20 columns | Slightly | Expect ~3–10s. Batch mode. |
| Any rows, > 20 columns with missing | Yes | Subset columns before analysis |
| Any rows, > 50 total columns | Yes | Subset columns. Consider column selection. |
| Missing only in categorical columns | Aware | Little's test will be INCONCLUSIVE. Use logistic/t-tests. |
| Column names with spaces | Aware | Use compare_mcar_tests (auto-sanitized). Avoid direct test_mcar_logistic. |
| First call in Julia session | Patient | JIT overhead: 10–50s. Normal. |