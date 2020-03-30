# Advanced techniques

Here we will show a few advanced techniques for data visualization using **Gnuplot.jl**.  The new concepts introduced in the examples are as follows:

- a name can be associated to a dataset, in order to use it multiple times in a plot while sending it only once to gnuplot. A dataset name must begin with a `$`;

- gnuplot is able to generate multiplot, i.e. a single figure containing multiple plots.  Each plot is identified by a numeric ID, starting from 1;

- **Gnuplot.jl** is able to handle multiple sessions, i.e. multiple gnuplot processes running simultaneously.  Each session is identified by a symbol.  If the session ID is not specified the `:default` session is considered.


```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")
saveas(file) = save(term="pngcairo size 480,360", output="assets/$(file).png")
empty!(Gnuplot.options.init)
Gnuplot.exec("set term unknown")
```


## Named datasets
A named dataset can be used multiple times in a plot, avoiding sending to gnuplot the same data multiple times.  A dataset name must always start with a `$`, and the dataset is defined as a `Pair{String, Tuple}`, e.g.:
```julia
"\$name" => (1:10,)
```

A named dataset can be used as an argument to both `@gp` and `gsp`, e.g.:
```@example abc
x = range(-2pi, stop=2pi, length=100);
y = sin.(x)
name = "\$MyDataSet1"
@gp name=>(x, y) "plot $name w l lc rgb 'black'" "pl $name u 1:(-1.5*\$2) w l lc rgb 'red'"
saveas("ex010") # hide
```
![](assets/ex010.png)

Both curves use the same input data, but the red curve has the second column (`\$2`, corresponding to the *y* value) is multiplied by a factor -1.5.


## Multiplot

### Mixing 2D and 3D plots
```julia

@gp "set multiplot layout 1,2"
@gp :- 1 "plot sin(x) w l"


x = y = -10:0.33:10
fz(x,y) = sin.(sqrt.(x.^2 + y.^2))./sqrt.(x.^2+y.^2)
fxy = [fz(x,y) for x in x, y in y]

@gsp :- 2 x y fxy "w pm3d notit"

```

```julia
img = testimage("earth_apollo17");
@gp "set multiplot layout 2,2 tit 'rotate keyword (positive direction is counter-clockwise)'" :-
@gp :- "set size square" "set autoscale fix" "unset tics" "\$img"=>(img,) :-
@gp :- 1 tit="Original"         "plot \$img               with rgbimage notit" :-
@gp :- 2 tit="rotate=-90 deg"   "plot \$img rotate=-90deg with rgbimage notit" :-
@gp :- 3 tit="rotate=0.5pi"     "plot \$img rotate=0.5pi  with rgbimage notit" :-
@gp :- 4 tit="rotate=180 deg"   "plot \$img rotate=180deg with rgbimage notit"
```

## Multiple sessions
## Histograms (1D)
## Histograms (2D)
## Contour lines
## Animations
## Dry sessions
## Options
