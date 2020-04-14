# Plot recipes

A plot *recipe* is a function to convert data from the "Julia world" into one, or more, `Gnuplot.PlotElements` object(s) suitable to be ingested in **Gnuplot.jl**.  These objects contain all the informations to create a plot, and can be passed directly to `@gp` or `@gsp`. The main purpose of recipes is to provide quick data visualization procedures.


There are two kinds of plot recipes:
- *explicit* recipe: a function which is explicitly invoked by the user.  It can have any name, and accept any number of arguments and keywords.  It is typically used when the conversion from Julia data to `Gnuplot.Recipe` objects requires some extra informations, beside data itself.  An example is the quick look procedure for a `DataFrame` object (shown below);

- *implicit* recipe: a function which is automatically called by **Gnuplot.jl** (never by the user).  It must extend the `Gnuplot.recipe` function, and accept exactly one argument and no keywords.  it is typically used when the conversion is completely determined by the data type itself.  An example is the plot of a `Matrix{ColorTypes.RGB}` data as an image.

In both cases the recipe function must return a scalar, or a vector of, `Gnuplot.PlotElements` object(s).  The fields of the structure are:
- `mid::Int`:: multiplot ID;
- `cmds::Vector{String}`: commands to set plot properties;
- `data::Vector{DataSet}`: data sets to plot;
- `plot::Vector{String}`: plot specifications for each `DataSet`.

`DataSet` is an abstract type, the actual data sets are stored in the form of either a `DataSetText` object (a textual representation of the data) or a `DataSetBin` object (a binary file).  Both `DataSetText` and `DataSetBin` structures provide a number of constructors accepting several types of input data.



