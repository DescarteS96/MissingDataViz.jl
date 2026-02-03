# Missing data pattern detection and analysis module

"""
    PatternInfo

Structure to store information about a specific missing data pattern.

# Fields
- `pattern::Vector{Bool}`: The binary pattern (true = missing, false = present)
- `count::Int`: Number of rows with this pattern
- `frequency::Float64`: Percentage of rows with this pattern (0.0 to 100.0)
- `row_indices::Vector{Int}`: Indices of rows that have this pattern

# Examples
```julia
info = PatternInfo(
    pattern = [true, false, true],
    count = 5,
    frequency = 25.0,
    row_indices = [2, 7, 10, 15, 18]
)
```
"""
struct PatternInfo
    pattern::Vector{Bool}
    count::Int
    frequency::Float64
    row_indices::Vector{Int}
end

# Custom display for PatternInfo
function Base.show(io::IO, info::PatternInfo)
    pattern_str = join(Int.(info.pattern), "")
    print(io, "PatternInfo(pattern=$pattern_str, count=$(info.count), freq=$(round(info.frequency, digits=2))%)")
end


"""
    missing_pattern(df::DataFrame) → BitMatrix

Converts a DataFrame to a binary matrix (true = missing, false = present).
OPTIMIZED: Uses Julia's efficient broadcast for minimal allocations.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `BitMatrix`: Binary matrix with same dimensions as df (true = missing, false = present)

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[4, 5, missing])
pattern = missing_pattern(df)
# 3×2 BitMatrix:
#  0  0
#  1  0
#  0  1
```
"""
function missing_pattern(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # OPTIMISATION: Broadcast direct - Julia gère l'optimisation
    # Cette approche minimise les allocations et est plus rapide
    # que les boucles manuelles pour ce cas d'usage
    pattern = BitMatrix(Matrix(ismissing.(df)))
    
    return pattern
end


"""
    missing_count(df::DataFrame) → Vector{Int}

Counts the absolute number of missing values per column.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Vector{Int}`: Number of missing values for each column

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[missing, missing, 6])
counts = missing_count(df)  # [1, 2]
```
"""
function missing_count(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # Get binary pattern matrix
    pattern = missing_pattern(df)
    
    # Sum columns
    counts = vec(sum(pattern, dims=1))
    
    return counts
end


"""
    missing_percentage(df::DataFrame) → Vector{Float64}

Calculates the percentage of missing values per column.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Vector{Float64}`: Percentages (0.0 to 100.0) for each column

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[4, 5, 6])
pct = missing_percentage(df)  # [33.33, 0.0]
```
"""
function missing_percentage(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # Get counts
    counts = missing_count(df)
    
    # Calculate percentages
    percentages = (counts ./ nrow(df)) .* 100.0
    
    return percentages
end


"""
    pattern_counts(df::DataFrame) → Dict{Vector{Bool}, Int}

Identifies unique missing data patterns and counts their occurrences.
OPTIMIZED: Uses views, pre-allocation, and get() for better performance.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Dict{Vector{Bool}, Int}`: Dictionary mapping each unique pattern to its count

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3, missing], B=[missing, 2, missing, 2])
counts = pattern_counts(df)
# Dict with patterns as keys, counts as values
```
"""
function pattern_counts(df::DataFrame)
    # ========================================
    # VALIDATION
    # ========================================
    validate_dataframe(df)
    
    # Warn for large datasets
    if nrow(df) > 50_000
        @warn "Dataset contains $(nrow(df)) rows. Pattern counting may take several seconds." maxlog=1
    end
    
    # ========================================
    # OPTIMIZED IMPLEMENTATION
    # ========================================
    
    # Get binary pattern matrix
    pattern_matrix = missing_pattern(df)
    n_rows = size(pattern_matrix, 1)
    
    # OPTIMISATION 1: Pré-allocation avec hint de capacité
    # On s'attend rarement à plus de 1000 patterns uniques
    counts = Dict{Vector{Bool}, Int}()
    sizehint!(counts, min(n_rows, 1000))
    
    # OPTIMISATION 2: Vue + get() au lieu de haskey
    for i in 1:n_rows
        # @view évite la copie, collect() fait une seule allocation
        row_pattern = collect(@view pattern_matrix[i, :])
        
        # get() avec valeur par défaut est plus rapide que haskey + accès
        counts[row_pattern] = get(counts, row_pattern, 0) + 1
    end
    
    return counts
end


"""
    pattern_counts_parallel(df::DataFrame) → Dict{Vector{Bool}, Int}

Parallel version of pattern_counts for large datasets (>10k rows).
Uses multi-threading for significant performance gains on multi-core systems.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Dict{Vector{Bool}, Int}`: Dictionary mapping each unique pattern to its count

# Performance
- Recommended for datasets >10k rows with ≥4 CPU cores
- Falls back to sequential version for small datasets (overhead > benefit)
"""
function pattern_counts_parallel(df::DataFrame)
    validate_dataframe(df)
    
    pattern_matrix = missing_pattern(df)
    n_rows = size(pattern_matrix, 1)
    
    # OPTIMISATION: Seuil pour parallélisation
    # En dessous de 10k lignes, overhead > bénéfice
    if n_rows < 10_000 || Threads.nthreads() == 1
        # Utiliser version séquentielle optimisée
        return pattern_counts(df)
    end
    
    # Division du travail par thread
    n_threads = Threads.nthreads()
    local_counts = [Dict{Vector{Bool}, Int}() for _ in 1:n_threads]
    
    # Pré-allocation des dictionnaires locaux
    for i in 1:n_threads
        sizehint!(local_counts[i], div(n_rows, n_threads) + 100)
    end
    
    # OPTIMISATION: Traitement parallèle
    Threads.@threads for i in 1:n_rows
        tid = Threads.threadid()
        row_pattern = collect(@view pattern_matrix[i, :])
        local_counts[tid][row_pattern] = get(local_counts[tid], row_pattern, 0) + 1
    end
    
    # Fusion des résultats locaux
    final_counts = Dict{Vector{Bool}, Int}()
    sizehint!(final_counts, sum(length, local_counts))
    
    for local_dict in local_counts
        for (pattern, count) in local_dict
            final_counts[pattern] = get(final_counts, pattern, 0) + count
        end
    end
    
    return final_counts
end


"""
    pattern_frequency(df::DataFrame) → Vector{Tuple{Vector{Bool}, Int}}

Returns unique patterns sorted by frequency (most common first).

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Vector{Tuple{Vector{Bool}, Int}}`: Vector of (pattern, count) tuples sorted by count descending

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[missing, 2, missing])
freq = pattern_frequency(df)
# [(pattern1, count1), (pattern2, count2), ...] sorted by count
```
"""
function pattern_frequency(df::DataFrame)
    # Get pattern counts (uses optimized version)
    counts = pattern_counts(df)
    
    # Convert Dict to Vector of tuples
    freq_vec = collect(counts)
    
    # Sort by count (descending order)
    sort!(freq_vec, by = x -> x[2], rev = true)
    
    return freq_vec
end


"""
    row_missing_stats(df::DataFrame) → Vector{Float64}

Calculates the percentage of missing values for each row.
OPTIMIZED: Pre-allocation and single-pass calculation.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `Vector{Float64}`: Percentage of missing values per row (0.0 to 100.0)

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[missing, 2, missing])
row_stats = row_missing_stats(df)
# [50.0, 50.0, 50.0]  (each row has 1 out of 2 missing)
```
"""
function row_missing_stats(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # Get binary pattern matrix
    pattern = missing_pattern(df)
    n_rows, n_cols = size(pattern)
    
    # OPTIMISATION 1: Pré-allocation du résultat
    row_percentages = Vector{Float64}(undef, n_rows)
    
    # OPTIMISATION 2: Pré-calcul de la constante
    inv_ncols_100 = 100.0 / n_cols
    
    # OPTIMISATION 3: Calcul direct en une passe avec vue
    for i in 1:n_rows
        row_sum = sum(@view pattern[i, :])
        @inbounds row_percentages[i] = row_sum * inv_ncols_100
    end
    
    return row_percentages
end


"""
    column_missing_distribution(df::DataFrame) → DataFrame

Creates a detailed distribution table of missing values by column.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `DataFrame`: Table with columns `column_name`, `n_missing`, `pct_missing`, `n_present`

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[4, 5, 6])
dist = column_missing_distribution(df)
# 2×4 DataFrame with distribution stats
```
"""
function column_missing_distribution(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # Get column names
    col_names = names(df)
    
    # Get missing counts and percentages
    n_missing = missing_count(df)
    pct_missing = missing_percentage(df)
    
    # Calculate number of present values
    n_present = nrow(df) .- n_missing
    
    # Create result DataFrame
    result = DataFrame(
        column_name = col_names,
        n_missing = n_missing,
        pct_missing = pct_missing,
        n_present = n_present
    )
    
    return result
end


"""
    extreme_patterns(df::DataFrame) → NamedTuple

Identifies extreme cases: rows/columns that are 100% missing or 100% complete.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `NamedTuple` with fields:
  - `rows_all_missing::Vector{Int}`: Row indices where all values are missing
  - `rows_all_complete::Vector{Int}`: Row indices where no values are missing
  - `cols_all_missing::Vector{Int}`: Column indices where all values are missing
  - `cols_all_complete::Vector{Int}`: Column indices where no values are missing

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[missing, 1], B=[missing, missing])
extremes = extreme_patterns(df)
# extremes.rows_all_missing == [1]
# extremes.cols_all_missing == [2]
```
"""
function extreme_patterns(df::DataFrame)
    # Validate DataFrame
    validate_dataframe(df)
    
    # Get statistics
    row_pcts = row_missing_stats(df)
    col_pcts = missing_percentage(df)
    
    # Identify extreme rows
    rows_all_missing = findall(x -> x == 100.0, row_pcts)
    rows_all_complete = findall(x -> x == 0.0, row_pcts)
    
    # Identify extreme columns
    cols_all_missing = findall(x -> x == 100.0, col_pcts)
    cols_all_complete = findall(x -> x == 0.0, col_pcts)
    
    # Return as NamedTuple for clean access
    return (
        rows_all_missing = rows_all_missing,
        rows_all_complete = rows_all_complete,
        cols_all_missing = cols_all_missing,
        cols_all_complete = cols_all_complete
    )
end


"""
    summarize_missing(df::DataFrame) → NamedTuple

Generates a comprehensive summary of missing data patterns and statistics.

# Arguments
- `df::DataFrame`: DataFrame to analyze

# Returns
- `NamedTuple` containing:
  - `total_cells::Int`: Total number of cells in DataFrame
  - `n_missing::Int`: Total number of missing values
  - `pct_missing::Float64`: Overall percentage of missing values
  - `by_column::DataFrame`: Distribution statistics by column
  - `by_row::Vector{Float64}`: Percentage missing per row
  - `extremes::NamedTuple`: Extreme patterns (all missing/complete rows/cols)
  - `top_patterns::Vector`: Top 5 most frequent patterns

# Throws
- `ArgumentError`: If df is empty

# Examples
```julia
df = DataFrame(A=[1, missing, 3], B=[4, 5, missing])
summary = summarize_missing(df)
println("Total missing: ", summary.n_missing)
println("By column: ", summary.by_column)
```
"""
function summarize_missing(df::DataFrame)
    # ========================================
    # VALIDATION
    # ========================================
    validate_dataframe(df)
    
    # ========================================
    # IMPLEMENTATION
    # ========================================
    
    # Overall statistics
    total_cells = nrow(df) * ncol(df)
    pattern = missing_pattern(df)
    n_missing = sum(pattern)
    pct_missing = (n_missing / total_cells) * 100.0
    
    # Statistics by dimension
    by_column = column_missing_distribution(df)
    by_row = row_missing_stats(df)
    
    # Extreme cases
    extremes = extreme_patterns(df)
    
    # Top patterns
    freq = pattern_frequency(df)
    # Take top 5 patterns (or fewer if less than 5 unique patterns)
    n_top = min(5, length(freq))
    top_patterns = freq[1:n_top]
    
    # Return comprehensive summary
    return (
        total_cells = total_cells,
        n_missing = n_missing,
        pct_missing = round(pct_missing, digits=2),
        
        by_column = by_column,
        by_row = by_row,
        
        extremes = extremes,
        top_patterns = top_patterns
    )
end