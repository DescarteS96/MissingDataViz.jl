# benchmarks/cross_language/aggregate_results.py
# Aggregate JSON results from Julia, Python, and R benchmarks.
# Produces:
#   - cross_language_report.md
#   - cross_language_report.docx (via pandoc)

import json
import os
import subprocess
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR = os.path.join(SCRIPT_DIR, "results")

TOOLS = [
    ("results_julia.json",  "MissingDataViz.jl (Julia)"),
    ("results_python.json", "missingno (Python)"),
    ("results_r.json",      "naniar (R)"),
]

OPS = [
    ("stats_time_s",   "Stats"),
    ("matrix_time_s",  "Matrix"),
    ("bar_time_s",     "Bar"),
    ("heatmap_time_s", "Heatmap"),
]

def load_results(filename):
    path = os.path.join(RESULTS_DIR, filename)
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        data = json.load(f)
    return {r["dataset"]: r for r in data if isinstance(r, dict)}

def speedup(base, target):
    """Return how many times faster target is vs base."""
    if base and target and base > 0 and target > 0:
        return round(base / target, 1)
    return None

def main():
    print("Aggregating benchmark results...")

    results = {}
    for filename, label in TOOLS:
        results[label] = load_results(filename)

    julia_label  = "MissingDataViz.jl (Julia)"
    python_label = "missingno (Python)"
    r_label      = "naniar (R)"

    # Get all datasets
    all_datasets = set()
    for data in results.values():
        all_datasets.update(data.keys())
    all_datasets = sorted(all_datasets)

    lines = []
    lines.append("# Cross-Language Performance Benchmark")
    lines.append("")
    lines.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    lines.append("## Methodology")
    lines.append("")
    lines.append("- All tools tested on identical CSV datasets")
    lines.append("- Headless rendering (no display) for fair comparison")
    lines.append("- 10 runs per operation — median time reported")
    lines.append("- Julia: JIT warmup run excluded from measurements")
    lines.append("- Memory: peak allocation per operation")
    lines.append("- naniar (R): vis_miss capped at 10,000 rows — "
                 "larger datasets sampled. Times marked [s] are "
                 "not directly comparable to Julia/Python full-data times.")
    lines.append("")

    # ── Table per operation ────────────────────────────────────
    for op_key, op_label in OPS:
        lines.append(f"## {op_label} — Execution Time (seconds)")
        lines.append("")
        lines.append(f"| Dataset | Rows | Julia | Python | R | "
                     f"Julia vs Python | Julia vs R |")
        lines.append(f"|---------|------|-------|--------|---|"
                     f"----------------|------------|")

        for ds in all_datasets:
            j = results.get(julia_label,  {}).get(ds, {})
            p = results.get(python_label, {}).get(ds, {})
            r = results.get(r_label,      {}).get(ds, {})

            j_crashed = j.get("crashed", False)
            p_crashed = p.get("crashed", False)
            r_crashed = r.get("crashed", False)

            j_t = j.get(op_key) if not j_crashed else None
            p_t = p.get(op_key) if not p_crashed else None
            r_t = r.get(op_key) if not r_crashed else None

            n_rows = (j or p or r).get("n_rows", "?")

            j_str = f"{j_t:.4f}" if j_t is not None else "CRASH"
            p_str = f"{p_t:.4f}" if p_t is not None else "CRASH"

            # R string with sampled marker for matrix operation
            r_str = f"{r_t:.4f}" if r_t is not None else "CRASH"
            if op_key == "matrix_time_s":
                r_data = results.get(r_label, {}).get(ds, {})
                if r_data.get("matrix_sampled"):
                    r_str += " [s]"

            sp_py = speedup(p_t, j_t)
            # For R matrix comparisons, skip speedup if sampled
            r_data = results.get(r_label, {}).get(ds, {})
            if op_key == "matrix_time_s" and r_data.get("matrix_sampled"):
                sp_r = None
            else:
                sp_r = speedup(r_t, j_t)

            sp_py_str = f"{sp_py}x faster" if sp_py else "—"
            sp_r_str  = f"{sp_r}x faster"  if sp_r  else "—"

            lines.append(
                f"| {ds} | {n_rows} | {j_str} | {p_str} | {r_str} | "
                f"{sp_py_str} | {sp_r_str} |"
            )

        lines.append("")

    # ── Memory table ───────────────────────────────────────────
    lines.append("## Peak Memory Usage (MB) — Matrix Operation")
    lines.append("")
    lines.append("| Dataset | Rows | Julia | Python | R |")
    lines.append("|---------|------|-------|--------|---|")

    for ds in all_datasets:
        j = results.get(julia_label,  {}).get(ds, {})
        p = results.get(python_label, {}).get(ds, {})
        r = results.get(r_label,      {}).get(ds, {})

        j_m = j.get("matrix_mem_mb") if not j.get("crashed") else None
        p_m = p.get("matrix_mem_mb") if not p.get("crashed") else None
        r_m = r.get("matrix_mem_mb") if not r.get("crashed") else None

        n_rows = (j or p or r).get("n_rows", "?")

        j_str = f"{j_m:.1f}" if j_m is not None else "CRASH"
        p_str = f"{p_m:.1f}" if p_m is not None else "CRASH"

        # Add sampled marker for R memory too
        r_data = results.get(r_label, {}).get(ds, {})
        r_str = f"{r_m:.1f}" if r_m is not None else "CRASH"
        if r_data.get("matrix_sampled"):
            r_str += " [s]"

        lines.append(f"| {ds} | {n_rows} | {j_str} | {p_str} | {r_str} |")

    lines.append("")
    lines.append("*[s] = naniar sampled to 10,000 rows. Not comparable to full-data measurements.*")
    lines.append("")

    # ── Feature comparison table ───────────────────────────────
    lines.append("## Feature Comparison")
    lines.append("")
    lines.append("| Feature | MissingDataViz.jl | missingno | naniar |")
    lines.append("|---------|-------------------|-----------|--------|")
    features = [
        ("Visualization",          "✓", "✓", "✓"),
        ("Little's MCAR test",     "✓", "✗", "✓"),
        ("Pairwise t-tests",       "✓", "✗", "✗"),
        ("Logistic regression",    "✓", "✗", "✗"),
        ("Multi-test consensus",   "✓", "✗", "✗"),
        ("Auto recommendation",    "✓", "✗", "✗"),
        ("Unified pipeline",       "✓", "✗", "✗"),
        ("100k+ rows (full data)", "✓", "⚠ Slow", "✗ Requires sampling"),
        ("Language",               "Julia", "Python", "R"),
    ]
    for feat, j, p, r in features:
        lines.append(f"| {feat} | {j} | {p} | {r} |")

    lines.append("")
    lines.append("## Interpretation")
    lines.append("")
    lines.append("MissingDataViz.jl provides the only unified pipeline combining")
    lines.append("visualization, statistical MCAR testing, and automated")
    lines.append("recommendation in a single package. Performance advantages")
    lines.append("are most significant at large dataset sizes (10k+ rows),")
    lines.append("where Julia's JIT compilation delivers consistent speedups")
    lines.append("over interpreted Python and R.")
    lines.append("")
    lines.append("**Note on bar chart performance:** naniar's `gg_miss_var` is faster")
    lines.append("than MissingDataViz.jl for simple bar charts on small datasets.")
    lines.append("Julia's advantage is most significant for matrix visualization")
    lines.append("and statistical operations at scale (>10k rows).")

    # ── Save markdown ──────────────────────────────────────────
    md_content = "\n".join(lines)
    md_path = os.path.join(RESULTS_DIR, "cross_language_report.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_content)
    print(f"✓ Markdown: {md_path}")

    # ── Generate Word via pandoc ───────────────────────────────
    docx_path = os.path.join(RESULTS_DIR, "cross_language_report.docx")
    try:
        subprocess.run(
            ["pandoc", md_path, "-o", docx_path],
            check=True, capture_output=True
        )
        print(f"✓ Word:     {docx_path}")
    except Exception as e:
        print(f"✗ Word generation failed: {e}")
        print(f"  Convert manually: pandoc {md_path} -o {docx_path}")

main()