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
    return (collect(keys(levels)), collect(values(levels)), length(cmap.colors))
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
