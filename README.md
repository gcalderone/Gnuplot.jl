# Gnuplot.jl
## A Julia interface to gnuplot.

[![CI](https://github.com/gcalderone/Gnuplot.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/gcalderone/Gnuplot.jl/actions/workflows/CI.yml)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![DocumentationStatus](https://img.shields.io/badge/docs-stable-blue.svg?style=flat)](https://gcalderone.github.io/Gnuplot.jl/stable/index.html)

**Gnuplot.jl** is a simple package able to send both data and commands from Julia to an underlying [gnuplot](http://gnuplot.sourceforge.net/) process.  Its main purpose it to provide a fast and powerful data visualization framework, using an extremely concise Julia syntax. It also has automatic display of plots in Jupyter, Juno and VS Code.

> [!NOTE]
> New examples added in the following sections of the documentation:
> - Basic usage -> Transparency
> - Advanced usage -> Animations

> [!WARNING]
> The code in version 1.6.0 underwent a signficant refactoring, and a few minor details may potentially break your code.
> **Please have a look at ChangeLog.md !!**

## Installation

Install with:
```julia
]add Gnuplot
```
A working [gnuplot](http://gnuplot.sourceforge.net/) package must be installed on your platform.

Test package:
```julia
using Gnuplot
println(Gnuplot.gpversion())
test_terminal()
```


## Quick start
The following examples are supposed to be self-explaining.  See [documentation](https://gcalderone.github.io/Gnuplot.jl/) for further informations.

### A simple parabola
```julia
x = 1.:20
@gp x x.^2 "with lines title 'Parabola'"
Gnuplot.save("examples/ex1.png", term="pngcairo size 480,360")
Gnuplot.savescript("examples/parabola.gp")  # => save a script file with both data and command to re-create the plot.
```
![ex1.png](examples/ex1.png)


### A slightly more complex plot, with unicode on X tics
```julia
x = -2pi:0.1:2pi
approx = fill(0., length(x));
@gp tit="Polynomial approximation of sin(x)" key="opaque" linetypes(:Blues_4)
@gp :- "set encoding utf8" raw"""set xtics ('-π' -pi, '-π/2' -pi/2, 0, 'π/2' pi/2, 'π' pi)"""
@gp :- xr=3.8.*[-1, 1] yr=[-1.5,1.5] "set grid front"
@gp :- x sin.(x) approx .+=  x          "w filledcurve t 'n=0' lt 1"
@gp :- x sin.(x) approx .+= -x.^3/6     "w filledcurve t 'n=1' lt 2"
@gp :- x sin.(x) approx .+=  x.^5/120   "w filledcurve t 'n=2' lt 3"
@gp :- x sin.(x) approx .+= -x.^7/5040  "w filledcurve t 'n=3' lt 4"
@gp :- x sin.(x)                        "w l t 'sin(x)' lw 2 lc rgb 'black'"
Gnuplot.save("examples/ex2.png", term="pngcairo size 640,480")
```
![ex2.png](examples/ex2.png)


### Multiplot: a 2D histogram contour plot and a 3D surface plot
```julia
x = randn(10_000)
y = randn(10_000)
h = hist(x, y, bs1=0.25, nbins2=20)
@gp "set multiplot layout 1,2"
@gp :- 1 key="outside top center box horizontal" "set size ratio -1" h
clines = contourlines(h, "levels discrete 10, 30, 60, 90");
for i in 1:length(clines)
    @gp :- clines[i].data "w l t '$(clines[i].z)' lw $i lc rgb 'gray'" :-
end
@gsp :- 2 hist_bins(h, 1) hist_bins(h, 2) hist_weights(h) "w pm3d notit"
Gnuplot.save("examples/ex3.png", term="pngcairo size 660,350 fontscale 0.8")
```
![ex3.png](examples/ex3.png)


## Further examples
The main gallery of examples is maintained in a separate repository:
https://lazarusa.github.io/gnuplot-examples/

Since **Gnuplot.jl** is just a transparent interface (not a wrapper) it exposes all capabilities of the underlying gnuplot process, hence pure-gnuplot examples also applies to **Gnuplot.jl**.  Further examples are available here:
- https://gnuplot.sourceforge.net/demo_6.0/
- http://www.gnuplotting.org/
