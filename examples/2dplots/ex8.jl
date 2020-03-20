# This file was generated, do not modify it. # hide
using Gnuplot, Colors, ColorSchemes
x = LinRange(-2π,2π,200)
#colorbar tricks... # hide
cbwt = 0.02 # hide
rightmargin = 0.875 # hide
cboxp="set colorbox user origin graph 1.01, graph 0 size $cbwt, graph 1" # hide
addmargin="set rmargin at screen $rightmargin" # hide
goffset="set offsets graph .05, graph .05, graph .05, graph .05" # hide
#custom palette, colormap # hide
function custom_palette(colormap=:viridis) # hide
cmap = get(colorschemes[colormap], LinRange(0,1,256)) # hide
ctmp = "0 '#$(hex(cmap[1]))'," # hide
for i in 2:256; ctmp = ctmp*"$(i-1) '#$(hex(cmap[i]))'," end; # hide
"set palette defined("*ctmp[1:end-1]*")" # hide
end # hide
@gp(x, -0.65sin.(3x), x,  "w l lw 3 dt 1 lc palette", 
    "set key off", "set auto fix")
    #goffset, cboxp, addmargin) # hide
save(term="pngcairo size 600,400", output="plt_ex8.png") # hide