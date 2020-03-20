# This file was generated, do not modify it. # hide
using Gnuplot, ColorSchemes
x = -2π:0.001:2π
function circShape(h,k,r)
    θ = LinRange(0,2π,500)
    h .+ r*sin.(θ), k .+ r*cos.(θ)
end
bgcp1 = "set object rectangle from screen 0,0 to screen 1,1"
bgcp2 = " behind fillcolor rgb 'black' fillstyle solid noborder"
bgcolor = bgcp1*bgcp2
cmap = get(colorschemes[:viridis], LinRange(0,1,15))
@gp " " :-  # this is just to reset session
@gp(circShape(0,0,1)..., "w l lw 2 lc '#$(hex(cmap[3]))'", 
    "set key off", "set auto fix",  "set size square",
    "set offsets graph .05, graph .05, graph .05, graph .05",
    "set border lw 1 lc rgb 'white'",
    "set ylabel 'y' textcolor rgb 'white'",
    "set xlabel 'x' textcolor rgb 'white'",
    "set xzeroaxis linetype 3 linewidth 1",
    "set yzeroaxis linetype 3 linewidth 1",
    bgcolor)
for (indx,r) in enumerate(0.9:-0.1:0.1)
    @gp(:-, circShape(0,0,r)..., "w l lw 2 lc '#$(hex(cmap[indx+3]))'",
    "set key off")
end
save(term="pngcairo size 400,400 ", output="plt2_ex7.png") # hide