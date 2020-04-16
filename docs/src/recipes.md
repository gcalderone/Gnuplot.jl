```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")

empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, "set term unknown")
empty!(Gnuplot.options.reset)
push!( Gnuplot.options.reset, linetypes(:Set1_5, lw=1.5))
saveas(file) = save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```

# Plot recipes

A plot *recipe* is a quicklook visualization procedure aimed at reducing the amount of repetitive code needed to generate a plot.  More specifically, a recipe is a function to convert data from the "Julia world" into a form suitable to be ingested in **Gnuplot.jl**.

There are two kinds of recipes:

- *explicit* recipe: a function which is explicitly invoked by the user.  It can have any name and accept any number of arguments and keywords.  It is typically used when the visualization of a data type requires some extra information, beside data itself.  An example is the quicklook procedure for a `DataFrame` object (shown below);

- *implicit* recipe: a function which is automatically called by **Gnuplot.jl**.  It must extend the `Gnuplot.recipe` function, and accept exactly one mandatory argument.  It is typically used when the visualization is completely determined by the data type itself.  An example is the visualization of a `Matrix{ColorTypes.RGB}` object as an image.

In both cases the recipe function must return a scalar, or a vector of, `PlotElements` object(s), containing all the informations to create a plot, or a part of it.


The `@gp` or `@gsp`.
In , and can be passed directly to `@gp` or `@gsp`.





.  The fields of the `PlotElements` structure are:
- `mid::Int`:: multiplot ID;
- `cmds::Vector{String}`: commands to set plot properties;
- `data::Vector{Dataset}`: data set(s);
- `plot::Vector{String}`: plot specifications for each `Dataset`;

where `Dataset` is an abstract type, the actual data sets are stored in the form of either a `DatasetText` object (a textual representation of the data) or a `DatasetBin` object (a binary file).  Both `DatasetText` and `DatasetBin` structures provide a number of constructors accepting several types of input data.





As anticipated, a recipe can be explicitly called by the user and the output passed to `@gp` or `@gsp`.

All arguments to `@gp` or `@gsp` (except `Int`s, `String`s, `Tuple`s, `Array` of both numbers and strings) are scanned to check if an implicit recipe exists to handle them, and in this case it is 

Although a recipe provides a very efficient mean for data exploration, 

## Histogram recipes

## Image recipes
If the orientation is not the correct one you may adjust it with the gnuplot `rotate=` keyword (the following example requires the `TestImages` package to be installed):
```@example abc
using TestImages
img = testimage("lighthouse");
@gp img
saveas("recipes007b") # hide
```
![](assets/recipes007b.png)


To display a gray image use `with image` in place of `with rgbimage`, e.g.:
```@example abc
img = testimage("walkbridge");
@gp palette(:viridis) recipe(img, "flipy rot=15deg")
saveas("recipes007c") # hide
```
![](assets/recipes007c.png)

Note that we used a custom palette (`:lapaz`, see [Palettes and line types](@ref)) and the rotation angle has been expressed in radians (`-0.5pi`).

