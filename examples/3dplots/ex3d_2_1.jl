# This file was generated, do not modify it. # hide
using Gnuplot
@gsp " " :-  # reset session
@gsp "unset key" "set multi layout 2,2 title 'Multiplot title'" :-
@gsp :- 1 x y Z "w linespoints pt 4 ps 2" :-
@gsp :- 2 x y Z "w points pt 3 ps 3" :-
@gsp :- 3 x y Z "w l palette" "set view 55, 65" :-
@gsp :- 4 x y Z "w pm3d" "set view 55, 65" "set key off" :-
@gsp :- x y Z "w l lc 'white'" 
save(term="pngcairo size 1200,800", output="plt3d_ex2.png")