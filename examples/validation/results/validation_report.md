# MissingDataViz.jl — Validation Report (Step 13, Part 1)

Generated: 2026-03-03 23:21:44

## 1. Dataset Summary

| Dataset | Domain | Rows | Cols | Missing % | Cols w/ Missing | Patterns | Time (s) |
|---------|--------|------|------|-----------|-----------------|----------|----------|
| Adult/Census Income | Marketing/Demographics | 32561 | 15 | 0.87% | 3 | 5 | 56.77 |
| Diabetes 130-US Hospitals | Medical | 101766 | 50 | 3.79% | 7 | 54 | 12.8 |
| Online Retail II | Finance/Commerce | 100000 | 8 | 4.4% | 2 | 3 | 21.99 |
| NYC Airbnb | Marketing/Real Estate | 48895 | 16 | 2.57% | 4 | 6 | 4.92 |
| Melbourne Housing | Finance/Real Estate | 13580 | 21 | 4.65% | 4 | 12 | 18.65 |

## 2. MCAR Test Results

| Dataset | Little's p-value | Little's Decision | Violations | Violated Columns |
|---------|------------------|-------------------|------------|------------------|
| Adult/Census Income | NaN | INCONCLUSIVE | 2 | workclass, occupation |
| Diabetes 130-US Hospitals | NaN | INCONCLUSIVE | 6 | diag_3, weight, race, medical_specialty, diag_2, payer_code |
| Online Retail II | 0.0 | MCAR_REJECTED | 1 | Customer_ID |
| NYC Airbnb | 0.0 | MCAR_REJECTED | 4 | last_review, host_name, reviews_per_month, name |
| Melbourne Housing | 0.0 | MCAR_REJECTED | 3 | CouncilArea, Car, BuildingArea |

## 3. Per-Dataset Details

### Adult/Census Income (Marketing/Demographics)

**Size**: 32561 rows × 15 columns

**Missing columns** (sorted by % missing):

| Column | Missing % |
|--------|-----------|
| occupation | 5.66% |
| workclass | 5.64% |
| native_country | 1.79% |

**MCAR diagnosis**: INCONCLUSIVE

**Violations**: workclass, occupation

**Notes**: Leading spaces in values — CSV.jl strips them if missingstring includes ' ?'

---

### Diabetes 130-US Hospitals (Medical)

**Size**: 101766 rows × 50 columns

**Missing columns** (sorted by % missing):

| Column | Missing % |
|--------|-----------|
| weight | 96.86% |
| medical_specialty | 49.08% |
| payer_code | 39.56% |
| race | 2.23% |
| diag_3 | 1.4% |
| diag_2 | 0.35% |
| diag_1 | 0.02% |

**MCAR diagnosis**: INCONCLUSIVE

**Violations**: diag_3, weight, race, medical_specialty, diag_2, payer_code

**Notes**: Many '?' encoded missing values. Some columns nearly 100% missing (weight ~97%).

---

### Online Retail II (Finance/Commerce)

**Size**: 100000 rows × 8 columns

**Missing columns** (sorted by % missing):

| Column | Missing % |
|--------|-----------|
| Customer_ID | 34.92% |
| Description | 0.3% |

**MCAR diagnosis**: MCAR_REJECTED

**Violations**: Customer_ID

**Notes**: Tab-separated file. Price uses European decimal comma. Limit to 100k rows.

---

### NYC Airbnb (Marketing/Real Estate)

**Size**: 48895 rows × 16 columns

**Missing columns** (sorted by % missing):

| Column | Missing % |
|--------|-----------|
| last_review | 20.56% |
| reviews_per_month | 20.56% |
| host_name | 0.04% |
| name | 0.03% |

**MCAR diagnosis**: MCAR_REJECTED

**Violations**: last_review, host_name, reviews_per_month, name

**Notes**: reviews_per_month missing = listing has 0 reviews (structural missing).

---

### Melbourne Housing (Finance/Real Estate)

**Size**: 13580 rows × 21 columns

**Missing columns** (sorted by % missing):

| Column | Missing % |
|--------|-----------|
| BuildingArea | 47.5% |
| YearBuilt | 39.58% |
| CouncilArea | 10.08% |
| Car | 0.46% |

**MCAR diagnosis**: MCAR_REJECTED

**Violations**: CouncilArea, Car, BuildingArea

**Notes**: Multiple columns with varying missing rates. Good test for pattern diversity.

---

## 4. Comparison with R/Python (Manual)

Fill in after running equivalent analyses in R (naniar) and Python (missingno).

| Dataset | Metric | MissingDataViz.jl | R (naniar) | Python (missingno) | Divergence? |
|---------|--------|-------------------|------------|--------------------| ------------|
| Adult/Census Income | Missing % | 0.87% | — | — | — |
| Adult/Census Income | Little's p | NaN | — | — | — |
| Diabetes 130-US Hospitals | Missing % | 3.79% | — | — | — |
| Diabetes 130-US Hospitals | Little's p | NaN | — | — | — |
| Online Retail II | Missing % | 4.4% | — | — | — |
| Online Retail II | Little's p | 0.0 | — | — | — |
| NYC Airbnb | Missing % | 2.57% | — | — | — |
| NYC Airbnb | Little's p | 0.0 | — | — | — |
| Melbourne Housing | Missing % | 4.65% | — | — | — |
| Melbourne Housing | Little's p | 0.0 | — | — | — |

### How to Compare

**R (naniar + mice)**:
```r
library(naniar)
library(mice)
# Load dataset
df <- read.csv("data/adult.csv", header=FALSE, na.strings=c("?", " ?"))
# Missing summary
miss_var_summary(df)
# Little's MCAR test
mcar_test(df)  # from naniar
```

**Python (missingno + scipy)**:
```python
import pandas as pd
import missingno as msno
# Load dataset
df = pd.read_csv('data/adult.csv', header=None, na_values=['?', ' ?'])
# Missing summary
df.isnull().sum() / len(df) * 100
# Visualizations
msno.matrix(df)
msno.heatmap(df)
```

## 5. Expected Divergence Sources

When comparing results across Julia/R/Python, expect these differences:

1. **Little's test p-values**: Small numerical differences due to different 
   chi-squared implementations and EM convergence criteria. Differences <0.01 
   in p-value are normal. Decisions (reject/accept) should agree.

2. **Logistic regression coefficients**: GLM.jl vs R glm() vs Python 
   statsmodels may use different optimization algorithms (IRLS vs Newton). 
   p-values should be close but not identical.

3. **Missing percentages**: Should be IDENTICAL. Any divergence here means 
   different missing value encoding (e.g., '?' not recognized as missing).

4. **Welch t-test results**: Should match closely. R uses `t.test()`, 
   Python uses `scipy.stats.ttest_ind(equal_var=False)`. Differences in 
   degrees of freedom rounding may cause minor p-value differences.

