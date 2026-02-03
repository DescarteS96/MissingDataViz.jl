# Force package path resolution
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using MissingDataViz
using Documenter

DocMeta.setdocmeta!(MissingDataViz, :DocTestSetup, :(using MissingDataViz); recursive=true)

makedocs(;
    modules=[MissingDataViz],
    authors="Rene Fassou Ballamou and collaborators <renefassouballamou96@gmail.com>",
    sitename="MissingDataViz.jl",
    clean=false,  # Prevent build/ deletion issues
    format=Documenter.HTML(;
        canonical="https://DescarteS96.github.io/MissingDataViz.jl",
        edit_link="master",
        assets=String[],
        ansicolor=true,
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",  
        "User Guide" => "guide.md",
        "API Reference" => "api.md",
    ],
    checkdocs=:exports,
    warnonly=true,  # Don't fail on missing docs during development
)

deploydocs(;
    repo="github.com/DescarteS96/MissingDataViz.jl",
    devbranch="master",
    push_preview=true,
)