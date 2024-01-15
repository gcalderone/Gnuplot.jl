```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")
Gnuplot.splash("assets/logo.png")
Gnuplot.options.term = "unknown"
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
saveas(file) = Gnuplot.save(term="pngcairo size 550,350 fontscale 0.8", "assets/$(file).png")
```

# Basic usage

The main purpose of the **Gnuplot.jl** package is to send data and commands to the underlying gnuplot process, in order to generate plots.  Unlike other packages, however, the actual commands to plot, or the plot attributes, are not specified through function calls.  This is what makes **Gnuplot.jl** *easy to learn and use*: there are no functions or keywords names to memorize[^1].

The most important symbols exported by the package are the [`@gp`](@ref) (for 2D plots) and [`@gsp`](@ref) (for 3D plots) macros.  The simplemost example is as follows:
```@example abc
using Gnuplot
@gp 1:20
saveas("basic000"); nothing # hide
```
![](assets/basic000.png)

The plots are displayed either in an interactive window (if running in the Julia REPL), as an inline image (if running in Jupyter) or in the plot pane (if running in Juno).  See [Display options](@ref) for further informations.

Both the [`@gp`](@ref) and [`@gsp`](@ref) macros accept any number of plot specifications (or *plot specs*), whose meaning is as follows:

- one, or a group of consecutive, array(s) of either `Real` or `String` build up a dataset.  The different arrays are accessible as columns 1, 2, etc. from the `gnuplot` process.  The number of required input arrays depends on the chosen plot style (see `gnuplot` documentation);

- a string occurring before a dataset is interpreted as a `gnuplot` command (e.g. `set grid`).  If the string begins with "plot" or "splot" it is interpreted as the corresponding gnuplot commands (note: "plot" and "splot" can be abbreviated to "p" and "s" respectively, or "pl" and "spl", etc.);

- a string occurring immediately after a dataset is interpreted as a plot command for the dataset, by which you can specify `using` clause, `with` clause, line styles, etc..  All keywords may be abbreviated following gnuplot conventions.

- an input in the form `"\\\$name"=>(array1, array2, etc...)` is interpreted as a named dataset.  Note that the dataset name must always start with a "`\$`";

- the literal symbol `:-` allows to avoid starting a new plot (if given as first argument), or to avoid immediately updating the plot (if given as last argument).  Its purpose is to split one long statement into multiple (shorter) ones.

The above list shows all the fundamental concepts to follow the examples presented below.  The [`@gp`](@ref) and [`@gsp`](@ref) macros also accepts further arguments, but their use will be discussed in [Advanced usage](@ref).

[^1]: a previous knowledge of [gnuplot](http://gnuplot.sourceforge.net/documentation.html) usage is, nevertheless, required.


## [2D plots](@id plots2d)

Here we will show a few examples to generate 2D plots.  The examples are intentionally very simple to highlight the behavior of **Gnuplot.jl**.  See [Examples](@ref) for more complex ones.

Remember to run:
```julia
using Gnuplot
```
before running the examples.




### Simple examples involving just gnuplot commands:

---
#### Plot a sinusoid:
```@example abc
@gp "plot sin(x)"
saveas("basic001"); nothing # hide
```
![](assets/basic001.png)

---
#### Plot two curves:
```@example abc
@gp "set key left" "plot sin(x)" "pl cos(x)"
saveas("basic002"); nothing # hide
```
![](assets/basic002.png)

!!! note
    Note that all gnuplot commands can be abbreviated as long as the resulting string is not ambiguous.  In the example above we used `pl` in place of `plot`.

---
#### Split a `@gp` call in three statements:
```@example abc
@gp    "set grid"  :-
@gp :- "p sin(x)"  :-
@gp :- "plo cos(x)"
saveas("basic003"); nothing # hide
```
![](assets/basic003.png)
!!! note
    The trailing `:-` symbol means the plot will not be updated until the last statement.


### Send data from Julia to gnuplot:

#### Plot a parabola
```@example abc
@gp (1:20).^2
saveas("basic004"); nothing # hide
```
![](assets/basic004.png)


---
#### Plot a parabola with scaled x axis, lines and legend
```@example abc
x = 1:20
@gp "set key left"   x ./ 20   x.^2   "with lines tit 'Parabola'"
saveas("basic005"); nothing # hide
```
![](assets/basic005.png)


#### Reuse last dataset to add labels on the parabola
The last dataset can be reused with `plot ''`, optionally followed by a [`using` clause](http://gnuplot.info/docs_6.0/loc9076.html):
```@example abc
x = 1:20
@gp  x  x.^2  "with lp tit 'Parabola'" "plot '' using 1:2:2 w labels right offset -1,0.5 notit"
saveas("basic005a"); nothing # hide
```
![](assets/basic005a.png)


#### Specify labels as strings
Labels can be provided as a `Vector{String}`:
```@example abc
x = (0.:5) .+ 0.5
labels = "P {/Symbol " .* string.('a' .+ (0:length(x)-1)) .* "}_0"
@gp x x.^2 labels "w lp notit" "p '' w labels right offset 1,1 notit"
saveas("basic005b"); nothing # hide
```
![](assets/basic005b.png)



---
#### Multiple datasets, logarithmic axis, labels and colors, etc.
```@example abc
x = 1:0.1:10
@gp    "set grid" "set key left" "set logscale y"
@gp :- "set title 'Plot title'" "set label 'X label'" "set xrange [0:*]"
@gp :- x x.^0.5 "w l tit 'Pow 0.5' dt 2 lw 2 lc rgb 'red'"
@gp :- x x      "w l tit 'Pow 1'   dt 1 lw 3 lc rgb 'blue'"
@gp :- x x.^2   "w l tit 'Pow 2'   dt 3 lw 2 lc rgb 'purple'"
saveas("basic006"); nothing # hide
```
![](assets/basic006.png)

!!! note
    The above example lacks the trailing `:-` symbol.  This means the plot will be updated at each command, adding one curve at a time.

---
## Keywords for common commands

In order to avoid typing long, and very frequently used gnuplot commands, **Gnuplot.jl** provides a few keywords which can be used in both `@gp` and `@sgp` calls (see [`Gnuplot.parseKeywords`](@ref) for a complete list):
 - `xrange=[low, high]` => `"set xrange [low:high]`;
 - `yrange=[low, high]` => `"set yrange [low:high]`;
 - `zrange=[low, high]` => `"set zrange [low:high]`;
 - `cbrange=[low, high]`=> `"set cbrange[low:high]`;
 - `key="..."`  => `"set key ..."`;
 - `title="..."`  => `"set title \"...\""`;
 - `xlabel="..."` => `"set xlabel \"...\""`;
 - `ylabel="..."` => `"set ylabel \"...\""`;
 - `zlabel="..."` => `"set zlabel \"...\""`;
 - `cblabel="..."` => `"set cblabel \"...\""`;
 - `xlog=true`   => `set logscale x`;
 - `ylog=true`   => `set logscale y`;
 - `zlog=true`   => `set logscale z`;
 - `margins=...` => `set margins ...`;
 - `lmargin=...` => `set lmargin ...`;
 - `rmargin=...` => `set rmargin ...`;
 - `bmargin=...` => `set bmargin ...`;
 - `tmargin=...` => `set tmargin ...`;

All keywords can be abbreviated to unambiguous names.

By using the above keywords the first lines of the previous example:
```julia
@gp    "set grid" "set key left" "set logscale y"
@gp :- "set title 'Plot title'" "set label 'X label'" "set xrange [0:*]"
```
can be replaced with a shorter version:
```julia
@gp    "set grid" k="left" ylog=true
@gp :- tit="Plot title" xlab="X label" xr=[0,NaN]
```
where `NaN` in the `xrange` keyword means using axis autoscaling.


## Plot matrix as images

**Gnuplot.jl** can display a 2D matrix as an image:
```@example abc
img = randn(Float64, 8, 5)
img[2,:] .= -5
@gp img "w image notit"
saveas("basic007a"); nothing # hide
```
![](assets/basic007a.png)

Note that the first index in the `img` matrix corresponds to the rows in the displayed image.

A simple way to remember the convention is to compare how a matrix is displayed in the REPL:
```@example abc
img = reshape(1:15, 5, 3)
```
and its image representation, which is essentially upside down (since the Y coordinates increase upwards):
```@example abc
@gp img "w image notit"
saveas("basic007b"); nothing # hide
```
![](assets/basic007b.png)

Also note that the `img[1,1]` pixel is shown at coordinates x=0, y=0.  See [Image recipes](@ref) for further info.


## [3D plots](@id plots3d)
3D plots follow the same rules as 2D ones, just replace the `@gp` macro with `@gsp` and add the required columns (according to the plotting style).

E.g., to plot a spiral increasing in size along the `X` direction:
```@example abc
x = 0:0.1:10pi
@gsp cbr=[-1,1].*30  x  x.*sin.(x)  x.*cos.(x)  x./20  "w p pt 7 ps var lc pal"
saveas("basic008"); nothing # hide
```
![](assets/basic008.png)

Note that the fourth array in the dataset, `x./20`, is used as by gnuplot as point size (`ps var`).  Also note that all the keywords discussed above can also be used in 3D plots.


## Palettes and line types
The **Gnuplot.jl** package comes with all the [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1) palettes readily available.

A gnuplot-compliant palette can be retrieved with [`palette()`](@ref), and used as any other command.  The previous example may use an alternative palette with:
```@example abc
x = 0:0.1:10pi
@gsp palette(:viridis) cbr=[-1,1].*30 :-
@gsp :-  x  x.*sin.(x)  x.*cos.(x)  x./20  "w p pt 7 ps var lc pal"
saveas("basic008a"); nothing # hide
```
![](assets/basic008a.png)

The palette levels may be easily stretched by using the [`palette_levels()`](@ref) and modifying the numeric levels, e.g.:
```@example abc
x = 0:0.1:10pi
v, l, n = palette_levels(:viridis)
@gsp palette(v.^0.25, l, n) cbr=[-1,1].*30 :-
@gsp :-  x  x.*sin.(x)  x.*cos.(x)  x./20  "w p pt 7 ps var lc pal"
saveas("basic008b"); nothing # hide
```
![](assets/basic008b.png)

The list of all available palette can be retrieved with [`palette_names()`](@ref):
```@repl abc
palette_names()
```


The [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1) palettes can also be used to generate line type colors, and optionally the line width, point size and dashed pattern, by means of the [`linetypes()`](@ref) function, e.g.
```@example abc
@gp key="left" linetypes(:Set1_5, lw=2)
for i in 1:10
    @gp :- i .* (0:10) "w lp t '$i'"
end
saveas("basic009a"); nothing # hide
```
![](assets/basic009a.png)


```@example abc
@gp key="left" linetypes(:Set1_5, dashed=true, ps=2)
for i in 1:10
    @gp :- i .* (0:10) "w lp t '$i'"
end
saveas("basic009b"); nothing # hide
```
![](assets/basic009b.png)

The first plot features the `:Set1_5` palette, with solid lines whose width is 2 times the default.  The second plot shows the same palette but default line widths are 1, default point size is 2 (for the first N line types, where N is the number of discrete colors in the palette), and the dashed pattern is automatically changed.

As discussed in [Options](@ref), you may set a default line types for all plots with:
```julia
push!(Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
```
All plot in this documentation were generated with these settings.


## Transparency

Gnuplot palette can't handle transparency, the only way to plot transparent symbols is via a *named colormap*.  **Gnuplot.jl** defines one such colormap dubbed a "Transparent Color Map" (TCM) based on a given palette via the [`tcm()`](@ref) function.  Copying from previous example we just need to replace a `palette()` call with a `tcm()` one, and specify `lc pal tcm`, as in the following example:
```@example abc
x = 0:0.1:10pi
@gsp tcm(:viridis) cbr=[-1,1].*30 :-
@gsp :-  x  x.*sin.(x)  x.*cos.(x)  x./20  "w p pt 7 ps var lc pal tcm"
saveas("basic010a"); nothing # hide
```
![](assets/basic010a.png)

In this plot all points have the same transparency of 0.5, you can specify a custom one via the `alpha=` keyword, e.g. `tcm(:viridis, alpha=0.8)` (note: `alpha=0` means completely opaque, `alpha=1` means completely transparent symbols).

You may also provide a mapping function to use different transparency levels depending on data values, e.g.:
```@example abc
x = 0:0.1:10pi
@gsp tcm(:viridis, alpha=x -> (1-x)) cbr=[-1,1].*30 :-
@gsp :-  x  x.*sin.(x)  x.*cos.(x)  x./20  "w p pt 7 ps var lc pal tcm"
saveas("basic010b"); nothing # hide
```
![](assets/basic010b.png)


In principle, you may also specify the (A)RGB color for each data point by providing them as hexadecimal integers, e.g.
```@example abc
colors        = [  0xff0000,   0x00ff00,   0x0000ff]
transp_colors = [0x44ff0000, 0x8800ff00, 0xcc0000ff]
@gp xr=[0,4] yr=[0,4] key="bottom right" :-
@gp :- 1:3   1:3          colors "w p  t 'Opaque'      pt 3 ps 5 lc rgb var"
@gp :- 1:3 1.5:3.5 transp_colors "w lp t 'Transparent' pt 7 ps 3 lc rgb var"
saveas("basic010c"); nothing # hide
```
![](assets/basic010c.png)


To easily generate the vector of (A)RGB colors you can use the [`v2argb()`](@ref) function which maps any user value to a specific palette, with optional transparency (to be specified via the `alpha=` keyword in the same way as for the `tcm()` function).  E.g.:
```@example abc
x = 1:19
y = x .* 0
@gp "set grid" yr=[0,9] :-
@gp :- x y.+1 v2argb(x)                               "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+2 v2argb(:grays, x)                       "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+3 v2argb(:grays, x, rev=true)             "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+4 v2argb(:roma , x, alpha=0.5)            "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+5 v2argb(:roma , x, alpha=x -> x)         "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+6 v2argb(:roma , x, alpha=x -> x^3)       "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+7 v2argb(:roma , x, alpha=x -> x^0.3)     "w p notit pt 5 ps 3 lw 3 lc rgb var"
@gp :- x y.+8 v2argb(:roma , x, alpha=x -> (1-x)^0.3) "w p notit pt 5 ps 3 lw 3 lc rgb var"
saveas("basic010d"); nothing # hide
```
![](assets/basic010d.png)

In the above plot:
- the symbols at `y=1` use the default `viridis` palette;
- the symbols at `y=2` use the `grays` palette;
- the symbols at `y=3` use the reversed `grays` palette;
- the symbols at `y=4` use the `roma` palette with a constant transparency of 0.5;
- the symbols at `y=5` use the `roma` palette with a linear transparency gradient (opaque for low values, transparent for high values);
- the symbols at `y=6` and `y=7` use the `roma` palette with a non-linear transparency mapping stretching opacity towards higher values (`y=6`) or transparency towards lower values (`y=7`);
- the symbols at `y=8` use the same palette but reversed transparency with respect to `y=7`.

The advantages of using `v2argb()` over `tcm()` are:
- you can use more than one palette in a single plot;
- you can specify transparency for the `lines` plot style.

On the other hand, `v2argb()` does not allow to draw a color bar to represent the color mapping.



## Exporting plots to files

**Gnuplot.jl** can export all plots (as well as multiplots, see [Multiplot](@ref)) to an external file using one of the many available gnuplot terminals.  To check which terminals are available in your platform type:
```@repl abc
terminals()
```
(see also [`terminal()`](@ref) to check your current terminal).

Once you choose the proper terminal (i.e. format of the exported file), use the [`Gnuplot.save()`](@ref) function to export.  As an example, all the plots in this page have been saved with:
```julia
Gnuplot.save("filename.png" term="pngcairo size 550,350 fontscale 0.8")
```
Note that you can pass both the terminal name and its options via the `term=` keyword.  See [Gnuplot terminals](@ref) for further info on the terminals.


## Gnuplot scripts
Besides exporting plots in image files, **Gnuplot.jl** can also save a *script*, i.e. a file containing the minimum set of data and commands required to re-create a figure using just gnuplot.

The script allows a complete decoupling of plot data and aethetics, from the Julia code used to generate them.  With scripts you can:
- modify all aesthetic details of a plot without re-running the (possibly complex and time-consuming) code used to generate it;
- share both data and plots with colleagues without the need to share the Julia code.

To generate a script for one of the examples above use:
```julia
Gnuplot.savescript("script.gp")
```
after the plot has been displayed.  Note that when images or large datasets are involved, `Gnuplot.savescript()` may store the data in binary files under a directory named `<script name>_data`. In order to work properly both the script and the associated directory must be available in the same directory.


E.g., the following code:
```@example abc
x = 1:10
@gp x x.^2 "w l"
Gnuplot.savescript("script1.gp")
nothing # hide
```
will produce the following file, named `script1.gp`:
```
reset session
$data1 << EOD
 1 1
 2 4
 3 9
 4 16
 5 25
 6 36
 7 49
 8 64
 9 81
 10 100
EOD
plot  \
  $data1 w l
set output
```

While the following:
```@example abc
img = randn(100, 300);
@gp "set size ratio -1" "set autoscale fix" img "flipy with image notit"
Gnuplot.savescript("script2.gp")
nothing # hide
```
will produce:
```
reset session
set size ratio -1
set autoscale fix
plot  \
   './script2_data/jl_OQrt9A' binary array=(300, 100) flipy with image notit
set output
```

The above scripts can be loaded into a pure gnuplot session (Julia is no longer needed) as follows:
```
gunplot> load 'script1.gp'
gunplot> load 'script2.gp'
```
to generate a plot identical to the original one.


The purpose of gnuplot scripts is to allow sharing all data, alongside a plot, in order to foster collaboration among scientists and replicability of results.  Moreover, a script can be used at any time to change the details of a plot, without the need to re-run the Julia code used to generate it the first time.

Finally, the scripts are the only possible output when [Dry sessions](@ref) are used (i.e. when gnuplot is not available in the user platform).
