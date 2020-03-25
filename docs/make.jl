using Documenter, Gnuplot

makedocs(sitename="Gnuplot.jl",
         authors = "Giorgio Calderone",
         format = Documenter.HTML(prettyurls = false),  # uncomment for local use, comment for deployment
         modules=[Gnuplot],
         pages = [
             "Home" => "index.md",
             "Installation" => "install.md",
             "Basic usage" => "basic.md",
             "Advanced techniques" => "advanced.md",
             "Tips" => "tips.md",
             "Examples" => "examples.md",
             "API" => "api.md"
         ])

#=
- Make documentation:
cd <repo>/docs
julia --color=yes make.jl


- Workflow to prepare `gh-pages` branch:

Change to a temporary directory, then:
git clone --no-checkout https://github.com/gcalderone/Gnuplot.jl.git
git checkout --orphan gh-pages
git rm -rf .

Now copy the documentation "build" directory into, e.g., "dev", then
git add dev/*
git commit -m 'First commit'
git push origin gh-pages


- Workflow to push changes to `gh-pages` branch:
Change to a temporary directory, then:
git clone --single-branch --branch gh-pages  https://github.com/gcalderone/Gnuplot.jl.git

Now copy the documentation "build" directory into, e.g., "dev", then
git add dev/*
git commit -m 'Docs updated'
git push origin gh-pages

- Documentation will be available online at:
https://gcalderone.github.io/Gnuplot.jl/dev
=#
