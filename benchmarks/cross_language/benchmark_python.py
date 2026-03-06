# benchmarks/cross_language/benchmark_python.py
# Performance benchmark for missingno (Python).
#
# Measures on each dataset:
#   - Load + basic statistics (missing %)
#   - Matrix visualization (heatmap)
#   - Bar chart visualization
#   - Heatmap (correlation-equivalent)
#
# All plots rendered in headless mode (Agg backend) for fair comparison.
# Each operation repeated 5 times — median reported.

import os
import time
import tracemalloc
import statistics
import json
from datetime import datetime

import matplotlib
matplotlib.use("Agg")  # Headless backend — no display required
import matplotlib.pyplot as plt
import pandas as pd
import missingno as msno

# ── Configuration ──────────────────────────────────────────────
N_RUNS     = 10
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR   = os.path.join(SCRIPT_DIR, "data")
OUT_DIR    = os.path.join(SCRIPT_DIR, "results")

os.makedirs(OUT_DIR, exist_ok=True)

# ── Benchmark helpers ──────────────────────────────────────────

def measure(fn, n_runs=N_RUNS):
    """Run fn n_runs times. Return median time (s) and peak memory (MB)."""
    times   = []
    mem_mb  = []

    for _ in range(n_runs):
        tracemalloc.start()
        t0 = time.perf_counter()

        fn()

        elapsed = time.perf_counter() - t0
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        plt.close("all")

        times.append(elapsed)
        mem_mb.append(peak / 1024 / 1024)

    return round(statistics.median(times), 4), round(max(mem_mb), 2)

def bench_dataset(path, name):
    """Run all benchmarks on a single dataset."""
    print(f"\n  Dataset: {name}")
    print(f"  {'─' * 50}")

    # Load data
    t0 = time.perf_counter()
    df = pd.read_csv(path)
    load_time = round(time.perf_counter() - t0, 4)
    n_rows, n_cols = df.shape
    miss_pct = round(df.isna().mean().mean() * 100, 1)

    print(f"  Rows: {n_rows:>7} | Cols: {n_cols} | Missing: {miss_pct}%")

    results = {
        "dataset":      name,
        "n_rows":       n_rows,
        "n_cols":       n_cols,
        "missing_pct":  miss_pct,
        "load_time_s":  load_time,
        "tool":         "missingno (Python)",
    }

    # ── Stats (missing percentage per column) ─────────────────
    def op_stats():
        _ = df.isna().mean() * 100

    t, m = measure(op_stats)
    results["stats_time_s"]  = t
    results["stats_mem_mb"]  = m
    print(f"  Stats:       {t:.4f}s | {m:.1f} MB")

    # ── Matrix visualization ───────────────────────────────────
    def op_matrix():
        msno.matrix(df)

    t, m = measure(op_matrix)
    results["matrix_time_s"] = t
    results["matrix_mem_mb"] = m
    print(f"  Matrix:      {t:.4f}s | {m:.1f} MB")

    # ── Bar chart ──────────────────────────────────────────────
    def op_bar():
        msno.bar(df)

    t, m = measure(op_bar)
    results["bar_time_s"]    = t
    results["bar_mem_mb"]    = m
    print(f"  Bar:         {t:.4f}s | {m:.1f} MB")

    # ── Heatmap ────────────────────────────────────────────────
    def op_heatmap():
        msno.heatmap(df)

    t, m = measure(op_heatmap)
    results["heatmap_time_s"] = t
    results["heatmap_mem_mb"] = m
    print(f"  Heatmap:     {t:.4f}s | {m:.1f} MB")

    # ── Crash detection ────────────────────────────────────────
    results["crashed"] = False

    return results

# ── Main ───────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("BENCHMARK: missingno (Python)")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Runs per operation: {N_RUNS}")
    print("=" * 60)

    datasets = sorted([
        f for f in os.listdir(DATA_DIR) if f.endswith(".csv")
    ])

    if not datasets:
        print(f"ERROR: No CSV files found in {DATA_DIR}")
        print("Run generate_data.py first.")
        return

    all_results = []

    for filename in datasets:
        path = os.path.join(DATA_DIR, filename)
        name = filename.replace(".csv", "")

        try:
            result = bench_dataset(path, name)
            all_results.append(result)
        except MemoryError:
            print(f"  ✗ CRASH: MemoryError on {name}")
            all_results.append({
                "dataset": name, "crashed": True,
                "error": "MemoryError", "tool": "missingno (Python)"
            })
        except Exception as e:
            print(f"  ✗ CRASH: {type(e).__name__}: {e}")
            all_results.append({
                "dataset": name, "crashed": True,
                "error": str(e), "tool": "missingno (Python)"
            })

    # Save JSON results
    out_path = os.path.join(OUT_DIR, "results_python.json")
    with open(out_path, "w") as f:
        json.dump(all_results, f, indent=2)

    print(f"\n✓ Results saved: {out_path}")

    # Console summary
    print("\n" + "=" * 60)
    print("SUMMARY (median times, seconds)")
    print("=" * 60)
    print(f"  {'Dataset':<25} {'Rows':>7} {'Stats':>8} {'Matrix':>8} "
          f"{'Bar':>8} {'Heatmap':>8}")
    print(f"  {'─' * 68}")

    for r in all_results:
        if r.get("crashed"):
            print(f"  {r['dataset']:<25} CRASHED: {r.get('error', '?')}")
        else:
            print(f"  {r['dataset']:<25} {r['n_rows']:>7} "
                  f"{r.get('stats_time_s', 0):>8.4f} "
                  f"{r.get('matrix_time_s', 0):>8.4f} "
                  f"{r.get('bar_time_s', 0):>8.4f} "
                  f"{r.get('heatmap_time_s', 0):>8.4f}")

main()