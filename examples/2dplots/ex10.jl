# This file was generated, do not modify it. # hide
using Gnuplot, Random
Random.seed!(123)
goffset = "set offsets graph .05, graph .05, graph .05, graph .05"
@gp rand(30) rand(30) "w p pt 4 ps 3 lc '#0072B2' lw 2 t 'marker'" goffset
save(term="pngcairo size 600,400", output="plt_ex10.png") # hide