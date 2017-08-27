# Gnuplot.jl
## A Julia interface to Gnuplot.

[![Build Status](https://travis-ci.org/gcalderone/Gnuplot.jl.svg?branch=master)](https://travis-ci.org/gcalderone/Gnuplot.jl)

**Gnuplot.jl** allows easy and fast use
of [Gnuplot](http://gnuplot.info/) as data visualization tool in
Julia.  It is mainly focused on 

GnuplotFeatures:

- transparent interface between Julia and gnuplot to exploit all
  functionalities of the latter, both present and future ones;
  
- fast data transmission to gnuplot through system pipes (no temporary
  files involved);
  
- support for running multiple gnuplot istances simulatneously;

- support for multiplots;

- extremely concise syntax (see Examples below) makes it ideal for
  interactive use and data exploration;

- very easy to use: if you know gnuplot you're ready to go.

## Installation
In the Julia REPL type:

``` julia
Pkg.clone("https://github.com/gcalderone/Gnuplot.jl.git")
```

You'll also need gnuplot (ver. >= 4.7) installed on your system.


## Quick start:
Here we will show basic usage:

``` Julia
using Gnuplot

# Create some noisy data
x = collect(linspace(-2pi, 2pi, 100))
y = 1.5 * sin.(0.3 + 0.7x) 
noise = randn(length(x))./2
e = 0.5 * ones(x)
@gp("set key horizontal",
	x, y, "w l dt 1 lw 2 t 'Real model'",
	x, y+noise, e, "w errorbars t 'Data'")
```
That's it for the first plot.  The syntax should be familitar to most
gnuplot users.


Now some more advanced usage (fit the data and overplot the results):

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

# Add param. values in the title and the Y label
gp.cmd(title="Fit param: " * @sprintf("a=%5.2f, b=%5.2f, c=%5.2f", a, b ,c),
       ylab="Y label")
	   
# Refresh the plot
gp.dump()
```

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
@gp("set key horizontal",
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




similar to gaston
Work in progress...



Examples:

Multiplot:

Multiple instaces:

Documentation:
? at the repl or use the `@doc` macro

AbbrvKW (si puo scaricare la versione master?)



