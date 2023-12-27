module Gnuplot

using StatsBase, ColorSchemes, ColorTypes, Colors, StructC14N, DataStructures

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
include("GnuplotProcess.jl")
using .GnuplotProcess
gpversion() = Gnuplot.GnuplotProcess.gpversion(options.cmd)
include("dataset.jl")
recipe() = error("No recipe defined")
include("plotspecs.jl")

struct GPSession{T}
    process::T
    specs::Vector{AbstractGPCommand}
    GPSession()             = new{Nothing}(  nothing, Vector{AbstractGPCommand}())
    GPSession(p::GPProcess) = new{GPProcess}(p      , Vector{AbstractGPCommand}())
end


# ---------------------------------------------------------------------
const sessions = OrderedDict{Symbol, GPSession}()
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


"""
    session_names()

Return a vector with all currently active sessions.
"""
session_names() = Symbol.(keys(sessions))


# ---------------------------------------------------------------------
import .GnuplotProcess: gpexec, gpvars, reset, quit, terminal, terminals
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
gpexec(gp::GPSession{Nothing}, s::AbstractString) = nothing
gpexec(gp::GPSession{GPProcess}, s::AbstractString) = gpexec(gp.process, s)
gpexec(sid::Symbol, s::String) = gpexec(getsession(sid), s)
gpexec(s::String) = gpexec(getsession(), s)


"""
    gpvars(sid::Symbol)
    gpvars()

Return a `NamedTuple` with all currently defined gnuplot variables.  If the `sid` argument is not provided, the default session is considered.
"""
gpvars(gp::GPSession{Nothing}) = nothing
gpvars(gp::GPSession{GPProcess}) = gpvars(gp.process)
gpvars(sid::Symbol=options.default) = gpvars(getsession(sid))


function reset(gp::GPSession)
    delete_binaries(gp)
    empty!(gp.specs)
    reset(gp.process)

    # Note: the reason to keep Options.term and .init separate are:
    # - .term can be overriden by "unknown" (if options.gpviewer is false);
    # - .init is saved in scripts, while .term is not;
    add_spec!(gp, GPCommand(options.init))
    return nothing
end


"""
    Gnuplot.quit(sid::Symbol)

Quit the session identified by `sid` and the associated gnuplot process (if any).
"""
quit(gp::GPSession{Nothing}) = 0
quit(gp::GPSession{GPProcess}) = quit(gp.process)
function quit(sid::Symbol=options.default)
    gp = getsession(sid)
    delete_binaries(gp)
    exitcode = quit(gp)
    delete!(sessions, sid)
    return exitcode
end


"""
    terminal(sid::Symbol)
    terminal()

Return a `String` with the current gnuplot terminal (and its options) of the process associated to session `sid`, or to the default session (if `sid` is not provided).
"""
terminal(gp::GPSession{Nothing}) = "unknown"
terminal(gp::GPSession{GPProcess}) = terminal(gp.process)
terminal(sid::Symbol=options.default) = terminal(getsession(sid))

"""
    terminals()

Return a `Vector{String}` with the names of all the available gnuplot terminals.
"""
terminals(gp::GPSession{Nothing}) = error("Unknown terminals for a dry session")
terminals(gp::GPSession{GPProcess}) = terminals(gp.process)
terminals(sid::Symbol=options.default) = terminals(getsession(sid))


# ---------------------------------------------------------------------
function datasets(gp::GPSession)
    out = []
    for i in 1:length(gp.specs)
        spec = gp.specs[i]
        if isa(spec, GPCommand)
            push!(out, (nothing, nothing, nothing))
        elseif isa(spec, GPNamedDataset)
            push!(out, (spec.name, spec.name, spec.data))
        elseif isa(spec, GPPlotCommand)
            push!(out, (nothing, nothing, nothing))
        else
            @assert isa(spec, GPPlotDataCommand)
            name = "\$data$i"
            if isa(spec.data, DatasetText)
                source = name
            else
                @assert isa(spec.data, DatasetBin)
                source = spec.data.source
            end
            push!(out, (name, source, spec.data))
        end
    end
    return out
end


# ---------------------------------------------------------------------
add_spec!(gp::GPSession{Nothing}, spec::AbstractGPCommand) = push!(gp.specs, spec)
function add_spec!(gp::GPSession{GPProcess}, spec::AbstractGPCommand)
    push!(gp.specs, spec)
    name, source, data = datasets(gp)[end]
    if isa(data, DatasetText)
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
    for (name, source, data) in datasets(gp)
        if isa(data, DatasetBin)  &&  (data.file != "")
            rm(data.file, force=true)
        end
    end
end


# ---------------------------------------------------------------------
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


# ---------------------------------------------------------------------
function collect_commands(gp::GPSession{T}; term::AbstractString="", output::AbstractString="", redirect_path=nothing) where T
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
    (length(mids) == 0)  &&  (mids = [1])
    @assert all(1 .<= mids)

    for mid in 1:maximum(mids)
        plotcmd = Vector{String}()
        is3d = nothing
        for i in 1:length(gp.specs)
            spec = gp.specs[i]
            if !isa(spec, GPNamedDataset)
                (spec.mid != mid)  &&  continue
            end

            if isa(spec, GPCommand)
                push!(out, spec.cmd)
            elseif isa(spec, GPNamedDataset)
                ; # nothing to do
            elseif isa(spec, GPPlotCommand)
                isnothing(is3d)  ?  (is3d = spec.is3d)  :  @assert(is3d == spec.is3d, "Mixing plot and splot commands is not allowed")
                push!(plotcmd, spec.cmd)
            else
                @assert isa(spec, GPPlotDataCommand)
                isnothing(is3d)  ?  (is3d = spec.is3d)  :  @assert(is3d == spec.is3d, "Mixing plot and splot commands is not allowed")
                if isa(spec.data, DatasetText)
                    push!(plotcmd, "\$data$(i) " * spec.cmd)
                else
                    @assert isa(spec.data, DatasetBin)
                    if isnothing(redirect_path)
                        push!(plotcmd, spec.data.source * " " * spec.cmd)
                    else
                        s = replace(spec.data.source, spec.data.file => joinpath(redirect_path, basename(spec.data.file)))
                        push!(plotcmd, s * " " * spec.cmd)
                    end
                end
            end
            #TODO elseif isa(spec.data, DatasetBin)  gp.datasources[i] = dropDuplicatedUsing.(spec.data.source, spec.plot)
        end

        if length(plotcmd) == 0
            if maximum(mids) > 1
                push!(out, "set multiplot next")
            end
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
"""
    SessionID

A structure identifying a specific session.  Used in the `show` interface.
"""
struct SessionHandle
    sid::Symbol
    readyToShow::Bool
end


# --------------------------------------------------------------------
function driver(_args...; kws...)
    args = Vector{Any}([_args...])

    # First pass: check for session name, `:-` and multiplot index
    sid = nothing
    doReset = length(args) > 0
    isReady = true
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if typeof(arg) == Symbol
            if arg == :-
                if pos == 1
                    doReset = false
                elseif pos == length(args)
                    isReady  = false
                else
                    error("Symbol `:-` has a meaning only if it is at first or last position in argument list.")
                end
            else
                @assert isnothing(sid) "Only one session at a time can be addressed"
                @assert pos == 1 "Session ID should be specified before plot specs"
                sid = arg
            end
            deleteat!(args, pos)
        else
            pos += 1
        end
    end
    isnothing(sid)  &&  (sid = options.default)

    gp = getsession(sid)
    doReset && reset(gp)
    specs = parseArguments(args...; kws...)
    add_spec!.(Ref(gp), specs)
    if options.gpviewer  &&  isReady
        gpexec.(Ref(gp), collect_commands(gp))
    end
    return SessionHandle(sid, isReady)
end


# ---------------------------------------------------------------------
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
    push!(out.args, :(Gnuplot.driver))
    for iarg in 1:length(args)
        arg = args[iarg]
        if (isa(arg, Expr)  &&  (arg.head == :(=)))
            push!(out.args, Expr(:kw, arg.args[1], arg.args[2]))
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


# ---------------------------------------------------------------------
savescript(             file::AbstractString) = savescript(options.default, file)
savescript(sid::Symbol, file::AbstractString) = savescript(getsession(sid), file)
function savescript(gp::GPSession, filename)
    stream = open(filename, "w")
    println(stream, "reset session")

    # Path for binary files associated to the output script
    s = split(basename(filename), ".")
    if length(s) > 1
        deleteat!(s, length(s))
    end
    s[end] *= "_data"
    path_bin = joinpath(dirname(filename), join(s, "."))
    isabspath(path_bin)  ||  (path_bin=joinpath(".", path_bin))

    # Write named datasets / copy binary files
    for (name, source, data) in datasets(gp)
        if isa(data, DatasetText)
            println(stream, name * " << EOD")
            println(stream, data.data)
            println(stream, "EOD")
        elseif isa(data, DatasetBin)  &&  (data.file != "")
            mkpath(path_bin)
            cp(data.file, joinpath(path_bin, basename(data.file), force=true))
        end
    end
    for s in collect_commands(gp, redirect_path=path_bin)
        println(stream, s)
    end
    close(stream)
    return filename
end


# --------------------------------------------------------------------
"""
    save([sid::Symbol]; term="", output="")
    save([sid::Symbol,] mime::Type{T}; output="") where T <: MIME
    save([sid::Symbol,] script_filename::String, ;term="", output="")

Export a (multi-)plot into the external file name provided in the `output=` keyword.  The gnuplot terminal to use is provided through the `term=` keyword or the `mime` argument.  In the latter case the proper terminal is set according to the `Gnuplot.options.mime` dictionary.

If the `script_filename` argument is provided a *gnuplot script* will be written in place of the output image.  The latter can then be used in a pure gnuplot session (Julia is no longer needed) to generate exactly the same original plot.

If the `sid` argument is provided the operation applies to the corresponding session, otherwise the default session is considered.

Example:
```julia
@gp hist(randn(1000))
save(MIME"text/plain")
save(term="pngcairo", output="output.png")
save("script.gp")
```
"""
save(sid::Symbol=options.default; kws...) = gpexec.(Ref(getsession(sid)), collect_commands(getsession(sid); kws...))

save(mime::Type{T}; kw...) where T <: MIME = save(options.default, mime; kw...)
function save(sid::Symbol, mime::Type{T}; kw...) where T <: MIME
    @assert mime in keys(options.mime) "No terminal is defined for $mime.  Check `Gnuplot.options.mime` dictionary."
    term = string(strip(options.mime[mime]))
    if term != ""
        return save(sid; term=term, kw...)
    end
end



include("utils.jl")
include("histogram.jl")
# include("recipes.jl")
include("repl.jl")


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
