# Sections à remplacer dans `examples/validation/results/validation_report.md`

Les chiffres proviennent de l'exécution du 27 août 2026, après les correctifs
apportés à `test_mcar_logistic` (commits a08fa9c, 1430403, ccc27e6).

Seule la colonne logistique change. Little et Welch ne sont pas affectés par
ces correctifs — leurs résultats restent ceux du rapport précédent.

---

## Remplacer le tableau « MCAR Test Results »

| Dataset | Little's p | Little | Logistic rejected | Logistic inconclusive | t-test violations | Verdict |
|---|---|---|---|---|---|---|
| Adult / Census Income | NaN | INCONCLUSIVE | 0 | 3 | 2 | MCAR VIOLATED |
| Diabetes 130-US Hospitals | NaN | INCONCLUSIVE | 2 | 5 | 6 | MCAR VIOLATED |
| Online Retail II | 0.0 | REJECTED | 0 | 1 | 1 | MCAR VIOLATED |
| NYC Airbnb | 0.0 | REJECTED | 2 | 2 | 4 | MCAR VIOLATED |
| Melbourne Housing | 0.0 | REJECTED | 3 | 1 | 3 | MCAR VIOLATED |

Across the five datasets, the logistic path returns a decision for 8 of the 20
columns containing missing values: 7 rejections and 1 non-rejection. The
remaining 12 are reported as inconclusive, with the reason recorded in each
result's `details["reason"]` field and in its warnings.

All five datasets are found to violate MCAR. The verdict rests on the pairwise
Welch *t*-tests in every case, and is corroborated by Little's test on three of
the five.

---

## Remplacer la note « Logistic INCONCLUSIVE »

**Note on inconclusive logistic results.** The logistic regression test declines
to return a decision when the fitted model cannot support one. Four distinct
conditions trigger this, all of which occur in the validation datasets:

**Missingness overlapping a predictor.** In the Adult dataset, `workclass` is
missing on exactly the same 1,836 rows as `occupation`. Complete-case filtering
on `occupation` therefore removes every row in which `workclass` is missing,
leaving no events to model. Both columns are reported as inconclusive, and the
warning names the overlapping predictor. Passing `exclude_cols=[:occupation]`
allows the test to proceed.

**Insufficient events per variable.** Following the conventional threshold of 10
events per estimated coefficient (Peduzzi et al., 1996), models below this ratio
return `INCONCLUSIVE` rather than an unreliable p-value. In NYC Airbnb, `name`
has 16 missing values against 15 estimated coefficients (EPV = 1.1); the
underlying p-value of 3.9 × 10⁻⁵ would otherwise have been reported as a
rejection. The threshold is configurable through `min_epv`.

**Non-convergence.** Five columns in the Diabetes dataset produce a model
deviance exceeding the null deviance, which is only possible when the fit has
not converged. Both deviances are reported in the warning.

**Complete separation.** In Online Retail II, `Customer_ID` missingness is
perfectly predicted by a single covariate, driving the deviance to infinity.

High-cardinality categorical predictors are excluded before fitting, with a
warning. The default threshold is 20 levels, configurable through `max_levels`.
Without it, the ICD-9 diagnosis columns in the Diabetes dataset (roughly 700
levels each) inflated the degrees of freedom to 2,321 for 3,197 events, and the
`name` column in NYC Airbnb (47,905 levels for 48,895 rows) exhausted memory
during model construction.

Where the logistic path is inconclusive, the Welch *t*-test and Little's test
remain available and were sufficient to establish the verdict on all five
datasets.

---

## Ajouter, en fin de rapport

## Reproducibility

The five datasets are not redistributed with the package. Three are available
from the UCI Machine Learning Repository (Adult, Diabetes 130-US Hospitals,
Online Retail II) and two from Kaggle (NYC Airbnb Open Data, Melbourne Housing
Snapshot). The latter two require authentication, so a fully automated download
script is not currently provided.

SHA-256 checksums of the files used for this report:

```
70acda78373ddd1c2615a7ae2afbc10c91e85edbdc7706a42c6b3818e2820e1e  adult.csv
0689e7ec031237dc63031b938805c48377748761a3b26acab621567afa24df97  diabetic_data.csv
3e449c3e95088da8a3a6b10331a5703f2c951d0740f317f97ed9baf0db1fd9f8  melbourne_housing.csv
e420db40ff10fcb40efc1b5b1648ee0b18a48f4e4537155cecc59fe95d18783a  nyc_airbnb.csv
e37a7952fcab727a345d7f7a9e7723c099779fbe835580ede0788a679a71057a  online_retail.csv
```

Online Retail II was truncated to its first 100,000 rows for this validation;
the full 541,910-row file was used for the cross-language performance
benchmarks.