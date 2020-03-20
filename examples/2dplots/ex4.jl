# This file was generated, do not modify it. # hide
using Gnuplot
x = -2π:0.001:2π
@gp(x, sin.(x),"w l t 'sin' lw 2 lc '#56B4E9'", "set grid", 
    xrange = (-2π - 0.3, 2π + 0.3), yrange = (-1.1,1.1))
@gp(:-, x, cos.(x), "w l t 'cos' lw 2 lc rgb '#E69F00'")
save(term="pngcairo size 600,400", output="plt2_ex4.png") # hide