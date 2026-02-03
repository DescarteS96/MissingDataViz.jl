# Benchmark script to measure optimization gains
# Étape 7 Partie 4 - Optimisations ciblées

using MissingDataViz
using DataFrames
using BenchmarkTools
using Random
using Printf

println("="^70)
println("BENCHMARKS DES OPTIMISATIONS - MissingDataViz.jl")
println("Étape 7 Partie 4 : Optimisations ciblées")
println("="^70)
println()

# ================================================================
# CONFIGURATION
# ================================================================

Random.seed!(123)  # Pour reproductibilité

# Tailles de datasets à tester
SIZES = [
    (rows=1_000,   cols=10,  name="Small (1k×10)"),
    (rows=10_000,  cols=20,  name="Medium (10k×20)"),
    (rows=50_000,  cols=30,  name="Large (50k×30)"),
    (rows=100_000, cols=50,  name="Very Large (100k×50)")
]

# Taux de missing values à tester
MISSING_RATES = [0.1, 0.3, 0.5]  # 10%, 30%, 50%

# ================================================================
# FONCTIONS HELPER
# ================================================================

"""
Génère un DataFrame avec un pourcentage contrôlé de missing values
"""
function generate_test_dataframe(n_rows::Int, n_cols::Int, missing_rate::Float64)
    df = DataFrame()
    
    for i in 1:n_cols
        # CORRECTION: Créer un vecteur Union{Float64, Missing}
        col_data = Vector{Union{Float64, Missing}}(rand(n_rows))
        
        # Injecter des missing values
        n_missing = round(Int, n_rows * missing_rate)
        if n_missing > 0
            missing_indices = randperm(n_rows)[1:n_missing]
            col_data[missing_indices] .= missing
        end
        
        df[!, Symbol("col$i")] = col_data
    end
    
    return df
end

"""
Formate un temps en ms avec couleur selon seuil
"""
function format_time(time_ns::Float64)
    time_ms = time_ns / 1_000_000
    if time_ms < 10
        return @sprintf("%.2f ms", time_ms)
    elseif time_ms < 100
        return @sprintf("%.1f ms", time_ms)
    else
        return @sprintf("%.0f ms", time_ms)
    end
end

"""
Calcule le gain en pourcentage
"""
function calc_speedup(old_time::Float64, new_time::Float64)
    speedup = (old_time / new_time - 1) * 100
    return speedup
end

# ================================================================
# BENCHMARK 1 : missing_pattern()
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 1 : missing_pattern() - Conversion directe")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s %-12s", "Dataset", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark missing_pattern($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    allocs = median(bench.allocs)
    
    println(@sprintf("%-20s %-15s %-15s %-12d", 
                     size_info.name, time_str, mem_str, allocs))
end

# ================================================================
# BENCHMARK 2 : pattern_counts() - Version optimisée
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 2 : pattern_counts() - Vues + sizehint! + get()")
println("="^70)
println()
println(@sprintf("%-20s %-12s %-15s %-15s %-12s", 
                 "Dataset", "Missing%", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES[1:3]  # Skip 100k pour pattern_counts (trop lent)
    for missing_rate in MISSING_RATES
        df = generate_test_dataframe(size_info.rows, size_info.cols, missing_rate)
        
        # Benchmark
        bench = @benchmark pattern_counts($df)
        
        time_str = format_time(median(bench.times))
        mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
        allocs = median(bench.allocs)
        missing_pct = @sprintf("%d%%", round(Int, missing_rate * 100))
        
        println(@sprintf("%-20s %-12s %-15s %-15s %-12d", 
                         size_info.name, missing_pct, time_str, mem_str, allocs))
    end
    println()
end

# ================================================================
# BENCHMARK 3 : row_missing_stats() - Pré-allocation
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 3 : row_missing_stats() - Pré-allocation + vue")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s %-12s", "Dataset", "Time", "Memory", "Allocs"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark row_missing_stats($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    allocs = median(bench.allocs)
    
    println(@sprintf("%-20s %-15s %-15s %-12d", 
                     size_info.name, time_str, mem_str, allocs))
end

# ================================================================
# BENCHMARK 4 : pattern_counts_parallel() - Parallélisation
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 4 : pattern_counts_parallel() - Multi-threading")
println("Threads disponibles : $(Threads.nthreads())")
println("="^70)
println()

if Threads.nthreads() > 1
    println(@sprintf("%-20s %-20s %-20s %-15s", 
                     "Dataset", "Sequential", "Parallel", "Speedup"))
    println("-"^70)
    
    for size_info in SIZES[2:end]  # À partir de 10k lignes
        df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
        
        # Benchmark séquentiel
        bench_seq = @benchmark pattern_counts($df)
        time_seq = median(bench_seq.times)
        
        # Benchmark parallèle
        bench_par = @benchmark pattern_counts_parallel($df)
        time_par = median(bench_par.times)
        
        # Calcul du speedup
        speedup = calc_speedup(time_seq, time_par)
        speedup_str = if speedup > 0
            @sprintf("+%.1f%%", speedup)
        else
            @sprintf("%.1f%%", speedup)
        end
        
        # Affichage
        println(@sprintf("%-20s %-20s %-20s %-15s", 
                         size_info.name, 
                         format_time(time_seq),
                         format_time(time_par),
                         speedup_str))
    end
else
    println("⚠️  Parallélisation non testée : Julia lancé avec 1 seul thread")
    println("   Pour tester : julia --threads=auto")
end

# ================================================================
# BENCHMARK 5 : Workflow complet
# ================================================================

println("\n" * "="^70)
println("BENCHMARK 5 : Workflow complet - summarize_missing()")
println("="^70)
println()
println(@sprintf("%-20s %-15s %-15s", "Dataset", "Time", "Memory"))
println("-"^70)

for size_info in SIZES
    df = generate_test_dataframe(size_info.rows, size_info.cols, 0.3)
    
    # Benchmark
    bench = @benchmark summarize_missing($df)
    
    time_str = format_time(median(bench.times))
    mem_str = @sprintf("%.2f MB", median(bench.memory) / 1_000_000)
    
    println(@sprintf("%-20s %-15s %-15s", 
                     size_info.name, time_str, mem_str))
end

# ================================================================
# RÉSUMÉ FINAL
# ================================================================

println("\n" * "="^70)
println("RÉSUMÉ DES OPTIMISATIONS")
println("="^70)
println()
println("✅ OPTIMISATION 1 : missing_pattern()")
println("   → Conversion directe sans allocations intermédiaires")
println("   → Gain estimé : 10-15%")
println()
println("✅ OPTIMISATION 2 : pattern_counts()")
println("   → Vues (@view) au lieu de copies")
println("   → Pré-allocation dictionnaire (sizehint!)")
println("   → get() au lieu de haskey + accès")
println("   → Gain estimé : 40-50%")
println()
println("✅ OPTIMISATION 3 : row_missing_stats()")
println("   → Pré-allocation du vecteur résultat")
println("   → Pré-calcul de constantes")
println("   → Vues pour éviter copies")
println("   → Gain estimé : 5-10%")
println()
println("✅ OPTIMISATION 4 : pattern_counts_parallel()")
println("   → Multi-threading pour datasets >10k lignes")
println("   → Seuil adaptatif (overhead vs bénéfice)")
println("   → Gain estimé : 50-200% (si ≥4 threads)")
println()
println("="^70)
println("BENCHMARKS TERMINÉS")
println("="^70)