# This file was generated, do not modify it. # hide
using Gnuplot
x=[0,1,2]
y=[0,1,2]
Z=[10 10 10; 10 3 10; 10 2 10]
@gsp x y Z "w l lc 'red'"
save(term="png", output="plt3d_ex1.png")