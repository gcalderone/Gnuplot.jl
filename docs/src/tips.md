# Tips

This page collects useful tips in using **Gnuplot.jl**.


## Which terminal should I use ?
Gnuplot provides dozens of terminals to display plots or export them into files (see [`terminals()`](@ref) to get a list of enabled terminals on your platform).  This section discuss a few tips on how to use the most common terminals.

To use a specific terminal for interactive use you may either add it as initialization command for all new session with (see [Options](@ref):
```julia
push!(Gnuplot.options.init, "set term wxt")
```
or directly send the command to a specific session (see [Direct command execution](@ref))
```julia
gpexec("set term wxt")
```


### Interactive terminals (`wxt` and `qt`)
The multiplatform `wxt` and `qt` terminals are among the most widely used ones for their nicely looking outputs on display and for their interactive capabilities.

You may set them as terminal with:
```
"set term wxt size 800,600"
```
or
```
"set term qt  size 800,600"
```
(the `size 800,600` is optional and can be omitted).

Press the `h` key on the window to display an help message with all available keyboard shortcuts.  In particular press `6` to enable printing plot coordinates on Julia stdout (ensure mouse is enabled with `m`).


### Plot in a terminal (`dumb`, `sixel` and `sixelgd`)
Gnuplot supports plotting in a terminal application, with no need for X11 or other GUI support, via the `dumb`, `sixel` and `sixelgd` terminals.  These are useful when you run Julia on a remote shell through `ssh`.  You may set these terminals with one of the following command:
```
"set term dumb"
"set term sixel"
"set term sixelgd"
```
The `dumb` terminal uses ASCII characters to draw a plot, while `sixel` and `sixelgd` actually use bitmaps (but require Sixel support to be enabled in the terminal, e.g. `xterm -ti vt340`).  A sixel plot on `xterm` looks as follows:
![](assets/sixelgd.png)

The above terminals are available if gnuplot has been compiled with the `--with-bitmap-terminals` option enabled. Also, `sixelgd` requires support for Libgd to be enabled.

### Export to image files

### `cairopng`

### `gif`
see [Animations](@ref).

### `pdf`

### `latex` and `cairolatex`
