# Installation

## Prerequisite
In order to use the **Gnuplot.jl** package you'll need [`gnuplot`](http://gnuplot.info/) (ver. >= 5.0) installed on your system, and its executable available in your path.

If `gnuplot` is not available in your platform you can still use **Gnuplot.jl** in "*dry*" mode (see [Dry sessions](@ref)).  In this case a plot can not be generated, but you may still generate [Gnuplot scripts](@ref).

## Package installation
In the Julia REPL type:
```julia-repl
julia> ]add Gnuplot
```
Then hit backspace key to return to Julia REPL.

## Check installation
Check execution and version of the underlying `gnuplot` process:
```@repl
using Gnuplot
Gnuplot.gpversion()
```

Generate the first plot:
```julia-repl
julia> @gp 1:9
```

Test default terminal capabilities:
```julia-repl
test_terminal()
```
