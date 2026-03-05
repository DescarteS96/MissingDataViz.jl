# src/plots/dashboard.jl
# Integrated diagnostic dashboard combining Phase 1 + Phase 2 visualizations

"""
    plot_missing_diagnosis(df; alpha=0.05, figsize=(1400, 900), title="Missing Data Diagnosis")

Generate a 2×2 integrated dashboard combining all missing data visualizations
and MCAR statistical tests.

# Layout
- Top-left:     Missing data matrix (heatmap)
- Top-right:    Missing percentage bar chart
- Bottom-left:  Missing correlation heatmap
- Bottom-right: MCAR test results (p-value bar chart)

# Arguments
- `df::DataFrame`: Input DataFrame (may contain `missing` values)
- `alpha::Float64=0.05`: Significance threshold for MCAR tests
- `figsize::Tuple=(1400, 900)`: Figure dimensions in pixels
- `title::String`: Dashboard title

# Returns
- `Figure`: Makie figure object containing all 4 panels

# Notes
- Runs `compare_mcar_tests()` internally — may take a few seconds on large datasets
- Columns with no missing values are excluded from MCAR tests automatically
- Annotations highlight columns where MCAR is rejected

# Examples
```julia
using MissingDataViz, DataFrames, Random
Random.seed!(42)
df = generate_mar_data(300, 5, 0.20)
fig = plot_missing_diagnosis(df)
save("diagnosis_dashboard.png", fig)
```
"""
function plot_missing_diagnosis(
    df::DataFrame;
    alpha::Float64   = 0.05,
    figsize::Tuple{Int,Int} = (1400, 900),
    title::String    = "Missing Data Diagnosis",
    mcar_results::Union{MCARTestComparison, Nothing} = nothing
)
    validate_dataframe(df)

    fig = Figure(size = figsize, backgroundcolor = :white)

    # ── Title bar ──────────────────────────────────────────────
    Label(
        fig[0, 1:2],
        title,
        fontsize  = 20,
        font      = :bold,
        tellwidth = false,
    )

    # ── Panel 1 : Missing matrix (top-left) ────────────────────
    ax1 = Axis(
        fig[1, 1],
        title     = "Missing Data Pattern",
        titlesize = 13,
    )
    _draw_matrix_panel!(ax1, df)

    # ── Panel 2 : Missing bars (top-right) ─────────────────────
    ax2 = Axis(
        fig[1, 2],
        title     = "Missing % by Column",
        titlesize = 13,
    )
    _draw_bars_panel!(ax2, df, alpha)

    # ── Panel 3 : Correlation (bottom-left) ────────────────────
    ax3 = Axis(
        fig[2, 1],
        title     = "Missing Correlation",
        titlesize = 13,
    )
    _draw_correlation_panel!(ax3, df)

    # ── Panel 4 : MCAR tests (bottom-right) ────────────────────
    ax4 = Axis(
        fig[2, 2],
        title     = "MCAR Test Results  (-log₁₀ p-value)",
        titlesize = 13,
    )
    violated_cols = _draw_mcar_panel!(ax4, df, alpha; mcar_results = mcar_results)

    # ── Spacing ────────────────────────────────────────────────
    rowgap!(fig.layout, 20)
    colgap!(fig.layout, 20)

    # ── Footer annotation ──────────────────────────────────────
    if !isempty(violated_cols)
        cols_str = join(string.(violated_cols), ", ")
        Label(
            fig[3, 1:2],
            "⚠  MCAR violated for: $(cols_str)  |  α = $(alpha)",
            fontsize  = 11,
            color     = :firebrick,
            tellwidth = false,
        )
    else
        Label(
            fig[3, 1:2],
            "✓  No MCAR violations detected  |  α = $(alpha)",
            fontsize  = 11,
            color     = :darkgreen,
            tellwidth = false,
        )
    end

    return fig
end


# ══════════════════════════════════════════════════════════════
# Internal panel renderers
# ══════════════════════════════════════════════════════════════

"""Draw missing matrix heatmap into an existing Axis."""
function _draw_matrix_panel!(ax::Axis, df::DataFrame)
    pattern = missing_pattern(df)   # BitMatrix: true = missing
    n_rows, n_cols = size(pattern)
    cols = names(df)

    # Sample rows if too large
    max_rows = 300
    row_idx = n_rows > max_rows ? round.(Int, range(1, n_rows, length=max_rows)) : 1:n_rows
    pat_display = pattern[row_idx, :]

    # Build color matrix: 1.0 = missing (dark), 0.0 = present (light)
    z = Float64.(pat_display)

    heatmap!(
        ax,
        z',
        colormap = [:white, :black],
        colorrange = (0.0, 1.0),
    )

    ax.xticks = (1:n_cols, cols)
    ax.xticklabelrotation = π/4
    ax.xticklabelsize = 9
    ax.yticks = (Int[], String[])
    ax.ylabel = "Observations"
    ax.ylabelsize = 9
end

"""Draw missing percentage bar chart into an existing Axis."""
function _draw_bars_panel!(ax::Axis, df::DataFrame, alpha::Float64)
    pct = missing_percentage(df)
    cols = names(df)
    n = length(cols)
    x = 1:n

    # Color by severity
    bar_colors = map(p -> p > 50 ? "#E63946" : p > 20 ? "#F4A261" : "#2DC653", pct)

    barplot!(ax, collect(x), pct, color = bar_colors, strokecolor = (:black, 0.2), strokewidth = 0.5)

    # Threshold line at alpha-derived suggestion (20% is common rule of thumb)
    hlines!(ax, [20.0], color = (:gray, 0.6), linestyle = :dash, linewidth = 1.0)

    ax.xticks = (collect(x), cols)
    ax.xticklabelrotation = π/4
    ax.xticklabelsize = 9
    ax.ylabel = "Missing (%)"
    ax.ylabelsize = 9
    ylims!(ax, 0, 105)
end

"""Draw missing correlation heatmap into an existing Axis."""
function _draw_correlation_panel!(ax::Axis, df::DataFrame)
    cols = names(df)
    n = length(cols)

    # Compute correlation between missing indicators
    pattern = Float64.(missing_pattern(df))

    # Guard: if any column is all-missing or all-present, correlation is undefined
    valid = [std(pattern[:, j]) > 0 for j in 1:n]
    valid_cols = cols[valid]
    pat_valid = pattern[:, valid]
    nv = length(valid_cols)

    if nv < 2
        text!(ax, 0.5, 0.5, text = "Insufficient\nvariable pairs",
              align = (:center, :center), fontsize = 12, color = :gray)
        hidedecorations!(ax)
        return
    end

    corr_matrix = cor(pat_valid)

    heatmap!(
        ax,
        corr_matrix,
        colormap   = :RdBu,
        colorrange = (-1.0, 1.0),
    )

    ax.xticks = (1:nv, valid_cols)
    ax.yticks = (1:nv, valid_cols)
    ax.xticklabelrotation = π/4
    ax.xticklabelsize = 9
    ax.yticklabelsize = 9
end

"""
Draw MCAR test results into an existing Axis.
Returns Vector of column names where MCAR is rejected.
"""
function _draw_mcar_panel!(ax::Axis, df::DataFrame, alpha::Float64;
                           mcar_results::Union{MCARTestComparison, Nothing} = nothing)
    violated_cols = Symbol[]

    # Use pre-computed results if available, otherwise run tests
    comparison = if !isnothing(mcar_results)
        mcar_results
    else
        try
            compare_mcar_tests(df; alpha = alpha, verbose = false)
        catch e
            text!(ax, 0.5, 0.5, text = "MCAR tests\nnot available:\n$(typeof(e))",
                  align = (:center, :center), fontsize = 10, color = :gray)
            hidedecorations!(ax)
            return violated_cols
        end
    end    

    test_vec = _extract_test_results(comparison)

    if isempty(test_vec)
        text!(ax, 0.5, 0.5, text = "No tests\nto display",
              align = (:center, :center), fontsize = 12, color = :gray)
        hidedecorations!(ax)
        return violated_cols
    end

    # Sort by -log10(p) descending
    neg_log_p = [-log10(max(r.pvalue, 1e-10)) for r in test_vec]
    order     = sortperm(neg_log_p, rev = true)
    test_vec  = test_vec[order]
    neg_log_p = neg_log_p[order]

    labels    = [_truncate_label(r.test_name, 18) for r in test_vec]
    colors    = [_decision_color(r.decision) for r in test_vec]
    threshold = -log10(alpha)
    n         = length(test_vec)
    x_pos     = collect(1:n)

    barplot!(ax, x_pos, neg_log_p, color = colors,
             strokecolor = (:black, 0.2), strokewidth = 0.5)

    hlines!(ax, [threshold], color = (:black, 0.7), linestyle = :dash, linewidth = 1.2)

    ax.xticks = (x_pos, labels)
    ax.xticklabelrotation = π/4
    ax.xticklabelsize = 8
    ax.ylabel = "-log₁₀(p)"
    ax.ylabelsize = 9
    xlims!(ax, 0.5, n + 0.5)

    # Collect violated columns for footer annotation
    has_little_violation = false

    for r in test_vec
        if r.decision == MCAR_REJECTED
            parts = split(r.test_name, ": ")
            if length(parts) == 2
                push!(violated_cols, Symbol(strip(parts[2])))
            elseif occursin("Little", r.test_name)
                has_little_violation = true
            end
        end
    end

    # If Little's test violated but no specific columns identified,
    # flag it explicitly in the footer via a sentinel symbol
    if has_little_violation && isempty(violated_cols)
        push!(violated_cols, Symbol("Little's test (global)"))
    elseif has_little_violation
        # Little confirms pairwise violations — no need to add separately
    end

    return unique(violated_cols)

end