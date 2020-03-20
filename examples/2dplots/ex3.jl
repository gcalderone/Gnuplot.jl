# This file was generated, do not modify it. # hide
using Gnuplot
x = -2π:0.001:2π
@gp(x, sin.(x), "w l t 'sin'", "set yrange [-1.1:1.1]", "set grid",
    x, cos.(x), "with linespoints ls 1 t 'cos' ",
    "set style line 1 lc rgb 'black' lt 1 lw 1 pt 6 pi -200 ps 1.5")
    save(term="pngcairo size 600,400", output="plt2_ex3.png") # hide