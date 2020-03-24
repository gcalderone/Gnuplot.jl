# Examples

```julia

@gp "set multiplot layout 1,2"
@gp :- 1 "plot sin(x) w l"


x = y = -10:0.33:10
fz(x,y) = sin.(sqrt.(x.^2 + y.^2))./sqrt.(x.^2+y.^2)
fxy = [fz(x,y) for x in x, y in y]

@gsp :- 2 x y fxy "w pm3d notit"

```



@gp "set multiplot layout 1,2"
@gp :- 2  "unset grid" "unset border" "unset tics" :-
@gp :- 1 "plot sin(x) w l"

x = y = -10:0.33:10
fz(x,y) = sin.(sqrt.(x.^2 + y.^2))./sqrt.(x.^2+y.^2)
fxy = [fz(x,y) for x in x, y in y]

@gsp :- 2 x y fxy "w pm3d notit"
