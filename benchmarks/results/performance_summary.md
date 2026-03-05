println("Observed age: ", count(!ismissing, df_mar_realistic.age))# MissingDataViz.jl - Performance Benchmark Report

**Date:** 2026-02-02T00:46:05.341
**Julia Version:** 1.12.0
**Threads:** 1

---

## Executive Summary

### Key Objectives
- ✅ 10k rows: < 2 seconds
- ✅ 100k rows: < 10 seconds
- ✅ Memory: < 500MB for large datasets

### Results Overview

**Pattern Detection (10k rows):**
- missing_pattern: 127.350 μs
- pattern_counts: 1.801 ms
- summarize_missing: 3.361 ms

**Visualization (10k rows):**
- plot_missing_matrix: 98.975 ms
- plot_missing_overview: 201.934 ms

**Complete Workflow (10k rows):**
- Interactive mode: 493.873 ms
- With HTML report: 1.543 s

**Stress Test (100k rows, pattern detection only):**
- Time: 154.083 ms
- Memory: 86.14 MiB

---

## Detailed Results

### Pattern Detection Functions

| Function | 100 rows | 1k rows | 10k rows | 100k rows |
|----------|----------|---------|----------|-----------|
| missing_pattern | 11.100 μs | 22.250 μs | 127.350 μs | 1.367 ms |
| pattern_counts | 26.500 μs | 186.700 μs | 1.801 ms | 18.595 ms |

---

## Recommendations

1. **Optimal Dataset Size:** < 10,000 rows for interactive use
2. **Batch Processing:** Use `report=true` for datasets > 5,000 rows
3. **Memory Considerations:** Monitor memory for datasets > 50,000 rows

---

## Next Steps

- [ ] Review profile results for optimization opportunities
- [ ] Consider implementing parallel processing for large datasets
- [ ] Add caching for repeated pattern detection

