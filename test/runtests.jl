using MissingDataViz
using Test
using DataFrames
using Random

@testset "MissingDataViz.jl" begin
    
    # ================================================================
    # PART 1: BASIC FUNCTIONS
    # ================================================================
    
    @testset "Part 1: Basic Functions" begin
        
        @testset "missing_pattern()" begin
            # Test 1.1: Simple case
            df = DataFrame(A=[1, missing, 3], B=[4, 5, missing])
            pattern = missing_pattern(df)
            @test size(pattern) == (3, 2)
            @test pattern[1, 1] == false  # A[1] present
            @test pattern[2, 1] == true   # A[2] missing
            @test pattern[3, 2] == true   # B[3] missing
            
            # Test 1.2: All present
            df_complete = DataFrame(A=[1,2,3], B=[4,5,6])
            pattern_complete = missing_pattern(df_complete)
            @test all(pattern_complete .== false)
            
            # Test 1.3: All missing
            df_all_missing = DataFrame(A=[missing, missing], B=[missing, missing])
            pattern_all = missing_pattern(df_all_missing)
            @test all(pattern_all .== true)
        end
        
        @testset "missing_count()" begin
            # Test 2.1: Known counts
            df = DataFrame(
                A = [1, missing, 3, missing],
                B = [missing, 2, missing, 4],
                C = [5, 6, 7, 8]
            )
            counts = missing_count(df)
            @test counts == [2, 2, 0]
            
            # Test 2.2: No missing
            df_complete = DataFrame(A=[1,2,3])
            @test missing_count(df_complete) == [0]
            
            # Test 2.3: All missing
            df_all = DataFrame(A=[missing, missing, missing])
            @test missing_count(df_all) == [3]
        end
        
        @testset "missing_percentage()" begin
            # Test 3.1: Known percentages
            df = DataFrame(
                A = [1, missing, 3, missing],  # 2/4 = 50%
                B = [1, 2, 3, 4]               # 0/4 = 0%
            )
            pcts = missing_percentage(df)
            @test pcts[1] ≈ 50.0
            @test pcts[2] ≈ 0.0
            
            # Test 3.2: 100% missing
            df_all = DataFrame(A=[missing, missing])
            @test missing_percentage(df_all)[1] ≈ 100.0
        end
        
        @testset "validate_dataframe()" begin
            # Test 4.1: Valid DataFrame
            df_valid = DataFrame(A=[1,2,3])
            @test validate_dataframe(df_valid) === nothing
            
            # Test 4.2: Empty DataFrame (0 rows)
            df_empty = DataFrame()
            @test_throws InvalidDataFrameError validate_dataframe(df_empty)
            
            # Test 4.3: DataFrame with 0 rows but columns
            df_no_rows = DataFrame(A=Int[], B=String[])
            @test_throws InvalidDataFrameError validate_dataframe(df_no_rows)
            
            # Test 4.4: Not a DataFrame
            @test_throws ArgumentError validate_dataframe([1, 2, 3])
        end
    end
    
    # ================================================================
    # PART 2: PATTERN ANALYSIS
    # ================================================================
    
    @testset "Part 2: Pattern Analysis" begin
        
        @testset "pattern_counts()" begin
            # Test 5.1: Known patterns
            df = DataFrame(
                A = [1, missing, 3, missing],
                B = [missing, 2, missing, 2]
            )
            counts = pattern_counts(df)
            
            # Should have 2 unique patterns
            @test length(counts) == 2
            
            # Pattern [0,1] appears 2 times (rows 1,3)
            # Pattern [1,0] appears 2 times (rows 2,4)
            @test sum(values(counts)) == 4  # Total rows
        end
        
        @testset "pattern_frequency()" begin
            # Test 6.1: Sorting by frequency
            df = DataFrame(
                A = [1, missing, 3, missing, 5, 6],
                B = [missing, 2, missing, 2, missing, 7]
            )
            freq = pattern_frequency(df)
            
            # Should be sorted descending
            @test freq[1][2] >= freq[2][2]  # First count >= Second count
            
            # Sum of all counts should equal number of rows
            total = sum(x[2] for x in freq)
            @test total == nrow(df)
        end
        
        @testset "PatternInfo" begin
            # Test 7.1: Structure creation
            info = PatternInfo([true, false, true], 5, 25.0, [1, 3, 5, 7, 9])
            @test info.count == 5
            @test info.frequency == 25.0
            @test length(info.row_indices) == 5
        end
    end
    
    # ================================================================
    # PART 3: DESCRIPTIVE STATISTICS
    # ================================================================
    
    @testset "Part 3: Descriptive Statistics" begin
        
        @testset "row_missing_stats()" begin
            # Test 8.1: Known row percentages
            df = DataFrame(
                A = [1, missing, missing],
                B = [2, 3, missing],
                C = [4, 5, 6]
            )
            row_stats = row_missing_stats(df)
            
            @test row_stats[1] ≈ 0.0      # Row 1: 0/3 = 0%
            @test row_stats[2] ≈ 33.33 atol=0.01  # Row 2: 1/3 = 33.33%
            @test row_stats[3] ≈ 66.67 atol=0.01  # Row 3: 2/3 = 66.67%
        end
        
        @testset "column_missing_distribution()" begin
            # Test 9.1: Distribution table
            df = DataFrame(
                A = [1, missing, 3],
                B = [4, 5, 6]
            )
            dist = column_missing_distribution(df)
            
            @test nrow(dist) == 2
            @test dist.column_name == ["A", "B"]
            @test dist.n_missing == [1, 0]
            @test dist.pct_missing[1] ≈ 33.33 atol=0.01
        end
        
        @testset "extreme_patterns()" begin
            # Test 10.1: Detect extremes
            df = DataFrame(
                A = [missing, 1, 1],
                B = [missing, 2, 2],
                C = [missing, missing, missing]
            )
            extremes = extreme_patterns(df)
            
            @test extremes.rows_all_missing == [1]  # Row 1 all missing
            @test extremes.cols_all_missing == [3]  # Column C all missing
        end
        
        @testset "summarize_missing()" begin
            # Test 11.1: Complete summary
            df = DataFrame(
                A = [1, missing, 3],
                B = [4, 5, missing]
            )
            summary = summarize_missing(df)
            
            @test summary.total_cells == 6
            @test summary.n_missing == 2
            @test summary.pct_missing ≈ 33.33 atol=0.01
            @test nrow(summary.by_column) == 2
            @test length(summary.by_row) == 3
            @test !isempty(summary.top_patterns)
        end
    end
    
    # ================================================================
    # STRENGTH TESTS
    # ================================================================
    
    @testset "Robustness Tests" begin
        
        @testset "Mixed types" begin
            # Test 12.1: Int and Float
            df_mixed = DataFrame(
                A = [1, missing, 3],
                B = [1.5, 2.5, missing]
            )
            @test length(missing_count(df_mixed)) == 2
        end
        
        @testset "NaN and Inf handling" begin
            # Test 13.1: NaN should NOT be counted as missing
            df_nan = DataFrame(A = [1.0, NaN, 3.0])
            counts = missing_count(df_nan)
            @test counts[1] == 0  # NaN is not missing
            
            # Test 13.2: Inf should NOT be counted as missing
            df_inf = DataFrame(A = [1.0, Inf, 3.0])
            counts_inf = missing_count(df_inf)
            @test counts_inf[1] == 0  # Inf is not missing
        end
        
        @testset "String columns" begin
            # Test 14.1: String with missing
            df_str = DataFrame(
                Name = ["Alice", missing, "Charlie"],
                Age = [25, 30, missing]
            )
            counts = missing_count(df_str)
            @test counts == [1, 1]
        end
        
        @testset "Boolean columns" begin
            # Test 15.1: Bool with missing
            df_bool = DataFrame(
                Flag = [true, false, missing]
            )
            @test missing_count(df_bool)[1] == 1
        end
    end
    
    # ================================================================
    # PERFORMANCE TESTS
    # ================================================================
    
    @testset "Performance Tests" begin
        
        @testset "1,000 rows" begin
            Random.seed!(123)
            df_1k = DataFrame(
                A = rand([1, 2, 3, missing], 1000),
                B = rand([10, 20, missing], 1000),
                C = rand([100, 200, 300, missing], 1000)
            )
            
            # Should complete in < 0.1 seconds
            time_taken = @elapsed begin
                missing_pattern(df_1k)
                missing_count(df_1k)
                pattern_counts(df_1k)
            end
            
            @test time_taken < 0.1
            println("1k rows: $(round(time_taken*1000, digits=2))ms")
        end
        
        @testset "10,000 rows" begin
            Random.seed!(456)
            df_10k = DataFrame(
                A = rand([1, 2, 3, missing], 10000),
                B = rand([10, 20, missing], 10000),
                C = rand([100, 200, 300, missing], 10000),
                D = rand([1.0, 2.0, missing], 10000)
            )
            
            # Should complete in < 1 second (OBJECTIVE)
            time_taken = @elapsed begin
                missing_pattern(df_10k)
                missing_count(df_10k)
                pattern_counts(df_10k)
                summarize_missing(df_10k)
            end
            
            @test time_taken < 1.0
            println("10k rows: $(round(time_taken*1000, digits=2))ms")
        end
        
        @testset "100,000 rows" begin
            Random.seed!(789)
            df_100k = DataFrame(
                A = rand([1, 2, missing], 100000),
                B = rand([10, missing], 100000),
                C = rand([100, 200, missing], 100000)
            )
            
            # Should complete in < 10 seconds
            time_taken = @elapsed begin
                pattern_counts(df_100k)
            end
            
            @test time_taken < 10.0
            println("100k rows: $(round(time_taken, digits=2))s")
        end
    end
    
    # ================================================================
    # VISUALIZATION TESTS
    # ================================================================
    
    include("test_plots.jl")
    
    # ================================================================
    # VALIDATION AND ERROR HANDLING TESTS
    # ================================================================
    
    include("test_validation.jl")
end