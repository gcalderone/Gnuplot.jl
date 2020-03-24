using Documenter, Gnuplot

makedocs(sitename="Gnuplot.jl",
         #format = Documenter.HTML(prettyurls = false),
         modules=[Gnuplot],
         pages = [
             "Home" => "index.md",
             "Installation" => "install.md",
             "Basic usage" => "basic.md",
             "Advanced usage" => "advanced.md",
             "Examples" => "examples.md",
             "API" => "api.md"
         ])
