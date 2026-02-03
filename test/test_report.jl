using Test
using DataFrames
using MissingDataViz

@testset "MissingDataViz - Report Generation Tests" begin
    
    @testset "generate_html_report - Basic Functionality" begin
        # Create test data
        df = DataFrame(
            A = [1, missing, 3, missing, 5],
            B = [missing, 2, 3, 4, missing],
            C = [1, 2, missing, missing, 5]
        )
        
        # Test basic report generation
        output_path = generate_html_report(df, "test_basic.html")
        
        @test isfile(output_path)
        @test isabspath(output_path)
        @test filesize(output_path) > 0
        
        # Verify HTML structure
        html_content = read(output_path, String)
        
        @test occursin("<!DOCTYPE html>", html_content)
        @test occursin("Missing Data Analysis Report", html_content)
        @test occursin("data:image/png;base64,", html_content)
        @test occursin("MissingDataViz.jl", html_content)
        
        # Verify all 4 plots are embedded
        base64_count = length(collect(eachmatch(r"data:image/png;base64,", html_content)))
        @test base64_count == 4
        
        # Cleanup
        rm(output_path)
    end
    
    @testset "generate_html_report - Custom Title" begin
        df = DataFrame(X = [1, missing, 3])
        
        custom_title = "Custom Test Report 2024"
        output_path = generate_html_report(
            df,
            "test_custom_title.html",
            title=custom_title
        )
        
        html_content = read(output_path, String)
        @test occursin(custom_title, html_content)
        
        rm(output_path)
    end
    
    @testset "generate_html_report - Path Handling" begin
        df = DataFrame(A = [1, missing, 3])
        
        # Test relative path
        rel_output = generate_html_report(df, "test_relative.html")
        @test isabspath(rel_output)
        @test isfile(rel_output)
        @test endswith(rel_output, "test_relative.html")
        rm(rel_output)
        
        # Test absolute path
        abs_output = joinpath(pwd(), "test_absolute.html")
        result = generate_html_report(df, abs_output)
        @test result == abs_output
        @test isfile(result)
        rm(result)
    end
    
    @testset "generate_html_report - Input Validation" begin
        # Test empty DataFrame
        df_empty = DataFrame()
        @test_throws ArgumentError generate_html_report(df_empty, "test.html")
        
        # Test DataFrame with no columns
        df_no_cols = DataFrame()
        @test_throws ArgumentError generate_html_report(df_no_cols, "test.html")
    end
    
    @testset "generate_html_report - Edge Cases" begin
        # Test single column DataFrame
        df_single = DataFrame(A = [1, missing, 3])
        output = generate_html_report(df_single, "test_single_col.html")
        @test isfile(output)
        rm(output)
        
        # Test DataFrame with no missing values
        df_complete = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
        output = generate_html_report(df_complete, "test_complete.html")
        @test isfile(output)
        html = read(output, String)
        @test occursin("0.0%", html) || occursin("0%", html)  # Should show 0% missing
        rm(output)
        
        # Test DataFrame with 100% missing
        df_all_missing = DataFrame(
            A = [missing, missing, missing],
            B = [missing, missing, missing]
        )
        output = generate_html_report(df_all_missing, "test_all_missing.html")
        @test isfile(output)
        html = read(output, String)
        @test occursin("100", html)  # Should show 100% missing
        rm(output)
        
        # Test filename with spaces (valid on most systems)
        df = DataFrame(X = [1, missing])
        output = generate_html_report(df, "test report spaces.html")
        @test isfile(output)
        rm(output)
    end
end

@testset "MissingDataViz - diagnose_missing Tests" begin
    
    @testset "diagnose_missing - Interactive Mode" begin
        df = DataFrame(
            A = [1, missing, 3],
            B = [missing, 2, 3]
        )
        
        # Test basic interactive mode
        results = diagnose_missing(df, display=false)
        
        @test haskey(results, :stats)
        @test haskey(results, :figures)
        @test !haskey(results, :report_path)  # No report in interactive mode
        
        # Verify statistics
        @test results[:stats][:total_missing] == 2
        @test results[:stats][:total_cells] == 6
        @test results[:stats][:overall_percentage] ≈ 33.333333333333336
        
        # Verify figures
        @test length(results[:figures]) == 4
        @test haskey(results[:figures], :matrix)
        @test haskey(results[:figures], :bars)
        @test haskey(results[:figures], :correlation)
        @test haskey(results[:figures], :overview)
    end
    
    @testset "diagnose_missing - Batch Mode" begin
        df = DataFrame(
            A = [1, missing, 3],
            B = [missing, 2, 3]
        )
        
        # Test batch mode
        results = diagnose_missing(df, report=true, output="test_batch.html")
        
        @test haskey(results, :stats)
        @test haskey(results, :figures)
        @test haskey(results, :report_path)  # Report path present in batch mode
        
        # Verify report was created
        @test isfile(results[:report_path])
        
        # Cleanup
        rm(results[:report_path])
    end
    
    @testset "diagnose_missing - Convenience Syntax" begin
        df = DataFrame(X = [1, missing])
        
        # Test shorthand syntax
        results = diagnose_missing(df, "test_convenience.html")
        
        @test haskey(results, :report_path)
        @test isfile(results[:report_path])
        
        rm(results[:report_path])
    end
    
    @testset "diagnose_missing - Input Validation" begin
        # Empty DataFrame
        df_empty = DataFrame()
        @test_throws ArgumentError diagnose_missing(df_empty)
        
        # DataFrame with no columns
        df_no_cols = DataFrame()
        @test_throws ArgumentError diagnose_missing(df_no_cols)
    end
    
    @testset "diagnose_missing - Statistics Accuracy" begin
        df = DataFrame(
            A = [1, missing, 3],  # 33.33% missing
            B = [missing, missing, 3],  # 66.67% missing
            C = [1, 2, 3]  # 0% missing
        )
        
        results = diagnose_missing(df, display=false)
        stats = results[:stats]
        
        # Overall statistics
        @test stats[:total_missing] == 3
        @test stats[:total_cells] == 9
        @test stats[:overall_percentage] ≈ 33.333333333333336
        
        # Per-column statistics
        @test stats[:columns]["A"][:count] == 1
        @test stats[:columns]["A"][:percentage] ≈ 33.333333333333336
        
        @test stats[:columns]["B"][:count] == 2
        @test stats[:columns]["B"][:percentage] ≈ 66.66666666666667
        
        @test stats[:columns]["C"][:count] == 0
        @test stats[:columns]["C"][:percentage] == 0.0
    end
    
    @testset "diagnose_missing - Edge Cases" begin
        # Single column
        df_single = DataFrame(A = [1, missing, 3])
        results = diagnose_missing(df_single, display=false)
        @test length(results[:stats][:columns]) == 1
        
        # All complete data
        df_complete = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
        results = diagnose_missing(df_complete, display=false)
        @test results[:stats][:total_missing] == 0
        @test results[:stats][:overall_percentage] == 0.0
        
        # All missing data
        df_all_missing = DataFrame(
            A = [missing, missing],
            B = [missing, missing]
        )
        results = diagnose_missing(df_all_missing, display=false)
        @test results[:stats][:total_missing] == 4
        @test results[:stats][:overall_percentage] == 100.0
    end
end

@testset "MissingDataViz - Internal Functions Tests" begin
    
    @testset "_compute_report_statistics" begin
        df = DataFrame(
            A = [1, missing, 3, missing],
            B = [missing, 2, 3, 4]
        )
        
        stats = MissingDataViz._compute_report_statistics(df)
        
        @test stats[:total_missing] == 3
        @test stats[:total_cells] == 8
        @test stats[:overall_percentage] == 37.5
        
        @test stats[:columns]["A"][:count] == 2
        @test stats[:columns]["A"][:percentage] == 50.0
        
        @test stats[:columns]["B"][:count] == 1
        @test stats[:columns]["B"][:percentage] == 25.0
    end
    
    @testset "_generate_all_plots" begin
        df = DataFrame(
            A = [1, missing, 3],
            B = [missing, 2, 3]
        )
        
        figures = MissingDataViz._generate_all_plots(df)
        
        @test isa(figures, Dict)
        @test length(figures) == 4
        @test haskey(figures, :matrix)
        @test haskey(figures, :bars)
        @test haskey(figures, :correlation)
        @test haskey(figures, :overview)
    end
    
    @testset "_convert_plots_to_base64" begin
        df = DataFrame(X = [1, missing])
        figures = MissingDataViz._generate_all_plots(df)
        
        plots_b64 = MissingDataViz._convert_plots_to_base64(figures)
        
        @test isa(plots_b64, Dict)
        @test length(plots_b64) == 4
        
        # Verify base64 format
        for (key, b64) in plots_b64
            @test isa(b64, String)
            @test startswith(b64, "data:image/png;base64,")
            @test length(b64) > 100  # Should have substantial content
        end
    end
end

println("\n" * "="^60)
println("ALL TESTS PASSED ✅")
println("="^60)
