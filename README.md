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
x = 1:10
@gp x x.^2 "w l tit 'Parabola'"
```

A real life example showing some random noise generated data:

``` Julia
# Create some noisy data...
x = range(-2pi, stop=2pi, length=100);
y = 1.5 .* sin.(0.3 .+ 0.7x) ;
noise = randn(length(x))./2;
e = 0.5 * fill(1., length(x));

# ...and show them using gnuplot.
@gp("set key horizontal", "set grid", title="My title",
    xrange=(-7,7), ylabel="Y label", xlab="X label", 
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'");
```

That's it for the first plots. The syntax should be familiar to most gnuplot users, with this code we:
- set a few gnuplot properties (`key` and `grid`);
- set the X axis range and Y axis label;
- send the data to gnuplot;
- plot two data sets specifying a few details (style, line width, color, legend, etc...).

Note that this simple example already covers the vast majority of use cases, since the remaining details of the plot can be easily tweaked by adding the appropriate gnuplot command.  Also note that you would barely recognize the Julia language by just looking at the `@gp` call since **Gnuplot.jl** aims to be mostly transparent: the user is supposed to focus only on the data and on the gnuplot commands, rather than the package details.

If you set the verbose option (`setverbosity(true)`, which is `false` by default) you'll be able to see all the communication taking place between the **Gnuplot.jl** package and the underlyng Gnuplot process.  Repeating the last command:
```Julia
julia> @gp("set key horizontal", "set grid", title="My title",
    xrange=(-7,7), ylabel="Y label", xlab="X label", 
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'");
GNUPLOT (default) reset session
GNUPLOT (default) print GPVAL_TERM
GNUPLOT (default) -> qt
GNUPLOT (default) print GPVAL_TERMOPTIONS
GNUPLOT (default) -> 0 title "Gnuplot.jl: default" font "Sans,9"
GNUPLOT (default) set key horizontal
GNUPLOT (default) set grid
GNUPLOT (default) set title  'My title'
GNUPLOT (default) set xrange  [-7:7]
GNUPLOT (default) set ylabel 'Y label'
GNUPLOT (default) set xlabel 'X label'
GNUPLOT (default) $data0 << EOD
GNUPLOT (default)  -6.283185307179586 1.2258873407968363
GNUPLOT (default)  -6.156252270670907 1.1443471266509504
GNUPLOT (default)  -6.029319234162229 1.05377837392046
GNUPLOT (default) ...
GNUPLOT (default) EOD
GNUPLOT (default) $data1 << EOD
GNUPLOT (default)  -6.283185307179586 1.516291874781302 0.5
GNUPLOT (default)  -6.156252270670907 1.5490769687987143 0.5
GNUPLOT (default)  -6.029319234162229 0.30753349072971314 0.5
GNUPLOT (default) ...
GNUPLOT (default) EOD
GNUPLOT (default) set key horizontal
GNUPLOT (default) set grid
GNUPLOT (default) set title  'My title'
GNUPLOT (default) set xrange  [-7:7]
GNUPLOT (default) set ylabel 'Y label'
GNUPLOT (default) set xlabel 'X label'
GNUPLOT (default) plot  \
  $data0 w l t 'Real model' dt 2 lw 2 lc rgb 'red', \
  $data1 w errorbars t 'Data'
GNUPLOT (default) 
```
The **Gnuplot.jl** package (note the leading `GNUPLOT`...) tells us which commands are being sent to the gnuplot process and the name of the current gnuplot session (`default`).  The **Gnuplot.jl** package will also print the replies from gnuplot, e.g.:
``` Julia
julia> Gnuplot.exec("print GPVAL_TERM");
GNUPLOT (default) print GPVAL_TERM
GNUPLOT (default) -> qt
```
Note the different color in the reply (if your terminal is able to display colors).

So far we have shown how to produce plots with a single command, however such task can also be performed using multiple statements.  The syntax is exactly the same, but we should use the `:-` symbol at the beginning of each statement (except the first) and at the end of each statement (except the last), e.g.:
``` Julia
# Reset the gnuplot session and give the dataset the name `MyDataSet1`
name = "\$MyDataSet1"
@gp x y+noise e name :-

# Define a model function to be fitted
@gp :- "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"  :-

# Fit the function to the :aa dataset
@gp :- "fit f(x) $name u 1:2:3 via a, b, c;" :-

# Prepare a multiplot showing the data, the model...
@gp :- "set multiplot layout 2,1" :-
@gp :- "plot $name w points tit 'Data'" ylab="Data and model" :-
@gp :- "plot $name u 1:(f(\$1)) w lines tit 'Best fit'" :-

# ... and the residuals (the `2` here refer to the second plot in the multiplot).
@gp :- 2 xlab="X label" ylab="Residuals" :-
@gp :- "plot $name u 1:((f(\$1)-\$2) / \$3):(1) w errorbars notit"
```

The **Gnuplot.jl** package also provide support 
As discussed above, **Gnuplot.jl** allows to trasparently exploit all gnuplot functionalities.  E.g., we can show a random image with:
```Julia
@gp randn(Float64, 30, 50) "w image"
```
or show an interactive 3D plots using the `@gsp` macro in place of `@gp`, e.g.:

``` Julia
@gsp randn(Float64, 30, 50)
```

Further documentation for the `@gp` and `@gsp` macros is available in the REPL by means of the `@doc` macro or by typing `?` in the REPL followed by the macro name.



### Multiple gnuplot istances

The **Gnuplot.jl** package can handle multiple gnuplot istances simultaneously, each idenitified by a unique session name (actually a Julia symbol).  To use a specific session simply name it in a `@gp` or `@gsp` call.  If the session is not yet created it will be automatically started:

``` Julia
# Plot using session GP1 
x = 1:10
@gp :GP1 x x.^2

# Plot using session GP2
@gp x x.^2 :GP2

# Plot using default session
@gp x x.^2
```

If needed, a specific session can be started by specifying a complete file path for the gnuplot executable, e.g.
``` Julia
gp = gnuplot(:CUSTOM1, "/path/to/gnuplot/executable")
```

Also, a session can be started as a *dry* one, i.e. a session with no underlying gnuplot process, by omitting the path to the Gnuplot executable:
``` Julia
gp = gnuplot(:DRY_SESSION)
```
The prupose is to create gnuplot scripts without running them, e.g:
```Julia
@gp :DRY_SESSION x x.^2 "w l" 
save("test.gp")
```
The `test.gp` can then be loaded directly in gnuplot with:
```
gnuplot> load 'test.gp'
```


### Direct execution of gnuplot commands
Both the `@gp` and `@gsp` macros stores data and commands in the package state to allow using multiple statements for a single plot, or to save all data and commands on a script file.  However the user may directly execute command on the underlying gnuplot process using the `gpeval` function.  E.g., we can retrieve the values of the fitting parameters of the previous example:
```Julia
# Retrieve values fr a, b and c
a = parse(Float64, exec("print a"))
b = parse(Float64, exec("print b"))
c = parse(Float64, exec("print c"))
```

### Terminating a session
A session and the associated gnuplot process can be terminated by a call to `quit`, specifying the session name, e.g.:
``` Julia
julia> quit(:GP1)
```
A call to `quitall()` will terminate all active sessions.
