module Gnuplot

using StatsBase, ColorSchemes, ColorTypes, Colors, StructC14N, DataStructures

include("GnuplotProcess.jl")
using .GnuplotProcess


export session_names, palette_names, linetypes, palette_levels, palette,
    terminal, terminals, test_terminal,
    stats, @gp, @gsp, save, gpexec,
    hist_bins, hist_weights,
    boxxy, contourlines, dgrid3d, hist, recipe, gpvars, gpmargins, gpranges

"""
    Gnuplot.version()

Return the **Gnuplot.jl** package version.
"""
version() = v"1.5.0"


include("dataset.jl")
include("plotspecs.jl")


# ---------------------------------------------------------------------
"""
    Options

Structure containing the package global options, accessible through `Gnuplot.options`.

# Fields
- `dry::Bool`: whether to use *dry* sessions, i.e. without an underlying Gnuplot process (default: `false`)
- `cmd::String`: command to start the Gnuplot process (default: `"gnuplot"`)
- `default::Symbol`: default session name (default: `:default`)
- `term::String`: default terminal for interactive use (default: empty string, i.e. use gnuplot settings);
- `mime::Dict{DataType, String}`: dictionary of MIME types and corresponding gnuplot terminals.  Used to export images with either [`save()`](@ref) or `show()` (see [Display options](@ref));
- `gpviewer::Bool`: use a gnuplot terminal as main plotting device (if `true`) or an external viewer (if `false`);
- `init::Vector{String}`: commands to initialize the session when it is created or reset (e.g., to set default palette);
- `verbose::Bool`: verbosity flag (default: `false`)
- `preferred_format::Symbol`: preferred format to send data to gnuplot.  Value must be one of:
   - `bin`: fastest solution for large datasets, but uses temporary files;
   - `text`: may be slow for large datasets, but no temporary file is involved;
   - `auto` (default) automatically choose the best strategy.
"""
Base.@kwdef mutable struct Options
    dry::Bool = false
    cmd::String = "gnuplot"
    default::Symbol = :default
    term::String = ""
    mime::Dict{DataType, String} = Dict(
        MIME"application/pdf" => "pdfcairo enhanced",
        MIME"image/jpeg"      => "jpeg enhanced",
        MIME"image/png"       => "pngcairo enhanced",
        MIME"image/svg+xml"   => "svg enhanced mouse standalone dynamic background rgb 'white'",
        MIME"text/html"       => "svg enhanced mouse standalone dynamic",  # canvas mousing
        MIME"text/plain"      => "dumb enhanced ansi")
    gpviewer::Bool = false
    init::Vector{String} = Vector{String}()
    verbose::Bool = true
    preferred_format::Symbol = :auto
end
const options = Options()
gpversion() = Gnuplot.GnuplotProcess.gpversion(options.cmd)


# ---------------------------------------------------------------------
function __init__()
    # Check whether we are running in an IJulia, Juno, VSCode or Pluto session.
    # (copied from Gaston.jl).
    options.gpviewer = !(
        ((isdefined(Main, :IJulia)  &&  Main.IJulia.inited)  ||
         (isdefined(Main, :Juno)    &&  Main.Juno.isactive()) ||
         (isdefined(Main, :VSCodeServer)) ||
         (isdefined(Main, :PlutoRunner)) )
    )
    if isdefined(Main, :VSCodeServer)
        # VS Code shows "dynamic" plots with fixed and small size :-(
        options.mime[MIME"image/svg+xml"] = replace(options.mime[MIME"image/svg+xml"], "dynamic" => "")
    end
end


# ---------------------------------------------------------------------
struct GPSession{T}
    process::T
    specs::Vector{AbstractGPCommand}
    GPSession()             = new{Nothing}(  nothing, Vector{AbstractGPCommand}())
    GPSession(p::GPProcess) = new{GPProcess}(p      , Vector{AbstractGPCommand}())
end
const sessions = OrderedDict{Symbol, GPSession}()


# ---------------------------------------------------------------------
import .GnuplotProcess: gpexec
gpexec(gp::GPSession{GPProcess}, s::AbstractString) = gpexec(gp.process, s)


# ---------------------------------------------------------------------
function getsession(sid::Symbol=options.default)
    if !(sid in keys(sessions))
        if options.dry
            sessions[sid] = GPSession()
        else
            popt = GnuplotProcess.Options()
            for f in fieldnames(typeof(options))
                if f in fieldnames(typeof(popt))
                    setproperty!(popt, f, getproperty(options, f))
                end
            end
            sessions[sid] = GPSession(GPProcess(sid, popt))
        end
    end
    return sessions[sid]
end


# ---------------------------------------------------------------------
add_spec!(gp::GPSession{Nothing}, spec::AbstractGPCommand) = push!(gp.specs, spec)
function add_spec!(gp::GPSession{GPProcess}, spec::AbstractGPCommand)
    push!(gp.specs, spec)
    if has_dataset(spec)  &&  isa(spec.data, DatasetText)
        if isa(spec, GPNamedDataset)
            name = spec.name
        else
            @assert isa(spec, GPPlotDataCommand)
            name = "\$data$(length(gp.specs))"
        end
        if gp.process.options.verbose
            printstyled(color=:light_black,      "GNUPLOT ($(gp.process.sid)) "  , name, " << EOD\n")
            printstyled(color=:light_black, join("GNUPLOT ($(gp.process.sid)) " .* spec.data.preview, "\n") * "\n")
            printstyled(color=:light_black,      "GNUPLOT ($(gp.process.sid)) ", "EOD\n")
        end
        write(gp.process.pin, name * " << EOD\n")
        write(gp.process.pin, spec.data.data)
        write(gp.process.pin, "\nEOD\n")
        flush(gp.process.pin)
    end
    nothing
end


# ---------------------------------------------------------------------
function delete_binaries(gp::GPSession)
    for spec in gp.specs
        if has_dataset(spec)
            if isa(spec.data, DatasetBin)  &&  (spec.data.file != "")
                rm(spec.data.file, force=true)
            end
        end
    end
end


# ---------------------------------------------------------------------
import .GnuplotProcess.reset
function reset(gp::GPSession)
    delete_binaries(gp)
    empty!(gp.specs)
    reset(gp.process)

    # Note: the reason to keep Options.term and .init separate are:
    # - .term can be overriden by "unknown" (if options.gpviewer is false);
    # - .init is dumped in scripts, while .term is not;
    add_spec!(gp, GPCommand(options.init))
    return nothing
end


# ---------------------------------------------------------------------
import .GnuplotProcess.quit

"""
    Gnuplot.quit(sid::Symbol)

Quit the session identified by `sid` and the associated gnuplot process (if any).
"""
function quit(sid::Symbol=options.default)
    (sid in keys(sessions))  ||  (return 0)
    gp = sessions[sid]
    exitcode = quit(gp.process)
    delete_binaries(gp)
    delete!(sessions, sid)
    return exitcode
end

"""
    Gnuplot.quitall()

Quit all the sessions and the associated gnuplot processes.
"""
function quitall()
    for sid in keys(sessions)
        quit(sid)
    end
    return nothing
end


# --------------------------------------------------------------------
"""
    gpexec(sid::Symbol, command::String)
    gpexec(command::String)

Execute the gnuplot command `command` on the underlying gnuplot process of the `sid` session, and return the results as a `Vector{String}`.  If a gnuplot error arises it is propagated as an `ErrorException`.

If the `sid` argument is not provided, the default session is considered.

## Examples:
```julia-repl
gpexec("print GPVAL_TERM")
gpexec("plot sin(x)")
```
"""
gpexec(sid::Symbol, s::String) = gpexec(getsession(sid).process, s)
gpexec(s::String) = gpexec(getsession().process, s)


# ---------------------------------------------------------------------
function collect_commands(gp::GPSession{T}; term::AbstractString="", output::AbstractString="") where T
    function dropDuplicatedUsing(source, spec)
        # Ensure there is no duplicated `using` clause
        m0 = match(r"(.*) using 1", source)
        if !isnothing(m0)
            for r in [r"u +[\d,\(]",
                      r"us +[\d,\(]",
                      r"usi +[\d,\(]",
                      r"usin +[\d,\(]",
                      r"using +[\d,\(]"]
                m = match(r, spec)
                if !isnothing(m)
                    source = string(m0.captures[1])
                    break
                end
            end
        end
        return source
    end

    out = Vector{String}()
    push!(out, "reset")
    if (term != "")  &&  (T == GPProcess)
        former_term = terminal(gp)
        push!(out, "unset multiplot")
        push!(out, "set term $term")
    end
    (output != "")  &&  push!(out, "set output '$(replace(output, "'" => "''"))'")

    mids = getfield.(filter(x -> (:mid in fieldnames(typeof(x))), gp.specs), :mid)
    @assert all(1 .<= mids)

    for mid in 1:maximum(mids)
        if !(mid in mids)
            push!(out, "set multiplot next")
        end

        is3d = false
        plotcmd = Vector{String}()
        for i in 1:length(gp.specs)
            spec = gp.specs[i]
            if !isa(spec, GPNamedDataset)  &&  (spec.mid != mid)
                continue
            end

            if isa(spec, GPCommand)
                push!(out, spec.cmd)
            elseif isa(spec, GPNamedDataset)
                ; # nothing to do
            elseif isa(spec, GPPlotCommand)
                is3d = is3d | spec.is3d
                push!(plotcmd, spec.cmd)
            else
                @assert isa(spec, GPPlotDataCommand)
                is3d = is3d | spec.is3d
                push!(plotcmd, "\$data$(i) " * spec.cmd)
            end
            #elseif isa(spec.data, DatasetBin)
            #    gp.datasources[i] = dropDuplicatedUsing.(spec.data.source, spec.plot)
        end

        if length(plotcmd) == 0
            push!(out, "set multiplot next")
        else
            push!(out, (is3d  ?  "splot "  :  "plot ") * " \\\n" *
                join(plotcmd, ", \\\n  "))
        end
    end
    push!(out, "unset multiplot")
    (output != "")  &&  push!(out, "set output")
    if term != ""  &&  (T == GPProcess)
        push!(out, "set term $former_term")
    end
    return out
end


# ---------------------------------------------------------------------
function dispatch(_args...; is3d=false)
    (sid, doReset, doDump, specs) = parseArguments(_args...)
    gp = getsession(sid)
    doReset  &&  reset(gp)

    for spec in specs
        add_spec!(gp, spec)
    end

    if options.gpviewer  &&  doDump
        for cmd in collect_commands(gp)
            gpexec(gp, cmd)
        end
    end
    return sid
end


# --------------------------------------------------------------------
"""
    @gp args...

The `@gp` macro, and its companion `@gsp` for 3D plots, allows to send data and commands to the gnuplot using an extremely concise syntax.  The macros accepts any number of arguments, with the following meaning:

- one, or a group of consecutive, array(s) of either `Real` or `String` build up a dataset.  The different arrays are accessible as columns 1, 2, etc. from the `gnuplot` process.  The number of required input arrays depends on the chosen plot style (see `gnuplot` documentation);

- a string occurring before a dataset is interpreted as a `gnuplot` command (e.g. `set grid`);

- a string occurring immediately after a dataset is interpreted as a *plot element* for the dataset, by which you can specify `using` clause, `with` clause, line styles, etc..  All keywords may be abbreviated following gnuplot conventions.  Moreover, "plot" and "splot" can be abbreviated to "p" and "s" respectively;

- the special symbol `:-` allows to split one long statement into multiple (shorter) ones.  If given as first argument it avoids starting a new plot.  If it given as last argument it avoids immediately running all commands to create the final plot;

- any other symbol is interpreted as a session ID;

- an `Int` (>= 1) is interpreted as the plot destination in a multi-plot session (this specification applies to subsequent arguments, not previous ones);

- an input in the form `"\\\$name"=>(array1, array2, etc...)` is interpreted as a named dataset.  Note that the dataset name must always start with a "`\$`";

- an input in the form `keyword=value` is interpreted as a keyword/value pair.  The accepted keywords and their corresponding gnuplot commands are as follows:
  - `xrange=[low, high]` => `"set xrange [low:high]`;
  - `yrange=[low, high]` => `"set yrange [low:high]`;
  - `zrange=[low, high]` => `"set zrange [low:high]`;
  - `cbrange=[low, high]`=> `"set cbrange[low:high]`;
  - `key="..."`  => `"set key ..."`;
  - `title="..."`  => `"set title \"...\""`;
  - `xlabel="..."` => `"set xlabel \"...\""`;
  - `ylabel="..."` => `"set ylabel \"...\""`;
  - `zlabel="..."` => `"set zlabel \"...\""`;
  - `cblabel="..."` => `"set cblabel \"...\""`;
  - `xlog=true`   => `set logscale x`;
  - `ylog=true`   => `set logscale y`;
  - `zlog=true`   => `set logscale z`.
  - `cblog=true`  => `set logscale cb`;
  - `margins=...` => `set margins ...`;
  - `lmargin=...` => `set lmargin ...`;
  - `rmargin=...` => `set rmargin ...`;
  - `bmargin=...` => `set bmargin ...`;
  - `tmargin=...` => `set tmargin ...`;

All Keyword names can be abbreviated as long as the resulting name is unambiguous.  E.g. you can use `xr=[1,10]` in place of `xrange=[1,10]`.

- a `PlotSpecs` object is expanded in its fields and processed as one of the previous arguments;

- any other data type is processed through an implicit recipe. If a suitable recipe do not exists an error is raised.
"""
macro gp(args...)
    out = Expr(:call)
    push!(out.args, :(Gnuplot.dispatch))
    for iarg in 1:length(args)
        arg = args[iarg]
        if (isa(arg, Expr)  &&  (arg.head == :(=)))
            sym = string(arg.args[1])
            val = arg.args[2]
            push!(out.args, :((Symbol($sym),$val)))
        else
            push!(out.args, arg)
        end
    end
    return esc(out)
end


"""
    @gsp args...

This macro accepts the same syntax as [`@gp`](@ref), but produces a 3D plot instead of a 2D one.
"""
macro gsp(args...)
    out = Expr(:macrocall, Symbol("@gp"), LineNumberNode(1, nothing))
    push!(out.args, args...)
    push!(out.args, Expr(:kw, :is3d, true))
    return esc(out)
end


# --------------------------------------------------------------------
"""
    session_names()

Return a vector with all currently active sessions.
"""
session_names() = Symbol.(keys(sessions))


# --------------------------------------------------------------------
"""
    terminals()

Return a `Vector{String}` with the names of all the available gnuplot terminals.
"""
terminals() = GnuplotProcess.terminals(getsession().process)


# --------------------------------------------------------------------
"""
    terminal(sid::Symbol)
    terminal()

Return a `String` with the current gnuplot terminal (and its options) of the process associated to session `sid`, or to the default session (if `sid` is not provided).
"""
terminal(sid::Symbol=options.default) = GnuplotProcess.terminal(getsession(sid).process)


# --------------------------------------------------------------------
import .GnuplotProcess.gpvars
"""
    gpvars(sid::Symbol)
    gpvars()

Return a `NamedTuple` with all currently defined gnuplot variables.  If the `sid` argument is not provided, the default session is considered.
"""
gpvars(sid::Symbol=options.default) = gpvars(getsession(sid).process)


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
#
# include("misc.jl")
# include("recipes.jl")
#
#
#
# using PrecompileTools
# @compile_workload begin
#     _orig_term = options.term
#     _orig_dry  = options.dry
#     options.term = "unknown"
#     options.dry = true
#     @gp 1:9
#     @gp tit="test" [0., 1.] [0., 1.] "w l"
#     @gp  hist(rand(10^6))
#     @gsp hist(rand(10^6), rand(10^6))
#     quitall()
#     options.term = _orig_term
#     options.dry  = _orig_dry
# end

end #module
