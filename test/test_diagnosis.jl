# test/test_diagnosis.jl
# Tests for the Phase 2 diagnostic pipeline: full_missing_diagnosis,
# plot_missing_diagnosis, and plot_mcar_test_results.
#
# These three functions were not exercised anywhere in the test suite
# prior to this file (flagged during package review).

using Test
using DataFrames
using MissingDataViz
using CairoMakie
using Random

@testset "full_missing_diagnosis" begin

    @testset "Basic run — all keys present" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)

        outdir = mktempdir()
        report = joinpath(outdir, "report.html")
        dash   = joinpath(outdir, "dash.png")

        results = full_missing_diagnosis(df;
            output           = report,
            dashboard_file   = dash,
            verbose          = false)

        @test results isa Dict{Symbol, Any}
        for k in (:report_path, :dashboard_path, :stats, :mcar_results,
                  :n_violations, :violated_cols, :recommendation, :elapsed_seconds)
            @test haskey(results, k)
        end

        @test isfile(results[:report_path])
        @test isfile(results[:dashboard_path])
        @test results[:mcar_results] isa MCARTestComparison
        @test results[:elapsed_seconds] >= 0.0
    end

    @testset "MAR data — violations detected and consistent" begin
        Random.seed!(42)
        df = generate_mar_data(2000, 4, 0.20; seed=42)

        outdir = mktempdir()
        results = full_missing_diagnosis(df;
            output         = joinpath(outdir, "report.html"),
            dashboard_file = joinpath(outdir, "dash.png"))

        @test results[:n_violations] == length(results[:violated_cols])
        @test results[:n_violations] > 0
        @test occursin("MICE", results[:recommendation])
    end

    @testset "run_mcar_tests=false skips statistical tests" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)

        outdir = mktempdir()
        results = full_missing_diagnosis(df;
            output         = joinpath(outdir, "report.html"),
            dashboard_file = joinpath(outdir, "dash.png"),
            run_mcar_tests = false)

        @test results[:mcar_results] === nothing
        @test results[:n_violations] == 0
        @test isempty(results[:violated_cols])
        @test occursin("not run", results[:recommendation])
    end

    @testset "export_dashboard=false skips PNG export" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)

        outdir = mktempdir()
        results = full_missing_diagnosis(df;
            output           = joinpath(outdir, "report.html"),
            export_dashboard = false)

        @test results[:dashboard_path] === nothing
        @test isfile(results[:report_path])
    end

    @testset "Input validation" begin
        outdir = mktempdir()
        df_empty = DataFrame()
        @test_throws ArgumentError full_missing_diagnosis(df_empty;
            output = joinpath(outdir, "r.html"))
    end

    @testset "No missing data" begin
        df_complete = DataFrame(a = collect(1:20), b = collect(21:40))
        outdir = mktempdir()
        results = full_missing_diagnosis(df_complete;
            output         = joinpath(outdir, "report.html"),
            dashboard_file = joinpath(outdir, "dash.png"))

        @test results[:n_violations] == 0
        @test occursin("No MCAR violations", results[:recommendation])
    end

end

@testset "plot_missing_diagnosis" begin

    @testset "Returns a Figure — standalone" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        fig = plot_missing_diagnosis(df)
        @test fig isa Figure
    end

    @testset "Accepts pre-computed mcar_results (no recomputation)" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        comp = compare_mcar_tests(df; verbose=false)

        # This must not error and must produce a Figure — the point of the
        # mcar_results kwarg is to reuse `comp` instead of recomputing
        # internally (Fix 2A: -81% pipeline time).
        fig = plot_missing_diagnosis(df; mcar_results=comp)
        @test fig isa Figure
    end

    @testset "No missing data" begin
        df = DataFrame(a = collect(1:20), b = collect(21:40))
        fig = plot_missing_diagnosis(df)
        @test fig isa Figure
    end

    @testset "Degenerate correlation panel (single column with missing)" begin
        # Only one column varies in missingness → correlation panel cannot
        # compute a pairwise correlation (nv < 2 branch in dashboard.jl).
        df = DataFrame(
            a = vcat(fill(missing, 5), fill(1.0, 15)),
            b = collect(1.0:20.0)
        )
        fig = plot_missing_diagnosis(df)
        @test fig isa Figure
    end

    @testset "Custom title and alpha" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        fig = plot_missing_diagnosis(df; title="Custom Title", alpha=0.01)
        @test fig isa Figure
    end

end

@testset "plot_mcar_test_results" begin

    @testset "Accepts MCARTestComparison" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        comp = compare_mcar_tests(df; verbose=false)
        fig = plot_mcar_test_results(comp)
        @test fig isa Figure
    end

    @testset "Accepts Vector{TestResult} directly" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        results = test_all_mcar_means(df)
        fig = plot_mcar_test_results(results)
        @test fig isa Figure
    end

    @testset "Empty results — does not error" begin
        fig = plot_mcar_test_results(TestResult[])
        @test fig isa Figure
    end

    @testset "Custom alpha and title" begin
        Random.seed!(42)
        df = generate_mar_data(300, 4, 0.20; seed=42)
        comp = compare_mcar_tests(df; verbose=false)
        fig = plot_mcar_test_results(comp; alpha=0.01, title="Custom")
        @test fig isa Figure
    end

end