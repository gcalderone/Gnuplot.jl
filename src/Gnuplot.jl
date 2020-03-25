module Gnuplot

using StatsBase, ColorSchemes, ColorTypes, StructC14N, ReusePatterns

import Base.reset
import Base.write

export @gp, @gsp, save, linestyles, palette, contourlines, hist, terminal, terminals

# ╭───────────────────────────────────────────────────────────────────╮
# │                           TYPE DEFINITIONS                        │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
mutable struct DataSet
    name::String
    lines::Vector{String}
end


# ---------------------------------------------------------------------
mutable struct SinglePlot
    cmds::Vector{String}
    elems::Vector{String}
    flag3d::Bool
    SinglePlot() = new(Vector{String}(), Vector{String}(), false)
end


# ---------------------------------------------------------------------
@quasiabstract mutable struct DrySession
    sid::Symbol                # session ID
    datas::Vector{DataSet}     # data sets
    plots::Vector{SinglePlot}  # commands and plot commands (one entry for each plot of the multiplot)
    curmid::Int                # current multiplot ID
end


# ---------------------------------------------------------------------
@quasiabstract mutable struct GPSession <: DrySession
    pin::Base.Pipe;
    pout::Base.Pipe;
    perr::Base.Pipe;
    proc::Base.Process;
    channel::Channel{String};
end


# ---------------------------------------------------------------------
Base.@kwdef mutable struct Options
    dry::Bool = false                         # Use "dry" sessions (i.e. without an underlying Gnuplot process)
    cmd::String = "gnuplot"                   # Customizable command to start the Gnuplot process
    default::Symbol = :default                # Default session name
    init::Vector{String} = Vector{String}()   # Commands to initialize the gnuplot session (e.g., to set default terminal)
    verbose::Bool = false                     # verbosity flag (true/false)
    datalines::Int = 4;                       # How many lines of a dataset are printed in log
end
const sessions = Dict{Symbol, DrySession}()
const options = Options()

# ╭───────────────────────────────────────────────────────────────────╮
# │                         LOW LEVEL FUNCTIONS                       │
# ╰───────────────────────────────────────────────────────────────────╯

version() = v"1.0-dev"

# ---------------------------------------------------------------------
"""
  # gpversion

  Check whether gnuplot is runnable with the default command.
  Raise an error if version is < 4.7 (required to use data
  blocks).
"""
function gpversion()
    options.dry  &&  (return v"0.0.0")
    icmd = `$(options.cmd) --version`

    proc = open(`$icmd`, read=true)
    s = String(read(proc))
    if !success(proc)
        error("An error occurred while running: " * string(icmd))
    end

    s = split(s, " ")
    ver = ""
    for token in s
        try
            ver = VersionNumber("$token")
            break
        catch
        end
    end

    if ver < v"4.7"
        error("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    return ver
end


# ---------------------------------------------------------------------
function parseKeywords(; kwargs...)
    template = (xrange=NTuple{2, Real},
                yrange=NTuple{2, Real},
                zrange=NTuple{2, Real},
                cbrange=NTuple{2, Real},
                key=AbstractString,
                title=AbstractString,
                xlabel=AbstractString,
                ylabel=AbstractString,
                zlabel=AbstractString,
                xlog=Bool,
                ylog=Bool,
                zlog=Bool)

    kw = canonicalize(template; kwargs...)
    out = Vector{String}()
    ismissing(kw.xrange ) || (push!(out, "set xrange  [" * join(kw.xrange , ":") * "]"))
    ismissing(kw.yrange ) || (push!(out, "set yrange  [" * join(kw.yrange , ":") * "]"))
    ismissing(kw.zrange ) || (push!(out, "set zrange  [" * join(kw.zrange , ":") * "]"))
    ismissing(kw.cbrange) || (push!(out, "set cbrange [" * join(kw.cbrange, ":") * "]"))
    ismissing(kw.key    ) || (push!(out, "set key " * kw.key  * ""))
    ismissing(kw.title  ) || (push!(out, "set title  \"" * kw.title  * "\""))
    ismissing(kw.xlabel ) || (push!(out, "set xlabel \"" * kw.xlabel * "\""))
    ismissing(kw.ylabel ) || (push!(out, "set ylabel \"" * kw.ylabel * "\""))
    ismissing(kw.zlabel ) || (push!(out, "set zlabel \"" * kw.zlabel * "\""))
    ismissing(kw.xlog   ) || (push!(out, (kw.xlog  ?  ""  :  "un") * "set logscale x"))
    ismissing(kw.ylog   ) || (push!(out, (kw.ylog  ?  ""  :  "un") * "set logscale y"))
    ismissing(kw.zlog   ) || (push!(out, (kw.zlog  ?  ""  :  "un") * "set logscale z"))
    return out
end


# ---------------------------------------------------------------------
tostring(v) = string(v)
tostring(c::ColorTypes.RGB) = string(float(c.r)*255) * " " * string(float(c.g)*255) * " " * string(float(c.b)*255)
tostring(v::AbstractString) = "\"" * string(v) * "\""

function data2string(args...)
    @assert length(args) > 0

    # Check types of args
    for iarg in 1:length(args)
        d = args[iarg]

        ok = false
        if typeof(d) <: Number
            ok = true
        elseif typeof(d) <: AbstractArray
            (typeof(d[1]) <: String)  &&  (ok = true)
            (typeof(d[1]) <: Number)  &&  (ok = true)
            (typeof(d[1]) <: ColorTypes.RGB)  &&  (ok = true)
        elseif typeof(d) <: Histogram1D
            ok = true
        elseif typeof(d) <: Histogram2D
            ok = true
        end
        @assert ok "Invalid argument type at position $iarg"
    end

    # Collect lengths and number of dims
    lengths = Vector{Int}()
    dims = Vector{Int}()
    firstMultiDim = 0
    for i in 1:length(args)
        d = args[i]
        @assert ndims(d) <= 3 "Array dimensions must be <= 3"
        push!(lengths, length(d))
        push!(dims   , ndims(d))
        (firstMultiDim == 0)  &&  (ndims(d) > 1)  &&  (firstMultiDim = i)
    end

    accum = Vector{String}()

    # All scalars
    if minimum(dims) == 0
        #@info "Case 0"
        @assert maximum(dims) == 0 "Input data are ambiguous: either use all scalar or arrays of floats"
        v = ""
        for iarg in 1:length(args)
            d = args[iarg]
            v *= " " * tostring(d)
        end
        push!(accum, v)
        return accum
    end

    @assert all((dims .== 1)  .|  (dims .== maximum(dims))) "Array size are incompatible"

    # All 1D
    if firstMultiDim == 0
        #@info "Case 1"
        @assert minimum(lengths) == maximum(lengths) "Array size are incompatible"
        for i in 1:lengths[1]
            v = ""
            for iarg in 1:length(args)
                d = args[iarg]
                v *= " " * tostring(d[i])
            end
            push!(accum, v)
        end
        return accum
    end

    # Multidimensional, no independent 1D indices
    if firstMultiDim == 1
        #@info "Case 2"
        @assert minimum(lengths) == maximum(lengths) "Array size are incompatible"
        i = 1
        for CIndex in CartesianIndices(size(args[1]))
            indices = Tuple(CIndex)
            (i > 1)  &&  (indices[end-1] == 1)  &&  (push!(accum, ""))  # blank line
            if length(args) == 1
                # Add independent indices (useful when plotting "with image")
                v = join(string.(getindex.(Ref(Tuple(indices)), 1:ndims(args[1]))), " ")
            else
                # Do not add independent indices since there is no way to identify the distinguish a "z" array from additional arrays
                v = ""
            end
            for iarg in 1:length(args)
                d = args[iarg]
                v *= " " * tostring(d[i])
            end
            i += 1
            push!(accum, v)
        end
        return accum
    end

    # Multidimensional (independent indices provided in input)
    if firstMultiDim >= 2
        refLength = lengths[firstMultiDim]
        @assert all(lengths[firstMultiDim:end] .== refLength) "Array size are incompatible"

        if lengths[1] < refLength
            #@info "Case 3"
            # Cartesian product of Independent variables
            checkLength = prod(lengths[1:firstMultiDim-1])
            @assert prod(lengths[1:firstMultiDim-1]) == refLength "Array size are incompatible"

            i = 1
            for CIndex in CartesianIndices(size(args[firstMultiDim]))
                indices = Tuple(CIndex)
                (i > 1)  &&  (indices[end-1] == 1)  &&  (push!(accum, ""))  # blank line
                v = ""
                for iarg in 1:firstMultiDim-1
                    d = args[iarg]
                    v *= " " * tostring(d[indices[iarg]])
                end
                for iarg in firstMultiDim:length(args)
                    d = args[iarg]
                    v *= " " * tostring(d[i])
                end
                i += 1
                push!(accum, v)
            end
            return accum
        else
            #@info "Case 4"
            # All Independent variables have the same length as the main multidimensional data
            @assert all(lengths[1:firstMultiDim-1] .== refLength) "Array size are incompatible"

            i = 1
            for CIndex in CartesianIndices(size(args[firstMultiDim]))
                indices = Tuple(CIndex)
                (i > 1)  &&  (indices[end-1] == 1)  &&  (push!(accum, ""))  # blank line
                v = ""
                for iarg in 1:length(args)
                    d = args[iarg]
                    v *= " " * tostring(d[i])
                end
                i += 1
                push!(accum, v)
            end
            return accum
        end
    end

    return nothing
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                SESSION CONSTRUCTORS AND getsession()              │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
function DrySession(sid::Symbol)
    (sid in keys(sessions))  &&  error("Gnuplot session $sid is already active")
    out = DrySession(sid, Vector{DataSet}(), [SinglePlot()], 1)
    sessions[sid] = out
    return out
end

# ---------------------------------------------------------------------
function GPSession(sid::Symbol)
    function readTask(sid, stream, channel)
        saveOutput = false

        while isopen(stream)
            line = readline(stream)
            if (length(line) >= 1)  &&  (line[1] == Char(0x1b)) # Escape (xterm -ti vt340)
                buf = Vector{UInt8}()
                append!(buf, convert(Vector{UInt8}, [line...]))
                push!(buf, 0x0a)
                c = 0x00
                while c != 0x1b
                    c = read(stream, 1)[1]
                    push!(buf, c)
                end
                c = read(stream, 1)[1]
                push!(buf, c)
                write(stdout, buf)
                continue
            end
            if line == "GNUPLOT_CAPTURE_BEGIN"
                saveOutput = true
            else
                if ((line != "")  &&  (line != "GNUPLOT_CAPTURE_END")  &&  (options.verbose))  ||
                    !isnothing(match(r"clipboard", line))
                    printstyled(color=:cyan, "GNUPLOT ($sid) -> $line\n")
                end
                (saveOutput)  &&  (put!(channel, line))
                (line == "GNUPLOT_CAPTURE_END")  &&  (saveOutput = false)
            end
        end
        delete!(sessions, sid)
        return nothing
    end


    gpversion()
    session = DrySession(sid)

    pin  = Base.Pipe()
    pout = Base.Pipe()
    perr = Base.Pipe()
    proc = run(pipeline(`$(options.cmd)`, stdin=pin, stdout=pout, stderr=perr), wait=false)
    chan = Channel{String}(32)

    # Close unused sides of the pipes
    Base.close(pout.in)
    Base.close(perr.in)
    Base.close(pin.out)
    Base.start_reading(pout.out)
    Base.start_reading(perr.out)

    # Start reading tasks
    @async readTask(sid, pout, chan)
    @async readTask(sid, perr, chan)

    out = GPSession(getfield.(Ref(session), fieldnames(concretetype(DrySession)))...,
                    pin, pout, perr, proc, chan)
    sessions[sid] = out

    for l in options.init
        writeread(out, l)
    end

    # Set window title (if not already set)
    term = writeread(out, "print GPVAL_TERM")[1]
    if term in ("aqua", "x11", "qt", "wxt")
        opts = writeread(out, "print GPVAL_TERMOPTIONS")[1]
        if findfirst("title", opts) == nothing
            writeread(out, "set term $term $opts title 'Gnuplot.jl: $(out.sid)'")
        end
    end

    return out
end


# ---------------------------------------------------------------------
function getsession(sid::Symbol=options.default)
    if !(sid in keys(sessions))
        if options.dry
            DrySession(sid)
        else
            GPSession(sid)
        end
    end
    return sessions[sid]
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                       write() and writeread()                     │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
"""
  # write

  Send a string to gnuplot's STDIN.

  The commands sent through `write` are not stored in the current
  session (use `newcmd` to save commands in the current session).

  ## Arguments:
  - `gp`: a `DrySession` object;
  - `str::String`: command to be sent;
"""
write(gp::DrySession, str::AbstractString) = nothing
function write(gp::GPSession, str::AbstractString)
    if options.verbose
        printstyled(color=:light_yellow, "GNUPLOT ($(gp.sid)) $str\n")
    end
    w = write(gp.pin, strip(str) * "\n")
    w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    flush(gp.pin)
    return w
end


write(gp::DrySession, d::DataSet) = nothing
function write(gp::GPSession, d::DataSet)
    if options.verbose
        v = ""
        printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) $(d.name) << EOD\n")
        n = min(options.datalines, length(d.lines))
        for i in 1:n
            printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) $(d.lines[i])\n")
        end
        if n < length(d.lines)
            printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) ...\n")
        end
        printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) EOD\n")
    end
    write(gp.pin, "$(d.name) << EOD\n")
    write(gp.pin, join(d.lines, "\n") * "\n")
    write(gp.pin, "EOD\n")
    flush(gp.pin)
    return nothing
end


# ---------------------------------------------------------------------
writeread(gp::DrySession, str::AbstractString) = [""]
function writeread(gp::GPSession, str::AbstractString)
    verbose = options.verbose

    options.verbose = false
    write(gp, "print 'GNUPLOT_CAPTURE_BEGIN'")

    options.verbose = verbose
    write(gp, str)

    options.verbose = false
    write(gp, "print 'GNUPLOT_CAPTURE_END'")
    options.verbose = verbose

    out = Vector{String}()
    while true
        l = take!(gp.channel)
        l == "GNUPLOT_CAPTURE_END"  &&  break
        push!(out, l)
    end
    return out
end


# ╭───────────────────────────────────────────────────────────────────╮
# │              PRIVATE FUNCTIONS TO MANIPULATE SESSIONS             │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
function reset(gp::DrySession)
    gp.datas = Vector{DataSet}()
    gp.plots = [SinglePlot()]
    gp.curmid = 1
    exec(gp, "reset session")
    return nothing
end


# ---------------------------------------------------------------------
function setmulti(gp::DrySession, mid::Int)
    @assert mid >= 1 "Multiplot ID must be a >= 1"
    while length(gp.plots) < mid
        push!(gp.plots, SinglePlot())
    end
    gp.curmid = mid
end


# ---------------------------------------------------------------------
function newdataset(gp::DrySession, accum::Vector{String}; name="")
    (name == "")  &&  (name = string("\$data", length(gp.datas)+1))
    #name = "\$$name"
    d = DataSet(name, accum)
    push!(gp.datas, d)
    write(gp, d) # Send now to gnuplot process
    return name
end
newdataset(gp::DrySession, args...; name="") = newdataset(gp, data2string(args...), name=name)


# ---------------------------------------------------------------------
function newcmd(gp::DrySession, v::String)
    (v != "")  &&  (push!(gp.plots[gp.curmid].cmds, v))
    (length(gp.plots) == 1)  &&  (exec(gp, v))  # execute now to check against errors
    return nothing
end

function newcmd(gp::DrySession; args...)
    for v in parseKeywords(;args...)
        newcmd(gp, v)
    end
    return nothing
end


# ---------------------------------------------------------------------
function newplot(gp::DrySession, name, opt="")
    push!(gp.plots[gp.curmid].elems, "$name $opt")
end


# ---------------------------------------------------------------------
function quit(gp::DrySession)
    delete!(sessions, gp.sid)
    return 0
end

function quit(gp::GPSession)
    close(gp.pin)
    close(gp.pout)
    close(gp.perr)
    wait( gp.proc)
    exitCode = gp.proc.exitcode
    invoke(quit, Tuple{DrySession}, gp)
    return exitCode
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                 execall(), dump() and driver()                    │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
execall(gp::DrySession; term::AbstractString="", output::AbstractString="") = nothing
function execall(gp::GPSession; term::AbstractString="", output::AbstractString="")
    exec(gp, "reset")
    if term != ""
        former_term = writeread(gp, "print GPVAL_TERM")[1]
        former_opts = writeread(gp, "print GPVAL_TERMOPTIONS")[1]
        exec(gp, "set term $term")
    end
    (output != "")  &&  exec(gp, "set output '$output'")

    for i in 1:length(gp.plots)
        d = gp.plots[i]
        for j in 1:length(d.cmds)
            exec(gp, d.cmds[j])
        end
        if length(d.elems) > 0
            s = (d.flag3d  ?  "splot "  :  "plot ") * " \\\n  " *
                join(d.elems, ", \\\n  ")
            exec(gp, s)
        end
    end
    (length(gp.plots) > 1)  &&  exec(gp, "unset multiplot")
    (output != "")  &&  exec(gp, "set output")
    if term != ""
        exec(gp, "set term $former_term $former_opts")
    end
    return nothing
end


function savescript(gp::DrySession, filename; term::AbstractString="", output::AbstractString="")
    stream = open(filename, "w")

    println(stream, "reset session")
    if term != ""
        println(stream, "set term $term")
    end
    (output != "")  &&  println(stream, "set output '$output'")

    for i in 1:length(gp.datas)
        d = gp.datas[i]
        println(stream, d.name * " << EOD")
        for j in 1:length(d.lines)
            println(stream, d.lines[j])
        end
        println(stream, "EOD")
    end

    for i in 1:length(gp.plots)
        d = gp.plots[i]
        for j in 1:length(d.cmds)
            println(stream, d.cmds[j])
        end
        if length(d.elems) > 0
            s = (d.flag3d  ?  "splot "  :  "plot ") * " \\\n  " *
                join(d.elems, ", \\\n  ")
            println(stream, s)
        end
    end
    (length(gp.plots) > 1)  &&  println(stream, "unset multiplot")
    println(stream, "set output")
    close(stream)
    return nothing
end


# ---------------------------------------------------------------------
function driver(args...; flag3d=false)
    function isPlotCmd(s::String)
        (length(s) >= 2)  &&  (s[1:2] ==  "p "    )  &&  (return (true, false, strip(s[2:end])))
        (length(s) >= 3)  &&  (s[1:3] ==  "pl "   )  &&  (return (true, false, strip(s[3:end])))
        (length(s) >= 4)  &&  (s[1:4] ==  "plo "  )  &&  (return (true, false, strip(s[4:end])))
        (length(s) >= 5)  &&  (s[1:5] ==  "plot " )  &&  (return (true, false, strip(s[5:end])))
        (length(s) >= 2)  &&  (s[1:2] ==  "s "    )  &&  (return (true, true , strip(s[2:end])))
        (length(s) >= 3)  &&  (s[1:3] ==  "sp "   )  &&  (return (true, true , strip(s[3:end])))
        (length(s) >= 4)  &&  (s[1:4] ==  "spl "  )  &&  (return (true, true , strip(s[4:end])))
        (length(s) >= 5)  &&  (s[1:5] ==  "splo " )  &&  (return (true, true , strip(s[5:end])))
        (length(s) >= 6)  &&  (s[1:6] ==  "splot ")  &&  (return (true, true , strip(s[6:end])))
        return (false, false, "")
    end

    if length(args) == 0
        gp = getsession()
        execall(gp)
        return nothing
    end

    # First pass: check for ":-" and session names
    gp = nothing
    doDump  = true
    doReset = true
    for iarg in 1:length(args)
        arg = args[iarg]

        if typeof(arg) == Symbol
            if arg == :-
                if iarg == 1
                    doReset = false
                elseif iarg == length(args)
                    doDump  = false
                else
                    @warn ":- at position $iarg in argument list has no meaning."
                end
            else
                @assert isnothing(gp) "Only one session at a time can be addressed"
                gp = getsession(arg)
            end
        end
    end
    (gp == nothing)  &&  (gp = getsession())
    doReset  &&  reset(gp)

    dataset = Vector{Any}()
    setname = ""
    plotspec = nothing

    function dataset_completed()
        if length(dataset) > 0
            AllArraysAreNotEmpty = true
            for i in 1:length(dataset)
                if (typeof(dataset[i]) <: AbstractArray)  &&  (length(dataset[i]) == 0)
                    AllArraysAreNotEmpty = false
                    break
                end
            end
            if AllArraysAreNotEmpty
                name = newdataset(gp, dataset...; name=setname)
                if !isnothing(plotspec)
                    newplot(gp, name, plotspec)
                    gp.plots[gp.curmid].flag3d = flag3d
                end
            end
        end
        dataset = Vector{Any}()
        setname = ""
        plotspec = nothing
    end

    # Second pass
    for iarg in 1:length(args)
        arg = args[iarg]
        isa(arg, Symbol)  &&  continue  # already handled

        if isa(arg, Int)
            # Change current multiplot index
            @assert arg > 0
            #@info "Multiplot ID" iarg typeof(arg) arg
            plotspec = "" # use an empty plotspec for pending dataset
            dataset_completed()
            setmulti(gp, arg)
            gp.plots[gp.curmid].flag3d = flag3d
        elseif isa(arg, String)
            # Either a plotspec or a command
            arg = string(strip(arg))
            if length(dataset) > 0
                #@info "Plot spec." iarg typeof(arg) arg
                plotspec = arg
                dataset_completed()
            else
                (isPlot, is3d, cmd) = isPlotCmd(arg)
                if isPlot
                    #@info "Plot command" iarg typeof(arg) arg
                    gp.plots[gp.curmid].flag3d = is3d
                    newplot(gp, cmd)
                else
                    #@info "Command (string)" iarg typeof(arg) arg
                    newcmd(gp, arg)
                end
            end
        elseif isa(arg, Tuple)  &&  length(arg) == 2  &&  isa(arg[1], Symbol)
            #@info "Command (tuple)" iarg typeof(arg) arg
            newcmd(gp; [arg]...)
        elseif isa(arg, Pair)
            # A named dataset
            #@info "Named dataset" iarg typeof(arg) arg
            @assert typeof(arg[1]) == String
            @assert arg[1][1] == '$'
            setname = arg[1]
            for d in arg[2]
                push!(dataset, d)
            end
            dataset_completed()
        elseif isa(arg, Histogram1D)
            newcmd(gp, "set grid")
            push!(dataset, arg.bins)
            push!(dataset, arg.counts)
            plotspec = "w histep notit lw 2 lc rgb 'black'"
            dataset_completed()
        elseif isa(arg, Histogram2D)
            newcmd(gp, "set autoscale fix")
            push!(dataset, arg.bins1)
            push!(dataset, arg.bins2)
            push!(dataset, arg.counts)
            plotspec = "w image notit"
            dataset_completed()
        else
             # A dataset
            #@info "Dataset element" iarg typeof(arg) arg
            push!(dataset, arg)
        end
    end

    plotspec = ""
    dataset_completed()
    (doDump)  &&  (execall(gp))

    return nothing
end


#_____________________________________________________________________
#                         EXPORTED FUNCTIONS
#_____________________________________________________________________

# --------------------------------------------------------------------
"""
`@gp args...`

The `@gp` macro (and its companion `@gsp`, for `splot` operations) allows to exploit all of the **Gnuplot** package functionalities using an extremely efficient and concise syntax.  Both macros accept the same syntax, as described below.

The macros accepts any number of arguments, with the following meaning:
- a symbol: the name of the session to use;
- a string: a command (e.g. "set key left") or plot specification (e.g. "with lines");
- a string starting with a `\$` sign: a data set name;
- an `Int` > 0: the plot destination in a multiplot session;
- a keyword/value pair: a keyword value (see below);
- any other type: a dataset to be passed to Gnuplot.  Each dataset must be terminated by either:
  - a string starting with a `\$` sign (i.e. the data set name);
  - or a string with the plot specifications (e.g. "with lines");
- the `:-` symbol, used as first argument, avoids resetting the Gnuplot session.  Used as last argument avoids immediate execution  of the plot/splot command.  This symbol can be used to split a  single call into multiple ones.

All entries are optional, and there is no mandatory order.  The plot specification can either be:
 - a complete plot/splot command (e.g., "plot sin(x)", both "plot" and "splot" can be abbreviated to "p" and "s" respectively);
 - or a partial specification starting with the "with" clause (if it follows a data set).

The list of accepted keyword is as follows:
- `title::String`: plot title;
- `xlabel::String`: X axis label;
- `ylabel::String`: Y axis label;
- `zlabel::String`: Z axis label;
- `xlog::Bool`: logarithmic scale for X axis;
- `ylog::Bool`: logarithmic scale for Y axis;
- `zlog::Bool`: logarithmic scale for Z axis;
- `xrange::NTuple{2, Number}`: X axis range;
- `yrange::NTuple{2, Number}`: Y axis range;
- `zrange::NTuple{2, Number}`: Z axis range;
- `cbrange::NTuple{2, Number}`: Color box axis range;

The symbol for the above-mentioned keywords may also be used in a shortened form, as long as there is no ambiguity with other keywords.  E.g. you can use: `xr=(1,10)` in place of `xrange=(1,10)`.

# Examples:

## Simple examples with no data:
```
@gp "plot sin(x)"
@gp "plot sin(x)" "pl cos(x)"
@gp "plo sin(x)" "s cos(x)"

# Split a `@gp` call in two
@gp "plot sin(x)" :-
@gp :- "plot cos(x)"

# Insert a 3 second pause between one plot and the next
@gp "plot sin(x)" 2 xr=(-2pi,2pi) "pause 3" "plot cos(4*x)"
```

### Simple examples with data:
```
@gp "set key left" tit="My title" xr=(1,12) 1:10 "with lines tit 'Data'"

x = collect(1.:10)
@gp x
@gp x x
@gp x -x
@gp x x.^2
@gp x x.^2 "w l"

lw = 3
@gp x x.^2 "w l lw \$lw"
```

### A more complex example
```
@gp("set grid", "set key left", xlog=true, ylog=true,
    title="My title", xlab="X label", ylab="Y label",
    x, x.^0.5, "w l tit 'Pow 0.5' dt 2 lw 2 lc rgb 'red'",
    x, x     , "w l tit 'Pow 1'   dt 1 lw 3 lc rgb 'blue'",
    x, x.^2  , "w l tit 'Pow 2'   dt 3 lw 2 lc rgb 'purple'")
```

### Multiplot example:
```
@gp(xr=(-2pi,2pi), "unset key",
    "set multi layout 2,2 title 'Multiplot title'",
    1, "p sin(x)"  ,
    2, "p sin(2*x)",
    3, "p sin(3*x)",
    4, "p sin(4*x)")
```
or equivalently
```
@gp xr=(-2pi,2pi) "unset key" "set multi layout 2,2 title 'Multiplot title'" :-
for i in 1:4
  @gp :- i "p sin(\$i*x)" :-
end
@gp
```

### Multiple gnuplot sessions
```
@gp :GP1 "plot sin(x)"
@gp :GP2 "plot sin(x)"

Gnuplot.quitall()
```

### Further examples
```
x = range(-2pi, stop=2pi, length=100);
y = 1.5 * sin.(0.3 .+ 0.7x) ;
noise = randn(length(x))./2;
e = 0.5 * fill(1, size(x));

name = "\\\$MyDataSet1"
@gp x y name "plot \$name w l" "pl \$name u 1:(2*\\\$2) w l"

@gsp randn(Float64, 30, 50)
@gp randn(Float64, 30, 50) "w image"
@gsp x y y

@gp("set key horizontal", "set grid",
    xrange=(-7,7), ylabel="Y label",
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'")

@gp "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"   :-
@gp :- x y+noise e name                               :-
@gp :- "fit f(x) \$name u 1:2:3 via a, b, c;"         :-
@gp :- "set multiplot layout 2,1"                     :-
@gp :- "plot \$name w points" ylab="Data and model"   :-
@gp :- "plot \$name u 1:(f(\\\$1)) w lines"           :-
@gp :- 2 xlab="X label" ylab="Residuals"              :-
@gp :- "plot \$name u 1:((f(\\\$1)-\\\$2) / \\\$3):(1) w errorbars notit"

# Retrieve values for a, b and c
a = Meta.parse(Gnuplot.exec("print a"))
b = Meta.parse(Gnuplot.exec("print b"))
c = Meta.parse(Gnuplot.exec("print c"))

# Save to a PDF file
save(term="pdf", output="gnuplot.pdf")
```

### Display an image
```
using TestImages
img = testimage("lena");
@gp img "w image"
@gp "set size square" img "w rgbimage" # Color image with correct proportions
@gp "set size square" img "u 2:(-\\\$1):3:4:5 with rgbimage" # Correct orientation
```
"""
macro gp(args...)
    out = Expr(:call)
    push!(out.args, :(Gnuplot.driver))
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
  # @gsp

  See documentation for `@gp`.
"""
macro gsp(args...)
    out = Expr(:macrocall, Symbol("@gp"), LineNumberNode(1, nothing))
    push!(out.args, args...)
    push!(out.args, Expr(:kw, :flag3d, true))
    return esc(out)
end


# ╭───────────────────────────────────────────────────────────────────╮
# │              FUNCTIONS MEANT TO BE INVOKED BY USERS               │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
"""
  `quit()`

  Quit the session and the associated gnuplot process (if any).
"""
function quit(sid::Symbol)
    (sid in keys(sessions))  ||  (return 0)
    return quit(sessions[sid])
end

"""
  `quitall()`

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
`exec(sid::Symbol, s::Vector{String})`

Directly execute commands on the underlying Gnuplot process, and return the result(s).

## Examples:
```julia
exec("print GPVAL_TERM")
exec("plot sin(x)")
```
"""
exec(gp::DrySession, command::String) = nothing
function exec(gp::GPSession, command::String)
    answer = Vector{String}()
    push!(answer, writeread(gp, command)...)

    verbose = options.verbose
    options.verbose = false
    errno = writeread(gp, "print GPVAL_ERRNO")[1]
    options.verbose = verbose

    if errno != "0"
        printstyled(color=:red, "GNUPLOT ERROR $(gp.sid) -> ERRNO=$errno\n")
        errmsg = writeread(gp, "print GPVAL_ERRMSG")
        write(gp.pin, "reset error\n")
        for line in errmsg
            printstyled(color=:red, "GNUPLOT ERROR $(gp.sid) -> $line\n")
        end
        error("Gnuplot process raised an error: $errmsg")
    end

    return join(answer, "\n")
end
exec(sid::Symbol, s::String) = exec(getsession(sid), s)
exec(s::String) = exec(getsession(), s)


# --------------------------------------------------------------------
"""
`setverbose(b::Bool)`

Set verbose flag to `true` or `false` (default: `false`).
"""
function setverbose(b::Bool)
    options.verbose = b
end


# --------------------------------------------------------------------
"""
`save(...)`

Save the data and commands in the current session to either:
- the gnuplot process (i.e. produce a plot): `save(term="", output="")`;
- an IO stream: `save(stream::IO; term="", output="")`;
- a file: `save(file::AbstractStrings; term="", output="")`.

To save the data and command from a specific session pass the ID as first argument, i.e.:
- `save(sid::Symbol, term="", output="")`;
- `save(sid::Symbol, file::AbstractStrings; term="", output="")`.

In all cases the `term` keyword allows to specify a gnuplot terminal, and the `output` keyword allows to specify an output file.
"""
save(           ; kw...) = execall(getsession()   ; kw...)
save(sid::Symbol; kw...) = execall(getsession(sid); kw...)
save(             file::AbstractString; kw...) = savescript(getsession()   , file, kw...)
save(sid::Symbol, file::AbstractString; kw...) = savescript(getsession(sid), file, kw...)


# ╭───────────────────────────────────────────────────────────────────╮
# │                     HIGH LEVEL FACILITIES                         │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
linestyles(s::Symbol) = linestyles(colorschemes[s])
function linestyles(cmap::ColorScheme)
    styles = Vector{String}()
    for i in 1:length(cmap.colors)
        push!(styles, "set style line $i lt 1 lc rgb '#" * Base.hex(cmap.colors[i]))
    end
    return join(styles, "\n")
end

# --------------------------------------------------------------------
palette(s::Symbol) = palette(colorschemes[s])
function palette(cmap::ColorScheme)
    levels = Vector{String}()
    for x in LinRange(0, 1, length(cmap.colors))
        color = get(cmap, x)
        push!(levels, "$x '#" * Base.hex(color) * "'")
    end
    return "set palette defined (" * join(levels, ", ") * ")\nset palette maxcol $(length(cmap.colors))\n"
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                     EXPERIMENTAL FUNCTIONS                        │
# ╰───────────────────────────────────────────────────────────────────╯
# # --------------------------------------------------------------------
# """
#   # repl
#
#   Read/evaluate/print/loop
# """
# function repl(sid::Symbol)
#     verb = options.verbose
#     options.verbose = 0
#     gp = getsession(sid)
#     while true
#         line = readline(stdin)
#         (line == "")  &&  break
#         answer = send(gp, line, true)
#         for line in answer
#             println(line)
#         end
#     end
#     options.verbose = verb
#     return nothing
# end
# function repl()
#     return repl(options.default)
# end

# --------------------------------------------------------------------
#=
Example:
v = randn(1000)
h = hist(v, bs=0.5)
@gp h  # preview
@gp h.bins h.counts "w histep" h.bins h.counts "w l"
=#

mutable struct Histogram1D
    bins::Vector{Float64}
    counts::Vector{Float64}
    binsize::Float64
end

mutable struct Histogram2D
    bins1::Vector{Float64}
    bins2::Vector{Float64}
    counts::Matrix{Float64}
    binsize1::Float64
    binsize2::Float64
end


function hist(v::Vector{T}; range=[NaN,NaN], bs=NaN, nbins=0, pad=true) where T <: Number
    i = findall(isfinite.(v))
    isnan(range[1])  &&  (range[1] = minimum(v[i]))
    isnan(range[2])  &&  (range[2] = maximum(v[i]))
    i = findall(isfinite.(v)  .&  (v.>= range[1])  .&  (v.<= range[2]))
    (nbins > 0)  &&  (bs = (range[2] - range[1]) / nbins)
    if isfinite(bs)
        rr = range[1]:bs:range[2]
        if maximum(rr) < range[2]
            rr = range[1]:bs:(range[2]+bs)
        end
        hh = fit(Histogram, v[i], rr, closed=:left)
        if sum(hh.weights) < length(i)
            j = findall(v[i] .== range[2])
            @assert length(j) == (length(i) - sum(hh.weights))
            hh.weights[end] += length(j)
        end
    else
        hh = fit(Histogram, v[i], closed=:left)
    end
    @assert sum(hh.weights) == length(i)
    x = collect(hh.edges[1])
    x = (x[1:end-1] .+ x[2:end]) ./ 2
    h = hh.weights
    binsize = x[2] - x[1]
    if pad
        x = [x[1]-binsize, x..., x[end]+binsize]
        h = [0, h..., 0]
    end
    return Histogram1D(x, h, binsize)
end


# --------------------------------------------------------------------
function hist(v1::Vector{T1}, v2::Vector{T2};
              range1=[NaN,NaN], bs1=NaN, nbins1=0,
              range2=[NaN,NaN], bs2=NaN, nbins2=0) where {T1 <: Number, T2 <: Number}
    @assert length(v1) == length(v2)
    i = findall(isfinite.(v1)  .&  isfinite.(v2))
    isnan(range1[1])  &&  (range1[1] = minimum(v1[i]))
    isnan(range1[2])  &&  (range1[2] = maximum(v1[i]))
    isnan(range2[1])  &&  (range2[1] = minimum(v2[i]))
    isnan(range2[2])  &&  (range2[2] = maximum(v2[i]))

    i = findall(isfinite.(v1)  .&  (v1.>= range1[1])  .&  (v1.<= range1[2])  .&
                 isfinite.(v2)  .&  (v2.>= range2[1])  .&  (v2.<= range2[2]))
    (nbins1 > 0)  &&  (bs1 = (range1[2] - range1[1]) / nbins1)
    (nbins2 > 0)  &&  (bs2 = (range2[2] - range2[1]) / nbins2)
    if isfinite(bs1) &&  isfinite(bs2)
        hh = fit(Histogram, (v1[i], v2[i]), (range1[1]:bs1:range1[2], range2[1]:bs2:range2[2]), closed=:left)
    else
        hh = fit(Histogram, (v1[i], v2[i]), closed=:left)
    end
    x1 = collect(hh.edges[1])
    x1 = (x1[1:end-1] .+ x1[2:end]) ./ 2
    x2 = collect(hh.edges[2])
    x2 = (x2[1:end-1] .+ x2[2:end]) ./ 2

    binsize1 = x1[2] - x1[1]
    binsize2 = x2[2] - x2[1]
    return Histogram2D(x1, x2, hh.weights, binsize1, binsize2)
end


# --------------------------------------------------------------------
mutable struct ContourLine
    level::Int
    x::Vector{Float64}
    y::Vector{Float64}
    z::Float64
    ContourLine(z) = new(1, Vector{Float64}(), Vector{Float64}(), z)
end

mutable struct IsoContourLines
    lines::Vector{ContourLine}
    paths::Vector{String}
    z::Float64
    function IsoContourLines(lines::Vector{ContourLine})
        z = unique(getfield.(lines, :z))
        @assert length(z) == 1
        paths = Vector{String}()
        for i in 1:length(lines)
            append!(paths, data2string(lines[i].x, lines[i].y))
            push!(paths, "")
        end
        return new(lines, paths, z[1])
    end
end

function contourlines(args...; cntrparam="level auto 10")
    tmpfile = Base.Filesystem.tempname()
    sid = Symbol("j", Base.Libc.getpid())
    if !haskey(Gnuplot.sessions, sid)
        gp = getsession(sid)
    end

    Gnuplot.exec(sid, "set term unknown")
    @gsp    sid "set contour base" "unset surface" :-
    @gsp :- sid "set cntrparam $cntrparam" :-
    @gsp :- sid "set table '$tmpfile'" :-
    @gsp :- sid args...
    Gnuplot.exec(sid, "unset table")
    Gnuplot.exec(sid, "reset")

    cur = ContourLine(NaN)
    lines = Vector{ContourLine}()
    for l in readlines(tmpfile)
        l = strip(l)
        if l == ""
            (length(cur.x) > 2)  &&  push!(lines, cur)
            cur = ContourLine(cur.z)
            continue
        end
        if !isnothing(findfirst("# Contour ", l))
            (length(cur.x) > 2)  &&  push!(lines, cur)
            cur = ContourLine(Meta.parse(strip(split(l, ':')[2])))
            continue
        end
        (l[1] == '#')  &&  continue

        n = Meta.parse.(split(l))
        @assert length(n) == 3
        push!(cur.x, n[1])
        push!(cur.y, n[2])
    end
    (length(cur.x) > 2)  &&  push!(lines, cur)
    rm(tmpfile)
    @assert length(lines) > 0
    lines = lines[sortperm(getfield.(lines, :z))]

    out = Vector{IsoContourLines}()
    for z in unique(getfield.(lines, :z))
        i = findall(getfield.(lines, :z) .== z)
        push!(out, IsoContourLines(lines[i]))
    end
    return out
end


# --------------------------------------------------------------------
function boxxyerror(x, y; xmin=NaN, ymin=NaN, xmax=NaN, ymax=NaN, cartesian=false)
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
        return (x, y, xlow, xhigh, ylow, yhigh)
    end
    i = repeat(1:length(x), outer=length(y))
    j = repeat(1:length(y), inner=length(x))
    return (x[i], y[j], xlow[i], xhigh[i], ylow[j], yhigh[j])
end


# --------------------------------------------------------------------
function histo2segments(in_x, counts)
    @assert length(in_x) == length(counts)
    x = Vector{Float64}()
    y = Vector{Float64}()
    push!(x, in_x[1])
    push!(y, counts[1])
    for i in 2:length(in_x)
        xx = (in_x[i-1] + in_x[i]) / 2.
        push!(x, xx)
        push!(y, counts[i-1])
        push!(x, xx)
        push!(y, counts[i])
    end
    push!(x, in_x[end])
    push!(y, counts[end])
    return (x, y)
end


# --------------------------------------------------------------------
terminals() = split(exec("print GPVAL_TERMINALS"), " ")
terminal() = exec("print GPVAL_TERM") * " " * exec("print GPVAL_TERMOPTIONS")

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
            exec(gp, "set term wxt  noenhanced size 600,300")
        elseif "qt" in terms
            exec(gp, "set term qt   noenhanced size 600,300")
        elseif "aqua" in terms
            exec(gp, "set term aqua noenhanced size 600,300")
        else
            @warn "None of the `wxt`, `qt` and `aqua` terminals are available.  Output may look strange.."
        end
    else
        exec(gp, "set term unknown")
    end
    @gp :- :splash "set margin 0"  "set border 0" "unset tics"
    @gp :- :splash xr=[-0.3,1.7] yr=[-0.3,1.1]
    @gp :- :splash "set origin 0,0" "set size 1,1"
    @gp :- :splash "set label 1 at graph 1,1 right font 'Verdana,20' tc rgb '#4d64ae' ' Ver: " * string(version()) * "' "
    @gp :- :splash "set arrow 1 from graph 0.05, 0.15 to graph 0.95, 0.15 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'"
    @gp :- :splash "set arrow 2 from graph 0.15, 0.05 to graph 0.15, 0.95 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'"
    @gp :- :splash ["0.35 0.65 @ 13253682'", "0.85 0.65 g 3774278", "1.3 0.65 p 9591203"] "w labels notit font 'Mono,160' tc rgb var"
    (outputfile == "")  ||  save(:splash, term="pngcairo transparent noenhanced size 600,300", output=outputfile)
    nothing
end

end #module
