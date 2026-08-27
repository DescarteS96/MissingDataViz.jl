# ================================================================
# CI WORKAROUND: Disable graphical precompilation
# Fixes CairoMakie precompilation error on GitHub Actions
# See: https://github.com/MakieOrg/Makie.jl/issues/XXXX
# ================================================================
ENV["JULIA_DEBUG"] = ""
ENV["GKSwstype"] = "nul"
ENV["MPLBACKEND"] = "Agg"

if get(ENV, "CI", "false") == "true"
    @info "Running on CI - graphical backend disabled"
end

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
    # MCAR TESTS — test_mcar_means
    # ================================================================

    @testset "MCAR Tests: test_mcar_means" begin

        # ── Common fixtures ──────────────────────────────────────
        Random.seed!(42)
        df_mcar = generate_mcar_data(200, 4, 0.20; seed=42)
        df_mar  = generate_mar_data(200, 4, 0.20; seed=42)
        df_mnar = generate_mnar_data(200, 4, 0.20; seed=42)

        # Complete column for testing on df_mcar
        df_mcar_with_z = copy(df_mcar)
        df_mcar_with_z.z = randn(MersenneTwister(42), 200)

        # ── Test 1: MCAR should not reject ───────────────────────
        @testset "MCAR data — should not reject" begin
            r = test_mcar_means(df_mcar_with_z, :x1, :z)
            @test r.decision == MCAR_NOT_REJECTED
            @test r.pvalue > 0.05
            @test r.test_name == "MCAR Means Test (Welch t-test)"
            @test !isnan(r.statistic)
            @test !isnan(r.pvalue)
        end

        # ── Test 2: MAR should reject ────────────────────────────
        @testset "MAR data — should reject" begin
            r = test_mcar_means(df_mar, :x2, :x1)
            @test r.decision == MCAR_REJECTED
            @test r.pvalue < 0.05
            @test r.details["n_observed"] + r.details["n_missing"] == 200
        end

        # ── Test 3: TestResult structure ─────────────────────────
        @testset "TestResult structure" begin
            r = test_mcar_means(df_mar, :x2, :x1)
            @test haskey(r.details, "n_observed")
            @test haskey(r.details, "n_missing")
            @test haskey(r.details, "mean_observed")
            @test haskey(r.details, "mean_missing")
            @test haskey(r.details, "mean_diff")
            @test r.alpha == 0.05
            @test r.degrees_of_freedom !== nothing
            @test r.degrees_of_freedom > 0                                   
        end

        # ── Test 4: Edge cases ───────────────────────────────────
        @testset "Edge cases" begin
            # Column without missing → INCONCLUSIVE
            df_no_miss = DataFrame(
                a = [1.0, 2.0, 3.0, 4.0],
                b = [5.0, 6.0, 7.0, 8.0]
            )
            r = test_mcar_means(df_no_miss, :a, :b)
            @test r.decision == INCONCLUSIVE

            # col_complete with missing → ArgumentError
            df_both_miss = DataFrame(
                a = [1.0, missing, 3.0],
                b = [missing, 2.0, 3.0]
            )
            @test_throws ArgumentError test_mcar_means(df_both_miss, :a, :b)

            # Nonexistent column → ArgumentError
            @test_throws ArgumentError test_mcar_means(df_mar, :nonexistent, :x1)

            # Same column twice → ArgumentError
            @test_throws ArgumentError test_mcar_means(df_mar, :x1, :x1)
        end

        # ── Test 5: Batch test_all_mcar_means ────────────────────
        @testset "test_all_mcar_means" begin
            results = test_all_mcar_means(df_mar)

            # At least 1 test returned
            @test length(results) >= 1

            # At least 1 rejection on MAR data
            @test any(r -> r.decision == MCAR_REJECTED, results)

            # Results sorted by ascending p-value
            pvals = [r.pvalue for r in results if !isnan(r.pvalue)]
            @test issorted(pvals)

            # Bonferroni correction: adjusted alpha ≤ 0.05
            @test all(r -> r.alpha <= 0.05, results)
        end

        # ── Test 6: No correction ────────────────────────────────
        @testset "test_all_mcar_means no correction" begin
            results = test_all_mcar_means(df_mar; correction=:none)
            @test all(r -> r.alpha == 0.05, results)
        end

        # ── Test 7: Small sample warnings ────────────────────────
        @testset "Small sample warnings" begin
            df_small = DataFrame(
                a = [missing, 1.0, 2.0, missing, 3.0,
                     missing, 4.0, 5.0, missing, 6.0],
                b = collect(1.0:10.0)
            )
            r = test_mcar_means(df_small, :a, :b)
            @test !isempty(r.warnings)
        end

        # ── Test 8: Outlier robustness ───────────────────────────
        @testset "Outlier robustness" begin
            Random.seed!(99)
            df_outlier = generate_mcar_data(200, 2, 0.20; seed=99)
            
            # Add complete column with extreme outliers
            z = randn(MersenneTwister(99), 200)
            z[1] = 1000.0    # extreme outlier
            z[2] = -1000.0   # extreme outlier
            df_outlier.z = z

            r = test_mcar_means(df_outlier, :x1, :z)

            # Test should return valid result, not crash
            @test r isa TestResult
            @test !isnan(r.pvalue)
            @test r.decision ∈ (MCAR_NOT_REJECTED, MCAR_REJECTED, INCONCLUSIVE)
            
            # With outliers on MCAR data, expect valid p-value
            @test r.pvalue >= 0.0
            @test r.pvalue <= 1.0
        end

    end

    # ================================================================
    # MCAR TESTS — summary_table
    # ================================================================

    @testset "summary_table conversion" begin
        Random.seed!(42)
        df_mar = generate_mar_data(200, 4, 0.20; seed=42)
        results = test_all_mcar_means(df_mar)

        # ── Test 1: Returns DataFrame ────────────────────────────
        @testset "Returns DataFrame" begin
            table = summary_table(results)
            @test table isa DataFrame
        end

        # ── Test 2: Has expected columns ─────────────────────────
        @testset "Has expected columns" begin
            table = summary_table(results)
            expected_cols = [:col_missing, :col_complete, :statistic, :pvalue, 
                           :decision, :n_observed, :n_missing, :mean_diff]
            @test all(c ∈ propertynames(table) for c in expected_cols)
        end

        # ── Test 3: Row count matches input ──────────────────────
        @testset "Row count matches" begin
            table = summary_table(results)
            @test nrow(table) == length(results)
        end

        # ── Test 4: Empty input → empty DataFrame ────────────────
        @testset "Empty input" begin
            empty_table = summary_table(TestResult[])
            @test empty_table isa DataFrame
            @test nrow(empty_table) == 0
        end

        # ── Test 5: Decision strings are readable ────────────────
        @testset "Decision formatting" begin
            table = summary_table(results)
            @test all(d ∈ ["MCAR_NOT_REJECTED", "MCAR_REJECTED", "INCONCLUSIVE"] 
                     for d in table.decision)
        end
    end

    # ================================================================
    # MCAR TESTS — test_mcar_logistic
    # ================================================================

    @testset "MCAR Tests: test_mcar_logistic" begin

        # ── Common fixtures ──────────────────────────────────────
        Random.seed!(42)
        df_mcar = generate_mcar_data(200, 4, 0.20; seed=42)
        df_mar  = generate_mar_data(200, 4, 0.20; seed=42)

        # ── Test 1: Basic functionality ──────────────────────────
        @testset "Basic functionality" begin
            r = test_mcar_logistic(df_mar, :x2)
            @test r isa TestResult
            @test r.test_name == "MCAR Logistic Regression Test"
            @test !isnan(r.statistic)
            @test !isnan(r.pvalue)
        end

        # ── Test 2: MAR data — should reject ─────────────────────
        @testset "MAR data — should reject" begin
            r = test_mcar_logistic(df_mar, :x2)
            
            # x1 should predict x2 missingness in MAR data
            @test r.decision == MCAR_REJECTED
            @test r.pvalue < 0.05
            @test r.details["n_observed"] + r.details["n_missing"] == 200
            @test !isempty(r.details["predictors"])
        end

        # ── Test 3: TestResult structure ─────────────────────────
        @testset "TestResult structure" begin
            r = test_mcar_logistic(df_mar, :x2)
            
            @test haskey(r.details, "n_observed")
            @test haskey(r.details, "n_missing")
            @test haskey(r.details, "col_missing")
            @test haskey(r.details, "predictors")           
            @test haskey(r.details, "min_pvalue")
            @test haskey(r.details, "global_pvalue")
            @test haskey(r.details, "lr_statistic")
            @test haskey(r.details, "significant_predictors")
            @test haskey(r.details, "n_significant")
            @test haskey(r.details, "model_deviance")
            @test haskey(r.details, "formula")
            
            @test r.alpha == 0.05
            @test r.degrees_of_freedom isa Float64
            @test r.degrees_of_freedom > 0
        end

        # ── Test 4: Edge cases ───────────────────────────────────
        @testset "Edge cases" begin
            # No missing values → INCONCLUSIVE
            df_no_miss = DataFrame(
                a = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0],
                b = [5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0]
            )
            r = test_mcar_logistic(df_no_miss, :a)
            @test r.decision == INCONCLUSIVE
            @test occursin("No missing", r.warnings[1])

            # All missing → INCONCLUSIVE
            df_all_miss = DataFrame(
                a = [missing, missing, missing, missing, missing, missing, missing, missing, missing, missing],
                b = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            )
            r_all = test_mcar_logistic(df_all_miss, :a)
            @test r_all.decision == INCONCLUSIVE

            # No fully observed predictors → INCONCLUSIVE
            df_no_pred = DataFrame(
                a = [1.0, missing, 3.0, 4.0, missing, 6.0, 7.0, missing, 9.0, 10.0],
                b = [missing, 2.0, 3.0, missing, 5.0, 6.0, missing, 8.0, 9.0, missing],
                c = [1.0, missing, 3.0, 4.0, missing, 6.0, 7.0, missing, 9.0, 10.0]
            )
            r_no_pred = test_mcar_logistic(df_no_pred, :a)
            @test r_no_pred.decision == INCONCLUSIVE
            @test occursin("predictor columns available", r_no_pred.warnings[1])

            # Nonexistent column → ArgumentError
            @test_throws ArgumentError test_mcar_logistic(df_mar, :nonexistent)

            # Too few observations → ArgumentError
            df_tiny = DataFrame(a = [missing, 1.0], b = [2.0, 3.0])
            @test_throws ArgumentError test_mcar_logistic(df_tiny, :a)
        end

        # ── Test 5: Significant predictors extraction ────────────
        @testset "Significant predictors extraction" begin
            r = test_mcar_logistic(df_mar, :x2)
            
            if r.decision == MCAR_REJECTED
                @test r.details["n_significant"] >= 1
                @test length(r.details["significant_predictors"]) >= 1
                
                # Check structure of significant_predictors
                for pred in r.details["significant_predictors"]
                    @test haskey(pred, "variable")
                    @test haskey(pred, "coefficient")
                    @test haskey(pred, "pvalue")
                    @test haskey(pred, "odds_ratio")
                    @test pred["pvalue"] < 0.05
                end
            end
        end

        # ── Test 6: Exclude columns functionality ────────────────
        @testset "Exclude columns" begin
            # Create dataset with 3 complete columns
            df_multi = DataFrame(
                target = [missing, 1.0, 2.0, missing, 3.0, 4.0, missing, 5.0, 6.0, 7.0,
                         missing, 8.0, 9.0, missing, 10.0],
                pred1 = collect(10.0:10.0:150.0),
                pred2 = collect(100.0:100.0:1500.0),
                pred3 = repeat(["A", "B", "C"], 5)
            )
            
            # Test without exclusion
            r1 = test_mcar_logistic(df_multi, :target)
            @test "pred1" ∈ r1.details["predictors"]
            @test "pred2" ∈ r1.details["predictors"]
            
            # Test with exclusion
            r2 = test_mcar_logistic(df_multi, :target, exclude_cols=[:pred2])
            @test "pred1" ∈ r2.details["predictors"]
            @test "pred2" ∉ r2.details["predictors"]
        end

        # ── Test 7: Small sample warnings ─────────────────────────
        @testset "Small sample warnings" begin
            df_small = DataFrame(
                a = [missing, 1.0, 2.0, missing, 3.0, 4.0, missing, 5.0, 6.0, 7.0],
                b = collect(1.0:10.0)
            )
            r = test_mcar_logistic(df_small, :a)
            @test !isempty(r.warnings)
            @test any(w -> occursin("Small sample", w), r.warnings)
        end

        # ── Test 8: Categorical predictors ───────────────────────
        @testset "Categorical predictors" begin
            df_cat = DataFrame(
                age = [25, missing, 30, missing, 35, 40, missing, 45, 50, missing,
                       28, 32, missing, 38, 42],
                income = Float64.(30000:5000:100000),
                gender = repeat(["M", "F"], 8)[1:15]  
            )

            r = test_mcar_logistic(df_cat, :age)
            
            # Should handle categorical predictor
            @test r isa TestResult
            @test !isnan(r.pvalue)
            
            # Formula should include gender
            @test occursin("gender", r.details["formula"])
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