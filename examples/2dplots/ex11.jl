# This file was generated, do not modify it. # hide
using Gnuplot, Random
Random.seed!(123)
goffset = "set offsets graph .05, graph .05, graph .05, graph .05"
@gp(rand(30), rand(30), "w p pt 6 ps 2 lc '#D55E00' lw 2 t 'marker'",
    goffset, title = "scatter plot", xlabel ="X", ylabel = "Y",
    "set key b l box opaque")
    save(term="pngcairo size 600,400", output="plt_ex11.png") # hide