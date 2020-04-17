```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")

Gnuplot.options.term = "unknown"
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
saveas(file) = save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```


# Plot recipes

A plot *recipe* is a quicklook visualization procedure aimed at reducing the amount of repetitive code to generate a plot.  More specifically, a recipe is a function that convert data from the "Julia world" into a form suitable to be ingested in **Gnuplot.jl**, namely a scalar (or a vector of) [`Gnuplot.PlotElement`](@ref) object(s).  The latter contain informations on how to create a plot, or a part of it, and can be used directly as arguments in a `@gp` or `@gsp` call.

There are two kinds of recipes:

- *explicit* recipe: a function which is explicitly invoked by the user.  It can have any name and accept any number of arguments and keywords.  It is typically used when the visualization of a data type requires some extra information, beside data itself (e.g. to plot data from a `DataFrame` object, see [Explicit recipe (example)](@ref));

- *implicit* recipe: a function which is automatically called by **Gnuplot.jl**.  It must extend the p`recipe()`](@ref) function, and accept exactly one mandatory argument.  It is typically used when the visualization is completely determined by the data type itself (e.g. the visualization of a `Matrix{ColorTypes.RGB}` object as an image, see [Image recipes](@ref));

An implicit recipe is invoked whenever the data type of an argument to `@gp` or `@gsp` is not among the allowed ones (see [`@gp()`](@ref) documentation).  If a suitable recipe do not exists an error is raised.  On the other hand, an explicit recipe needs to be invoked by the user, and the output passed directly to `@gp` or `@gsp`.

Although recipes provides very efficient tools for data exploration, their use typically hide the details of plot generation.  As a consequence they provide less flexibility than the approaches described in [Basic usage](@ref) and [Advanced usage](@ref).

Currently, the **Gnuplot.jl** package provides no built-in explicit recipe.  The implicit recipes are implemented in [recipes.jl](https://github.com/gcalderone/Gnuplot.jl/blob/master/src/recipes.jl).



## Explicit recipe (example)

To generate a plot using the data contained in a `DataFrame` object we need, beside the data itself, the name of the columns to use for the X and Y coordinates.  The following example shows how to implement an explicit recipe to plot a `DataFrame` object:
```@example abc
using RDatasets, DataFrames, Gnuplot
import Gnuplot: PlotElement, DatasetText

function plotdf(df::DataFrame, colx::Symbol, coly::Symbol; group=nothing)
    if isnothing(group)
        return PlotElement(data=DatasetText(df[:, colx], df[:, coly]),
                           plot="w p notit",
                           xlab=string(colx), ylab=string(coly))
    end

    out = Vector{Gnuplot.PlotElement}()
    push!(out, PlotElement(;xlab=string(colx), ylab=string(coly)))
    for g in sort(unique(df[:, group]))
        i = findall(df[:, group] .== g)
        if length(i) > 0
            push!(out, PlotElement(data=DatasetText(df[i, colx], df[i, coly]),
                                   plot="w p t '$g'"))
        end
    end
    return out
end

# Load a DataFrame and convert it to a PlotElement
iris = dataset("datasets", "iris")
@gp plotdf(iris, :SepalLength, :SepalWidth, group=:Species)
saveas("recipes001") # hide
```
![](assets/recipes001.png)



## Histogram recipes
The object returned by the [`hist()`](@ref) function can be readily visualized by means of implicit recipes defined on the `Gnuplot.Histogram1D` and `Gnuplot.Histogram2D` types:

```@example abc
x = randn(1000);
@gp hist(x)
saveas("recipes002") # hide
```
![](assets/recipes002.png)


```@example abc
x = randn(10_000);
y = randn(10_000);
@gp hist(x, y)
saveas("recipes002a") # hide
```
![](assets/recipes002a.png)




## Image recipes

The **Gnuplot.jl** package provides implicit recipes to display images in the following formats:
- `Matrix{ColorTypes.RGB{T}}`;
- `Matrix{ColorTypes.RGBA{T}}`
- `Matrix{ColorTypes.Gray{T}}`;
- `Matrix{ColorTypes.GrayA{T}}`;

To use these recipes simply pass an image to `@gp`, e.g.:
```@example abc
using TestImages
img = testimage("lighthouse");
@gp img
saveas("recipes007b") # hide
```
![](assets/recipes007b.png)


All such recipes are defined as:
```julia
function recipe(M::Matrix{ColorTypes.RGB{T}}, opt="flipy")
  ...
end
```
with only one mandatory argument.  In order to exploit the optional keyword we can explicitly invoke the recipe as follows:
```@example abc
img = testimage("walkbridge");
@gp palette(:gray) recipe(img, "flipy rot=15deg")
saveas("recipes007c") # hide
```
![](assets/recipes007c.png)

Note that we used both a palette (`:gray`, see [Palettes and line types](@ref)) and a custom rotation angle.


The `flipy` option is necessary for proper visualization (see discussion in [Plot matrix as images](@ref)).
