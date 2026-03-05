# MissingDataViz.jl — Performance Benchmark Report

Generated: 2026-03-04 11:10:40

## Configuration

| Parameter | Value |
|-----------|-------|
| Columns | 8 |
| Missing rate | 15% |
| Repeats per benchmark | 3 |
| Alpha | 0.05 |
| Sizes tested | 1000, 5000, 10000, 50000, 100000 |

## Summary: Median Time (seconds)

| Component | 1k | 5k | 10k | 50k | 100k |
|-----------|------|------|------|------|------|
| Little's test | 0.002 | 0.011 | 0.015 | 0.065 | 0.131 |
| Logistic (single) | 0.002 | 0.007 | 0.015 | 0.054 | 0.106 |
| t-test (single) | 0.000 | 0.000 | 0.000 | 0.000 | 0.001 |
| compare_mcar_tests | 0.018 | 0.068 | 0.124 | 0.541 | 0.908 |
| Visualizations | 0.258 | 0.271 | 0.247 | 0.183 | 0.165 |
| full_diagnosis | 1.785 | 1.895 | 1.486 | 1.911 | 2.212 |

## Scalability Analysis

Time per 10k rows (seconds):

| Component | 1k | 5k | 10k | 50k | 100k |
|-----------|------|------|------|------|------|
| Little's test | 0.018 | 0.022 | 0.015 | 0.013 | 0.013 |
| Logistic (single) | 0.020 | 0.013 | 0.015 | 0.011 | 0.011 |
| t-test (single) | 0.001 | 0.000 | 0.000 | 0.000 | 0.000 |
| compare_mcar_tests | 0.180 | 0.136 | 0.124 | 0.108 | 0.091 |
| Visualizations | 2.578 | 0.541 | 0.247 | 0.037 | 0.016 |
| full_diagnosis | 17.853 | 3.791 | 1.486 | 0.382 | 0.221 |

## Performance Targets

| Target | Threshold | Status |
|--------|-----------|--------|
| compare_mcar_tests @ 10k | < 5s | ✓ PASS (0.12s) |
| Visualizations @ 10k | < 2s | ✓ PASS (0.25s) |
| full_diagnosis @ 10k | < 10s | ✓ PASS (1.49s) |

## Detailed Results

### 1k rows

| Component | Median | Min | Max | Status |
|-----------|--------|-----|-----|--------|
| Little's test | 0.002s | 0.002s | 0.002s | ✓ |
| Logistic (single) | 0.002s | 0.002s | 0.009s | ✓ |
| t-test (single) | 0.000s | 0.000s | 0.000s | ✓ |
| compare_mcar_tests | 0.018s | 0.018s | 0.021s | ✓ |
| Visualizations | 0.258s | 0.153s | 0.324s | ✓ |
| full_diagnosis | 1.785s | 1.588s | 2.106s | ✓ |

### 5k rows

| Component | Median | Min | Max | Status |
|-----------|--------|-----|-----|--------|
| Little's test | 0.011s | 0.009s | 0.011s | ✓ |
| Logistic (single) | 0.007s | 0.007s | 0.009s | ✓ |
| t-test (single) | 0.000s | 0.000s | 0.000s | ✓ |
| compare_mcar_tests | 0.068s | 0.063s | 0.120s | ✓ |
| Visualizations | 0.271s | 0.231s | 0.313s | ✓ |
| full_diagnosis | 1.895s | 1.769s | 1.941s | ✓ |

### 10k rows

| Component | Median | Min | Max | Status |
|-----------|--------|-----|-----|--------|
| Little's test | 0.015s | 0.014s | 0.019s | ✓ |
| Logistic (single) | 0.015s | 0.014s | 0.016s | ✓ |
| t-test (single) | 0.000s | 0.000s | 0.000s | ✓ |
| compare_mcar_tests | 0.124s | 0.115s | 2.223s | ✓ |
| Visualizations | 0.247s | 0.189s | 4.746s | ✓ |
| full_diagnosis | 1.486s | 1.361s | 1.546s | ✓ |

### 50k rows

| Component | Median | Min | Max | Status |
|-----------|--------|-----|-----|--------|
| Little's test | 0.065s | 0.065s | 0.068s | ✓ |
| Logistic (single) | 0.054s | 0.050s | 0.057s | ✓ |
| t-test (single) | 0.000s | 0.000s | 0.000s | ✓ |
| compare_mcar_tests | 0.541s | 0.516s | 0.600s | ✓ |
| Visualizations | 0.183s | 0.157s | 0.216s | ✓ |
| full_diagnosis | 1.911s | 1.770s | 2.060s | ✓ |

### 100k rows

| Component | Median | Min | Max | Status |
|-----------|--------|-----|-----|--------|
| Little's test | 0.131s | 0.129s | 0.135s | ✓ |
| Logistic (single) | 0.106s | 0.103s | 0.106s | ✓ |
| t-test (single) | 0.001s | 0.001s | 0.001s | ✓ |
| compare_mcar_tests | 0.908s | 0.908s | 0.933s | ✓ |
| Visualizations | 0.165s | 0.165s | 0.172s | ✓ |
| full_diagnosis | 2.212s | 2.196s | 2.278s | ✓ |

