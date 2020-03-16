# Original example:
# http://gnuplot.sourceforge.net/demo/hidden2.html

using Gnuplot

x = LinRange(-10, 10, 25)
y = LinRange(-10, 10, 25)

@gsp    "set xyplane at 0"
@gsp :- "unset key"
@gsp :- "set palette rgbformulae 31,-11,32"
@gsp :- "set style fill solid 0.5"
@gsp :- "set cbrange [-1:1]"
@gsp :- title="Mixing pm3d surfaces with hidden-line plots"
@gsp :- "set hidden3d front"

f = [sin(-sqrt((x+5)^2+(y-7)^2)*0.5) for x in x, y in y]
z = [x*x-y*y for x in x, y in y]
@gsp :- x y f "w pm3d" x y z "w l lc rgb 'black'"
