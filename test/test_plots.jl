# test/test_plots.jl
using Test
using DataFrames
using MissingDataViz
using CairoMakie

@testset "MissingDataViz - Visualization Tests" begin
    
    df_test = DataFrame(
        A = [1, missing, 3, missing, 5],
        B = [missing, 2, 3, missing, 5],
        C = [1, 2, 3, 4, 5],
        D = [missing, missing, 3, 4, 5]
    )
    
    @testset "plot_missing_matrix" begin
        fig = plot_missing_matrix(df_test)
        @test fig isa Figure
        @test !isnothing(fig)
        
        fig_custom = plot_missing_matrix(df_test, figsize=(800, 600))
        @test fig_custom isa Figure
        
        df_complete = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
        fig_no_missing = plot_missing_matrix(df_complete)
        @test fig_no_missing isa Figure
        
        df_single = DataFrame(X = [1, missing, 3])
        fig_single = plot_missing_matrix(df_single)
        @test fig_single isa Figure
    end
    
    @testset "plot_missing_bars" begin
        fig = plot_missing_bars(df_test)
        @test fig isa Figure
        
        fig_sorted = plot_missing_bars(df_test, sort=true)
        @test fig_sorted isa Figure
        
        fig_threshold = plot_missing_bars(df_test, threshold=30.0)
        @test fig_threshold isa Figure
    end
    
    @testset "plot_missing_correlation" begin
        fig = plot_missing_correlation(df_test)
        @test fig isa Figure
        
        df_single = DataFrame(A = [1, missing, 3], B = [1, 2, 3])
        fig_single = plot_missing_correlation(df_single)
        @test fig_single isa Figure
    end
    
    @testset "plot_missing_overview" begin
        fig = plot_missing_overview(df_test)
        @test fig isa Figure
        
        df_single = DataFrame(X = [1, missing, 3])
        fig_single = plot_missing_overview(df_single)
        @test fig_single isa Figure
    end
    
    @testset "Plot Performance" begin
        using Random
        Random.seed!(42)
        
        df_medium = DataFrame(
            [Symbol("col$i") => rand([1.0, 2.0, missing], 1000) for i in 1:10]
        )
        
        time_matrix = @elapsed plot_missing_matrix(df_medium)
        @test time_matrix < 2.0
        
        time_bars = @elapsed plot_missing_bars(df_medium)
        @test time_bars < 2.0
        
        time_corr = @elapsed plot_missing_correlation(df_medium)
        @test time_corr < 2.0
        
        time_overview = @elapsed plot_missing_overview(df_medium)
        @test time_overview < 5.0
    end
end