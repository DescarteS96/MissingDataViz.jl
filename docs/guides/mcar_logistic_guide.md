# MCAR Logistic Regression Test - Theoretical Guide

**Author:** MissingDataViz.jl  
**Last Updated:** 2025-02-17  
**Test Function:** `test_mcar_logistic(df, col_missing; alpha=0.05, exclude_cols=Symbol[])`

---

## Table of Contents

1. [Mathematical Principle](#1-mathematical-principle)
2. [When to Use This Test](#2-when-to-use-this-test)
3. [Interpretation Guide](#3-interpretation-guide)
4. [Step-by-Step Example](#4-step-by-step-example)
5. [Decision Tree](#5-decision-tree)
6. [Advantages Over Other Tests](#6-advantages-over-other-tests)
7. [Assumptions and Limitations](#7-assumptions-and-limitations)
8. [Common Pitfalls](#8-common-pitfalls)
9. [References](#9-references)

---

## 1. Mathematical Principle

### The Logistic Regression Model

The MCAR logistic regression test creates a **binary outcome variable**:

$$
y_i = \begin{cases} 
1 & \text{if observation } i \text{ is missing in } \texttt{col\_missing} \\
0 & \text{if observation } i \text{ is observed in } \texttt{col\_missing}
\end{cases}
$$

Then fits a **logistic regression model**:

$$
\text{logit}(P(y_i = 1)) = \log\left(\frac{P(y_i = 1)}{1 - P(y_i = 1)}\right) = \beta_0 + \beta_1 x_{i1} + \beta_2 x_{i2} + \cdots + \beta_p x_{ip}
$$

Where:
- $P(y_i = 1)$ is the probability that observation $i$ is missing
- $x_{i1}, x_{i2}, \ldots, x_{ip}$ are **fully observed predictor variables**
- $\beta_0$ is the intercept
- $\beta_1, \beta_2, \ldots, \beta_p$ are regression coefficients

### Null Hypothesis (MCAR)

$$
H_0: \beta_1 = \beta_2 = \cdots = \beta_p = 0
$$

**Interpretation:** No predictor variable is associated with missingness → MCAR holds.

### Alternative Hypothesis (MAR/MNAR)

$$
H_1: \text{At least one } \beta_j \neq 0 \text{ for } j \in \{1, 2, \ldots, p\}
$$

**Interpretation:** At least one variable predicts missingness → MCAR violated (MAR or MNAR).

### Test Statistic

The function reports:
- **Deviance**: Model fit statistic (lower = better fit)
- **p-value**: Minimum p-value among all predictors
- **Decision**: MCAR rejected if any predictor has $p < \alpha$

---

## 2. When to Use This Test

### ✅ Use Logistic Regression Test When:

1. **Multiple predictors available**
   - You have 2+ fully observed columns to test simultaneously
   - Example: Testing if `age`, `gender`, and `education` predict `income` missing

2. **Categorical predictors present**
   - Logistic regression handles categorical variables via dummy coding
   - Example: Testing if `gender` (M/F) predicts `salary` missing

3. **Need to control for confounding**
   - You suspect multiple variables jointly predict missingness
   - Example: Does `income` predict `age` missing **after controlling for education**?

4. **Large sample size (n ≥ 50)**
   - Logistic regression requires sufficient data per predictor
   - Rule of thumb: At least 10 events (missing values) per predictor

### ❌ Do NOT Use When:

1. **No fully observed predictors**
   - All columns have missing values → test cannot run
   - Solution: Use `test_mcar_little()` for global test

2. **Very small sample (n < 10)**
   - Logistic regression unreliable with <10 observations
   - Solution: Use descriptive analysis only

3. **Only 1 numeric predictor**
   - For single numeric predictor, `test_mcar_means()` is simpler
   - Logistic regression adds unnecessary complexity

4. **Perfect separation**
   - If predictor perfectly separates observed/missing groups
   - Logistic regression fails to converge (deviance = 0)

---

## 3. Interpretation Guide

### P-Value Interpretation Table

| **p-value Range** | **Decision** | **Interpretation** | **Action** |
|-------------------|--------------|---------------------|------------|
| **p < 0.01** | MCAR **rejected** (strong evidence) | Variable strongly predicts missingness | Investigate relationship. Use MICE, regression imputation, or inverse probability weighting. Avoid simple mean/mode imputation. |
| **0.01 ≤ p < 0.05** | MCAR **rejected** (moderate evidence) | Variable moderately predicts missingness | Use caution with simple imputation. Consider advanced methods. Check sensitivity to imputation method. |
| **0.05 ≤ p < 0.10** | MCAR **not rejected** (borderline) | Weak evidence of association | Simple imputation may be acceptable, but validate with other tests. Document uncertainty. |
| **p ≥ 0.10** | MCAR **not rejected** | No evidence against MCAR for this predictor | Simple imputation (mean, median, mode) acceptable for this variable. |
| **p = NaN** | **INCONCLUSIVE** | Test could not run | Check warnings: insufficient data, no predictors, or convergence failure. |

### Odds Ratio Interpretation

Each predictor returns an **odds ratio (OR)**:

$$
\text{OR} = e^{\beta_j}
$$

**Interpretation:**

| **Odds Ratio** | **Meaning** | **Example** |
|----------------|-------------|-------------|
| **OR > 1** | Higher predictor value → **more likely** to be missing | OR = 1.5 for `income`: Each $10k increase in income → 1.5× higher chance of `age` being missing |
| **OR = 1** | Predictor has **no effect** on missingness | OR = 1.0 for `gender`: Gender does not predict `salary` missing |
| **OR < 1** | Higher predictor value → **less likely** to be missing | OR = 0.7 for `education`: Higher education → 30% lower chance of `income` missing |

### Coefficient Sign Interpretation

| **Coefficient** | **Effect on Missingness** |
|-----------------|---------------------------|
| **β > 0** | Positive association: Higher X → Higher P(missing) |
| **β = 0** | No association |
| **β < 0** | Negative association: Higher X → Lower P(missing) |

---

## 4. Step-by-Step Example

### Scenario: Healthcare Dataset

**Research Question:** Does patient `age`, `gender`, and `income` predict missing `blood_pressure` readings?

#### Step 1: Load Data
```julia
using MissingDataViz, DataFrames

df = DataFrame(
    age = [25, 30, missing, 40, 45, 50, 55, 60, 65, 70,
           28, 32, 38, 42, 48, 52, 58, 62, 68, 72],
    income = [30000, 35000, 40000, 45000, 50000, 55000, 60000, 65000, 70000, 75000,
              32000, 38000, 42000, 48000, 52000, 58000, 62000, 68000, 72000, 78000],
    gender = repeat(["M", "F"], 10),
    blood_pressure = [120, missing, 130, missing, 140, 145, missing, 150, 155, missing,
                      125, 128, missing, 138, 142, 148, missing, 158, 162, missing]
)
```

#### Step 2: Run Test
```julia
result = test_mcar_logistic(df, :blood_pressure)
println(result)
```

**Output:**
```
─────────────────────────────────────────
MCAR Test: MCAR Logistic Regression Test
─────────────────────────────────────────
  Statistic : 45.23
  p-value   : 0.0023
  Alpha     : 0.05
  Decision  : MCAR rejected (significant dependence detected)
─────────────────────────────────────────
```

#### Step 3: Identify Significant Predictors
```julia
println("\n=== SIGNIFICANT PREDICTORS ===")
for pred in result.details["significant_predictors"]
    println("⚠️  Variable: $(pred["variable"])")
    println("   Coefficient: $(round(pred["coefficient"], digits=4))")
    println("   p-value: $(round(pred["pvalue"], digits=4))")
    println("   Odds Ratio: $(round(pred["odds_ratio"], digits=2))")
    println()
end
```

**Output:**
```
=== SIGNIFICANT PREDICTORS ===
⚠️  Variable: age
   Coefficient: 0.0450
   p-value: 0.0023
   Odds Ratio: 1.05

⚠️  Variable: income
   Coefficient: 0.0001
   p-value: 0.0189
   Odds Ratio: 1.00
```

#### Step 4: Interpret Results

**Findings:**
1. **Age** predicts missingness (p = 0.0023)
   - Odds Ratio = 1.05 → Each 1-year increase in age → 5% higher chance of missing BP
   - **Older patients more likely to have missing blood pressure**

2. **Income** predicts missingness (p = 0.0189)
   - Odds Ratio ≈ 1.00 (1.0001) → Weak effect
   - **Higher income slightly increases missingness**

3. **Gender** does NOT predict (not in list)
   - p > 0.05 → Gender has no effect on BP missingness

**Conclusion:**
- **MCAR is VIOLATED** (p = 0.0023 < 0.05)
- Missingness mechanism is **MAR** (depends on observed `age`)
- **Action:** Use regression imputation or MICE, adjusting for `age`

---

## 5. Decision Tree

### Choosing the Right MCAR Test
```
┌─────────────────────────────────────────────────────┐
│ START: Do you need to test MCAR assumption?        │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ How many fully observed predictors do you have?     │
└─────────────────────────────────────────────────────┘
         │                        │                    │
    None/All Missing        1 Predictor         2+ Predictors
         │                        │                    │
         ▼                        ▼                    ▼
┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐
│ test_mcar_little │   │ Is it numeric?   │   │ Are any       │
│ (Global test)    │   │                  │   │ categorical?  │
└──────────────────┘   └──────────────────┘   └────────────────┘
                         │              │         │          │
                     Numeric      Categorical   Yes        No
                         │              │         │          │
                         ▼              ▼         ▼          ▼
              ┌──────────────┐  ┌────────────────────────────────┐
              │test_mcar_means│  │   test_mcar_logistic           │
              │(Simple t-test)│  │   (Handles all types)          │
              └──────────────┘  └────────────────────────────────┘
```

### Quick Reference

| **Situation** | **Best Test** | **Why?** |
|---------------|---------------|----------|
| 1 numeric predictor | `test_mcar_means` | Simpler, same power |
| 2+ numeric predictors | `test_mcar_logistic` | Controls for confounding |
| Categorical predictors | `test_mcar_logistic` | Only test that handles categorical |
| All columns missing | `test_mcar_little` | Global test (future) |
| Small sample (n < 30) | Descriptive only | Statistical tests unreliable |

---

## 6. Advantages Over Other Tests

### vs. `test_mcar_means()` (Welch t-test)

| **Feature** | **test_mcar_means** | **test_mcar_logistic** |
|-------------|---------------------|------------------------|
| **Number of predictors** | 1 only | Multiple (2+) |
| **Predictor type** | Numeric only | Numeric + Categorical |
| **Controls confounding** | ❌ No | ✅ Yes |
| **Example** | "Does `income` predict `age` missing?" | "Does `income` predict `age` missing **after controlling for gender**?" |
| **Complexity** | Low | Moderate |
| **Sample size** | n ≥ 10 per group | n ≥ 50 recommended |

**Use Case Example:**
```julia
# Scenario: Does income predict age missing?

# Simple test (ignores gender)
test_mcar_means(df, :age, :income)  # p = 0.03 → Reject MCAR

# Adjusted test (controls for gender)
test_mcar_logistic(df, :age)  # income: p = 0.12 (not significant after controlling for gender!)
```

### vs. `test_mcar_little()` (Little's Global Test)

| **Feature** | **test_mcar_little** | **test_mcar_logistic** |
|-------------|----------------------|------------------------|
| **Scope** | Global (all columns) | Single column |
| **Identifies culprits** | ❌ No | ✅ Yes (which variables predict?) |
| **Actionable** | Low | High |
| **Use case** | Initial screening | Detailed investigation |

**Workflow:**
1. Run `test_mcar_little()` first → Global test fails
2. Run `test_mcar_logistic()` for each column → Identify which variables predict missingness

---

## 7. Assumptions and Limitations

### Assumptions

1. **Independence of observations**
   - Rows must be independent (no repeated measures, clustering)
   - Violation: Time series data, family data

2. **At least 1 fully observed predictor**
   - Cannot test if all columns have missing values
   - Workaround: Use `test_mcar_little()` or impute predictors first

3. **Sufficient sample size**
   - Minimum 10 observations per group (missing vs observed)
   - Minimum 10 events per predictor (rule of thumb)
   - Small samples → unreliable p-values

4. **No perfect separation**
   - Predictor cannot perfectly separate missing/observed groups
   - Example: If `income > 50k` → **always** missing, model fails

### Limitations

| **Limitation** | **Impact** | **Solution** |
|----------------|------------|--------------|
| **Pairwise only** | Tests each column separately, misses multivariate patterns | Complement with `test_mcar_little()` |
| **Requires complete predictors** | Cannot test if all variables have missing | Use Little's test or impute first |
| **Separation issues** | Model fails if predictor perfectly predicts missingness | Check `deviance` value; if 0, separation occurred |
| **Multiple testing** | Testing many columns inflates Type I error | Use Bonferroni correction: `alpha / n_tests` |
| **Cannot detect MNAR** | If missingness depends on **unobserved** values, no test detects it | Requires domain knowledge, sensitivity analysis |

### Common Warnings
```julia
result = test_mcar_logistic(df, :age)

# Warning 1: Small sample
"Small sample: n_missing=8, n_observed=12. Results may be unreliable."
→ Action: Collect more data or use descriptive analysis

# Warning 2: No predictors
"No fully observed predictor columns — cannot fit model"
→ Action: Use test_mcar_little() or impute some columns first

# Warning 3: Model fitting failed
"Model fitting failed — possible perfect separation or collinearity"
→ Action: Check if predictor perfectly separates groups; remove collinear predictors
```

---

## 8. Common Pitfalls

### Pitfall 1: Ignoring Multiple Testing

**Problem:**
```julia
# Testing 10 columns at α = 0.05
for col in [:age, :income, :gender, :education, :bmi, :bp, :cholesterol, :glucose, :smoker, :exercise]
    result = test_mcar_logistic(df, col)
end
# Expected false positives: 10 × 0.05 = 0.5 (at least 1 spurious rejection likely)
```

**Solution:**
```julia
# Use Bonferroni correction
alpha_corrected = 0.05 / 10  # 0.005
for col in columns
    result = test_mcar_logistic(df, col, alpha=alpha_corrected)
end
```

### Pitfall 2: Misinterpreting "Not Rejected"

**❌ Wrong:**
> "p = 0.12 → MCAR is TRUE → Simple imputation is perfect"

**✅ Correct:**
> "p = 0.12 → No evidence against MCAR **among observed variables** → Simple imputation may be acceptable, but we cannot rule out MNAR (dependence on unobserved values)"

**Key:** MCAR tests only detect MAR violations, **not** MNAR.

### Pitfall 3: Using with All Missing Predictors

**Problem:**
```julia
df = DataFrame(
    age = [missing, 25, missing, 30],
    income = [30k, missing, 40k, missing],
    bp = [120, missing, 130, missing]
)

result = test_mcar_logistic(df, :bp)  # ERROR: No fully observed predictors
```

**Solution:**
```julia
# Option 1: Use Little's test (global, handles all missing)
test_mcar_little(df)

# Option 2: Test only columns with complete predictors
test_mcar_logistic(df[df.age .!== missing, :], :bp)  # Use only complete-case rows
```

### Pitfall 4: Perfect Separation

**Problem:**
```julia
df = DataFrame(
    age = [25, 30, 35, 40, 45, 50, 55, 60, 65, 70],
    income = [30k, 35k, 40k, 45k, 50k, 55k, 60k, 65k, 70k, 75k],
    bp = [120, 130, 140, 145, missing, missing, missing, missing, missing, missing]
)

result = test_mcar_logistic(df, :bp)
# Deviance = 0, p-value = NaN
# income perfectly separates: income < 50k → observed, income ≥ 50k → missing
```

**Diagnosis:**
```julia
result.details["model_deviance"]  # 0.0 → Perfect separation detected
```

**Solution:**
- This is a **data issue**, not a test failure
- Perfect separation rarely occurs in real data
- If observed: Use descriptive analysis instead of statistical test

### Pitfall 5: Forgetting Categorical Encoding

**Problem:**
```julia
df = DataFrame(
    age = [25, missing, 30, missing, 35],
    gender = ["M", "F", "M", "F", "M"]  # String, not numeric
)

result = test_mcar_logistic(df, :age)
# Warning: GLM.jl auto-encodes strings → "genderM" predictor created
```

**✅ This is CORRECT behavior:**
- Logistic regression automatically creates dummy variables
- `gender = "M"` → `genderM = 1`, `gender = "F"` → `genderM = 0`
- Formula becomes: `y ~ genderM` (not `y ~ gender`)

**Check results:**
```julia
result.details["formula"]
# "y ~ gender"  ← GLM internally converts to dummy

result.details["significant_predictors"]
# Variable: "gender: M"  ← Coefficient for males vs. females (reference)
```

---

## 9. References

### Academic Literature

1. **Little, R. J. A. (1988).** "A Test of Missing Completely at Random for Multivariate Data with Missing Values." *Journal of the American Statistical Association*, 83(404), 1198-1202.
   - Original MCAR test (global chi-square test)

2. **Rubin, D. B. (1976).** "Inference and Missing Data." *Biometrika*, 63(3), 581-592.
   - Formalized MCAR, MAR, MNAR definitions

3. **Hosmer, D. W., Lemeshow, S., & Sturdivant, R. X. (2013).** *Applied Logistic Regression* (3rd ed.). Wiley.
   - Logistic regression theory and diagnostics

4. **Van Buuren, S. (2018).** *Flexible Imputation of Missing Data* (2nd ed.). CRC Press.
   - Chapter 2: Missing data mechanisms
   - Chapter 4: Testing MCAR

### Online Resources

- **GLM.jl Documentation:** https://github.com/JuliaStats/GLM.jl
  - Logistic regression in Julia

- **MissingDataViz.jl Repository:** https://github.com/DescarteS96/MissingDataViz.jl
  - Source code and examples

- **Anthropic Claude AI Assistance:** Used for documentation generation and code review

---

## Appendix: Comparison Table

| **Test** | **Predictors** | **Type** | **Scope** | **Output** | **Best For** |
|----------|---------------|----------|-----------|------------|--------------|
| `test_mcar_means` | 1 | Numeric | Single pair | p-value, mean difference | Quick check, simple case |
| `test_mcar_logistic` | 2+ | Numeric + Categorical | Single column | p-values, odds ratios, coefficients | Detailed investigation, multiple predictors |
| `test_mcar_little` | All | Numeric | Global | Single p-value | Screening, all missing columns |

---

**End of Guide**

For questions or feedback, please open an issue on GitHub: https://github.com/DescarteS96/MissingDataViz.jl/issues