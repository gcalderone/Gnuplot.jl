```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")

Gnuplot.options.term = "unknown"
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
saveas(file) = Gnuplot.save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```


# Plot recipes

A plot *recipe* is a quicklook visualization procedure aimed at reducing the amount of repetitive code to generate a plot.  More specifically, a recipe is a function that convert data from the "Julia world" into a form suitable to be ingested in **Gnuplot.jl**, namely a scalar (or a vector of) `Gnuplot.PlotElement` TODO object(s).  The latter contain informations on how to create a plot, or a part of it, and can be used directly as arguments in a `@gp` or `@gsp` call.

There are two kinds of recipes:

- *explicit* recipe: a function which is explicitly invoked by the user.  It can have any name and accept any number of arguments and keywords.  It is typically used when the visualization of a data type requires some extra information, beside data itself (e.g. to plot data from a `DataFrame` object, see [Simple explicit recipe](@ref));

- *implicit* recipe: a function which is automatically called by **Gnuplot.jl**.  It must extend the `recipe()` TODO function, and accept exactly one mandatory argument.  It is typically used when the visualization is completely determined by the data type itself (e.g. the visualization of a `Matrix{ColorTypes.RGB}` object as an image, see [Image recipes](@ref));

An implicit recipe is invoked whenever the data type of an argument to `@gp` or `@gsp` is not among the allowed ones (see [`@gp()`](@ref) documentation).  If a suitable recipe do not exists an error is raised.  On the other hand, an explicit recipe needs to be invoked by the user, and the output passed directly to `@gp` or `@gsp`.

Although recipes provides very efficient tools for data exploration, their use typically hide the details of plot generation.  As a consequence they provide less flexibility than the approaches described in [Basic usage](@ref) and [Advanced usage](@ref).

Currently, the **Gnuplot.jl** package provides no built-in explicit recipe.  The implicit recipes are implemented in [recipes.jl](https://github.com/gcalderone/Gnuplot.jl/blob/master/src/recipes.jl).



## Simple explicit recipe

To generate a plot using the data contained in a `DataFrame` object we need, beside the data itself, the name of the columns to use for the X and Y coordinates.  The following example shows how to implement an explicit recipe to plot a `DataFrame` object:
```@example abc
using RDatasets, DataFrames, Gnuplot

function plotdf(df::DataFrame, colx::Symbol, coly::Symbol; group=nothing)
    if isnothing(group)
        return Gnuplot.parseSpecs(df[:, colx], df[:, coly], "w p notit",
                                  xlab=string(colx), ylab=string(coly))
    end

    out = Vector{Gnuplot.AbstractGPCommand}()
	append!(out, Gnuplot.parseSpecs(xlab=string(colx), ylab=string(coly)))
    for g in sort(unique(df[:, group]))
        i = findall(df[:, group] .== g)
        if length(i) > 0
            append!(out, Gnuplot.parseSpecs(df[i, colx], df[i, coly], "w p t '$g'"))
        end
    end
    return out
end

# Load a DataFrame and plot two of its columns
iris = dataset("datasets", "iris")
@gp plotdf(iris, :SepalLength, :SepalWidth, group=:Species)
saveas("recipes001") # hide
```
![](assets/recipes001.png)


## Corner plot recipe

The following is a slightly more complex example illustrating how to generate a corner plot:
```@example abc
using RDatasets, DataFrames, Gnuplot

function cornerplot(df::DataFrame; nbins=5, margins="0.1, 0.9, 0.15, 0.9", spacing=0.01, ticscale=1)
    numeric_cols = findall([eltype(df[:, i]) <: Real for i in 1:ncol(df)])
    out = Vector{Gnuplot.AbstractGPCommand}()
    append!(out, Gnuplot.parseSpecs("set multiplot layout $(length(numeric_cols)), $(length(numeric_cols)) margins $margins spacing $spacing columnsfirst downward"))
    id = 1
    for ix in numeric_cols
        for iy in numeric_cols
			append!(out, Gnuplot.parseSpecs(id, xlab="", ylab="", "set xtics format ''", "set ytics format ''", "set tics scale $ticscale"))
            (iy == maximum(numeric_cols))  &&  append!(out, Gnuplot.parseSpecs(id, xlab=names(df)[ix], "set xtics format '% h'"))
            (ix == minimum(numeric_cols))  &&  append!(out, Gnuplot.parseSpecs(id, ylab=names(df)[iy]))

            xr = [extrema(df[:, ix])...]
            yr = [extrema(df[:, iy])...]
            if ix == iy
                h = hist(df[:, ix], range=xr, nbins=nbins)
                append!(out, Gnuplot.parseSpecs(id, "unset ytics", xr=xr, yr=[NaN,NaN], hist_bins(h), hist_weights(h), "w steps notit lc rgb 'black'"))
            elseif ix < iy
                append!(out, Gnuplot.parseSpecs(id,                xr=xr, yr=yr       , df[:, ix], df[:, iy], "w p notit"))
            end
            id += 1
        end
    end
    return out
end

# Load a DataFrame and generate a cornerplot
iris = dataset("datasets", "iris")
@gp cornerplot(iris)
saveas("recipes001_1") # hide
```
![](assets/recipes001_1.png)


## Histogram recipes
The object returned by the [`hist()`](@ref) function can be readily visualized by means of implicit recipes defined on the `StatsBase.Histogram` type (in both 1D and 2D) types:

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


## Contour lines recipes
The object returned by the [`contourlines()`](@ref) function can be readily visualized by means of implicit recipes defined on the `Gnuplot.IsoContourLines` types:
```@example abc
x = randn(10_000);
y = randn(10_000);
h = hist(x, y)
clines = contourlines(h, "levels discrete 10, 30, 60, 90");
@gp clines
saveas("recipes002b") # hide
```
![](assets/recipes002b.png)




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
@gp palette(:gray1) Gnuplot.recipe(img, "flipy rot=15deg")
saveas("recipes007c") # hide
```
![](assets/recipes007c.png)

Note that we used both a palette (`:gray`, see [Palettes and line types](@ref)) and a custom rotation angle.


The `flipy` option is necessary for proper visualization (see discussion in [Plot matrix as images](@ref)).
