using MissingDataViz
using Documenter

DocMeta.setdocmeta!(MissingDataViz, :DocTestSetup, :(using MissingDataViz); recursive=true)

makedocs(;
    modules=[MissingDataViz],
    authors="Rene Fassou Ballamou and collaborators <renefassouballamou96@gmail.com>",
    sitename="MissingDataViz.jl",
    format=Documenter.HTML(;
        canonical="https://DescarteS96.github.io/MissingDataViz.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/DescarteS96/MissingDataViz.jl",
    devbranch="master",
)
