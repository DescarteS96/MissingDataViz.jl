# HTML template generation for missing data reports

"""
    _generate_html_template(title::String, summary_html::String,
                            plots_html::String, mcar_html::String,
                            timestamp::String)::String

Generate complete HTML document for missing data report.

This is an internal function that assembles the final HTML from components.

# Arguments
- `title::String`: Report title
- `summary_html::String`: HTML for summary statistics table
- `plots_html::String`: HTML for visualizations section
- `mcar_html::String`: HTML for MCAR diagnostic section (empty string if not run)
- `timestamp::String`: Generation timestamp

# Returns
- `String`: Complete HTML document (ready to write to file)

# Template Structure
- DOCTYPE HTML5
- Inline CSS (no external dependencies)
- Responsive meta tags
- Sections: Header, Summary, Visualizations, MCAR Diagnostic (optional), Footer
- Fixed width: 1200px (desktop-optimized)

# Note
- If `mcar_html` is an empty string, the MCAR section is simply not rendered
- MCAR section is injected between Visualizations and Footer
"""
function _generate_html_template(title::String, summary_html::String,
                                 plots_html::String, mcar_html::String,
                                 timestamp::String)::String
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }

        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }

        header h1 {
            font-size: 2.5em;
            font-weight: 700;
            margin-bottom: 10px;
        }

        header p {
            font-size: 1.1em;
            opacity: 0.9;
        }

        .content {
            padding: 40px;
        }

        section {
            margin-bottom: 50px;
        }

        h2 {
            font-size: 1.8em;
            color: #667eea;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }

        h3 {
            font-size: 1.2em;
            color: #555;
            margin: 20px 0 10px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 0.95em;
        }

        thead {
            background-color: #667eea;
            color: white;
        }

        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }

        tbody tr:hover {
            background-color: #f5f5f5;
        }

        tbody tr:nth-child(even) {
            background-color: #fafafa;
        }

        .plot-container {
            margin: 30px 0;
            text-align: center;
        }

        .plot-container img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .plot-container h3 {
            font-size: 1.3em;
            color: #555;
            margin-bottom: 15px;
        }

        footer {
            background-color: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #ddd;
        }

        footer p {
            margin: 5px 0;
        }

        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
        }

        .badge-warning {
            background-color: #fff3cd;
            color: #856404;
        }

        .badge-danger {
            background-color: #f8d7da;
            color: #721c24;
        }

        .badge-success {
            background-color: #d4edda;
            color: #155724;
        }

        /* ── MCAR Diagnostic section ────────────────────────────────── */

        /* Color-coded rows in MCAR results table */
        .mcar-table        { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .mcar-rejected     { background-color: #f8d7da; color: #721c24; font-weight: 600; }
        .mcar-accepted     { background-color: #d4edda; color: #155724; font-weight: 600; }
        .mcar-inconclusive { background-color: #e2e3e5; color: #383d41; font-weight: 600; }

        /* Verdict banner at top of MCAR section */
        .verdict-box {
            padding: 15px 20px;
            border-radius: 6px;
            margin: 15px 0;
            font-size: 1em;
        }

        .verdict-violated { background-color: #f8d7da; border-left: 5px solid #E63946; }
        .verdict-ok       { background-color: #d4edda; border-left: 5px solid #2DC653; }

        /* Recommendation list spacing */
        .recommendation li { margin: 6px 0; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>$title</h1>
            <p>Comprehensive Missing Data Analysis Report</p>
        </header>

        <div class="content">
            <section id="summary">
                <h2>📊 Summary Statistics</h2>
                $summary_html
            </section>

            <section id="visualizations">
                <h2>📈 Visualizations</h2>
                $plots_html
            </section>

            $mcar_html
        </div>

        <footer>
            <p><strong>Generated by MissingDataViz.jl</strong></p>
            <p>Timestamp: $timestamp</p>
            <p>Julia package for missing data visualization and diagnosis</p>
        </footer>
    </div>
</body>
</html>
"""
end

"""
    _generate_summary_table(df::DataFrame, stats::Dict)::String

Generate HTML table with summary statistics of missing data.

# Arguments
- `df::DataFrame`: Input data
- `stats::Dict`: Statistics dictionary from pattern detection module

# Returns
- `String`: HTML table element with summary statistics
"""
function _generate_summary_table(df::DataFrame, stats::Dict)::String
    n_rows, n_cols = size(df)

    # Start table
    html = """
    <table>
        <thead>
            <tr>
                <th>Column</th>
                <th>Missing Count</th>
                <th>Missing %</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
    """

    # Add row for each column
    for col in names(df)
        missing_count = stats[:columns][col][:count]
        missing_pct   = stats[:columns][col][:percentage]

        # Determine status badge
        badge_class = if missing_pct == 0
            "badge-success"
        elseif missing_pct < 25
            "badge-warning"
        else
            "badge-danger"
        end

        status = if missing_pct == 0
            "Complete"
        elseif missing_pct < 25
            "Minor"
        elseif missing_pct < 50
            "Moderate"
        else
            "Severe"
        end

        html *= """
            <tr>
                <td><strong>$col</strong></td>
                <td>$missing_count / $n_rows</td>
                <td>$(round(missing_pct, digits=2))%</td>
                <td><span class="badge $badge_class">$status</span></td>
            </tr>
        """
    end

    html *= """
        </tbody>
    </table>

    <p><strong>Overall Summary:</strong>
       $(stats[:total_missing]) missing values out of $(n_rows * n_cols) total cells
       ($(round(stats[:total_missing] / (n_rows * n_cols) * 100, digits=2))%)
    </p>
    """

    return html
end

"""
    _generate_plots_section(matrix_b64::String, bars_b64::String,
                            corr_b64::String, overview_b64::String)::String

Generate HTML section with embedded base64 plot images.

# Arguments
- `matrix_b64::String`: Base64 data URI for missing matrix plot
- `bars_b64::String`: Base64 data URI for bar chart
- `corr_b64::String`: Base64 data URI for correlation matrix
- `overview_b64::String`: Base64 data URI for overview dashboard

# Returns
- `String`: HTML with plot containers and embedded images
"""
function _generate_plots_section(matrix_b64::String, bars_b64::String,
                                 corr_b64::String,   overview_b64::String)::String
    return """
    <div class="plot-container">
        <h3>Missing Data Matrix</h3>
        <img src="$matrix_b64" alt="Missing Data Matrix">
        <p style="margin-top: 10px; color: #666; font-size: 0.9em;">
            Heatmap showing missing (red) vs present (blue) values across all observations.
        </p>
    </div>

    <div class="plot-container">
        <h3>Missing Percentage by Column</h3>
        <img src="$bars_b64" alt="Missing Bars Chart">
        <p style="margin-top: 10px; color: #666; font-size: 0.9em;">
            Bar chart displaying the percentage of missing values for each column.
        </p>
    </div>

    <div class="plot-container">
        <h3>Missing Data Correlation Matrix</h3>
        <img src="$corr_b64" alt="Correlation Matrix">
        <p style="margin-top: 10px; color: #666; font-size: 0.9em;">
            Correlation between missingness patterns across columns (ranges from -1 to +1).
        </p>
    </div>

    <div class="plot-container">
        <h3>Complete Overview Dashboard</h3>
        <img src="$overview_b64" alt="Overview Dashboard">
        <p style="margin-top: 10px; color: #666; font-size: 0.9em;">
            Combined view of all visualizations for comprehensive analysis.
        </p>
    </div>
    """
end

"""
    _generate_mcar_section(comparison, alpha::Float64)::String

Generate HTML section with MCAR test results, color-coded table,
and actionable recommendations.

This is an internal function called by `generate_html_report` when
`run_mcar_tests=true`. It consumes the output of `compare_mcar_tests()`.

# Arguments
- `comparison`: `MCARTestComparison` struct from `compare_mcar_tests()`
- `alpha::Float64`: Significance threshold used for the tests

# Returns
- `String`: Complete HTML `<section>` block with:
  - Verdict banner (green/red)
  - Color-coded results table (one row per test)
  - Actionable recommendations (column-specific when violations detected)

# Note
- Rows are sorted by p-value ascending (most significant violations first)
- Column names are extracted from test labels of the form "prefix: colname"
- Little's test violations without pairwise confirmation generate a global warning
"""
function _generate_mcar_section(comparison, alpha::Float64)::String

    # ── 1. Extract all test results ──────────────────────────────────────
    test_vec = _extract_test_results(comparison)

    # ── 2. Determine global verdict ──────────────────────────────────────
    n_rejected     = count(r -> r.decision == MCAR_REJECTED, test_vec)
    global_verdict = n_rejected > 0 ? :violated : :ok

    verdict_class = global_verdict == :violated ? "verdict-violated" : "verdict-ok"
    verdict_icon  = global_verdict == :violated ? "⚠️" : "✅"
    verdict_text  = global_verdict == :violated ?
        "MCAR violated — missing data is <strong>not random</strong>. Advanced imputation recommended." :
        "No strong evidence against MCAR — missing data appears random."

    # ── 3. Build color-coded test results table ───────────────────────────
    # Sorted by p-value ascending: most significant violations appear first
    rows_html = ""
    for r in sort(test_vec, by = r -> r.pvalue)
        row_class = if r.decision == MCAR_REJECTED
            "mcar-rejected"
        elseif r.decision == MCAR_NOT_REJECTED
            "mcar-accepted"
        else
            "mcar-inconclusive"
        end

        decision_text = if r.decision == MCAR_REJECTED
            "❌ Rejected"
        elseif r.decision == MCAR_NOT_REJECTED
            "✅ Not Rejected"
        else
            "⚪ Inconclusive"
        end

        # Use HTML entity for < to avoid breaking the HTML
        pval_str = r.pvalue < 0.001 ? "&lt;0.001" : string(round(r.pvalue, digits=3))

        rows_html *= """
        <tr>
            <td>$(r.test_name)</td>
            <td>$(round(r.statistic, digits=3))</td>
            <td>$(pval_str)</td>
            <td>$(alpha)</td>
            <td class="$(row_class)">$(decision_text)</td>
        </tr>
        """
    end

    # ── 4. Build actionable recommendations ──────────────────────────────
    # Extract column names from labels of the form "t-test: x2", "Logistic: x3"
    violated_cols = Symbol[]
    for r in test_vec
        if r.decision == MCAR_REJECTED
            parts = split(r.test_name, ": ")
            if length(parts) == 2
                push!(violated_cols, Symbol(strip(parts[2])))
            end
        end
    end
    violated_cols = unique(violated_cols)

    recs_html = if global_verdict == :violated
        # Column-specific recommendations when pairwise violations detected
        # Generic global warning when only Little's test fired
        col_list = isempty(violated_cols) ?
            "<li>Review all columns — global test (Little's) detected non-random missingness.</li>" :
            join(["<li>Column <strong>$(c)</strong>: missingness is predicted by other variables → use regression-based imputation (MICE).</li>"
                  for c in violated_cols])
        """
        <ul class="recommendation">
            $(col_list)
            <li>Include identified predictors in your imputation model.</li>
            <li>Run sensitivity analysis comparing simple vs. advanced imputation.</li>
            <li>Consider collecting more data for severely affected columns.</li>
        </ul>
        """
    else
        """
        <ul class="recommendation">
            <li>Simple imputation methods (mean, median, mode) are statistically acceptable.</li>
            <li>Multiple imputation (MICE) is still recommended for conservative analysis.</li>
            <li>Verify MNAR risk using domain knowledge — statistical tests cannot detect MNAR.</li>
        </ul>
        """
    end

    # ── 5. Assemble complete section ──────────────────────────────────────
    return """
    <section id="mcar-diagnosis">
        <h2>🔬 MCAR Diagnostic</h2>

        <div class="verdict-box $(verdict_class)">
            $(verdict_icon) <strong>Verdict:</strong> $(verdict_text)
        </div>

        <h3>Test Results</h3>
        <table class="mcar-table">
            <thead>
                <tr>
                    <th>Test</th>
                    <th>Statistic</th>
                    <th>p-value</th>
                    <th>α</th>
                    <th>Decision</th>
                </tr>
            </thead>
            <tbody>
                $(rows_html)
            </tbody>
        </table>

        <h3>Actionable Recommendations</h3>
        $(recs_html)
    </section>
    """
end