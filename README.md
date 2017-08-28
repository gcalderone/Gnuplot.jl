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
  
- handles multiple gnuplot process simultaneously;

- support for multiplots;

- save sessions into gnuplot scripts;

- extremely concise syntax (see examples below) makes it ideal for
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


## Usage:
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
    xrange=(-7,7), ylabel="Y label",
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
  using a
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

Actually the **Gnuplot.jl** package hides much more under the hood as
we will show below.  Let's discuss some more advanced usage: fit the
data (with gnuplot) and overplot the results.
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

Besides these functions however, the strings still contain gnuplot
syntax.

Note that these functions operates on the data and status we set up in
the previous example, i.e. we are operating in a **session**.  This
allow to build a plot step by step and (optionally) to dump all data
and commands on a gnuplot script file, to be edited/used outside
Julia.  All **Gnuplot.jl** functions always operate on the so-called
*current* session, but users can change it using `Gnuplot.setCurrent`.

Now we will introduce a few more functions designed to produce
multiplots:
```
gp.multi("layout 2,1")
gp.next() 
gp.cmd(tit="", xlab="X label", ylab="Residuals")
gp.plot(gp.lastData() * " u 1:((f(x)-\$2)/\$3):(1) w errorbars notit")
gp.dump()
```
- `Gnuplot.multi`: initialize a multiplot session.  This is typically
  used at the beginning of the session but it can also be used after
  the first plot;
- `Gnuplot.next`: select to the next plot in the multiplot session.
  
Note that now we set the Y axis label with `ylab=...`, while we used
`ylabel=...` in a previous example.  This is not a typo, but a desired
behavior: all keywords in the **Gnuplot.jl** functions can
be [abbreviated](https://github.com/gcalderone/AbbrvKW.jl) as long as
the provided names allow complete disambiguation.  
  
Although these functions provide great flexibility they can almost
always be replaced by simpler (and shorter) `@gp` or `@gpi` calls.
The whole plot can be reproduced with:

``` Julia
# Compute the model in Julia
m = a * sin.(b + c * x)

# Start a new gnuplot process (to see the output in another window)
gp.session()

# Plot again using the @gp macro.
title = "Fit param: " * @sprintf("a=%5.2f, b=%5.2f, c=%5.2f", a, b ,c),
@gp("set key horizontal", "set grid",
    :multi, "layout 2,1",
    title=title, ylab="Y label",
    x, y, "w l dt 1 lw 2 t 'Real model'",
    x, y+noise, e, "w errorbars t 'Data'",
    x, m, "w l lw 2 t 'Fit'",
    :next,
    tit="", xlab="X label", ylab="Residuals",
    x, (m-y-noise)./e, ones(e), "w errorbars notit")
```
It is often instructive to check how the macro expands to understand
what's going on.  The expansion of the last `@gp` call is:
``` Julia
Gnuplot.reset()
begin 
    Gnuplot.cmd("set key horizontal")
    Gnuplot.cmd("set grid")
    Gnuplot.multi("layout 2,1")
    Gnuplot.cmd(title=title)
    Gnuplot.cmd(ylab="Y label")
    Gnuplot.data(x, y)
    Gnuplot.plot(last=true, "w l dt 1 lw 2 t 'Real model'")
    Gnuplot.data(x, y + noise, e)
    Gnuplot.plot(last=true, "w errorbars t 'Data'")
    Gnuplot.data(x, m)
    Gnuplot.plot(last=true, "w l lw 2 t 'Fit'")
    Gnuplot.next()
    Gnuplot.cmd(tit="")
    Gnuplot.cmd(xlab="X label")
    Gnuplot.cmd(ylab="Residuals")
    Gnuplot.data(x, ((m - y) - noise) ./ e, ones(e))
    Gnuplot.plot(last=true, "w errorbars notit")
end
Gnuplot.dump()
```
Here a few new functions appeared:
- `Gnuplot.session`: start a new gnuplot process and initialize a new session;
- `Gnuplot.reset`: reset the gnuplot session;
- `Gnuplot.data`: send data to gnuplot in the form of a data block.

The `@gpi` macro works exactly like the `@gp` one, but it doesn't add
the wrapping `reset` and `dump` calls, hence it is suited to build a
plot step by step.


Finally, let's save all the data and commands on a gnuplot script, and
close all the sessions:
```
# Save the gnuplot session in a file
gp.dump(file="test.gp");

# Quit all gnuplot sessions
gp.exitAll()
```
Note that we used again the `Gnuplot.dump` function, but we added the
`file=` keyword which tells `dump` to redirect all data and commands
on a file rather than on the gnuplot pipe.

Now you can quit Julia and load/modify `test.gp` directly in gnuplot or
any other program.  If you want to load it again from the Julia REPL:

``` Julia
using Gnuplot
gp`test.gp`
```

Further examples may be found in `test/runtests.jl`.



## List of functions in the package (by category):

The documentation for each of these functions can be retrieved with
the `@doc` macro or by typing `?` in the REPL followed by the function
name.

### Get/set options:

- `Gnuplot.getStartup`: return the gnuplot command(s) to be executed
at the beginning of each session;

- `Gnuplot.getSpawnCmd`: return the command used to spawn a gnuplot
process;

- `Gnuplot.getVerbose`: return the verbosity level;

- `Gnuplot.setOption: set package options.


### Session handling:

- `Gnuplot.handles`: return a `Vector{Int}` of  available session handles;
- `Gnuplot.current`: return the handle of the current session;
- `Gnuplot.setCurrent`: change the current session;
- `Gnuplot.session`: create a new session (by starting a new gnuplot
process) and make it the
current one;
- `Gnuplot.exit`: close current session and quit the corresponding gnuplot
process;
- `Gnuplot.exitAll`: repeatedly call `gp.exit` until all sessions are
closed;


### Send data and commands to Gnuplot:

- `Gnuplot.send`: send a string to the current session's gnuplot pipe
(without saving it in the current session);

- `Gnuplot.reset`: send a "reset session" command to gnuplot and delete all commands,
data, and plots in the current session;

- `Gnuplot.cmd`: send a command to gnuplot process and store it in the
current session;

- `Gnuplot.data`: send data to the gnuplot process and store it in the
current session;

- `Gnuplot.lastData`: return the name of the last data block;

- `Gnuplot.getVal`: return the value of one (or more) gnuplot variables;

- `Gnuplot.plot`: add a new plot/splot comand to the current session;

- `Gnuplot.multi`: initialize multiplot;

- `Gnuplot.next`: select next slot for multiplot sessions;

- `Gnuplot.dump`: send all necessary commands to gnuplot to do/refresh the
plot.  Optionally, the commands and data can be sent to a file.


### Misc.:
- `Gnuplot.terminals`: return the list of available gnuplot terminal.
- `Gnuplot.terminal`: return the current gnuplot terminal.


### Symbols exported by **Gnuplot.jl**
- `@gp`: the *swiss army knife* of the package, it allows to send
  command and data to gnuplot, and produce very complex plots;
- `@gpi`: very similar to `@gp`, but it allows to build a plot in
  several calls, rather than a single `@gp` call;
- `@gp_str`: run simple gnuplot commands
  using a
  [non-standard string literal](https://docs.julialang.org/en/stable/manual/strings/#non-standard-string-literals-1);
- `@gp_cmd`: load a gnuplot script file using a non-standard string literal.

The last two macros are supposed to be used only in the REPL, not in
Julia function.
