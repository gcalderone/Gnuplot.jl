# --------------------------------------------------------------------
# Histograms
"""
    recipe(h::StatsBase.Histogram)

Implicit recipes to visualize 1D and 2D histograms.
"""
recipe(h::StatsBase.Histogram{T, 1, R}) where {T, R} =
    parseArguments("set grid", hist_bins(h), hist_weights(h), "w step notit lw 2 lc rgb 'black'")

recipe(h::StatsBase.Histogram{T, 2, R}) where {T, R} =
    parseArguments("set autoscale fix", # , "set size ratio -1"]
                   hist_bins(h, 1), hist_bins(h, 2), hist_weights(h), "w image notit")


# --------------------------------------------------------------------
# Contour lines
"""
    recipe(c::IsoContourLines)
    recipe(v::Vector{IsoContourLines})

Implicit recipes to visualize iso-contour lines.
"""
function recipe(c::IsoContourLines)
    if isnan(c.prob)
        return parseArguments(c.data, "w l t '$(c.z)'")
    end
    return parseArguments(c.data, "w l t '$(round(c.prob * 100, sigdigits=6))%'")
end
function recipe(v::Vector{IsoContourLines})
    out = recipe(v[1])
    for i in 2:length(v)
        append!(out, recipe(v[i]))
    end
    return out
end


# --------------------------------------------------------------------
# Images
"""
    recipe(M::Matrix{ColorTypes.RGB{T}}, opt="flipy")
    recipe(M::Matrix{ColorTypes.RGBA{T}}, opt="flipy")
    recipe(M::Matrix{ColorTypes.Gray{T}}, opt="flipy")
    recipe(M::Matrix{ColorTypes.GrayA{T}}, opt="flipy")

Implicit recipes to show images.
"""
recipe(M::Matrix{ColorTypes.RGB{T}}, opt="flipy") where T =
    parseArguments("set autoscale fix", "set size ratio -1",
                   DatasetBin(256 .* getfield.(M, :r),
                              256 .* getfield.(M, :g),
                              256 .* getfield.(M, :b)),
                   "$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.RGBA{T}}, opt="flipy") where T =
    parseArguments("set autoscale fix", "set size ratio -1",
                   DatasetBin(256 .* getfield.(M, :r),
                              256 .* getfield.(M, :g),
                              256 .* getfield.(M, :b)),
                   "$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.Gray{T}}, opt="flipy") where T =
    parseArguments("set autoscale fix", "set size ratio -1",
                   DatasetBin(256 .* getfield.(M, :val)),
                   "$opt with image notit")

recipe(M::Matrix{ColorTypes.GrayA{T}}, opt="flipy") where T =
    parseArguments("set autoscale fix", "set size ratio -1",
                   DatasetBin(256 .* getfield.(M, :val)),
                   "$opt with image notit")



