#!/bin/bash
# benchmarks/cross_language/run_all.sh
# Run all three benchmarks sequentially and aggregate results.
# Usage: bash benchmarks/cross_language/run_all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

export PATH="/c/Program Files/R/R-4.4.3/bin:$PATH"

echo "========================================"
echo "CROSS-LANGUAGE BENCHMARK SUITE"
echo "========================================"
echo ""

# Step 1: Generate data
echo "[1/5] Generating datasets..."
python "$SCRIPT_DIR/generate_data.py"

# Step 2: Python benchmark
echo ""
echo "[2/5] Running Python benchmark (missingno)..."
python "$SCRIPT_DIR/benchmark_python.py"

# Step 3: R benchmark
echo ""
echo "[3/5] Running R benchmark (naniar)..."
Rscript "$SCRIPT_DIR/benchmark_r.R"

# Step 4: Julia benchmark
echo ""
echo "[4/5] Running Julia benchmark (MissingDataViz.jl)..."
julia --project="$REPO_DIR" "$SCRIPT_DIR/benchmark_julia.jl"

# Step 5: Aggregate
echo ""
echo "[5/5] Aggregating results..."
python "$SCRIPT_DIR/aggregate_results.py"

echo ""
echo "========================================"
echo "DONE — Results in benchmarks/cross_language/results/"
echo "========================================"