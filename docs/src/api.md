# API

## Index
```@index
```

## Exported symbols
The list of **Gnuplot.jl** exported symbols is as follows:

```@docs
@gp
@gsp
boxxy
contourlines
dgrid3d
gpexec
gpmargins
gpranges
gpvars
hist
hist_bins
hist_weights
linetypes
palette
palette_levels
palette_names
recipe
save
session_names
stats
terminals
terminal
test_terminal
```


## Non-exported symbols
The following functions are not exported by the **Gnuplot.jl** package since they are typically not used in every day work, or aimed to debugging purposes.  Still, they can be useful in some case, hence they are documented here.

In order to call these functions you should add the `Gnuplot.` prefix to the function name.

```@docs
Gnuplot.Dataset
Gnuplot.DatasetEmpty
Gnuplot.DatasetText
Gnuplot.DatasetBin
Gnuplot.IsoContourLines
Gnuplot.Options
Gnuplot.Path2d
Gnuplot.gpversion
Gnuplot.quit
Gnuplot.quitall
Gnuplot.repl_init
Gnuplot.version
```
