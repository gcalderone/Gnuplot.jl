# This file was generated, do not modify it. # hide
using Gnuplot, Colors, ColorSchemes, Random
Random.seed!(123)
function custom_palette(colormap=:viridis)
    cmap = get(colorschemes[colormap], LinRange(0,1,256))
    ctmp = "0 '#$(hex(cmap[1]))',"
    for i in 2:256; ctmp = ctmp*"$(i-1) '#$(hex(cmap[i]))'," end;
    "set palette defined("*ctmp[1:end-1]*")"
end
@gp " " :-  # this is just to reset session
@gp :- "set multiplot layout 3,3; set key off" :-
cmaps = [:magma, :viridis, :plasma, :inferno, :berlin, :leonardo,
    :devon, :spring, :ice]
for i in 1:9
    @gp :- i title = "$(cmaps[i]), pt $(i)" "set size square" :-
    @gp(:-, rand(15), rand(15), rand(15), 
    "w p pt $(i) ps 3 lc palette", custom_palette(cmaps[i]), 
    "set cbtics out nomirror", "set xtics 0,1", "set ytics 0,1", 
    "set cbtics 0.0,0.2,1.0", xrange= (-0.1,1.1), 
    yrange= (-0.1,1.1), :-)
end
@gp
save(term="pngcairo size 900,800", output="plt_ex12.png") # hide