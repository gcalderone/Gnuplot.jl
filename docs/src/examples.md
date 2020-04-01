# Examples

An exhaustive gallery of example is available here:

[https://lazarusa.github.io/gnuplot-examples/](https://lazarusa.github.io/gnuplot-examples/)

Further `gnuplot` examples can be found here: [http://www.gnuplotting.org/](http://www.gnuplotting.org/)
```julia
Gnuplot.quitall()
@gp    "set term wxt  noenhanced size 600,300" :-
@gp :- "set margin 0"  "set border 0" "unset tics" :-
@gp :- xr=[-0.3,1.7] yr=[-0.3,1.1] :-
@gp :- "set origin 0,0" "set size 1,1" :-
@gp :- "set label 1 at graph 1,1 right offset character -1,-1 font 'Verdana,20' tc rgb '#4d64ae' ' Ver: " * string(Gnuplot.version()) * "' " :-
@gp :- "set arrow 1 from graph 0.05, 0.15 to graph 0.95, 0.15 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
@gp :- "set arrow 2 from graph 0.15, 0.05 to graph 0.15, 0.95 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
@gp :- ["0.35 0.65 @ 13253682", "0.85 0.65 g 3774278", "1.3 0.65 p 9591203"] "w labels notit font 'Mono,160' tc rgb var"
save(term="pngcairo noenhanced size 600,300", output="splash.png")
```
