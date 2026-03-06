# benchmarks/cross_language/generate_data.py
# Generate benchmark datasets for cross-language comparison.
#
# Two types:
#   1. Synthetic: controlled MCAR/MAR datasets (3 sizes)
#   2. Real: the 5 public datasets already in data/
#
# All datasets exported as CSV in benchmarks/cross_language/data/
# Same files used by Julia, Python, and R for fair comparison.

import numpy as np
import pandas as pd
import os
import shutil

# ── Configuration ─────────────────────────────────────────────
SIZES     = [1_000, 10_000, 100_000]
N_COLS    = 10
MISS_RATE = 0.20
SEED      = 42

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
OUT_DIR      = os.path.join(SCRIPT_DIR, "data")
REAL_DATA_DIR = os.path.join(SCRIPT_DIR, "..", "..", "data")

REAL_DATASETS = {
    "adult":           "adult.csv",
    "diabetic":        "diabetic_data.csv",
    "melbourne":       "melbourne_housing.csv",
    "nyc_airbnb":      "nyc_airbnb.csv",
    "online_retail":   "online_retail.csv",
}

os.makedirs(OUT_DIR, exist_ok=True)

# ── 1. Synthetic datasets ──────────────────────────────────────
print("=" * 60)
print("SYNTHETIC DATASETS")
print("=" * 60)

rng = np.random.default_rng(SEED)

for n in SIZES:
    df = pd.DataFrame(
        rng.standard_normal((n, N_COLS)),
        columns=[f"x{i}" for i in range(1, N_COLS + 1)]
    )

    # Introduce MAR-like missingness: x2-x10 depend on x1
    for col in df.columns[1:]:
        mask = (df["x1"] > df["x1"].quantile(1 - MISS_RATE)) & \
               (rng.random(n) < 0.6)
        df.loc[mask, col] = np.nan

    path = os.path.join(OUT_DIR, f"synthetic_{n}.csv")
    df.to_csv(path, index=False)

    actual_miss = df.isna().mean().mean() * 100
    size_mb     = os.path.getsize(path) / 1024 / 1024
    print(f"  ✓ synthetic_{n}.csv | {n:>7} rows | "
          f"{actual_miss:.1f}% missing | {size_mb:.1f} MB")

# ── 2. Real datasets ───────────────────────────────────────────
print()
print("=" * 60)
print("REAL DATASETS")
print("=" * 60)

for name, filename in REAL_DATASETS.items():
    src = os.path.join(REAL_DATA_DIR, filename)

    if not os.path.exists(src):
        print(f"  ✗ {filename} not found — skipping")
        continue

    try:
        # Special handling for online_retail (tab-separated, European decimals)
        if name == "online_retail":
            df = pd.read_csv(src, low_memory=False, sep="\t",
                             encoding="latin-1", on_bad_lines="skip")
            if "Price" in df.columns:
                df["Price"] = (df["Price"].astype(str)
                               .str.replace(",", ".", regex=False))
                df["Price"] = pd.to_numeric(df["Price"], errors="coerce")
        else:
            df = pd.read_csv(src, low_memory=False, on_bad_lines="skip")

        # Replace common missing value markers
        df.replace(["?", "NA", "N/A", "nan", "NaN", "", " "], np.nan, inplace=True)

        n_rows      = len(df)
        n_cols      = len(df.columns)
        actual_miss = df.isna().mean().mean() * 100
        n_numeric   = df.select_dtypes(include=[np.number]).shape[1]

        dst = os.path.join(OUT_DIR, f"real_{name}.csv")
        df.to_csv(dst, index=False)

        size_mb = os.path.getsize(dst) / 1024 / 1024
        print(f"  ✓ real_{name}.csv | {n_rows:>7} rows | "
              f"{n_cols:>3} cols ({n_numeric} numeric) | "
              f"{actual_miss:.1f}% missing | {size_mb:.1f} MB")

    except Exception as e:
        print(f"  ✗ {filename} failed: {e}")

# ── Summary ────────────────────────────────────────────────────
print()
print("=" * 60)
print("SUMMARY")
print("=" * 60)

all_files = sorted(os.listdir(OUT_DIR))
total_size = sum(
    os.path.getsize(os.path.join(OUT_DIR, f))
    for f in all_files if f.endswith(".csv")
) / 1024 / 1024

print(f"  Datasets generated : {len(all_files)}")
print(f"  Total size         : {total_size:.1f} MB")
print(f"  Output directory   : {OUT_DIR}")
print()
print("Ready for cross-language benchmarks.")