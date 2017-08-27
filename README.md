# Gnuplot.jl
## A Julia interface to Gnuplot.

[![Build Status](https://travis-ci.org/gcalderone/Gnuplot.jl.svg?branch=master)](https://travis-ci.org/gcalderone/Gnuplot.jl)

**Gnuplot.jl** allows easy and fast use
of [Gnuplot](http://gnuplot.info/) as data visualization tool in
Julia.  Its main features are:

- transparent interface between Julia and gnuplot to exploit all
  functionalities of the latter, both present and future ones;
  
- fast data transmission to gnuplot through system pipes (no temporary
  files involved);
  
- support for running multiple gnuplot process simulatneously;

- support for multiplots;

- extremely concise syntax (see examples below), makes it ideal for
  interactive data exploration;

- very easy to use: if you know gnuplot you're ready to go.


The purpose is similar to
the [Gaston](https://github.com/mbaz/Gaston.jl) package, but
**Gnuplot.jl** main focus is on on the syntax conciseness and ease of
use.


## Installation
In the Julia REPL type:

``` julia
Pkg.clone("https://github.com/gcalderone/Gnuplot.jl.git")
```

You'll also need gnuplot (ver. >= 4.7) installed on your system.


## Quick start:
Here we will show a very basic usage:

``` Julia
using Gnuplot

# Create some noisy data...
x = collect(linspace(-2pi, 2pi, 100))
y = 1.5 * sin.(0.3 + 0.7x) 
noise = randn(length(x))./2
e = 0.5 * ones(x)

# ...and show them using gnuplot.
@gp("set key horizontal", "set grid",
    xrange=(-7,7), ylab="Y label",
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'")
```
That's it for the first plot, the syntax should be familiar to most
gnuplot users.  With this code we:
- set a few gnuplot properties (`key` and `grid`);
- set the X axis range and Y axis label;
- passed the data to gnuplot;
- plot two data sets specifying a few details (style, line
  width, color, legend, etc...).

Note that this simple example already covers the vast majority of use
cases, since the remaining details of the plot can be easily tweaked
by adding the appropriate gnuplot command.  Also note that you would
barely recognize the Julia language by just looking at the `@gp` call
since **Gnuplot.jl** aims to be mostly transparent: the user is
supposed to focus only on the data and on the gnuplot commands, rather
than the package details.

Before proceeding we will brief discuss the four symbols exported
by the package:
- `@gp`: the *swiss army knife* of the package, it allows to send
  command and data to gnuplot, and produce very complex plots;
- `@gpi`: very similar to `@gp`, but it allows to build a plot in
  several calls, rather than a single `@gp` call;
- `@gp_str`: run simple gnuplot commands
  using
  [non-standard string literal](https://docs.julialang.org/en/stable/manual/strings/#non-standard-string-literals-1),
  e.g.
``` Julia
gp"print GPVAL_TERM"
```
- `@gp_cmd`: load a gnuplot script file using a non-standard string literal, e.g.
``` Julia
gp`test.gp`
```

The last two macros are supposed to be used only in the REPL, not in
Julia function.  As you can see there is not much more to know before
starting *gnuplotting*!

Clearly, the **Gnuplot.jl** package hides much more under the hood.

Now let's discuss some more advanced usage: fit the data (with
gnuplot) and overplot the results.
``` Julia
const gp = Gnuplot  # use an alias for the package name to quickly
                    # access non exported symbols.
                    
# Define the fitting function and set guess param.
gp.cmd("f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;")

# Fit the data
gp.cmd("fit f(x) $(gp.lastData()) u 1:2:3 via a, b, c;")

# Overplot the fitted model
gp.plot("f(x) w l lw 2 t 'Fit'")

# Get param values
(a, b, c) = parse.(Float64, gp.getVal("a", "b", "c"))

# Add param. values in the title
gp.cmd(title="Fit param: " * @sprintf("a=%5.2f, b=%5.2f, c=%5.2f", a, b ,c))
       
# Refresh the plot
gp.dump()
```
Here we introduced a few new functions:
- `Gnuplot.cmd`: send gnuplot commands;
- `Gnuplot.lastData`: returns the name of the last data block
  sent to gnuplot;
- `Gnuplot.plot`: add a new plot;
- `Gnuplot.getVal`: retrieve values from gnuplot;
- `Gnuplot.dump`: send the required commands to refresh the plot.

The documentation for each of these functions can be retrieved with
the `@doc` macro or by typing `?` in the REPL followed by the function
name.

Besides these functions however, the syntax is still the the gnuplot one.



```
gp.multi("layout 2,1")
gp.next()
gp.cmd(tit="", xlab="X label", ylab="Residuals")
gp.plot(gp.lastData() * " u 1:((f(x)-\$2)/\$3):(1) w errorbars notit")
gp.dump()
```

``` Julia
# Compute the model in Julia
m = a * sin.(b + c * x)

# Start a new gnuplot process and plot again using the @gp macro.
@gp("set key horizontal", "set grid",
    :multi, "layout 2,1",
    title="Fit param: " * @sprintf("a=%5.2f, b=%5.2f, c=%5.2f", a, b ,c),
    ylab="Y label",
    x, y, "w l dt 1 lw 2 t 'Real model'",
    x, y+noise, e, "w errorbars t 'Data'",
    x, m, "w l lw 2 t 'Fit'",
    :next,
    tit="", xlab="X label", ylab="Residuals",
    x, (m-y-noise)./e, ones(e), "w errorbars notit")

# Save the gnuplot session in a file
gp.dump(file="test.gp");

# Quit all gnuplot sessions
gp.exitAll()
```
Now you can quit Julia, and load `test.gp` directly in gnuplot or
any other program.



