# Advanced techniques

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
## Named datasets
## Histograms (1D)
## Histograms (2D)
## Contour lines
## Animations
## Dry sessions
## Options
