using Documenter, Gnuplot
empty!(Gnuplot.options.mime)

makedocs(sitename="Gnuplot.jl",
         authors = "Giorgio Calderone",
         #format = Documenter.HTML(prettyurls = false),  # uncomment for local use, comment for deployment
         modules=[Gnuplot],
         pages = [
             "Home" => "index.md",
             "Installation" => "install.md",
             "Basic usage" => "basic.md",
             "Advanced usage" => "advanced.md",
             "Package options" => "options.md",
             "Style guide" => "style.md",
             "Gnuplot terminals" => "terminals.md",
             "Plot recipes" => "recipes.md",
             "Examples" => "examples.md",
             "API" => "api.md"
         ])
