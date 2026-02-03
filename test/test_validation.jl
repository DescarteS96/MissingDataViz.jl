# test/test_validation.jl
# Tests for validation and error handling

using Test
using DataFrames
using MissingDataViz

# ⭐ IMPORTS CRITIQUES - Sans ça, les tests échouent
using MissingDataViz: InvalidDataFrameError, InvalidParameterError, InsufficientDataError
using MissingDataViz: validate_figsize, validate_threshold, validate_numeric_columns

@testset "Validation and Error Handling" begin
    
    @testset "validate_dataframe" begin
        # Valid DataFrame
        df_valid = DataFrame(A=[1,2,3], B=[4,5,6])
        @test_nowarn validate_dataframe(df_valid)
        
        # Not a DataFrame
        @test_throws ArgumentError validate_dataframe([1,2,3])
        @test_throws ArgumentError validate_dataframe("not a dataframe")
        
        # Empty DataFrame (0 rows)
        df_empty = DataFrame(A=Int[], B=Int[])
        @test_throws InvalidDataFrameError validate_dataframe(df_empty)
        
        # No columns
        df_nocols = DataFrame()
        @test_throws InvalidDataFrameError validate_dataframe(df_nocols)
    end
    
    @testset "validate_figsize" begin
        # Valid sizes
        @test_nowarn validate_figsize((800, 600))
        @test_nowarn validate_figsize((1200, 900))
        
        # Invalid: negative or zero
        @test_throws InvalidParameterError validate_figsize((-100, 600))
        @test_throws InvalidParameterError validate_figsize((800, 0))
        @test_throws InvalidParameterError validate_figsize((-10, -10))
        
        # Warning for very large (should warn but not throw)
        @test_logs (:warn,) validate_figsize((6000, 4000))
        
        # Warning for very small
        @test_logs (:warn,) validate_figsize((100, 100))
    end
    
    @testset "validate_threshold" begin
        # Valid thresholds
        @test_nowarn validate_threshold(0.0)
        @test_nowarn validate_threshold(50.0)
        @test_nowarn validate_threshold(100.0)
        
        # Invalid thresholds
        @test_throws InvalidParameterError validate_threshold(-0.1)
        @test_throws InvalidParameterError validate_threshold(100.1)
        @test_throws InvalidParameterError validate_threshold(-50)
    end
    
    @testset "validate_numeric_columns" begin
        # DataFrame with numeric columns
        df_numeric = DataFrame(A=[1,2,3], B=[4.0,5.0,6.0])
        @test_nowarn validate_numeric_columns(df_numeric, 1)
        @test_nowarn validate_numeric_columns(df_numeric, 2)
        
        # DataFrame with mixed types
        df_mixed = DataFrame(A=[1,2,3], B=["a","b","c"])
        @test_nowarn validate_numeric_columns(df_mixed, 1)
        @test_throws InsufficientDataError validate_numeric_columns(df_mixed, 2)
        
        # DataFrame with no numeric columns
        df_strings = DataFrame(A=["a","b","c"], B=["x","y","z"])
        @test_throws InsufficientDataError validate_numeric_columns(df_strings, 1)
    end
    
    @testset "Graceful degradation with warnings" begin
        # Large dataset warning
        df_large = DataFrame([Symbol("col$i") => rand(15000) for i in 1:5])
        
        # Should warn but not crash
        @test_logs (:warn,) match_mode=:any plot_missing_matrix(df_large)
        
        # All missing column
        df_all_missing = DataFrame(A=[missing, missing, missing], B=[1,2,3])
        @test_logs (:warn,) match_mode=:any plot_missing_matrix(df_all_missing)
        
        # Many columns
        df_many_cols = DataFrame([Symbol("col$i") => [1,2,3] for i in 1:120])
        @test_logs (:warn,) match_mode=:any plot_missing_bars(df_many_cols)
    end
    
    @testset "Custom error messages" begin
        # Check error message content
        try
            validate_dataframe([1,2,3])
            @test false  # Should not reach here
        catch e
            @test e isa ArgumentError
            @test occursin("DataFrame", e.msg)
        end
        
        # Check InvalidParameterError formatting
        try
            validate_figsize((-100, 600))
            @test false
        catch e
            @test e isa InvalidParameterError
            @test e.parameter == "figsize[1] (width)"
            @test e.value == -100
        end
        
        # Check InsufficientDataError formatting
        df_nocols = DataFrame(A=["a","b","c"])
        try
            validate_numeric_columns(df_nocols, 1)
            @test false
        catch e
            @test e isa InsufficientDataError
            @test occursin("correlation analysis", e.operation)
        end
    end
end