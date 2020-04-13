```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")
Gnuplot.splash("assets/logo.png")
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, "set term unknown")
empty!(Gnuplot.options.reset)
push!( Gnuplot.options.reset, linetypes(:Set1_5, lw=2))
saveas(file) = save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```

# Basic usage

The main purpose of the **Gnuplot.jl** package is to send data and commands to the underlying gnuplot process, in order to generate plots.  Unlike other packages, however, the actual commands to plot, or the plot attributes, are not specified through function calls.  This is what makes **Gnuplot.jl** *easy to learn and use*: there are no functions or keywords names to memorize[^1].

The most important symbols exported by the package are the [`@gp`](@ref) (for 2D plots) and [`@gsp`](@ref) (for 3D plots) macros.  The simplemost example is as follows:
```@example abc
@gp 1:20
saveas("ex000") # hide
```
![](assets/ex000.png)


Both macros accept any number of arguments, whose meaning is interpreted as follows:

- one, or a group of consecutive, array(s) build up a dataset.  The different arrays are accessible as columns 1, 2, etc. from the gnuplot process.  The number of required input arrays depends on the chosen plot style (see gnuplot documentation);

- a string occurring before a dataset is interpreted as a gnuplot command (e.g. `set grid`);

- a string occurring immediately after a dataset is interpreted as a *plot element* for the dataset, by which you can specify `using` clause, `with` clause, line styles, etc.;

- the special symbol `:-`, whose meaning is to avoid starting a new plot (if given as first argument), or to avoid immediately running all commands to create the final plot (if given as last argument).  Its purpose is to allow splitting one long statement into multiple (shorter) ones.

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
saveas("ex001") # hide
```
![](assets/ex001.png)

---
#### Plot two curves:
```@example abc
@gp "set key left" "plot sin(x)" "pl cos(x)"
saveas("ex002") # hide
```
![](assets/ex002.png)

!!! note
    Note that all gnuplot commands can be abbreviated as long as the resulting string is not ambiguous.  In the example above we used `pl` in place of `plot`.

---
#### Split a `@gp` call in three statements:
```@example abc
@gp    "set grid"  :-
@gp :- "p sin(x)"  :-
@gp :- "plo cos(x)"
saveas("ex003") # hide
```
![](assets/ex003.png)
!!! note
    The trailing `:-` symbol means the plot will not be updated until the last statement.


### Send data from Julia to gnuplot:

#### Plot a parabola
```@example abc
@gp (1:20).^2
saveas("ex004") # hide
```
![](assets/ex004.png)


---
#### Plot a parabola with scaled x axis, lines and legend
```@example abc
x = 1:20
@gp "set key left"   x ./ 20   x.^2   "with lines tit 'Parabola'"
saveas("ex005") # hide
```
![](assets/ex005.png)

---
#### Multiple datasets, logarithmic axis, labels and colors, etc.
```@example abc
x = 1:0.1:10
@gp    "set grid" "set key left" "set logscale y"
@gp :- "set title 'Plot title'" "set label 'X label'" "set xrange [0:*]"
@gp :- x x.^0.5 "w l tit 'Pow 0.5' dt 2 lw 2 lc rgb 'red'"
@gp :- x x      "w l tit 'Pow 1'   dt 1 lw 3 lc rgb 'blue'"
@gp :- x x.^2   "w l tit 'Pow 2'   dt 3 lw 2 lc rgb 'purple'"
saveas("ex006") # hide
```
![](assets/ex006.png)

!!! note
    The above example lacks the trailing `:-` symbol.  This means the plot will be updated at each command, adding one curve at a time.

---
## Keywords for common commands
In order to avoid typing long, and very frequently used gnuplot commands, **Gnuplot.jl** provides a few keywords which can be used in both `@gp` and `@sgp` calls:
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

All such keywords can be abbreviated to unambiguous names.

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


## Plot images

**Gnuplot.jl** can also display images, i.e. 2D arrays:
```@example abc
img = randn(Float64, 30, 50)
img[10,:] .= -5
@gp img "w image notit"
saveas("ex007a") # hide
```
![](assets/ex007a.png)

Note that the first index in the `img` matrix corresponds to the `x` coordinate when the image is displayed.

If the orientation is not the correct one you may adjust it with the gnuplot `rotate=` keyword (the following example requires the `TestImages` package to be installed):
```@example abc
using TestImages
img = testimage("lighthouse");
@gp "set size square" "set autoscale fix" img "rotate=-90deg with rgbimage notit"
saveas("ex007b") # hide
```
![](assets/ex007b.png)


To display a gray image use `with image` in place of `with rgbimage`, e.g.:
```@example abc
img = testimage("walkbridge");
@gp palette(:viridis) "set size square" "set autoscale fix" img "rotate=-0.5pi with image notit"
saveas("ex007c") # hide
```
![](assets/ex007c.png)

Note that we used a custom palette (`:lapaz`, see [Palettes and line types](@ref)) and the rotation angle has been expressed in radians (`-0.5pi`).



## [3D plots](@id plots3d)
3D plots follow the same rules as 2D ones, just replace the `@gp` macro with `@gsp` and add the required columns (according to the plotting style).

E.g., to plot a spiral increasing in size along the `X` direction:
```@example abc
x = 0:0.1:10pi
@gsp cbr=[-1,1].*30  x  sin.(x) .* x  cos.(x) .* x  x./20  "w p pt 7 ps var lc pal"
saveas("ex008") # hide
```
![](assets/ex008.png)

Note that the fourth array in the dataset, `x./20`, is used as by gnuplot as point size (`ps var`).  Also note that all the keywords discussed above can also be used in 3D plots.


## Palettes and line types
The **Gnuplot.jl** package comes with all the [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1) palettes readily available.

A gnuplot-compliant palette can be retrieved with [`palette()`](@ref), and used as any other command.  The previous example may use an alternative palette with:
```@example abc
x = 0:0.1:10pi
@gsp palette(:viridis) cbr=[-1,1].*30 :-
@gsp :-  x  sin.(x) .* x  cos.(x) .* x  x./20  "w p pt 7 ps var lc pal"
saveas("ex008a") # hide
```
![](assets/ex008a.png)

The list of all available palette can be retrieved with [`palette_names()`](@ref):
```@repl abc
palette_names()
```


The [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1) palettes can also be used to generate line type colors, and optionally the line width, point size and dashed pattern, by means of the [`linetypes()`](@ref) function, e.g.
```@example abc
@gp "set key left" "set multiplot layout 1,2"
@gp :- 1 linetypes(:Set1_5, lw=2)
for i in 1:10
    @gp :- i .* (0:10) "w lp t '$i'"
end
@gp :- 2 linetypes(:Set1_5, dashed=true, ps=2)
for i in 1:10
    @gp :- i .* (0:10) "w lp t '$i'"
end
saveas("ex009") # hide
```
![](assets/ex009.png)

The plot on the left features the `:Set1_5` palette and where each line is solid and has a width of 2 by default.  The plot on the right shows the same palette but default line widths are 1, default point size is 2 (for the first N line types, where N is the number of discrete colors in the palette), and the dashed pattern is automatically changed.  

You may set a default line types for all plots with:
```julia
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=2))
```
(see [Options](@ref) for further informations).  All plot in this documentation were generated with the latter settings.


## Exporting plots to files

**Gnuplot.jl** to export all plots (as well as multiplots, see [Multiplot](@ref)) to an external file using one of the many available gnuplot terminals.  To check which terminals are available in your platform type:
```@repl abc
terminals()
```
(see also [`terminal()`](@ref) to check your current terminal).

Once you choose the proper terminal (i.e. format of the exported file), use the [`save()`](@ref) function to export.  As an example, all the plots in this page have been saved with:
```julia
save(term="pngcairo size 550,350 fontscale 0.8", output="assets/output.png")
```
Note that you can pass both the terminal name and its options via the `term=` keyword.  See [Gnuplot terminals](@ref) for further info on the terminals.


## Gnuplot scripts
Besides exporting plots in image files, **Gnuplot.jl** can also save a *script*, i.e. a file containing the minimum set of data and commands required to re-create a figure using just gnuplot.

The script allows a complete decoupling of plot data and aethetics, from the Julia code used to generate them.  With scripts you can:
- modify all aesthetic details of a plot without re-running the (possibly complex and time-consuming) code used to generate it;
- share both data and plots with colleagues without the need to share the Julia code.

To generate a script for one of the examples above use:
```julia
save("script.gp")
```
after the plot has been displayed.  Note that when images or large datasets are involved, `save()` may store the data in binary files under a directory named `<script name>_data`. In order to work properly both the script and the associated directory must be available in the same directory.


E.g., the following code:
```@example abc
x = 1:10
@gp x x.^2 "w l"
save("script1.gp")
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
img = testimage("lighthouse");
@gp "set size square" "set autoscale fix" img "rotate=-90deg with rgbimage notit"
save("script2.gp")
```
will produce:
```
reset session
set size square
set autoscale fix
plot  \
   './script2_data/jl_vH8X4k' binary array=(512, 768) rotate=-90deg with rgbimage notit
set output
```

The above scripts can be loaded into a pure gnuplot session (Julia is no longer needed) as follows:
```
gunplot> load 'script1.gp'
gunplot> load 'script2.gp'
```
to generate a plot identical to the original one.


The purpose of gnuplot scripts is to allow sharing all data, alongside a plot, in order to foster collaboration among scientists and replicability of results.  Moreover, a script can be used at any time to change the details of a plot, without the need to re-run the Julia code used to generate it the first time.

Finally, the scripts are the only possible output when [Dry sessions](@ref) are used (i.e. when gnuplot is not available in the user platform.
