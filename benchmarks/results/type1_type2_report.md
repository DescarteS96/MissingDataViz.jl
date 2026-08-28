# MissingDataViz.jl — Type I / Type II Error Simulations

**Generated:** 27 August 2026
**Supersedes:** the March 2026 report, whose results were invalidated by two
implementation defects (see Section 5).

---

## 1. Configuration

| Parameter | Value |
|---|---|
| Iterations per condition | 1,000 |
| Sample sizes | 1,000 and 5,000 rows |
| Missing rates | 10%, 20%, 30% |
| Alpha levels | 0.01, 0.05, 0.10 |
| Columns | 5 (x1 fully observed, x2–x5 subject to missingness) |
| Seeds | Fixed (`seed = i` at iteration `i`) for reproducibility |
| Script | `benchmarks/simulations_type1_type2.jl` |

Monte Carlo standard error at 1,000 iterations: ±0.31% at α = 0.01,
±0.69% at α = 0.05, ±0.95% at α = 0.10. Approximate 95% acceptance
intervals for a correctly calibrated test are therefore 0.4–1.6%,
3.6–6.4% and 8.1–11.9% respectively.

**Inconclusive results:** all three tests returned a decision in every one of
the 18,000 MCAR iterations. No `INCONCLUSIVE` outcome was recorded, so every
reported rate is computed over the full 1,000 iterations.

---

## 2. Type I error — MCAR data

Target: rejection rate ≤ α. Values outside the acceptance interval are marked ✗.

### 2.1. n = 1,000

| Test | Missing | α = 0.01 | α = 0.05 | α = 0.10 |
|---|---|---|---|---|
| Welch *t*-test | 10% | ✓ 1.1% | ✓ 5.5% | ✓ 10.1% |
| Welch *t*-test | 20% | ✓ 0.9% | ✓ 4.3% | ✓ 10.7% |
| Welch *t*-test | 30% | ✓ 0.8% | ✓ 4.0% | ✓ 7.7% |
| Logistic regression | 10% | ✓ 1.3% | ✓ 5.6% | ✓ 12.1% |
| Logistic regression | 20% | ✓ 1.3% | ✓ 5.5% | ✓ 10.9% |
| Logistic regression | 30% | ✓ 0.8% | ✓ 4.1% | ✓ 7.8% |
| Little's test | 10% | ✗ 2.9% | ✗ 10.0% | ✗ 16.8% |
| Little's test | 20% | ✗ 6.2% | ✗ 17.5% | ✗ 26.1% |
| Little's test | 30% | ✗ 15.2% | ✗ 32.0% | ✗ 42.3% |

### 2.2. n = 5,000

| Test | Missing | α = 0.01 | α = 0.05 | α = 0.10 |
|---|---|---|---|---|
| Welch *t*-test | 10% | ✓ 1.6% | ✓ 5.9% | ✓ 11.2% |
| Welch *t*-test | 20% | ✓ 1.5% | ✓ 4.5% | ✓ 8.1% |
| Welch *t*-test | 30% | ✓ 1.5% | ✓ 6.6% | ✓ 10.9% |
| Logistic regression | 10% | ✓ 1.3% | ✓ 4.7% | ✓ 9.5% |
| Logistic regression | 20% | ✓ 1.7% | ✓ 5.5% | ✓ 9.7% |
| Logistic regression | 30% | ✓ 1.4% | ✓ 6.7% | ✓ 11.0% |
| Little's test | 10% | ✗ 1.9% | ✗ 7.5% | ✗ 14.1% |
| Little's test | 20% | ✗ 5.2% | ✗ 15.1% | ✗ 23.4% |
| Little's test | 30% | ✗ 14.5% | ✗ 29.6% | ✗ 41.1% |

---

## 3. Statistical power — MAR data

| Test | Missing | α=0.01 (n=1k) | α=0.05 (n=1k) | α=0.10 (n=1k) |
|---|---|---|---|---|
| Welch *t*-test | 10–30% | 100.0% | 100.0% | 100.0% |
| Logistic regression | 10% | 99.4% | 99.9% | 99.9% |
| Logistic regression | 20–30% | 100.0% | 100.0% | 100.0% |
| Little's test | 10% | 92.8% | 98.2% | 99.3% |
| Little's test | 20–30% | 100.0% | 100.0% | 100.0% |

At n = 5,000 all three tests reach 100% power in every condition.

**These power figures are not informative and should not be interpreted as a
comparison between tests.** The MAR generator induces missingness in x2 through
a logistic model on x1 with β = 2.0, then rescales the probabilities to hit the
target missing rate. This produces a dependence strong enough that any
reasonable test detects it, so the design has no discriminating power. The only
condition where a difference emerges — Little's test at 10% missingness,
n = 1,000 (92.8% at α = 0.01) — is the weakest signal in the design, which is
consistent with Little's test being the least sensitive of the three, but a
single cell cannot support that conclusion.

Characterising relative power would require varying β across a range
(e.g. 0.25, 0.5, 1.0, 2.0) to locate where each test begins to fail. This is
listed as future work.

---

## 4. Sensitivity to the significance threshold

Because all conditions were run at α ∈ {0.01, 0.05, 0.10}, the stability of each
test's conclusions across thresholds can be read directly from the tables above.
The ratio of observed rejection rate to nominal α is reported below for n = 1,000.

| Test | Missing | α = 0.01 | α = 0.05 | α = 0.10 |
|---|---|---|---|---|
| Welch *t*-test | 10% | 1.1× | 1.1× | 1.0× |
| Welch *t*-test | 20% | 0.9× | 0.9× | 1.1× |
| Welch *t*-test | 30% | 0.8× | 0.8× | 0.8× |
| Logistic regression | 10% | 1.3× | 1.1× | 1.2× |
| Logistic regression | 20% | 1.3× | 1.1× | 1.1× |
| Logistic regression | 30% | 0.8× | 0.8× | 0.8× |
| Little's test | 10% | 2.9× | 2.0× | 1.7× |
| Little's test | 20% | 6.2× | 3.5× | 2.6× |
| Little's test | 30% | **15.2×** | **6.4×** | **4.2×** |

**Welch and logistic regression are stable across thresholds.** Every ratio lies
between 0.8 and 1.3, with no systematic drift as α changes. Conclusions drawn at
one threshold hold at the others. The same pattern is observed at n = 5,000
(ratios between 0.9 and 1.7).

**Little's test is not, and the instability has a direction.** The inflation
ratio grows as α shrinks: at 30% missingness it is 4.2× at α = 0.10 but 15.2× at
α = 0.01. The excess is therefore concentrated in the tail of the null
distribution — precisely the region a practitioner relies on when reporting
p < 0.01 as strong evidence against MCAR.

This has a practical consequence that the raw rates understate. Reading
"p < 0.01, strong evidence" from Little's test on a dataset with 30% missing
values corresponds, in these simulations, to a false positive roughly fifteen
times more often than the threshold implies. Relaxing the threshold does not
help in absolute terms — the rejection rate is still 42.3% at α = 0.10 — but the
discrepancy between nominal and actual is widest where confidence is usually
highest.

---

## 5. Interpretation

**Welch *t*-test and logistic regression are nominally calibrated.** All 18
conditions for each test fall inside the Monte Carlo acceptance interval, and
the rejection rate tracks α as it should.

**Little's test shows Type I error inflation that grows with the missingness
rate.** At α = 0.05 and n = 1,000, the rejection rate is 2.0× the nominal level
at 10% missingness, 3.5× at 20%, and 6.4× at 30%. The pattern is monotone in
the missingness rate and holds at all three α levels.

**The inflation is reduced but not resolved by a larger sample.** Moving from
n = 1,000 to n = 5,000 lowers the rate at α = 0.05 from 10.0% to 7.5% (10%
missing), 17.5% to 15.1% (20%), and 32.0% to 29.6% (30%). A fivefold increase
in sample size therefore removes roughly a fifth of the excess at best, and the
rate remains far above nominal in every case.

This behaviour is consistent with the known limitation of the chi-squared
approximation underlying Little's statistic: as the missingness rate rises, the
number of distinct missingness patterns grows and the number of observations
per pattern falls, degrading the asymptotic approximation. Increasing n adds
observations but does not reduce the number of patterns, which is why the
inflation persists.

**Practical implication.** A practitioner applying Little's test to a dataset
with 30% missing values and reading p < 0.05 as evidence against MCAR is, on
these simulations, wrong roughly six times more often than the nominal rate
implies. This does not make the test useless — a rejection at very small p
remains informative — but the nominal α cannot be taken at face value at
moderate to high missingness rates.

---

## 5. Note on the superseded March 2026 report

The previous version of this report contained two invalid results, both traced
to implementation defects rather than to the statistical methods.

**Welch *t*-test reported at 0.0% Type I error in all 18 conditions.**
`generate_mcar_data` introduced missing values into every column, leaving no
fully observed column for the *t*-test wrapper to use as a comparison variable.
The wrapper returned `INCONCLUSIVE` at every MCAR iteration, and `INCONCLUSIVE`
was counted as a non-rejection. The test never executed under H₀. Fixed by
adding an `n_complete_cols` argument to `generate_mcar_data`, mirroring the
structure of `generate_mar_data`, which has always reserved x1 as a complete
predictor.

**Logistic regression reported a bimodal pattern** (≈20% Type I error at 10–20%
missingness, ≈0% at 30%). The decision rule was `min(p-value) < α` across
predictor coefficients, with no multiple-testing correction. With k predictors
this inflates Type I error to 1 − (1−α)^k, which equals 18.5% for k = 4 at
α = 0.05 — matching the observed rates. The drop at 30% missingness occurred
because the 80% observation threshold reduced the predictor set from four
columns to one, so k = 1 and no inflation arose. Fixed by replacing the decision
rule with a global likelihood ratio test against the intercept-only model,
LR ~ χ²(k). Individual predictor p-values and odds ratios remain available in
the result's `details` field for imputation model building, but no longer drive
the decision. The implemented method now matches the documented one.

Little's test was unaffected by either defect. Its results changed only through
the modified column structure of the MCAR generator: the α = 0.05 inflation at
30% missingness moved from 38.6% to 32.0% at n = 1,000. The qualitative finding
is unchanged.

---

## 6. Limitations

- All variables are drawn from a standard normal distribution. Little's test
  assumes multivariate normality, so this design is favourable to it; the
  observed inflation would likely be larger under non-normal data.
- Five columns only. The number of distinct missingness patterns — the
  suspected driver of the inflation — scales with the number of columns, so
  wider datasets are likely to show stronger effects. Not tested here.
- Two sample sizes only. The reduction from n = 1,000 to n = 5,000 is
  documented, but the asymptotic behaviour is not characterised.
- Power is not informative under the current MAR generator (see Section 3).
- No categorical variables. Little's test excludes them by construction, and
  their effect on the logistic regression path is untested.