# Interpreting MCAR Tests: A Practical Guide

> **Audience:** Researchers, analysts, and students who work with data containing missing values.  
> **Prerequisites:** Basic understanding of p-values and hypothesis testing.  
> **Reading time:** ~15 minutes

---

## Table of Contents

1. [Why Missing Data Matters](#1-why-missing-data-matters)
2. [The Three Missing Data Mechanisms](#2-the-three-missing-data-mechanisms)
3. [Understanding the Three MCAR Tests](#3-understanding-the-three-mcar-tests)
4. [Decision Tree: Which Test to Use](#4-decision-tree-which-test-to-use)
5. [Reading Your Results](#5-reading-your-results)
6. [What to Do After Diagnosis](#6-what-to-do-after-diagnosis)
7. [Common Pitfalls](#7-common-pitfalls)
8. [Worked Examples](#8-worked-examples)
9. [Frequently Asked Questions](#9-frequently-asked-questions)
10. [References](#10-references)

---

## 1. Why Missing Data Matters

Every dataset with missing values carries a hidden question: **why** are these values missing? The answer determines whether your statistical analyses will be valid or biased.

Consider a hospital survey measuring patient satisfaction. If some patients didn't respond:

- **Scenario A:** Patients forgot to fill in the last page because the survey was too long. Missingness is unrelated to satisfaction → your average satisfaction score is still valid.
- **Scenario B:** Dissatisfied patients refused to respond. Missingness depends on the variable itself → your average satisfaction score is **biased upward**.
- **Scenario C:** Older patients were less likely to respond. Missingness depends on age (an observed variable) → your average is biased, but you can correct for it.

These three scenarios correspond to the three missing data mechanisms. MissingDataViz.jl helps you determine which one applies to your data.

---

## 2. The Three Missing Data Mechanisms

### MCAR — Missing Completely At Random

**Definition:** The probability of a value being missing is the same for all observations, regardless of any variable in the dataset.

**Plain language:** The missingness is like flipping a coin — it has nothing to do with the data itself.

**Example:** A lab technician accidentally drops 5% of blood samples. Which samples were dropped has nothing to do with the patients' health.

**Consequence:** Your analyses remain unbiased. Simple methods (mean imputation, listwise deletion) are acceptable, though not optimal.

### MAR — Missing At Random

**Definition:** The probability of a value being missing depends on other *observed* variables, but not on the missing value itself.

**Plain language:** The missingness can be explained by information you already have.

**Example:** In a clinical trial, younger patients are more likely to miss follow-up visits. Age is recorded, so you can account for it.

**Consequence:** Your analyses are biased if you ignore the mechanism. However, methods like multiple imputation (MICE) can correct the bias because the predictors of missingness are observed.

### MNAR — Missing Not At Random

**Definition:** The probability of a value being missing depends on the missing value itself.

**Plain language:** The very reason a value is missing is related to what that value would have been.

**Example:** High-income individuals refuse to report their salary. The missingness depends on salary — the variable that is missing.

**Consequence:** No standard statistical method can fully correct this bias. You need domain knowledge, sensitivity analyses, or external data.

### The Testing Hierarchy

| Mechanism | Can you detect it statistically? | What to do? |
|-----------|----------------------------------|-------------|
| MCAR | Yes — this is what MissingDataViz tests | Simple or advanced imputation |
| MAR | Partially — rejection of MCAR suggests MAR or MNAR | Advanced imputation (MICE) |
| MNAR | No — cannot be distinguished from MAR with observed data alone | Domain knowledge + sensitivity analysis |

**Important:** Statistical tests can reject MCAR, but they cannot distinguish between MAR and MNAR. If MCAR is rejected, you know the data is *not* missing at random — but you need domain expertise to determine whether it's MAR (correctable) or MNAR (problematic).

---

## 3. Understanding the Three MCAR Tests

MissingDataViz.jl implements three complementary tests. Each has different strengths.

### 3.1. Little's MCAR Test (Global)

**What it does:** Tests whether the pattern of missing data across *all* variables simultaneously is consistent with MCAR.

**How it works (simplified):**
1. Groups observations by their missing data pattern (e.g., "missing on age and income" vs. "missing on income only")
2. Compares the means of observed variables across these groups
3. If the groups have similar means → consistent with MCAR
4. If the groups have different means → evidence against MCAR

**Output:** A single chi-squared statistic and p-value for the entire dataset.

**Strengths:**
- Single global test — one p-value for the whole dataset
- Well-established in the literature (Little, 1988)
- Considers all variables simultaneously

**Limitations:**
- Requires numeric columns with missing values (categorical-only missing → INCONCLUSIVE)
- Low statistical power for detecting weak or localized MAR patterns
- Cannot identify *which* specific columns violate MCAR
- Sensitive to multivariate normality assumptions

**When to trust it:**
- Trust a rejection (p < α) — it means MCAR is violated somewhere
- Be cautious with non-rejection (p ≥ α) — it might miss weak MAR patterns

### 3.2. Pairwise t-tests (Univariate)

**What it does:** For each column with missing values, tests whether the missingness is related to one other numeric column.

**How it works (simplified):**
1. Take a column with missing values (e.g., `income`)
2. Split observations into two groups: those where `income` is observed vs. missing
3. Compare the mean of another column (e.g., `age`) between these two groups using a Welch t-test
4. If the means differ significantly → missingness in `income` is related to `age` → MCAR violated

**Output:** One p-value per column with missing data.

**Strengths:**
- Simple and interpretable
- Identifies *which* column pair shows the relationship
- No distributional assumptions (Welch t-test is robust)
- Very fast

**Limitations:**
- Tests only one predictor at a time (univariate)
- May miss multivariate patterns (e.g., missingness depends on age AND gender together)
- Multiple testing issue: with many columns, some p-values may be significant by chance

**When to trust it:**
- Good first-pass screening
- Trust strong rejections (p < 0.01)
- Be cautious with borderline results when testing many pairs

### 3.3. Logistic Regression (Multivariate)

**What it does:** For each column with missing values, fits a logistic regression model predicting missingness from *all* other columns simultaneously.

**How it works (simplified):**
1. Create a binary indicator: 1 = missing, 0 = observed for the target column
2. Fit a logistic regression: `P(missing) = f(all other columns)`
3. Test whether the overall model is significant (likelihood ratio test)
4. If significant → other columns predict missingness → MCAR violated

**Output:** One p-value per column with missing data, plus the identity of significant predictors.

**Strengths:**
- Multivariate — considers all predictors simultaneously
- Identifies *which* predictors drive missingness
- Handles both numeric and categorical predictors (via GLM.jl)
- Most powerful of the three tests for detecting MAR

**Limitations:**
- Slower than t-tests (fits a full GLM for each column)
- Requires sufficient sample size relative to number of predictors
- May produce INCONCLUSIVE if too few complete predictors are available
- Column names must be valid Julia identifiers (auto-sanitized in `compare_mcar_tests`)

**When to trust it:**
- Most reliable for multivariate MAR detection
- The significant predictors tell you *why* data is missing
- Essential for building a good imputation model

### Side-by-Side Comparison

| Feature | Little's Test | t-tests | Logistic Regression |
|---------|--------------|---------|-------------------- |
| Scope | Global (all variables) | Pairwise (one pair) | Per-column (all predictors) |
| Speed | Fast | Very fast | Moderate |
| Identifies problematic columns | No | Yes (one pair) | Yes (all predictors) |
| Handles categorical columns | No | No | Yes |
| Power for weak MAR | Low | Moderate | High |
| Multiple testing concern | No (single test) | Yes | Moderate |
| Minimum data requirement | Numeric columns with missing | One complete numeric column | Multiple complete columns |

---

## 4. Decision Tree: Which Test to Use

```
START: Do you have missing data?
│
├── NO → No MCAR testing needed. Dataset is complete.
│
└── YES → What types of columns have missing values?
    │
    ├── ONLY NUMERIC columns have missing
    │   │
    │   └── Run all three tests: compare_mcar_tests(df)
    │       │
    │       ├── All agree (all reject or all accept)
    │       │   └── Trust the consensus
    │       │
    │       ├── Little accepts, pairwise reject
    │       │   └── Trust pairwise tests (more sensitive)
    │       │       Likely weak or localized MAR
    │       │
    │       └── Mixed results
    │           └── Assume MAR (conservative approach)
    │               Investigate specific columns
    │
    ├── ONLY CATEGORICAL columns have missing
    │   │
    │   └── Little's test will be INCONCLUSIVE
    │       Use logistic regression only:
    │       compare_mcar_tests(df) → focus on logistic results
    │
    └── MIXED (numeric + categorical) missing
        │
        └── Run all three tests: compare_mcar_tests(df)
            Little's tests numeric columns only
            Logistic regression tests all columns
            Combine results for full picture
```

### Quick Decision Rules

**Use `compare_mcar_tests(df)` (recommended default):**
- Runs all three tests automatically
- Provides consensus analysis and recommendation
- Works for any dataset type

**Use `test_mcar_little(df)` alone when:**
- You need a single global p-value for a publication
- Your dataset is primarily numeric
- You want to cite a well-known statistical test

**Use `test_mcar_logistic(df, :column)` alone when:**
- You want to investigate one specific column in depth
- You need to know *which* predictors drive missingness
- You're building an imputation model and need predictor selection

**Use `test_mcar_means(df, :col1, :col2)` alone when:**
- Quick exploratory check between two specific columns
- Educational or teaching context
- Very large datasets where logistic regression is too slow

### Dataset Size Considerations

| Dataset | Recommended Approach |
|---------|---------------------|
| < 100 rows | Insufficient power for reliable testing. Use domain knowledge. |
| 100–1,000 rows | All tests applicable. Watch for low power in Little's test. |
| 1,000–100,000 rows | Optimal range. All tests reliable. Use `compare_mcar_tests`. |
| > 100,000 rows | All tests work but logistic regression slows with many columns. Consider column subsetting if > 20 columns. |

---

## 5. Reading Your Results

### The Summary Output

When you run `compare_mcar_tests(df)`, the output contains four sections:

**Section 1: Little's Test**
```
Decision: MCAR_REJECTED       ← MCAR is violated globally
p-value:  0.0001              ← Very strong evidence
Chi²:     45.23, df = 12      ← Test statistic and degrees of freedom
```

**Section 2: Logistic Regression**
```
Variables tested: 3            ← 3 columns had missing values
MCAR rejected:   2            ← 2 of them violate MCAR
MCAR accepted:   1            ← 1 is consistent with MCAR
⚠️  MCAR VIOLATED for:
  • income (p = 0.0023)        ← Missingness in income is predictable
    Predictors: age, education ← These predict whether income is missing
  • weight (p = 0.0001)
    Predictors: gender, age
```

**Section 3: Pairwise t-tests**
```
MCAR rejected:  2
  • income (p = 0.0045)        ← Confirms logistic result
  • weight (p = 0.0012)
```

**Section 4: Consensus Analysis**
```
✓ STRONG AGREEMENT: All tests reject MCAR
Confidence: HIGH
```

### Interpreting the Consensus

| Consensus | Meaning | Confidence | Action |
|-----------|---------|------------|--------|
| STRONG AGREEMENT (all reject) | MCAR is clearly violated | HIGH | Use advanced imputation (MICE) |
| FULL AGREEMENT (all accept) | No evidence against MCAR | MODERATE | Simple imputation acceptable, but MICE is safer |
| PARTIAL DISAGREEMENT | Weak or localized MAR | MODERATE | Trust pairwise tests; use MICE for flagged columns |
| MIXED RESULTS | Complex mechanism | LOW | Assume MAR; investigate further; use MICE |

### What the p-values Mean

| p-value | Interpretation | Practical meaning |
|---------|---------------|-------------------|
| p < 0.001 | Very strong evidence against MCAR | Missingness is clearly not random |
| p < 0.01 | Strong evidence | Missingness is very likely not random |
| p < 0.05 | Moderate evidence | Missingness is probably not random |
| p = 0.05–0.10 | Weak evidence | Borderline — investigate further |
| p > 0.10 | No evidence against MCAR | Missingness may be random (but test may lack power) |

---

## 6. What to Do After Diagnosis

### Scenario A: MCAR Accepted (No Violations)

Your missing data appears to be random. You have several options:

**Option 1: Listwise Deletion (simplest)**
- Remove rows with any missing value
- Valid under MCAR, but reduces sample size
- Acceptable when missing rate is low (< 5%)

**Option 2: Mean/Median Imputation**
- Replace missing values with column mean (numeric) or mode (categorical)
- Preserves sample size
- Underestimates variance — use with caution for inferential statistics

**Option 3: Multiple Imputation (recommended)**
- Even under MCAR, MICE produces better estimates than simple methods
- Properly accounts for uncertainty due to missingness
- Standard in modern applied statistics

```julia
# MissingDataViz diagnosis shows no violations
# → Simple imputation is acceptable, but MICE is better

# Example with Impute.jl (separate package):
# using Impute
# df_imputed = Impute.substitute(df, :mean)  # mean imputation
# df_imputed = Impute.mice(df)                # MICE (preferred)
```

### Scenario B: MCAR Rejected (Violations Detected)

Your missing data is **not random**. The specific predictors identified by the logistic regression test tell you why.

**Step 1: Identify the mechanism**

Check the significant predictors from the logistic regression output:

```
⚠️  MCAR VIOLATED for:
  • income (p = 0.0023)
    Predictors: age, education
```

This means: whether `income` is missing depends on `age` and `education`. If you can explain this relationship with domain knowledge, it's likely MAR (correctable). If the missingness depends on income itself (e.g., high earners refuse to report), it may be MNAR.

**Step 2: Choose your imputation strategy**

| Suspected Mechanism | Strategy |
|---------------------|----------|
| MAR (predictors explain missingness) | Multiple imputation (MICE) including the identified predictors |
| MNAR (missingness depends on the value itself) | Sensitivity analysis + domain-specific methods |
| Uncertain | Use MICE + perform sensitivity analysis to check robustness |

**Step 3: Build the imputation model**

The logistic regression predictors tell you which variables to include in your imputation model:

```julia
# Example: income is MAR, predicted by age and education
# Include BOTH age and education in the imputation model for income
# This is critical — omitting predictors of missingness introduces bias
```

**Step 4: Validate**

After imputation, compare:
- Distributions of imputed vs. observed values
- Results across different imputation methods
- Sensitivity to assumptions about the missing mechanism

### Scenario C: Structural Missingness

Some missing data is **by design**, not by accident:

- **Surveys:** Skip logic (if "no children", skip child-related questions)
- **Databases:** Fields added after initial deployment (older records lack them)
- **Sensors:** Device offline = missing readings (not random)

These patterns are usually MNAR but are **expected and documented**. The correct response is not imputation but acknowledging the data structure.

```julia
# NYC Airbnb: last_review and reviews_per_month are missing
# for listings with 0 reviews — this is structural, not random.
# Solution: filter to listings with reviews, or create a binary
# indicator "has_reviews" instead of imputing.
```

### Summary: Post-Diagnostic Actions

| Diagnosis | Missing Rate | Recommended Action |
|-----------|-------------|-------------------|
| MCAR, < 5% missing | Low | Listwise deletion or mean imputation |
| MCAR, 5–20% missing | Moderate | Multiple imputation (MICE) |
| MCAR, > 20% missing | High | MICE + consider dropping high-missing columns |
| MAR identified | Any | MICE with predictors from logistic regression |
| MNAR suspected | Any | Sensitivity analysis + domain expertise |
| Structural missing | Any | Don't impute — restructure or filter |

---

## 7. Common Pitfalls

### Pitfall 1: "Little's test says MCAR, so my data is fine"

Little's test has **low power** for detecting weak or localized MAR patterns. A non-significant result means "we didn't find evidence against MCAR" — not "MCAR is true." Always check the pairwise tests too.

### Pitfall 2: "MCAR is rejected, so my data is useless"

Rejecting MCAR is not a disaster. It means you need to use appropriate methods (MICE, not mean imputation). Most real-world datasets are MAR, and well-designed multiple imputation handles MAR effectively.

### Pitfall 3: Ignoring the missing rate

A column with 95% missing values is unlikely to be reliably imputed regardless of the mechanism. Consider:
- Dropping columns with > 50% missing
- Using them as auxiliary variables only (include in imputation model but don't analyze directly)

### Pitfall 4: Testing too many columns

With 50 columns, you'll get some significant pairwise tests by chance alone (multiple testing problem). Look for:
- Consistent patterns across tests (not just one isolated p-value)
- Strong effects (p < 0.01, not just p < 0.05)
- Alignment with domain knowledge

### Pitfall 5: Confusing statistical significance with practical importance

A p-value of 0.001 on a dataset of 100,000 rows might reflect a trivially small effect. Check the actual mean differences or odds ratios in the logistic regression output, not just p-values.

### Pitfall 6: Assuming MNAR without evidence

MNAR is often invoked as a worst case, but many real-world missing data mechanisms are MAR. Before concluding MNAR:
- Check if observed variables explain the missingness (logistic regression)
- Consult domain experts
- Consider whether the "MNAR story" is actually plausible

### Pitfall 7: Correlation plot unreadable on wide datasets

The `plot_missing_correlation` heatmap displays all columns simultaneously. On datasets with 50+ columns (e.g., Diabetes 130-US Hospitals with 50 columns), axis labels overlap and become illegible, and the matrix becomes too dense to interpret visually.

**Recommendation:** Filter to columns with missing values before plotting the correlation matrix:
```julia
# Instead of plotting all 50 columns:
# plot_missing_correlation(df)  # unreadable

# Filter to columns that actually have missing data:
cols_with_missing = [col for col in names(df) if any(ismissing, df[!, col])]
plot_missing_correlation(df[:, cols_with_missing])  # readable
```

This limitation applies only to the correlation visualization — the MCAR statistical tests handle any number of columns correctly.

---

## 8. Worked Examples

### Example 1: Clean Synthetic Data (MCAR)

```julia
using MissingDataViz, DataFrames

# Generate data where missingness is truly random
df = generate_mcar_data(1000, 5, 0.15)

# Run full diagnosis
results = full_missing_diagnosis(df, verbose=true)

# Expected output:
# - Little's test: MCAR_NOT_REJECTED (p > 0.05)
# - Logistic regression: MCAR_NOT_REJECTED for all columns
# - t-tests: MCAR_NOT_REJECTED for all columns
# - Consensus: FULL AGREEMENT — All tests accept MCAR

# Action: Simple imputation is fine, MICE is better
```

### Example 2: MAR Data (Income Depends on Age)

```julia
# Generate data where missingness depends on another variable
df = generate_mar_data(1000, 5, 0.20)

# Run full diagnosis
results = full_missing_diagnosis(df, verbose=true)

# Expected output:
# - Little's test: MCAR_REJECTED (p < 0.05)
# - Logistic regression: MCAR_REJECTED for some columns
#   Predictors: x1 (the column that drives missingness)
# - Consensus: STRONG AGREEMENT or PARTIAL DISAGREEMENT

# Action: Use MICE, include x1 as predictor in imputation model
```

### Example 3: Real-World Data (NYC Airbnb)

```julia
using CSV
df = CSV.read("nyc_airbnb.csv", DataFrame)

results = full_missing_diagnosis(df, verbose=true)

# Output shows:
# - last_review and reviews_per_month: 20.56% missing (identical rate)
# - MCAR rejected (p = 0.0)
# - 4 violations detected

# Interpretation:
# These columns are missing for listings with 0 reviews.
# This is STRUCTURAL missing, not random.
# Action: Don't impute. Create a "has_reviews" binary variable.
```

---

## 9. Frequently Asked Questions

**Q: Can these tests prove that my data is MCAR?**

No. Statistical tests can only reject MCAR (find evidence against it). A non-significant result means "we didn't find evidence against MCAR" — it does not prove MCAR. This is the standard logic of hypothesis testing.

**Q: What sample size do I need for reliable results?**

As a rule of thumb:
- Little's test: at least 50 complete cases per missing data pattern
- Logistic regression: at least 10–20 observations per predictor
- t-tests: at least 30 observations in each group (missing vs. observed)

For datasets under 100 rows, rely on domain knowledge rather than statistical tests.

**Q: What if Little's test says MCAR but logistic regression says MAR?**

Trust the logistic regression. Little's test has lower power for detecting weak or localized MAR patterns. The `compare_mcar_tests` function flags this as "PARTIAL DISAGREEMENT" and recommends trusting the pairwise results.

**Q: My column names have spaces. Will the tests work?**

Yes, if you use `compare_mcar_tests(df)`. Column names are automatically sanitized internally. Direct calls to `test_mcar_logistic` may fail with special characters — rename columns first or use the comparison function.

**Q: What if most of my missing data is in categorical columns?**

Little's test will return INCONCLUSIVE (it requires numeric columns with missing values). The logistic regression and t-tests will still work. Focus on the logistic regression results for your diagnosis.

**Q: How do I cite these tests in a paper?**

- Little's test: Little, R. J. A. (1988). A test of missing completely at random for multivariate data with missing values. *Journal of the American Statistical Association*, 83(404), 1198–1202.
- For the general framework: Rubin, D. B. (1976). Inference and missing data. *Biometrika*, 63(3), 581–592.
- For MissingDataViz.jl: [Your citation here]

---

## 10. References

### Core References

1. **Little, R. J. A. (1988).** A test of missing completely at random for multivariate data with missing values. *Journal of the American Statistical Association*, 83(404), 1198–1202.  
   *The foundational paper for Little's MCAR test. Essential reading for understanding the chi-squared approach.*

2. **Rubin, D. B. (1976).** Inference and missing data. *Biometrika*, 63(3), 581–592.  
   *Defines the MCAR/MAR/MNAR taxonomy used throughout this guide.*

3. **van Buuren, S., & Groothuis-Oudshoorn, K. (2011).** mice: Multivariate Imputation by Chained Equations in R. *Journal of Statistical Software*, 45(3), 1–67.  
   *The reference implementation for multiple imputation. Explains the MICE algorithm in detail.*

### Practical Guides

4. **Schafer, J. L., & Graham, J. W. (2002).** Missing data: Our view of the state of the art. *Psychological Methods*, 7(2), 147–177.  
   *Accessible overview of missing data methods for applied researchers.*

5. **Graham, J. W. (2009).** Missing data analysis: Making it work in the real world. *Annual Review of Psychology*, 60, 549–576.  
   *Practical recommendations for handling missing data in research.*

6. **Tierney, N. J., & Cook, D. H. (2023).** Expanding tidy data principles to facilitate missing data exploration, visualization and assessment of imputations. *Journal of Statistical Software*, 105(7), 1–31.  
   *The R naniar package paper. Covers visualization approaches similar to MissingDataViz.jl.*

### Advanced Reading

7. **Little, R. J. A., & Rubin, D. B. (2019).** *Statistical Analysis with Missing Data* (3rd ed.). Wiley.  
   *The definitive textbook on missing data. Comprehensive but mathematically demanding.*

8. **Enders, C. K. (2010).** *Applied Missing Data Analysis*. Guilford Press.  
   *More accessible than Little & Rubin. Excellent for social science researchers.*

9. **Jamshidian, M., & Jalal, S. (2010).** Tests of homoscedasticity, normality, and missing completely at random for incomplete multivariate data. *Psychometrika*, 75(4), 649–674.  
   *Extensions and improvements to Little's test under non-normality.*

### Julia Ecosystem

10. **Bezanson, J., Edelman, A., Karpinski, S., & Shah, V. B. (2017).** Julia: A Fresh Approach to Numerical Computing. *SIAM Review*, 59(1), 65–98.  
    *The Julia language paper. Explains the performance advantages relevant to statistical computing.*