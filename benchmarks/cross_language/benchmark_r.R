# benchmarks/cross_language/benchmark_r.R
# Performance benchmark for naniar (R).
#
# Measures on each dataset:
#   - Load + basic statistics (missing %)
#   - Visualization: vis_miss (matrix equivalent)
#   - Visualization: gg_miss_var (bar chart equivalent)
#   - Visualization: miss_var_summary (correlation-equivalent stats)
#
# All plots rendered headless (no display).
# Each operation repeated 5 times — median reported.

library(naniar)
library(dplyr)
library(ggplot2)
library(jsonlite)

# Headless rendering
options(device = "png")

# ── Configuration ──────────────────────────────────────────────
N_RUNS <- 10

# Robust path detection for Rscript
args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("--file=", args)]
if (length(file_arg) > 0) {
    SCRIPT_DIR <- normalizePath(dirname(sub("--file=", "", file_arg[1])))
} else {
    SCRIPT_DIR <- normalizePath("benchmarks/cross_language")
}

DATA_DIR <- file.path(SCRIPT_DIR, "data")
OUT_DIR  <- file.path(SCRIPT_DIR, "results")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ── Benchmark helper ───────────────────────────────────────────

measure <- function(fn, n_runs = N_RUNS) {
  # Returns list(median_time_s, peak_mem_mb)
  times <- numeric(n_runs)
  mems  <- numeric(n_runs)

  for (i in seq_len(n_runs)) {
    gc()
    mem_before <- sum(gc()[, 2])  # MB used before
    t0 <- proc.time()["elapsed"]

    fn()

    times[i] <- proc.time()["elapsed"] - t0
    mem_after <- sum(gc()[, 2])
    mems[i]   <- max(0, mem_after - mem_before)
  }

  list(
    time_s = round(median(times), 4),
    mem_mb = round(max(mems), 2)
  )
}

bench_dataset <- function(path, name) {
  cat(sprintf("\n  Dataset: %s\n", name))
  cat(sprintf("  %s\n", strrep("-", 50)))

  # Load
  t0 <- proc.time()["elapsed"]
  df <- read.csv(path, stringsAsFactors = FALSE,
                 na.strings = c("", "NA", "N/A", "?", "nan"))
  load_time <- round(proc.time()["elapsed"] - t0, 4)

  n_rows    <- nrow(df)
  n_cols    <- ncol(df)
  miss_pct  <- round(mean(is.na(df)) * 100, 1)

  cat(sprintf("  Rows: %7d | Cols: %d | Missing: %.1f%%\n",
              n_rows, n_cols, miss_pct))

  result <- list(
    dataset     = name,
    n_rows      = n_rows,
    n_cols      = n_cols,
    missing_pct = miss_pct,
    load_time_s = load_time,
    tool        = "naniar (R)",
    crashed     = FALSE
  )

  # ── Stats ──────────────────────────────────────────────────
  m <- measure(function() miss_var_summary(df))
  result$stats_time_s <- m$time_s
  result$stats_mem_mb <- m$mem_mb
  cat(sprintf("  Stats:       %.4fs | %.1f MB\n", m$time_s, m$mem_mb))

  # ── vis_miss (matrix) ──────────────────────────────────────
  # Cap at 10k rows for vis_miss (known crash above)
  df_vis <- if (n_rows > 10000) df[sample(n_rows, 10000), ] else df
  m <- measure(function() {
    p <- vis_miss(df_vis)
    invisible(p)
  })
  result$matrix_time_s  <- m$time_s
  result$matrix_mem_mb  <- m$mem_mb
  result$matrix_sampled <- n_rows > 10000
  cat(sprintf("  Matrix:      %.4fs | %.1f MB%s\n",
              m$time_s, m$mem_mb,
              if (n_rows > 10000) " [sampled 10k]" else ""))

  # ── gg_miss_var (bar chart) ────────────────────────────────
  m <- measure(function() {
    p <- gg_miss_var(df)
    invisible(p)
  })
  result$bar_time_s <- m$time_s
  result$bar_mem_mb <- m$mem_mb
  cat(sprintf("  Bar:         %.4fs | %.1f MB\n", m$time_s, m$mem_mb))

  # ── miss_var_summary as heatmap equivalent ─────────────────
  m <- measure(function() {
    s <- miss_var_summary(df)
    invisible(s)
  })
  result$heatmap_time_s <- m$time_s
  result$heatmap_mem_mb <- m$mem_mb
  cat(sprintf("  Correlation: %.4fs | %.1f MB\n", m$time_s, m$mem_mb))

  result
}

# ── Main ───────────────────────────────────────────────────────

cat(strrep("=", 60), "\n")
cat("BENCHMARK: naniar (R)\n")
cat(sprintf("Generated: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Runs per operation: %d\n", N_RUNS))
cat(strrep("=", 60), "\n")

csv_files <- sort(list.files(DATA_DIR, pattern = "\\.csv$",
                             full.names = FALSE))

if (length(csv_files) == 0) {
  cat(sprintf("ERROR: No CSV files in %s\n", DATA_DIR))
  cat("Run generate_data.py first.\n")
  quit(status = 1)
}

all_results <- list()

for (filename in csv_files) {
  path <- file.path(DATA_DIR, filename)
  name <- sub("\\.csv$", "", filename)

  result <- tryCatch({
    bench_dataset(path, name)
  }, error = function(e) {
    cat(sprintf("  CRASH: %s\n", conditionMessage(e)))
    list(dataset = name, crashed = TRUE,
         error = conditionMessage(e), tool = "naniar (R)")
  })

  all_results[[length(all_results) + 1]] <- result
}

# Save JSON
out_path <- file.path(OUT_DIR, "results_r.json")
write_json(all_results, out_path, pretty = TRUE, auto_unbox = TRUE)
cat(sprintf("\n✓ Results saved: %s\n", out_path))

# Console summary
cat("\n", strrep("=", 60), "\n")
cat("SUMMARY (median times, seconds)\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  %-25s %7s %8s %8s %8s %8s\n",
            "Dataset", "Rows", "Stats", "Matrix", "Bar", "Corr"))
cat(sprintf("  %s\n", strrep("-", 68)))

for (r in all_results) {
  if (isTRUE(r$crashed)) {
    cat(sprintf("  %-25s CRASHED: %s\n", r$dataset,
                r$error %||% "unknown"))
  } else {
    cat(sprintf("  %-25s %7d %8.4f %8.4f %8.4f %8.4f\n",
                r$dataset, r$n_rows,
                r$stats_time_s, r$matrix_time_s,
                r$bar_time_s, r$heatmap_time_s))
  }
}