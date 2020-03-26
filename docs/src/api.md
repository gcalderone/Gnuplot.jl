# API

## Exported symbols
The list of **Gnuplot.jl** exported symbols is as follows:

```@docs
@gp
@gsp
save
```


## Non-exported symbols
The following functions are not exported by the **Gnuplot.jl** package since they are typically not used in every day work, or aimed to debugging purposes.  Still, they can be useful in some case, hence they are documented here.

In order to call these functions you should add the `Gnuplot.` prefix to the function name.

```@docs
Gnuplot.exec
Gnuplot.gpversion
Gnuplot.quit
Gnuplot.quitall
Gnuplot.version
```
