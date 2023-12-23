# ╭───────────────────────────────────────────────────────────────────╮
# │                       IMPLICIT RECIPES                            │
# ╰───────────────────────────────────────────────────────────────────╯

# --------------------------------------------------------------------
# Histograms
"""
    recipe(h::StatsBase.Histogram)

Implicit recipes to visualize 1D and 2D histograms.
"""
recipe(h::StatsBase.Histogram{T, 1, R}) where {T, R} =
    PlotElement(cmds="set grid",
                data=DatasetText(hist_bins(h), hist_weights(h)),
                plot="w histep notit lw 2 lc rgb 'black'")

recipe(h::StatsBase.Histogram{T, 2, R}) where {T, R} =
    PlotElement(cmds=["set autoscale fix"], # , "set size ratio -1"]
                data=DatasetText(hist_bins(h, 1), hist_bins(h, 2), hist_weights(h)),
                plot="w image notit")



# --------------------------------------------------------------------
# Contour lines
"""
    recipe(c::IsoContourLines)
    recipe(v::Vector{IsoContourLines})

Implicit recipes to visualize iso-contour lines.
"""
function recipe(c::IsoContourLines)
    if isnan(c.prob)
        return PlotElement(data=c.data, plot="w l t '$(c.z)'")
    end
    return PlotElement(data=c.data, plot="w l t '$(round(c.prob * 100, sigdigits=6))%'")
end
recipe(v::Vector{IsoContourLines}) = recipe.(v)


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
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :r),
                                256 .* getfield.(M, :g),
                                256 .* getfield.(M, :b)),
                plot="$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.RGBA{T}}, opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :r),
                                256 .* getfield.(M, :g),
                                256 .* getfield.(M, :b)),
                plot="$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.Gray{T}}, opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :val)),
                plot="$opt with image notit")

recipe(M::Matrix{ColorTypes.GrayA{T}}, opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :val)),
                plot="$opt with image notit")
