using Documenter, Gnuplot

makedocs(sitename="Gnuplot.jl",
         authors = "Giorgio Calderone",
         #format = Documenter.HTML(prettyurls = false),  # uncomment for local use, comment for deployment
         modules=[Gnuplot],
         pages = [
             "Home" => "index.md",
             "Installation" => "install.md",
             "Basic usage" => "basic.md",
             "Advanced usage" => "advanced.md",
             "Gnuplot terminals" => "terminals.md",
             "Examples" => "examples.md",
             "API" => "api.md"
         ])
