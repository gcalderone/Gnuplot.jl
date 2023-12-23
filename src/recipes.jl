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
                plot="w step notit lw 2 lc rgb 'black'")

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


# --------------------------------------------------------------------
#=
export cornerplot

function cornerplot(df::DataFrame; nbins=5, margins="0.1, 0.9, 0.15, 0.9", spacing=0.01)
    numeric_cols = findall([eltype(df[:, i]) <: Real for i in 1:ncol(df)])
    out = Vector{Gnuplot.PlotElement}()
    push!(out, Gnuplot.PlotElement(cmds="set multiplot layout $(length(numeric_cols)), $(length(numeric_cols)) margins $margins spacing $spacing columnsfirst downward"))
    push!(out, Gnuplot.PlotElement(name="\$null", data=Gnuplot.DatasetText([10,10])))
    id = 1
    for ix in numeric_cols
        for iy in numeric_cols
            push!(out, Gnuplot.PlotElement(mid=id, xlab="", ylab="", cmds=["set xtics format ''","set ytics format ''", "set border"]))
            (iy == maximum(numeric_cols))  &&  push!(out, Gnuplot.PlotElement(mid=id, xlab=names(df)[ix], cmds="set xtics format '% h'"))
            (ix == minimum(numeric_cols))  &&  push!(out, Gnuplot.PlotElement(mid=id, ylab=names(df)[iy]))

            xr = [extrema(df[:, ix])...]
            yr = [extrema(df[:, iy])...]
            if ix == iy
                h = hist(df[:, ix], range=xr, nbins=nbins)
                push!(out, Gnuplot.PlotElement(mid=id, cmds="unset ytics", xr=xr, yr=[NaN,NaN], data=Gnuplot.DatasetBin(hist_bins(h), hist_weights(h)), plot="w steps notit lc rgb 'black'"))
            elseif ix < iy
                push!(out, Gnuplot.PlotElement(mid=id,                     xr=xr, yr=yr       , data=Gnuplot.DatasetBin(df[:, ix], df[:, iy]), plot="w p notit"))
            else
                push!(out, Gnuplot.PlotElement(mid=id, xr=[0,1], yr=[0,1], cmds=["unset border", "unset tics", "plot \$null w d notit"]))
            end
            id += 1
        end
    end
    return out
end

=#
