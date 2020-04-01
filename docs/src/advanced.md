# Advanced usage

Here we will show a few advanced techniques for data visualization using **Gnuplot.jl**.


```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")
saveas(file) = save(term="pngcairo size 480,360 fontscale 0.8", output="assets/$(file).png")
empty!(Gnuplot.options.init)
gpexec("set term unknown")
```


## Named datasets

A dataset may have an associated name whose purpose is to use it multiple times for plotting, while sending it only once to gnuplot. A dataset name must begin with a `$`.

A named dataset is defined as a `Pair{String, Tuple}`, e.g.:
```julia
"\$name" => (1:10,)
```
and can be used as an argument to both `@gp` and `gsp`, e.g.:
```@example abc
x = range(-2pi, stop=2pi, length=100);
y = sin.(x)
name = "\$MyDataSet1"
@gp name=>(x, y) "plot $name w l lc rgb 'black'" "pl $name u 1:(1.5*\$2) w l lc rgb 'red'"
saveas("ex010") # hide
```
![](assets/ex010.png)

Both curves use the same input data, but the red curve has the second column (`\$2`, corresponding to the *y* value) multiplied by a factor 1.5.

A named dataset comes in hand also when using gnuplot to fit experimental data to a model, e.g.:
```@example abc
# Generate data and some noise to simulate measurements
x = range(-2pi, stop=2pi, length=20);
y = 1.5 * sin.(0.3 .+ 0.7x);
err = 0.1 * maximum(abs.(y)) .* fill(1, size(x));
y += err .* randn(length(x));
name = "\$MyDataSet1"

@gp    "f(x) = a * sin(b + c*x)"     :- # define an analytical model
@gp :- "a=1" "b=1" "c=1"             :- # set parameter initial values
@gp :- name=>(x, y, err)             :- # define a named dataset
@gp :- "fit f(x) $name via a, b, c;"    # fit the data
```

The parameter best fit values can be retrieved as follows:
```@example abc
@info("Best fit values:",
a = gpexec("print a"),
b = gpexec("print b"),
c = gpexec("print c"))
```

A named dataset is available until the session is reset, i.e. as long as `:-` is used as first argument to `@gp`.


## Multiplot

**Gnuplot.jl** can draw multiple plots in the same figure by exploiting the `multiplot` command.  Each plot is identified by a positive integer number, which can be used as argument to `@gp` to redirect commands to the appropriate plot.

Continuing previous example we can plot both data and best fit model (in plot `1`) and residuals (in plot `2`):
```@example abc
@gp :- "set multiplot layout 2,1"
@gp :- 1 "p $name w errorbars t 'Data'" 
@gp :-   "p $name u 1:(f(\$1)) w l t 'Best fit model'"
@gp :- 2 "p $name u 1:((f(\$1)-\$2) / \$3):(1) w errorbars t 'Resid. [{/Symbol s}]'"
@gp :-   [extrema(x)...] [0,0] "w l notit dt 2 lc rgb 'black'" # reference line
saveas("ex011") # hide
```
![](assets/ex011.png)

Note that the order of the plots is not relevant, i.e. we would get the same results with:
```julia
@gp :- "set multiplot layout 2,1"
@gp :- 2 "p $name u 1:((f(\$1)-\$2) / \$3):(1) w errorbars t 'Resid. [{/Symbol s}]'"
@gp :-   [extrema(x)...] [0,0] "w l notit dt 2 lc rgb 'black'" # reference line
@gp :- 1 "p $name w errorbars t 'Data'" 
@gp :-   "p $name u 1:(f(\$1)) w l t 'Best fit model'"
```

### Mixing 2D and 3D plots
A multiplot can also mix 2D and 3D plots:

```@example abc
x = y = -10:0.33:10
@gp "set multiplot layout 1,2"

# 2D
@gp :- 1 x sin.(x) ./ x "w l notit"

# 3D
sinc2d(x,y) = sin.(sqrt.(x.^2 + y.^2))./sqrt.(x.^2+y.^2)
fxy = [sinc2d(x,y) for x in x, y in y]
@gsp :- 2 x y fxy "w pm3d notit"
saveas("ex012") # hide
```
![](assets/ex012.png)


## Multiple sessions

**Gnuplot.jl** can handle multiple sessions, i.e. multiple gnuplot processes running simultaneously.  Each session is identified by an ID (`sid::Symbol`, in the documentation).

In order to redirect commands to a specific session simply insert a symbol into your `@gp` or `@gsp` call, e.g.:
```@example abc
@gp :GP1 "plot sin(x)"    # opens first window
@gp :GP2 "plot sin(x)"    # opens secondo window
@gp :- :GP1 "plot cos(x)" # add a plot on first window
```
The session ID can appear in every position in the argument list, but only one ID can be present in each call.  If the session ID is not specified the `:default` session is considered.

The names of all current sessions can be retrieved with [`session_names()`](@ref):
```@repl abc
println(session_names())
```

To quit a specific session use [`Gnuplot.quit()`](@ref):
```@repl abc
Gnuplot.quit(:GP1)
```
The output value is the exit status of the underlying gnuplot process.

You may also quit all active sessions at once with [`Gnuplot.quitall()`](@ref):
```@repl abc
Gnuplot.quitall()
gpexec("set term unknown") # hide
```

## Histograms
**Gnuplot.jl** provides facilities to compute and display histograms, through the [`hist()`](@ref) function.  E.g., to quickly preview an histogram:
```@example abc
x = randn(1000);
@gp hist(x)
saveas("ex013a") # hide
```
![](assets/ex013a.png)

A finer control on the output is achieved by setting the range to consider (`range=` keyword) and either the bin size (`bs=`) or the total number of bins (`nbins=`) in the histogram.  See [`hist()`](@ref) documentation for further information.

Moreover, the [`hist()`](@ref) return a [`Gnuplot.Histogram1D`](@ref) structure, whose content can be exploited to customize histogram appearence, e.g.:
```@example abc
x = randn(1000);
h = hist(x, range=3 .* [-1,1], bs=0.5)
@gp h.bins h.counts "w histep t 'Data' lc rgb 'red'"
saveas("ex013b") # hide
```
![](assets/ex013b.png)


**Gnuplot.jl** also allows to compute 2D histograms by passing two vectors (with the same lengths) to [`hist()`](@ref).  A quick preview is simply obtained by:
```@example abc
x = randn(5000)
y = randn(5000)
@gp "set size ratio -1" hist(x, y)
saveas("ex014a") # hide
```
![](assets/ex014a.png)

Again, a finer control can be achieved by specifying ranges, bin size or number of bins (along both dimensions) and by explicitly using the content of the returned [`Gnuplot.Histogram2D`](@ref) structure:
```@example abc
h = hist(x, y, bs1=0.5, nbins2=10, range1=[-3,3], range2=[-3,3])
@gp "set size ratio -1" h.bins1 h.bins2 h.counts "w image notit"
saveas("ex014b") # hide
```
![](assets/ex014b.png)


Alternatively, 2D histograms may be displayed using the `boxxyerror` plot style which allows more flexibility in, e.g., handling transparencies and drawing the histogram grid.  In this case the data can be prepared using the [`boxxyerror()`](@ref) function, as follows:
```@example abc
box = boxxyerror(h.bins1, h.bins2, cartesian=true)
@gp "set size ratio -1" "set style fill solid 0.5 border lc rgb 'gray'" :-
@gp :- box... h.counts "w boxxyerror notit lc pal"
saveas("ex014c") # hide
```
![](assets/ex014c.png)


## Contour lines
Although gnuplot already handles contours by itself (with the `set contour` command), **Gnuplot.jl** provides a way to calculate contour lines paths before displaying them, using the [`contourlines()`](@ref) function.  We may use it for, e.g., plot contour lines with customized widths and palette, according to their z level.  Continuing previous example:
```@example abc
clines = contourlines(h.bins1, h.bins2, h.counts, cntrparam="levels discrete 50, 100, 200");
for i in 1:length(clines)
    @gp :- clines[i].data "w l t '$(clines[i].z)' lw $(1.5 * i) lc pal" :-
end
@gp :- key="outside top center box horizontal"
saveas("ex014d") # hide
```
![](assets/ex014d.png)


## Animations

The [Multiplot](@ref) capabilities can also be used to stack plots one above the other in order to create an animation, as in the following example:
```@example abc
x = y = -10:3.33:10
fz(x,y) = sin.(sqrt.(x.^2 + y.^2))./sqrt.(x.^2+y.^2)
fxy = [fz(x,y) for x in x, y in y]
@gsp "set xyplane at 0" "unset colorbox" cb=[-1,1] zr=[-1,1] 
frame = 0
for direction in [-1,1]
    for factor in -1:0.1:1
        global frame += 1
        @gsp :- frame x y direction * factor .* fxy "w pm3d notit" :-
    end
end
@gsp
```
The animation can also be saved in a gif file with:
```@example abc
save(term="gif animate size 480,360 delay 5", output="assets/animation.gif")
```
![](assets/animation.gif)


## Direct command execution
When gnuplot commands are passed to `@gp` or `@gsp` they are stored in a session for future use, or to be saved in [Gnuplot scripts](@ref).  If you simply wish to execute a command, without storing it in the session, use [`gpexec`](@ref).  E.g. if you wish to temporarily change the current terminal:
```@repl abc
gpexec("set term wxt");
```
The gnuplot process replies are returned as a string, e.g.:
```@repl abc
gpexec("print GPVAL_TERM")
gpexec("set term unknown")  #hide
```

You may also provide a session ID as first argument (see [Multiple sessions](@ref), to redirect the command to a specific session.


## Dry sessions
A "*dry session*" is a session with no underlying gnuplot process.  To enable dry sessions type:
```@repl abc
Gnuplot.options.dry = true;
Gnuplot.options.dry = false  #hide
```
before starting a session (see also [Options](@ref)).  Note that the `dry` option is a global one, i.e. it affects all sessions started after setting the option.

Clearly, no plot can be generated in dry sessions. Still, they are useful to run **Gnuplot.jl** code without raising errors (no attempt will be made to communicate with the underlying process).  Moreover, [Gnuplot scripts](@ref) can also be generated in a dry session, without the additional overhead of sending data to the gnuplot process.

If a gnuplot process can not be started the package will print a warning, and automatically enable dry sessions.


## Options
Thepackage options are stored in a global structure available in Julia as `Gnuplot.option` (the type of the structure is [`Gnuplot.Options`](@ref)).  The most important settings are as follows:

- `dry::Bool`: if true all new sessions will be started [Dry sessions](@ref).  Default is `false`, but if the package is not able to start a gnuplot it will automatically switch to `false`;

- `init::Vector{String}`: This vector can be used to `push!` initialization commands to be executed when a new session is started.  Default is an empty vector.  It can be used to, e.g., set a custom terminal for all new sessions:
```@repl abc
push!(Gnuplot.options.init, "set term sixelgd");
```
Note that this is a global option, i.e. it will affect all new sessions.  Also note that the commands in `Gnuplot.options.init` are not saved in [Gnuplot scripts](@ref);

- `verbose::Bool`: a flag to set verbosity of the package.  In particular if it is `true` all communication with the underlying process will be printed on stdout. E.g.:
```@repl abc
gpexec("set term wxt")  #hide
Gnuplot.options.verbose = true;
x = 1.:10;
@gp x x.^2 "w l t 'Parabola'"
save(term="pngcairo size 480,360 fontscale 0.8", output="output.png")
```
Each line reports the package name (`GNUPLOT`), the session name (`default`), the command or string being sent to gnuplot process, and the returned response (line starting with `->`).  Default value is `false`;

```@setup abc
Gnuplot.options.verbose = false
gpexec("set term unknown")
```

- `cmd::String`: command to start the gnuplot process, default value is `"gnuplot"`.  If you need to specify a custom path to the gnuplot executable you may change this value;

- `default::Symbol`: default session name, i.e. the session that will be used when no session name is provided;

- `preferred_format::Symbol`: preferred format to send data to gnuplot.  Value must be one of:
   - `bin`: provides best performances for large datasets, but uses temporary files;
   - `text`: may be slow for large datasets, but no temporary file is involved;
   - `auto` (default) automatically choose the best strategy.

