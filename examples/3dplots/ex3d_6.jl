# This file was generated, do not modify it. # hide
using Gnuplot, ColorSchemes, RDatasets, Colors
function gp_palette(colormap=:viridis)
    cmap = get(colorschemes[colormap], LinRange(0,1,256))
    ctmp = "0 '#$(hex(cmap[1]))',"
    for i in 2:256; ctmp = ctmp*"$(i-1) '#$(hex(cmap[i]))'," end;
    "set palette defined("*ctmp[1:end-1]*")"
end

volcano = Matrix{Float64}(dataset("datasets", "volcano"))
@gsp(volcano, "w image", "set view map", "set auto fix",
    gp_palette(:inferno), title = "Auckland s Maunga Whau Volcano")
save(term="pngcairo size 900,600", output="plt3d_ex6.png")