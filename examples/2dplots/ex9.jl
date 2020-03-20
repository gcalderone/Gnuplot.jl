# This file was generated, do not modify it. # hide
using Gnuplot, Colors, ColorSchemes, Random
Random.seed!(123)
function custom_palette(colormap=:viridis)
    cmap = get(colorschemes[colormap], LinRange(0,1,256))
    ctmp = "0 '#$(hex(cmap[1]))',"
    for i in 2:256; ctmp = ctmp*"$(i-1) '#$(hex(cmap[i]))'," end;
    "set palette defined("*ctmp[1:end-1]*")"
end
# Archimedes spiral
a = 1.5
b = -2.4
t = LinRange(0,5*π,500)
x = (a .+ b*t) .* cos.(t)
y = (a .+ b*t) .* sin.(t)
@gp " " :-  # this is just to reset session
@gp :- "set multiplot layout 3,3; set key off; 
    unset ytics; unset xtics; unset border" :-
colormaps = [:magma, :viridis, :plasma, :inferno, :berlin, 
    :leonardo, :devon, :spring, :ice]
for i in 1:9
    @gp :- i title = "$(colormaps[i])" "set size square" :-
    @gp(:-, x, y, t, "w l lw 3 dt 1 lc palette", 
        custom_palette(colormaps[i]),"set cbtics out nomirror", :-)
end
@gp
save(term="pngcairo size 900,800", output="plt_ex9.png") # hide