module Gnuplot

using StatsBase, ColorSchemes, ColorTypes, Colors, StructC14N, DataStructures

export session_names, palette_names, linetypes, palette_levels, palette,
    terminal, terminals, test_terminal,
    stats, @gp, @gsp, gpexec,
    hist_bins, hist_weights,
    boxxy, contourlines, dgrid3d, hist, gpvars, gpmargins, gpranges

"""
    Gnuplot.version()

Return the **Gnuplot.jl** package version.
"""
version() = v"1.6.0"


# ---------------------------------------------------------------------
"""
    Options

Structure containing the package global options, accessible through `Gnuplot.options`.

# Fields
- `dry::Bool`: whether to use *dry* sessions, i.e. without an underlying Gnuplot process (default: `false`)
- `cmd::String`: command to start the Gnuplot process (default: `"gnuplot"`)
- `default::Symbol`: default session name (default: `:default`)
- `term::String`: default terminal for interactive use (default: empty string);
- `gpviewer::Bool`: use a gnuplot terminal as main plotting device (if `true`) or an external viewer (if `false`);
- `init::Vector{String}`: commands to initialize the session when it is created or reset (e.g., to set default palette);
- `verbose::Bool`: verbosity flag (default: `false`)
- `preferred_format::Symbol`: preferred format to send data to gnuplot.  Value must be one of:
   - `bin`: fastest solution for large datasets, but uses temporary files;
   - `text`: may be slow for large datasets, but no temporary file is involved;
   - `auto` (default) use a heuristic to identify the best strategy.
"""
Base.@kwdef mutable struct Options
    dry::Bool = false
    cmd::String = "gnuplot"
    default::Symbol = :default
    term::String = ""
    gpviewer::Bool = false
    init::Vector{String} = Vector{String}()
    verbose::Bool = false
    preferred_format::Symbol = :auto
end
const options = Options()


function __init__()
    # Check whether we are running in an IJulia, Juno, VSCode or Pluto session.
    # (copied from Gaston.jl).
    options.gpviewer = true
    if ((isdefined(Main, :IJulia)  &&  Main.IJulia.inited)  ||
        (isdefined(Main, :Juno)    &&  Main.Juno.isactive()) ||
        (isdefined(Main, :VSCodeServer)) ||
        (isdefined(Main, :PlutoRunner)) )
        options.gpviewer = false
    end
end


# ---------------------------------------------------------------------
include("GnuplotProcess.jl")
using .GnuplotProcess

"""
    Gnuplot.gpversion()

Return the gnuplot application version.

Raise an error if version is < 5.0 (required to use data blocks).
"""
function gpversion()
    ver = Gnuplot.GnuplotProcess.gpversion(options.cmd)
     if ver < v"5.0"
        error("gnuplot ver. >= 5.0 is required, but " * string(ver) * " was found.")
     end
end

include("dataset.jl")
recipe() = error("No recipe defined")
include("plotspecs.jl")

struct GPSession{T}
    sid::Symbol
    process::T
    specs::Vector{AbstractGPSpec}
    GPSession(sid::Symbol)               = new{Nothing}(  sid, nothing, Vector{AbstractGPSpec}())
    GPSession(sid::Symbol, p::GPProcess) = new{GPProcess}(sid, p      , Vector{AbstractGPSpec}())
end


# ---------------------------------------------------------------------
const sessions = OrderedDict{Symbol, GPSession}()
function getsession(sid::Symbol=options.default)
    if !(sid in keys(sessions))
        if options.dry
            sessions[sid] = GPSession(sid)
        else
            popt = GnuplotProcess.Options()
            for f in fieldnames(typeof(options))
                if f in fieldnames(typeof(popt))
                    setproperty!(popt, f, getproperty(options, f))
                end
            end
            sessions[sid] = GPSession(sid, GPProcess(sid, popt))

            # Read gnuplot default terminal
            if options.term == ""
                options.term = terminal(sessions[sid])
            end
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
function gpexec(gp::GPSession{GPProcess}, s::AbstractString)
    gp.process.options.verbose = options.verbose
    gpexec(gp.process, s)
end
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


function reset(gp::GPSession{T}) where T
    delete_binaries(gp)
    empty!(gp.specs)
    (T == GnuplotProcess)  &&  reset(gp.process)

    if options.gpviewer
        # Use gnuplot viewer
        (options.term != "")  &&  gpexec(gp, "set term " * options.term)

        # Set window title (if not already set)
        term = gpexec(gp, "print GPVAL_TERM")
        if term in ("aqua", "x11", "qt", "wxt")
            opts = gpexec(gp, "print GPVAL_TERMOPTIONS")
            if findfirst("title", opts) == nothing
                gpexec(gp, "set term $term $opts title 'Gnuplot.jl: $(gp.sid)'")
            end
        end
    else
        # Use external viewer
        gpexec(gp, "set term unknown")
    end

    # Note: the reason to keep Options.term and .init separate are:
    # - .term can be overriden by "unknown" (if options.gpviewer is false);
    # - .init is saved in scripts, while .term is not;
    push!(gp, GPCommand(1, options.init))
    return nothing
end


"""
    Gnuplot.quit(sid::Symbol)

Quit the session identified by `sid` and the associated gnuplot process (if any).
"""
quit(sid::Symbol=options.default) = quit(getsession(sid))
function quit(gp::GPSession{T}) where T
    delete_binaries(gp)
    exitcode = (T == GPProcess)  ?   quit(gp.process)  :  0
    delete!(sessions, gp.sid)
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
            @assert isa(spec, GPPlotWithData)
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
import Base.push!, Base.append!
function push!(gp::GPSession{Nothing}, spec::AbstractGPSpec)
    push!(gp.specs, spec)
    nothing
end

function push!(gp::GPSession{GPProcess}, spec::AbstractGPSpec)
    push!(gp.specs, spec)
    name, source, data = datasets(gp)[end]
    if isa(data, DatasetText)
        if options.verbose
            printstyled(color=:light_black,      "GNUPLOT ($(gp.sid)) "  , name, " << EOD\n")
            printstyled(color=:light_black, join("GNUPLOT ($(gp.sid)) " .* spec.data.preview, "\n") * "\n")
            printstyled(color=:light_black,      "GNUPLOT ($(gp.sid)) ", "EOD\n")
        end
        write(gp.process.pin, name * " << EOD\n")
        write(gp.process.pin, spec.data.data)
        write(gp.process.pin, "\nEOD\n")
        flush(gp.process.pin)
    end
    nothing
end
append!(gp::GPSession, specs::Vector{AbstractGPSpec}) = push!.(Ref(gp), specs)


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
            isa(spec, AbstractGPSpecMid)  &&  (spec.mid != mid)  &&  continue

            if isa(spec, GPCommand)
                push!(out, spec.cmd)
            elseif isa(spec, GPNamedDataset)
                ; # nothing to do
            elseif isa(spec, GPPlotCommand)
                isnothing(is3d)  ?  (is3d = spec.is3d)  :  @assert(is3d == spec.is3d, "Mixing plot and splot commands is not allowed")
                push!(plotcmd, spec.cmd)
            else
                @assert isa(spec, GPPlotWithData)
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
            push!(out, (is3d  ?  "splot "  :  "plot ") * join(plotcmd, ", "))
        end
    end
    push!(out, "unset multiplot")
    (output != "")  &&  push!(out, "set output")
    if term != ""  &&  (T == GPProcess)
        push!(out, "set term $former_term")
    end
    return out
end


# --------------------------------------------------------------------
function last_added_mid(gp::GPSession)
    for i in length(gp.specs):-1:1
        isa(gp.specs[i], AbstractGPSpecMid)  &&  (return gp.specs[i].mid)
    end
    return 1
end

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
    first = 1
    is3d = false
    if first <= length(args)  &&  isa(args[first], Bool)  &&  args[first]
        is3d = true
        first += 1
    end
    doReset = true
    if first <= length(args)  &&  isa(args[first], QuoteNode)  &&  (args[first] == QuoteNode(:-))
        doReset = false
        first += 1
    end
    sid = nothing
    if (first <= length(args))  &&  isa(args[first], QuoteNode)
        sid = args[first]
        first += 1
    else
        sid = :(Gnuplot.options.default)
    end
    doExec = true
    last = length(args)
    if (last >= 1)  &&  (last <= length(args))  &&  isa(args[last] , QuoteNode)  &&  (args[last] == QuoteNode(:-))
        doExec = false
        last -= 1
    end

    if first <= last
        specs = Expr(:call, :(Gnuplot.parseSpecs))
        for i in first:last
            arg = args[i]
            if (isa(arg, Expr)  &&  (arg.head == :(=)))  # forward keywords
                push!(specs.args, Expr(:kw, arg.args[1], arg.args[2]))
            else
                push!(specs.args, arg)
            end
        end
        push!(specs.args, Expr(:kw, :default_mid, :(Gnuplot.last_added_mid(gp))))
        push!(specs.args, Expr(:kw, :is3d, is3d))
    else
        doReset = false
        specs = nothing
    end
    out = Expr(:block)
    if doReset  ||  doExec  ||  !isnothing(specs)
        push!(out.args,                       :(local gp = Gnuplot.getsession($sid)))
        doReset  &&           push!(out.args, :(Gnuplot.reset(gp)))
        isnothing(specs)  ||  push!(out.args, :(Gnuplot.append!(gp, $specs)))
        doExec            &&  push!(out.args, :(Gnuplot.options.gpviewer  &&  gpexec.(Ref(gp), Gnuplot.collect_commands(gp))))
        push!(out.args, doExec  ?             :(gp)  :  :(nothing))
    end
    return esc(out)
end

"""
    @gsp args...

This macro accepts the same syntax as [`@gp`](@ref), but produces a 3D plot instead of a 2D one.
"""
macro gsp(args...)
    out = Expr(:macrocall, Symbol("@gp"), LineNumberNode(1, nothing))
    push!(out.args, true)
    append!(out.args, args)
    return esc(out)
end


# ---------------------------------------------------------------------
"""
    savescript([sid::Symbol,] filename::String)

Save a gnuplot script in `filename`.  The latter can then be used in a pure gnuplot session (Julia is no longer needed) to generate exactly the same plot.

If the `sid` argument is provided the operation applies to the corresponding session, otherwise the default session is considered.

Example:
```julia
@gp hist(randn(1000))
Gnuplot.savescript("script.gp")
```
"""
savescript(file::AbstractString) = savescript(options.default, file)
function savescript(sid::Symbol, filename::AbstractString)
    gp = getsession(sid)
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
            cp(data.file, joinpath(path_bin, basename(data.file)), force=true)
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
    save([sid::Symbol,] filename:String; term="")

Export a plot into `filename` using the terminal provided via the `term=` keyword.

If the `sid` argument is provided the operation applies to the corresponding session, otherwise the default session is considered.

Example:
```julia
@gp hist(randn(1000))
Gnuplot.save("output.png", term="pngcairo")
```
"""
save(file::AbstractString; term::AbstractString="") = save(options.default, file, term=term)
function save(sid::Symbol, file::AbstractString; term::AbstractString="")
    gp = getsession(sid)
    gpexec.(Ref(gp), collect_commands(gp; term=term, output=file))
    return file
end


# --------------------------------------------------------------------
import Base.show

show(io::IO, d::T) where T <: Dataset = write(io, string(T))

function _show(io::IO, gp::GPSession, term::String)
    options.gpviewer  &&  return nothing
    filename = tempname()
    save(gp.sid, filename, term=term)
    write(io, read(filename))
    rm(filename; force=true)
    nothing
end
show(io::IO, ::MIME"application/pdf", gp::GPSession) = _show(io, gp, "pdfcairo enhanced")
show(io::IO, ::MIME"image/jpeg"     , gp::GPSession) = _show(io, gp, "jpeg enhanced")
show(io::IO, ::MIME"image/png"      , gp::GPSession) = _show(io, gp, "pngcairo enhanced")
show(io::IO, ::MIME"image/svg+xml"  , gp::GPSession) = _show(io, gp, "svg enhanced mouse standalone background rgb 'white'")  #  dynamic
show(io::IO, ::MIME"text/html"      , gp::GPSession) = _show(io, gp, "svg enhanced mouse standalone dynamic")  # canvas mousing
show(io::IO, ::MIME"text/plain"     , gp::GPSession) = _show(io, gp, "dumb enhanced ansi")


include("histogram.jl")
include("utils.jl")
include("recipes.jl")
include("repl.jl")


using PrecompileTools
@compile_workload begin
    _orig_term = options.term
    _orig_dry  = options.dry
    options.term = "unknown"
    options.dry = true
    @gp 1:9
    @gp tit="test" [0., 1.] [0., 1.] "w l"
    @gp  hist(rand(10^6))
    @gsp hist(rand(10^6), rand(10^6))
    quitall()
    options.term = _orig_term
    options.dry  = _orig_dry
end

end #module
