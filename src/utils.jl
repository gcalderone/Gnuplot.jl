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


# --------------------------------------------------------------------
"""
    stats(sid::Symbol)
    stats()

Print a statistical summary for the `name` dataset, belonging to `sid` session.  If `name` is not provdied a summary is printed for each dataset in the session.  If `sid` is not provided the default session is considered.

This function is actually a wrapper for the gnuplot command `stats`.
"""
function stats(gp::GPSession{GPProcess})
    for (name, source, data) in datasets(gp)
        isnothing(data)  &&  continue
        @info sid=gp.process.sid name=name source=source type=typeof(data)
        println(gpexec(gp, "stats $source"))
    end
end
stats(sid::Symbol=options.default) = stats(getsession(sid))


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
    (outputfile == "")  ||  save(:splash, term="pngcairo transparent noenhanced size 600,300", output=outputfile)
    nothing
end
