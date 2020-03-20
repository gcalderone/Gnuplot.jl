# This file was generated, do not modify it. # hide
using Gnuplot
t = 0:0.001:1
@gp(t, sin.(2π*5*t), "with lines title 'sin' linecolor 'black'")
#save("plt2_ex2.gp") # hide
#save(term="pdf size 5,3", output="plt2_ex2.pdf") # hide
save(term="pngcairo size 600,400", output="plt2_ex2.png") # hide