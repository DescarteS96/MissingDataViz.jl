# src/plots/mcar_results.jl
# Visualization of MCAR test results

"""
    plot_mcar_test_results(results; alpha=0.05, figsize=(800, 500), title="MCAR Test Results")

Create a horizontal bar plot visualizing p-values from MCAR tests.

# Arguments
- `results`: Either a `MCARTestComparison` (from `compare_mcar_tests()`) or a `Vector{TestResult}`
- `alpha::Float64=0.05`: Significance threshold (shown as vertical line)
- `figsize::Tuple=(800, 500)`: Figure dimensions in pixels
- `title::String="MCAR Test Results"`: Plot title

# Returns
- `Figure`: Makie figure object

# Color coding
- 🟢 Green (`MCAR_NOT_REJECTED`): No evidence against MCAR
- 🔴 Red (`MCAR_REJECTED`): Significant evidence against MCAR
- ⚫ Gray (`INCONCLUSIVE`): Insufficient data to conclude

# Notes
- P-values are displayed on a -log10 scale for readability
- The vertical dashed line marks -log10(alpha), the decision threshold
- Bars exceeding the threshold line indicate MCAR violations

# Examples
```julia
using MissingDataViz, DataFrames, Random
Random.seed!(42)
df = generate_mar_data(200, 4, 0.20)
comparison = compare_mcar_tests(df)
fig = plot_mcar_test_results(comparison)
save("mcar_results.png", fig)
```
"""
function plot_mcar_test_results(
    results;
    alpha::Float64 = 0.05,
    figsize::Tuple{Int,Int} = (800, 500),
    title::String = "MCAR Test Results"
)
    # --- 1. Extract TestResult vector from either input type ---
    test_vec = _extract_test_results(results)

    if isempty(test_vec)
        @warn "plot_mcar_test_results: no test results to display."
        fig = Figure(size = figsize)
        ax = Axis(fig[1, 1], title = "No results to display")
        return fig
    end

    # --- 2. Build plotting data ---
    labels      = _build_labels(test_vec)
    neg_log_p   = [-log10(max(r.pvalue, 1e-10)) for r in test_vec]  # clamp to avoid -Inf
    colors      = [_decision_color(r.decision) for r in test_vec]
    threshold   = -log10(alpha)

    # Sort by neg_log_p descending (most significant on top)
    order = sortperm(neg_log_p, rev = true)
    labels    = labels[order]
    neg_log_p = neg_log_p[order]
    colors    = colors[order]

    n = length(test_vec)
    y_positions = collect(1:n)

    # --- 3. Build figure ---
    fig = Figure(size = figsize, backgroundcolor = :white)

    ax = Axis(
    fig[1, 1],
    title          = title,
    titlesize      = 16,
    titlefont      = :bold,
    ylabel         = "-log₁₀(p-value)  [higher = more significant]",
    ylabelsize     = 12,
    xticks         = (y_positions, labels),
    xticklabelsize = 11,
    xticklabelrotation = π/4,
    ygridvisible   = true,
    xgridvisible   = false,
    ygridcolor     = (:gray, 0.2),
    )

    # --- 4. Draw bars ---
    barplot!(
    ax,
    y_positions,
    neg_log_p,
    color       = colors,
    strokecolor = (:black, 0.3),
    strokewidth = 0.5,
    )

    # --- 5. Threshold line ---
    hlines!(ax, [threshold],
    color     = (:black, 0.75),
    linewidth = 1.5,
    linestyle = :dash,
    )

    # Label on the threshold line
    text!(ax, n + 0.5, threshold + 0.05,
    text  = "α = $(alpha)",
    fontsize = 10,
    color = :black,
    align = (:left, :center),
    )

    # --- 6. Annotate p-values on bars ---
    for (i, (yp, nlp, res)) in enumerate(zip(y_positions, neg_log_p, [test_vec[o] for o in order]))
        pval_str = _format_pvalue(res.pvalue)
        text!(ax, yp, nlp + 0.05,
            text     = pval_str,
            fontsize = 9,
            color    = (:black, 0.7),
            align    = (:center, :bottom),
        )
    end

    # --- 7. Legend ---
    legend_entries = [
        PolyElement(color = "#2DC653", strokecolor = :black, strokewidth = 0.5),
        PolyElement(color = "#E63946", strokecolor = :black, strokewidth = 0.5),
        PolyElement(color = "#8D99AE", strokecolor = :black, strokewidth = 0.5),
    ]
    legend_labels = ["MCAR not rejected", "MCAR rejected", "Inconclusive"]

    Legend(
        fig[1, 2],
        legend_entries,
        legend_labels,
        "Decision",
        framevisible  = true,
        labelsize     = 11,
        titlesize     = 12,
    )

    # --- 8. Y-axis padding ---
    xlims!(ax, 0.5, n + 1.0)

    return fig
end


# ──────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────

"""Map MCARMechanism to a hex color string."""
function _decision_color(decision::MCARMechanism)
    if decision == MCAR_NOT_REJECTED
        return "#2DC653"   # green
    elseif decision == MCAR_REJECTED
        return "#E63946"   # red
    else
        return "#8D99AE"   # gray for INCONCLUSIVE
    end
end

"""
Extract a flat Vector{TestResult} from either a MCARTestComparison or a Vector{TestResult}.
"""
function _extract_test_results(results)
    if results isa Vector{TestResult}
        return results
    end
    
    extracted = TestResult[]
    
    for fname in fieldnames(typeof(results))
        val = getfield(results, fname)
        if val isa TestResult
            push!(extracted, val)
        elseif val isa Vector{TestResult}
            append!(extracted, val)
        elseif val isa Dict{Symbol, TestResult}
            for (k, v) in val
                prefix = if occursin("Logistic", v.test_name)
                    "Logistic"
                elseif occursin("Means", v.test_name)
                    "t-test"
                else
                    "Test"
                end
                enriched = TestResult(
                    "$(prefix): $(k)",
                    v.statistic,
                    v.pvalue,
                    v.alpha,
                    v.decision,
                    v.degrees_of_freedom,
                    v.details,
                    v.warnings
                )
                push!(extracted, enriched)
            end
        end
    end
    
    return extracted
end

"""Build a readable label for each TestResult using test_name."""
function _build_labels(test_vec::Vector{TestResult})
    return [_truncate_label(r.test_name, 40) for r in test_vec]
end

"""Truncate a label to max_len characters with ellipsis."""
function _truncate_label(s::String, max_len::Int)
    return length(s) <= max_len ? s : s[1:max_len-1] * "…"
end

"""Format a p-value for display (e.g. 0.032, <0.001)."""
function _format_pvalue(p::Float64)
    if p < 0.001
        return "<0.001"
    elseif p < 0.01
        return string(round(p, digits=3))
    else
        return string(round(p, digits=3))
    end
end