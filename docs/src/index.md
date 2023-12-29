# Gnuplot.jl
## A Julia interface to gnuplot.
[![Stars](https://img.shields.io/github/stars/gcalderone/Gnuplot.jl?style=social)](https://github.com/gcalderone/Gnuplot.jl)


The **Gnuplot.jl** package allows easy and fast use of [gnuplot](http://gnuplot.info/) as a data visualization tool in Julia.  Have a look at [Basic usage](@ref) and [Examples](@ref) for a quick overview.  The package main features are:

- fast time-to-first-plot;

- extremely concise yet meaningful syntax, makes it ideal for interactive data exploration;

- no need to learn new API functions or keywords: only two macros (`@gp` for 2D plots, `@gsp` for 3D plots) and a basic knowledge of gnuplot are enough to generate most plots;

- transparent interface between Julia and gnuplot to exploit all functionalities of the latter, both present and future ones;

- availability of all the palettes from [ColorSchemes](https://github.com/JuliaGraphics/ColorSchemes.jl);

- support for multiple plots in one window, multiple plotting windows, as well as ASCII and Sixel plots (to plot directly in a terminal);

- support for histograms (both 1D and 2D);

- enhanced support for contour plots;

- 2D interpolation of scattered data on a regular grid;

- export to a huge number of formats such as `pdf`, `png`, `gif`, ``\LaTeX``, `svg`, etc. (actually all those supported by gnuplot);

- compatibility with Jupyter and Juno;

- save sessions into gnuplot scripts, to enable easy plot customization and reproducibility.

If you're unfamiliar with gnuplot have a look at:

- [Main gnuplot site](http://gnuplot.info/)
- [gnuplot FAQ](http://gnuplot.info/faq/index.html)


## Yet another plotting package?

A powerful plotting framework is among the most important tool in the toolbox of any modern scientist and engineer.  As such, it is hard to find a single package to fit all needs, and many solutions are indeed available in the Julia [ecosystem](https://github.com/JuliaPlots).

**Gnuplot.jl** package fills the niche of users who needs:

1. publication-quality plots, by exploiting the capabilities of a widely used tool such as gnuplot, and its many output formats available;
1. a well-documented framework, by taking advantage of all the gnuplot documentation, tutorials and examples available on the web;
1. a fast response, by relying on an external program (rather than on a large Julia code base);
1. an interactive data exploration framework, by exposing a carefully designed, extremely concise and easy to remember syntax (at least for users with minimal gnuplot knowledge);
1. a procedure to decouple plot data and aesthetics from the Julia code used to generate them.

Unlike other packages **Gnuplot.jl** is not a pure Julia solution as it depends on an external package to actually generate plots.  However, if gnuplot is not available on a given platform, the package could still be used in "*dry*" mode, and no error for a missing dependency will be raised (see [Dry sessions](@ref)).

The **Gnuplot.jl** package development follows a minimalistic approach: it is essentially a thin layer to send data and commands to gnuplot.  This way all underlying capabilities, both present and future ones, are automatically exposed to the Julia user, with no need to implement dedicated wrappers.

The functionalities 1, 2 and 3 listed above are similar to those provided by the [Gaston](https://github.com/mbaz/Gaston.jl) package.  **Gnuplot.jl** also provides features 4 and 5, as well as the minimalistic approach.


## Does Gnuplot.jl suit my needs?

Any modern plotting framework is able to produce a simple scatter plot, with custom symbols, line styles, colors and axis labels.  Indeed, this is exactly the example that is reported in every package documentation (also here: see [2D plots](@ref plots2d)). Still, producing complex and publication-quality plots is not an easy task.  As a consequence is also hard to tell whether a package can cope with the most difficult cases, unless you actually try it out.  A reasonable choice, then, is to rely on the size of the user base, the availability of documentation / tutorials, and the possibility to preview complex examples.

By allowing transparent access to the underlying gnuplot process, the **Gnuplot.jl** package immediately exposes all capabilities of the backend and allows to take advantage of the many resources available online.  The minimalistic approach allows to value the widely spread knowledge of gnuplot syntax, and ensures a shallow learning curve for the package.  Finally, its extremely concise syntax makes it ideal for interactive data exploration.

As a final remark, note that the **Gnuplot.jl** features directly maps onto the different stages of production of a plot:
- syntax conciseness, interactivity, [Plot recipes](@ref) => preliminary data exploration;
- access to all gnuplot capabilities, allowing to tweak even the smallest detail of a plot => plot preparation;
- [Gnuplot scripts](@ref) => post-production.

Before continuing, have a look at the [Examples](@ref) page!



## Notation
In this documentation:
- "**Gnuplot.jl**" refers to the Julia package;
- "gnuplot" refers to the [gnuplot](http://gnuplot.info/) application.


## Table of Contents
```@contents
Pages = ["index.md", "install.md", "basic.md", "advanced.md", "options.md", "style.md", "terminals.md", "recipes.md", "examples.md", "api.md"]
```
