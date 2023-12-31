# --------------------------------------------------------------------
"""
    test_terminal(term=nothing; linetypes=nothing, palette=nothing)

Run the `test` and `test palette` commands on a gnuplot terminal.

If no `term` is given it will use the default terminal. If `lt` and `pal` are given they are used as input to the [`linetypes`](@ref) and [`palette`](@ref) function repsetcively to load the associated color scheme.

# Examples
```julia
test_terminal()
test_terminal("wxt", lt=:rust, pal=:viridis)
```
"""
function test_terminal(term=nothing; lt=nothing, pal=nothing)
    quit(:test_term)
    quit(:test_palette)
    if !isnothing(term)
        gpexec(:test_term    , "set term $term")
        gpexec(:test_palette , "set term $term")
    end
    s = (isnothing(lt)  ?  ""  :  linetypes(lt))
    gpexec(:test_term    , "$s; test")
    s = (isnothing(pal)  ?  ""  :  palette(pal))
    gpexec(:test_palette , "$s; test palette")
end


# --------------------------------------------------------------------
"""
    gpmargins(sid::Symbol)
    gpmargins()

Return a `NamedTuple` with keys `l`, `r`, `b` and `t` containing respectively the left, rigth, bottom and top margins of the current plot (in screen coordinates).
"""
function gpmargins(sid::Symbol=options.default)
    vars = gpvars(sid)
    l = vars.TERM_XMIN / (vars.TERM_XSIZE / vars.TERM_SCALE)
    r = vars.TERM_XMAX / (vars.TERM_XSIZE / vars.TERM_SCALE)
    b = vars.TERM_YMIN / (vars.TERM_YSIZE / vars.TERM_SCALE)
    t = vars.TERM_YMAX / (vars.TERM_YSIZE / vars.TERM_SCALE)
    return (l=l, r=r, b=b, t=t)
end

"""
    gpranges(sid::Symbol)
    gpranges()

Return a `NamedTuple` with keys `x`, `y`, `z` and `cb` containing respectively the current plot ranges for the X, Y, Z and color box axis.
"""
function gpranges(sid::Symbol=options.default)
    vars = gpvars(sid)
    x = [vars.X_MIN, vars.X_MAX]
    y = [vars.Y_MIN, vars.Y_MAX]
    z = [vars.Z_MIN, vars.Z_MAX]
    c = [vars.CB_MIN, vars.CB_MAX]
    return (x=x, y=y, z=z, cb=c)
end

# ---------------------------------------------------------------------
"""
    palette_names()

Return a vector with all available color schemes for the [`palette`](@ref) and [`linetypes`](@ref) function.
"""
palette_names() = Symbol.(keys(ColorSchemes.colorschemes))


"""
    linetypes(cmap::ColorScheme; lw=1, ps=1, dashed=false, rev=false)
    linetypes(s::Symbol; lw=1, ps=1, dashed=false, rev=false)

Convert a `ColorScheme` object into a string containing the gnuplot commands to set up *linetype* colors.

If the argument is a `Symbol` it is interpreted as the name of one of the predefined schemes in [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1).

If `rev=true` the line colors are reversed.  If a numeric or string value is provided through the `lw` and `ps` keywords thay are used to set the line width and the point size respectively.  If `dashed` is true the linetypes with index greater than 1 will be displayed with dashed pattern.
"""
linetypes(s::Symbol; kwargs...) = linetypes(colorschemes[s]; kwargs...)
function linetypes(cmap::ColorScheme; lw=1, ps=1, dashed=false, rev=false)
    out = Vector{String}()
    push!(out, "unset for [i=1:256] linetype i")
    for i in 1:length(cmap.colors)
        if rev
            color = cmap.colors[end - i + 1]
        else
            color = cmap.colors[i]
        end
        dt = (dashed  ?  "$i"  :  "solid")
        push!(out, "set linetype $i lc rgb '#" * Colors.hex(color) * "' lw $lw dt $dt pt $i ps $ps")
    end
    return join(out, "\n") * "\nset linetype cycle " * string(length(cmap.colors)) * "\n"
end


"""
    palette_levels(cmap::ColorScheme; rev=false, smooth=false)
    palette_levels(s::Symbol; rev=false, smooth=false)

Convert a `ColorScheme` object into a `Tuple{Vector{Float64}, Vector{String}, Int}` containing:
- the numeric levels (between 0 and 1 included) corresponding to colors in the palette;
- the corresponding colors (as hex strings);
- the total number of different colors in the palette.

If the argument is a `Symbol` it is interpreted as the name of one of the predefined schemes in [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1).

If `rev=true` the palette is reversed.  If `smooth=true` the palette is interpolated in 256 levels.
"""
palette_levels(s::Symbol; kwargs...) = palette_levels(colorschemes[s]; kwargs...)
function palette_levels(cmap::ColorScheme; rev=false, smooth=false)
    levels = OrderedDict{Float64, String}()
    for x in LinRange(0, 1, (smooth  ?  256  : length(cmap.colors)))
        if rev
            color = get(cmap, 1-x)
        else
            color = get(cmap, x)
        end
        levels[x] = "#" * Colors.hex(color)
    end
    return (collect(keys(levels)), collect(values(levels)), (smooth  ?  256  : length(cmap.colors)))
end


"""
    palette(cmap::ColorScheme; rev=false, smooth=false)
    palette(s::Symbol; rev=false, smooth=false)

Convert a `ColorScheme` object into a string containing the gnuplot commands to set up the corresponding palette.

If the argument is a `Symbol` it is interpreted as the name of one of the predefined schemes in [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1).

If `rev=true` the palette is reversed.  If `smooth=true` the palette is interpolated in 256 levels.
"""
function palette(values::Vector{Float64}, levels::Vector{String}, ncolors::Int)
    str = string.(values) .* " '" .* levels .* "'"
    return "set palette defined (" * join(str, ", ") * ")\nset palette maxcol $(ncolors)\n"
end
palette(s::Symbol; kwargs...) = palette(colorschemes[s]; kwargs...)
palette(cmap::ColorScheme; kwargs...) =
    palette(palette_levels(cmap; kwargs...)...)


# ---------------------------------------------------------------------
"""
    show_specs(sid::Symbol)
    show_specs()

Prints a brief overview of all stored plot specs for the `sid` session.  If `sid` is not provided the default session is considered.
"""
function show_specs(sid::Symbol=options.default)
    gp = getsession(sid)
    @info "Session id: $sid"
    display(gp.specs)
end


# --------------------------------------------------------------------
"""
    stats(sid::Symbol)
    stats()

Print a statistical summary all datasets belonging to `sid` session.  If `sid` is not provided the default session is considered.

This function is actually a wrapper for the gnuplot command `stats`.
"""
function stats(sid::Symbol=options.default)
    gp = getsession(sid)
    for (name, source, data) in datasets(gp)
        isnothing(data)  &&  continue
        @info sid=gp.sid name=name source=source type=typeof(data)
        println(gpexec(gp, "stats $source"))
    end
end


# --------------------------------------------------------------------
function splash(outputfile="")
    quit(:splash)
    gp = getsession(:splash)
    if outputfile == ""
        # Try to set a reasonably modern terminal.  Setting the size
        # is necessary for the text to be properly sized.  The
        # `noenhanced` option is required to display the "@" character
        # (alternatively use "\\\\@", but it doesn't work on all
        # terminals).
        terms = terminals()
        if "wxt" in terms
            gpexec(gp, "set term wxt  noenhanced size 600,300")
        elseif "qt" in terms
            gpexec(gp, "set term qt   noenhanced size 600,300")
        elseif "aqua" in terms
            gpexec(gp, "set term aqua noenhanced size 600,300")
        else
            @warn "None of the `wxt`, `qt` and `aqua` terminals are available.  Output may look strange..."
        end
    else
        gpexec(gp, "set term unknown")
    end
    @gp :- :splash "set margin 0"  "set border 0" "unset tics" :-
    @gp :- :splash xr=[-0.3,1.7] yr=[-0.3,1.1] :-
    @gp :- :splash "set origin 0,0" "set size 1,1" :-
    @gp :- :splash "set label 1 at graph 1,1 right offset character -1,-1 font 'Verdana,20' tc rgb '#4d64ae' ' Ver: " * string(version()) * "' " :-
    @gp :- :splash "set arrow 1 from graph 0.05, 0.15 to graph 0.95, 0.15 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
    @gp :- :splash "set arrow 2 from graph 0.15, 0.05 to graph 0.15, 0.95 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
    @gp :- :splash ["0.35 0.65 @ 13253682", "0.85 0.65 g 3774278", "1.3 0.65 p 9591203"] "w labels notit font 'Mono,160' tc rgb var"
    (outputfile == "")  ||  save(:splash, outputfile, term="pngcairo transparent noenhanced size 600,300")
    nothing
end


# --------------------------------------------------------------------
function gp_write_table(args...; kw...)
    @assert !options.dry "Feature not available in *dry* mode."
    tmpfile = Base.Filesystem.tempname()
    sid = Symbol("j", Base.Libc.getpid())
    gp = getsession(sid)
    empty!(gp.specs)
    reset(gp.process)
    append!(gp, parseSpecs("set term unknown", "set table '$tmpfile'", args...; kw...))
    gpexec.(Ref(gp), collect_commands(gp))
    gpexec(gp, "unset table")
    quit(gp)
    out = readlines(tmpfile)
    rm(tmpfile)
    return out
end


# --------------------------------------------------------------------
"""
    boxxy(x, y; xmin=NaN, ymin=NaN, xmax=NaN, ymax=NaN, cartesian=false)
    boxxy(h::StatsBase.Histogram)
"""
boxxy(h::StatsBase.Histogram{T, 2, R}) where {T, R} = boxxy(hist_bins(h, 1), hist_bins(h, 2), hist_weights(h), cartesian=true)
function boxxy(x, y, aux...; xmin=NaN, ymin=NaN, xmax=NaN, ymax=NaN, cartesian=false)
    function box(v; vmin=NaN, vmax=NaN)
        vlow  = Vector{Float64}(undef, length(v))
        vhigh = Vector{Float64}(undef, length(v))
        for i in 2:length(v)-1
            vlow[i]  = (v[i-1] + v[i]) / 2
            vhigh[i] = (v[i+1] + v[i]) / 2
        end
        vlow[1]    = v[ 1 ] - (v[ 2 ] - v[ 1 ]  ) / 2
        vlow[end]  = v[end] - (v[end] - v[end-1]) / 2
        vhigh[1]   = v[ 1 ] + (v[ 2 ] - v[ 1 ]  ) / 2
        vhigh[end] = v[end] + (v[end] - v[end-1]) / 2

        isfinite(vmin)  &&  (vlow[  1 ] = vmin)
        isfinite(vmax)  &&  (vhigh[end] = vmax)
        return (vlow, vhigh)
    end
    @assert issorted(x)
    @assert issorted(y)
    xlow, xhigh = box(x, vmin=xmin, vmax=xmax)
    ylow, yhigh = box(y, vmin=ymin, vmax=ymax)
    if !cartesian
        return Dataset(x, y, xlow, xhigh, ylow, yhigh, aux...)
    end
    i = repeat(1:length(x), outer=length(y))
    j = repeat(1:length(y), inner=length(x))
    return Dataset([x[i], y[j], xlow[i], xhigh[i], ylow[j], yhigh[j], aux...])
end


# --------------------------------------------------------------------
"""
    Path2d

A path in 2D.

# Fields
- `x::Vector{Float64}`
- `y::Vector{Float64}`
"""
struct Path2d
    x::Vector{Float64}
    y::Vector{Float64}
    Path2d() = new(Vector{Float64}(), Vector{Float64}())
end


"""
    IsoContourLines

Coordinates of all contour lines of a given level.

# Fields
 - `paths::Vector{Path2d}`: vector of [`Path2d`](@ref) objects, one for each continuous path;
 - `data::Vector{String}`: vector with string representation of all paths (ready to be sent to gnuplot);
 - `z::Float64`: level of the contour lines.
"""
struct IsoContourLines
    paths::Vector{Path2d}
    data::Dataset
    z::Float64
    prob::Float64
end
function IsoContourLines(paths::Vector{Path2d}, z)
    @assert length(z) == 1
    # Prepare Dataset object
    data = Vector{String}()
    for i in 1:length(paths)
        append!(data, arrays2datablock(paths[i].x, paths[i].y, z .* fill(1., length(paths[i].x))))
        push!(data, "")
        push!(data, "")
    end
    return IsoContourLines(paths, DatasetText(data), z, NaN)
end


"""
    contourlines(x, y, z, cntrparam="level auto 4")
    contourlines(x, y, z, fractions)
    contourlines(h::StatsBase.Histogram, ...)

Compute paths of contour lines for 2D data, and return a vector of [`IsoContourLines`](@ref) object.

!!! note
    This feature is not available in *dry* mode and will raise an error if used.

# Arguments:
- `x`, `y` (as `AbstractVector{Float64}`): Coordinates;
- `z::AbstractMatrix{Float64}`: the levels on which iso-contour lines are to be calculated;
- `cntrparam::String`: settings to compute contour line paths (see gnuplot documentation for `cntrparam`);
- `fractions::Vector{Float64}`: compute contour lines encompassing these fractions of total counts;
- `h::StatsBase.Histogram`: use 2D histogram bins and counts to compute contour lines.


# Example
```julia
x = randn(10^5);
y = randn(10^5);
h = hist(x, y, nbins1=20, nbins2=20);
clines = contourlines(h, "levels discrete 500, 1500, 2500");

# Use implicit recipe
@gp clines

# ...or use IsoContourLines fields:
@gp "set size ratio -1"
for i in 1:length(clines)
    @gp :- clines[i].data "w l t '\$(clines[i].z)' lw \$i dt \$i"
end

# Calculate probability within 0 < r < σ
p(σ) = round(1 - exp(-(σ^2) / 2), sigdigits=3)

# Draw contour lines at 1, 2 and 3 σ
clines = contourlines(h, p.(1:3));
@gp palette(:beach, smooth=true, rev=true) "set grid front" "set size ratio -1" h clines
```
"""
contourlines(h::StatsBase.Histogram{T, 2, R}, args...) where {T, R} = contourlines(hist_bins(h, 1), hist_bins(h, 2), hist_weights(h) .* 1., args...)
function contourlines(x::AbstractVector{Float64}, y::AbstractVector{Float64}, z::AbstractMatrix{Float64},
                      fraction::Vector{Float64})
    @assert minimum(fraction) > 0
    @assert maximum(fraction) < 1
    @assert length(fraction) >= 1
    sorted_fraction = sort(fraction, rev=true)

    i = sortperm(z[:], rev=true)
    topfrac = cumsum(z[i]) ./ sum(z)
    selection = Int[]
    for f in sorted_fraction
        push!(selection, minimum(findall(topfrac .>= f)))
    end
    levels = z[i[selection]]
    clines = contourlines(x, y, z, "levels discrete " * join(string.(levels), ", "))
    @assert issorted(getfield.(clines, :z))

    if  length(clines) == length(fraction)
        out = [IsoContourLines(clines[i].paths, clines[i].data, clines[i].z,
                               sorted_fraction[i]) for i in 1:length(clines)]
        return out
    end
    return clines
end

function contourlines(x::AbstractVector{Float64}, y::AbstractVector{Float64}, z::AbstractMatrix{Float64},
                      cntrparam="level auto 4")
    lines = gp_write_table("set contour base", "unset surface",
                           "set cntrparam $cntrparam", x, y, z, is3d=true)
    level = NaN
    path = Path2d()
    paths = Vector{Path2d}()
    levels = Vector{Float64}()
    for l in lines
        l = strip(l)
        if (l == "")  ||
            !isnothing(findfirst("# Contour ", l))
            if length(path.x) > 2
                push!(paths, path)
                push!(levels, level)
            end
            path = Path2d()

            if l != ""
                level = Meta.parse(strip(split(l, ':')[2]))
            end
            continue
        end
        (l[1] == '#')  &&  continue

        n = Meta.parse.(split(l))
        @assert length(n) == 3
        push!(path.x, n[1])
        push!(path.y, n[2])
    end
    if length(path.x) > 2
        push!(paths, path)
        push!(levels, level)
    end
    @assert length(paths) > 0
    i = sortperm(levels)
    paths  = paths[ i]
    levels = levels[i]

    # Join paths with the same level
    out = Vector{IsoContourLines}()
    for zlevel in unique(levels)
        i = findall(levels .== zlevel)
        push!(out, IsoContourLines(paths[i], zlevel))
    end
    return out
end


# --------------------------------------------------------------------
"""
    dgrid3d(x, y, z, opts=""; extra=true)

Interpolate non-uniformly spaced 2D data onto a regular grid.

!!! note
    This feature is not available in *dry* mode and will raise an error if used.

# Arguments:
- `x`, `y`, `z` (as `AbstractVector{Float64}`): coordinates and values of the function to interpolate;
- `opts`: interpolation settings (see gnuplot documentation for `dgrid3d`);
- `extra`: if `true` (default) compute inerpolated values in all regions, even those which are poorly constrained by input data (namely, extrapolated values).  If `false` set these values to `NaN`.

# Return values:
A tuple with `x` and `y` coordinates on the regular grid (as `Vector{Float64}`), and `z` containing interpolated values (as `Matrix{Float64}`).

# Example
```julia
x = (rand(200) .- 0.5) .* 3;
y = (rand(200) .- 0.5) .* 3;
z = exp.(-(x.^2 .+ y.^2));

# Interpolate on a 20x30 regular grid with splines
gx, gy, gz = dgrid3d(x, y, z, "20,30 splines")

@gsp "set size ratio -1" "set xyplane at 0" xlab="X" ylab="Y" :-
@gsp :-  x  y  z "w p t 'Scattered data' lc pal"
@gsp :- gx gy gz "w l t 'Interpolation on a grid' lc pal"
```
!!! warn
    The `splines` algorithm may be very slow on large datasets.  An alternative option is to use a smoothing kernel, such as `gauss`:

```julia
x = randn(2000) .* 0.5;
y = randn(2000) .* 0.5;
rsq = x.^2 + y.^2;
z = exp.(-rsq) .* sin.(y) .* cos.(2 * rsq);

@gsp "set size ratio -1" palette(:balance, smooth=true) "set view map" "set pm3d" :-
@gsp :- "set multiplot layout 1,3" xr=[-2,2] yr=[-2,2] :-
@gsp :- 1 tit="Scattered data"  x  y  z "w p notit lc pal"

# Show extrapolated values
gx, gy, gz = dgrid3d(x, y, z, "40,40 gauss 0.1,0.1")
@gsp :- 2 tit="Interpolation on a grid\\\\n(extrapolated values are shown)"  gx gy gz "w l notit lc pal"

# Hide exrapolated values
gx, gy, gz = dgrid3d(x, y, z, "40,40 gauss 0.1,0.1", extra=false)
@gsp :- 3 tit="Interpolation on a grid\\\\n(extrapolated values are hidden)" gx gy gz "w l notit lc pal"
```
"""
function dgrid3d(x::AbstractVector{Float64},
                 y::AbstractVector{Float64},
                 z::AbstractVector{Float64},
                 opts::String="";
                 extra=true)
    c = Gnuplot.gp_write_table("set dgrid3d $opts", x, y, z, is3d=true)
    gx = Vector{Float64}()
    gy = Vector{Float64}()
    gz = Vector{Float64}()
    ix = 0
    iy = 0
    for l in c
        l = string(strip(l))
        if l == "# x y z type"
            ix += 1
            iy = 1
        else
            (l == "" )     &&  continue
            (l[1] == '#')  &&  continue
            n = Meta.parse.(split(l)[1:3])
            (iy == 1)  &&  push!(gx, n[1])
            (ix == 1)  &&  push!(gy, n[2])
            if n[3] == :NaN
                push!(gz, NaN)
            else
                push!(gz, n[3])
            end
            iy += 1
        end
    end
    gz = collect(reshape(gz, length(gy), length(gx))')
    if !extra
        dx = abs(gx[2]-gx[1]) / 2
        dy = abs(gy[2]-gy[1]) / 2
        for ix in 1:length(gx)
            for iy in 1:length(gy)
                n = length(findall(((gx[ix] - dx) .< x .< (gx[ix] + dx))  .&
                                   ((gy[iy] - dy) .< y .< (gy[iy] + dy))))
                (n == 0)  &&  (gz[ix, iy] = NaN)
            end
        end
    end
    return (gx, gy, gz)
end
