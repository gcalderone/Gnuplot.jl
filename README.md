# Gnuplot.jl
## A Julia interface to Gnuplot.

[![Build Status](https://travis-ci.org/gcalderone/Gnuplot.jl.svg?branch=master)](https://travis-ci.org/gcalderone/Gnuplot.jl)

**Gnuplot.jl** allows easy and fast use of [Gnuplot](http://gnuplot.info/) as data visualization tool in Julia.  Its main features are:

- transparent interface between Julia and gnuplot to exploit all functionalities of the latter, both present and future ones;
  
- fast data transmission to gnuplot through system pipes (no temporary files involved);
  
- handles multiple gnuplot process simultaneously;

- support for multiplots;

- save sessions into gnuplot scripts;

- extremely concise syntax (see examples below) makes it ideal for interactive data exploration;

- very easy to use: if you know gnuplot you're ready to go.


The purpose is similar to the [Gaston](https://github.com/mbaz/Gaston.jl) package, but **Gnuplot.jl** main focus is on on the syntax conciseness and ease of use.


## Installation
In the Julia REPL type:

``` julia
Pkg.add("Gnuplot")
```

You'll also need [gnuplot](http://gnuplot.info/) (ver. >= 4.7) installed on your system.


## Usage:
The simplemost plot ever can be generated with just 8 characters:
``` Julia
using Gnuplot
@gp 1:10
```

A slightly more complicated one showing a parabola with a solid line and a title:
``` Julia
using Gnuplot
x = 1:10
@gp x x.^2 "w l tit 'Parabola'"
```

A real life example showing some random noise generated data:

``` Julia
using Gnuplot

# Create some noisy data...
x = linspace(-2pi, 2pi, 100);
y = 1.5 * sin.(0.3 + 0.7x) ;
noise = randn(length(x))./2;
e = 0.5 * ones(x);

# ...and show them using gnuplot.
@gp("set key horizontal", "set grid", title="My title",
    xrange=(-7,7), ylabel="Y label", xlab="X label", 
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'");
```

That's it for the first plots. The syntax should be familiar to most gnuplot users, with this code we:
- set a few gnuplot properties (`key` and `grid`);
- set the X axis range and Y axis label;
- passed the data to gnuplot;
- plot two data sets specifying a few details (style, line width, color, legend, etc...).

Note that this simple example already covers the vast majority of use cases, since the remaining details of the plot can be easily tweaked by adding the appropriate gnuplot command.  Also note that you would barely recognize the Julia language by just looking at the `@gp` call since **Gnuplot.jl** aims to be mostly transparent: the user is supposed to focus only on the data and on the gnuplot commands, rather than the package details.

Let's have a look to the REPL output of the above command (this may
differ on your computer since we used random numbers):
```Julia
GNUPLOT (1) -> reset session
GNUPLOT (1) -> 
GNUPLOT (1) -> set key horizontal
GNUPLOT (1) -> set grid
GNUPLOT (1) -> set xrange [-7:7]
GNUPLOT (1) -> set ylabel 'Y label'
GNUPLOT (1) -> $data0 << EOD
GNUPLOT (1) ->  -6.283185307179586 1.2258873407968363
GNUPLOT (1) ->  -6.156252270670907 1.1443471266509504
GNUPLOT (1) ->  -6.029319234162229 1.05377837392046
GNUPLOT (1) -> ...
GNUPLOT (1) -> EOD
GNUPLOT (1) -> $data1 << EOD
GNUPLOT (1) ->  -6.283185307179586 1.770587856071291 0.5
GNUPLOT (1) ->  -6.156252270670907 0.9350095514668977 0.5
GNUPLOT (1) ->  -6.029319234162229 0.8960704540397358 0.5
GNUPLOT (1) -> ...
GNUPLOT (1) -> EOD
GNUPLOT (1) -> plot  \
  $data0 w l t 'Real model' dt 2 lw 2 lc rgb 'red', \
  $data1 w errorbars t 'Data'
```
The **Gnuplot.jl** package (note the leading `GNUPLOT`...) tells us which commands are being sent to the gnuplot process and the ID of the current gnuplot session (see below).  The **Gnuplot.jl** package will also print the replies from gnuplot, e.g.:
``` Julia
julia> GnuplotGet("GPVAL_TERM");
GNUPLOT (1) -> print GPVAL_TERM
GNUPLOT (1)    qt
```
Note the lack of ` -> ` and the different color in the reply (if your terminal is able to display colors).  You may tune the amount of lines being printed by the **Gnuplot.jl** package setting a specific verbosity level as an integer number between 0 and 4, e.g.:
``` Julia
@gp verb=1
```
The default verbosity level is 4.


So far we have shown how to produce plots with a single command, however such task can also be break into multiple statements by using `@gpi` in place of `@gp`.  The syntax is exactly the same, but we should explicitly take care of resetting the gnuplot session (by using the `0` number) and send the final plot commands (using the `:.` symbol), e.g.:
``` Julia
# Reset the gnuplot session and give the dataset the name :aa
@gpi 0 x y+noise e :aa

# Define a model function to be fitted
@gpi "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"

# Fit the function to the :aa dataset
@gpi "fit f(x) \$aa u 1:2:3 via a, b, c;"

# Prepare a multiplot showing the data, the model...
@gpi "set multiplot layout 2,1"
@gpi "plot \$aa w points tit 'Data'" ylab="Data and model"
@gpi "plot \$aa u 1:(f(\$1)) w lines tit 'Best fit'"

# ... and the residuals (the `2` here refer to the second plot in the multiplot.  Also note the `:.` symbol has last argument which triggers the actual plot generation.
@gpi 2 xlab="X label" ylab="Residuals"
@gpi "plot \$aa u 1:((f(\$1)-\$2) / \$3):(1) w errorbars notit"  :.
```

Further documentation for the `@gp` and `@gpi` macros is available in the REPL by means of the `@doc` macro or by typing `?` in the REPL followed by the macro name.



### Multiple gnuplot istances

The **Gnuplot.jl** package can handle multiple gnuplot istances simultaneously, each idenitified by a unique identifier (ID).  The purpose of such identifier, as shown on the log, is to distinguish which istance is producing the log.  The package, however,  will send commands to only one istance at a time, the so called *current* istance.  If there is no current istance a default one will be created.

The commands to start a new gnuplot istance and make it the current one are:
``` Julia
gp = GnuplotProc()
setCurrent(gp)
```
The current istance can be retrieved with `getCurrent()`.

A gnuplot istance can be made temporarily current (for a single `@gp` call) by passing it as an argument, e.g.:

``` Julia
# Plot using current istance
x = 1:10
@gp x x.^2

# Create a new istance and use it as "temporarily current"
new = GnuplotProc()
@gp new x x.^2

# Go back to the previous istance
@gp x x.^2 "w l"
```


The `GnuplotProc` accepts a string argument (to specify a custom location of the gnuplot executable) and a keyword (`default`, to specify a newline separated list of commands to be sent to the new istance).  E.g.
``` Julia
gp = GnuplotProc("/path/to/gnuplot/executable", default="set term wxt")
```
will run gnuplot from the specified path and will set the `wxt` terminal each time the session is initialized.

An istance and the associated gnuplot process can be terminated by a call to `GnuplotQuit`, specifying either its ID, e.g.:
``` Julia
julia> GnuplotQuit(1)
GNUPLOT (1)    pipe closed
GNUPLOT (1)    pipe closed
GNUPLOT (1)    Process exited with status 0
0
```
or providing the istance object, e.g.:

``` Julia
julia> new = GnuplotProc()
julia> @gp new x x.^2
julia> GnuplotQuit(new)
GNUPLOT (2)    pipe closed
GNUPLOT (2)    pipe closed
GNUPLOT (2)    Process exited with status 0
0
```
Note that `GnuplotQuit` returns the exit code of the underlying gnuplot process.  Alternatively you can use `GnuplotQuitAll()`  to terminate all active istances.



