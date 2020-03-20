# This file was generated, do not modify it. # hide
using Gnuplot
@gsp " " :-  # reset session
@gsp "unset key" "set multi layout 1,2 title 'Multiplot title'" :-
@gsp :- 1 x y Z "w l palette" "set view 55, 65" :-
@gsp :- 2 x y Z "w pm3d" "set view 55, 65" "set key off" :-
@gsp :- x y Z "w l lc 'white'" 
save(term="pngcairo size 800,400", output="plt3d_ex2_2.png")