# Installation

## Prerequisite
In order to use the **Gnuplot.jl** package you'll need [`gnuplot`](http://gnuplot.info/) (ver. >= 5.0) installed on your system, and its executable available in your path.

If `gnuplot` is not available in your platform you can still use **Gnuplot.jl** in "*dry*" mode (see [Dry sessions](@ref)).  In this case a plot can not be generated, but you may still generate [Gnuplot scripts](@ref).

## Package installation
In the Julia REPL type:
```julia-repl
julia> ]add Gnuplot
```
The `]` character starts the Julia [package manager](https://julialang.github.io/Pkg.jl/v1/getting-started.html#Basic-Usage-1). Hit backspace key to return to Julia prompt.


## Check installation

Check **Gnuplot.jl** version with:
```julia-repl
julia> ]st Gnuplot
Status `~/.julia/environments/v1.4/Project.toml`
  [dc211083] Gnuplot v1.3.0
```
If the displayed version is not `v1.3.0` you are probably having a dependency conflict.  In this case try forcing installation of the latest version with:
```julia-repl
julia> ]add Gnuplot@1.3.0
```
and check which package is causing the conflict.



Check execution and version of the underlying `gnuplot` process:
```@repl
using Gnuplot
Gnuplot.gpversion()
```
The minimum required version is `v5.0`.


Generate the first plot:
```julia-repl
julia> @gp 1:9
```

Test default terminal capabilities:
```julia-repl
test_terminal()
```
