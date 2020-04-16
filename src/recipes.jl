# ╭───────────────────────────────────────────────────────────────────╮
# │                       IMPLICIT RECIPES                            │
# ╰───────────────────────────────────────────────────────────────────╯

# --------------------------------------------------------------------
# Histograms
recipe(h::Histogram1D) =
    PlotElement(cmds="set grid",
                data=DatasetText(h.bins, h.counts),
                plot="w histep notit lw 2 lc rgb 'black'")

recipe(h::Histogram2D) =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetText(h.bins1, h.bins2, h.counts),
                plot="w image notit")


# --------------------------------------------------------------------
# Images
recipe(M::Matrix{ColorTypes.RGB{T}}; opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :r),
                                256 .* getfield.(M, :g),
                                256 .* getfield.(M, :b)),
                plot="$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.RGBA{T}}; opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :r),
                                256 .* getfield.(M, :g),
                                256 .* getfield.(M, :b)),
                plot="$opt with rgbimage notit")

recipe(M::Matrix{ColorTypes.Gray{T}}; opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :val)),
                plot="$opt with image notit")

recipe(M::Matrix{ColorTypes.GrayA{T}}; opt="flipy") where T =
    PlotElement(cmds=["set autoscale fix", "set size ratio -1"],
                data=DatasetBin(256 .* getfield.(M, :val)),
                plot="$opt with image notit")


# ╭───────────────────────────────────────────────────────────────────╮
# │                       EXPLICIT RECIPES                            │
# ╰───────────────────────────────────────────────────────────────────╯

macro recipes_DataFrames()
    return esc(:(
        function plotdf(df::DataFrame, colx::Symbol, coly::Symbol; group=nothing);
        if isnothing(group);
        return Gnuplot.PlotElement(xlab=string(colx), ylab=string(coly),
                                   data=Gnuplot.DatasetText(df[:, colx], df[:, coly]),
                                   plot="w p notit");
        end;

        data = Vector{Gnuplot.Dataset}();
        plot = Vector{String}();
        for g in sort(unique(df[:, group]));
            i = findall(df[:, group] .== g);
            if length(i) > 0;
                push!(data, Gnuplot.DatasetText(df[i, colx], df[i, coly]));
                push!(plot, "w p t '$g'");
            end;
        end;
        return Gnuplot.PlotElement(xlab=string(colx), ylab=string(coly),
                                   data=data, plot=plot);
        end
    ))
end
