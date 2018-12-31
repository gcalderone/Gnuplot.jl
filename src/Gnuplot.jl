__precompile__(true)

module Gnuplot

using StructC14N, ColorTypes, Printf, StatsBase

import Base.reset
import Base.write
import Base.iterate
import Base.convert

export gnuplot, quit, quitall,
    hist, @gp, @gsp, gpeval


#_____________________________________________________________________
#                         MACRO DEFINITIONS
#_____________________________________________________________________

# --------------------------------------------------------------------
macro inherit_fields(T)
    out = Expr(:block)
    for name in fieldnames(eval(T))
        e = Expr(Symbol("::"))
        push!(e.args, name)
        push!(e.args, fieldtype(eval(T), name))
        push!(out.args, e)
    end
    return esc(out)
end


#_____________________________________________________________________
#                          TYPE DEFINITIONS
#_____________________________________________________________________

# --------------------------------------------------------------------
abstract type ○DataSource end
mutable struct DataSource <: ○DataSource
    name::String
    lines::Vector{String}
end


# --------------------------------------------------------------------
abstract type ○SinglePlot end
mutable struct SinglePlot <: ○SinglePlot
    cmds::Vector{String}
    elems::Vector{String}
    flag3d::Bool
    SinglePlot() = new(Vector{String}(), Vector{String}(), false)
end


# --------------------------------------------------------------------
abstract type ○Session end
mutable struct Session <: ○Session
    sid::Symbol                # session ID
    datas::Vector{DataSource}  # data sources
    plots::Vector{SinglePlot}  # commands and plot commands (one entry for eahelemec plot of the multiplot)
    curmid::Int                # current multiplot ID
end


# --------------------------------------------------------------------
abstract type ○Process <: ○Session end
mutable struct Process <: ○Process
    @inherit_fields(Session)
    pin::Base.Pipe;
    pout::Base.Pipe;
    perr::Base.Pipe;
    proc::Base.Process;
    channel::Channel{String};
end


# --------------------------------------------------------------------
abstract type ○State end
mutable struct State <: ○State
    sessions::Dict{Symbol, ○Session};
    default::Symbol;        # default session name
    verbosity::Bool;        # verbosity level (0 - 1), default: 1
    printlines::Int;        # How many data lines are printed in log
    State() = new(Dict{Symbol, ○Session}(), :default, 1, 4)
end
const state = State()


# --------------------------------------------------------------------
abstract type ○PackedDataAndCmds end
mutable struct PackedDataAndCmds <: ○PackedDataAndCmds
    data::Vector{Any}
    name::String
    cmds::Vector{String}
    plot::Vector{String}
end


#_____________________________________________________________________
#                 "PRIVATE" (NON-EXPORTED) FUNCTIONS
#_____________________________________________________________________

# --------------------------------------------------------------------
"""
  # CheckGnuplotVersion

  Check whether gnuplot is runnable with the command given in `cmd`.
  Also check that gnuplot version is >= 4.7 (required to use data
  blocks).
"""
function CheckGnuplotVersion(cmd::String)
    icmd = `$(cmd) --version`

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
        # Do not raise error in order to pass Travis CI test, since it has v4.6
        @warn "gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found."
    end
    if ver < v"4.6"
        error("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    @info "  Gnuplot version: " * string(ver)
    return ver
end
    

# --------------------------------------------------------------------
function parseKeywords(; kwargs...)
    template = (xrange=NTuple{2, Number},
                yrange=NTuple{2, Number},
                zrange=NTuple{2, Number},
                cbrange=NTuple{2, Number},
                title=String,
                xlabel=String,
                ylabel=String,
                zlabel=String,
                xlog=Bool,
                ylog=Bool,
                zlog=Bool)

    kw = canonicalize(template; kwargs...)
    out = Vector{String}()
    ismissing(kw.xrange ) || (push!(out, "set xrange  [" * join(kw.xrange , ":") * "]"))
    ismissing(kw.yrange ) || (push!(out, "set yrange  [" * join(kw.yrange , ":") * "]"))
    ismissing(kw.zrange ) || (push!(out, "set zrange  [" * join(kw.zrange , ":") * "]"))
    ismissing(kw.cbrange) || (push!(out, "set cbrange [" * join(kw.cbrange, ":") * "]"))
    ismissing(kw.title  ) || (push!(out, "set title  '" * kw.title  * "'"))
    ismissing(kw.xlabel ) || (push!(out, "set xlabel '" * kw.xlabel * "'"))
    ismissing(kw.ylabel ) || (push!(out, "set ylabel '" * kw.ylabel * "'"))
    ismissing(kw.zlabel ) || (push!(out, "set zlabel '" * kw.zlabel * "'"))
    ismissing(kw.xlog   ) || (push!(out, (kw.xlog  ?  ""  :  "un") * "set logscale x"))
    ismissing(kw.ylog   ) || (push!(out, (kw.ylog  ?  ""  :  "un") * "set logscale y"))
    ismissing(kw.zlog   ) || (push!(out, (kw.zlog  ?  ""  :  "un") * "set logscale z"))
    return out
end


# --------------------------------------------------------------------
function Session(sid::Symbol)
    global state
    (sid in keys(state.sessions))  &&
        error("Gnuplot session $sid is already active")
    out = Session(sid, Vector{DataSource}(), [SinglePlot()], 1)
    return out
end


# --------------------------------------------------------------------
function getsession(sid::Symbol)
    global state
    if !(sid in keys(state.sessions))
        @info "Creating session $sid..."
        gnuplot(sid)
    end
    return state.sessions[sid]
end
function getsession()
    global state
    return getsession(state.default)
end


# --------------------------------------------------------------------
"""
  # write

  Send a string to gnuplot's STDIN.

  The commands sent through `send` are not stored in the current
  session (use `newcmd` to save commands in the current session).

  ## Arguments:
  - `gp`: a `Session` object;
  - `str::String`: command to be sent;
  - `capture=false`: set to `true` to capture and return the output.
"""
write(gp::Session, str::AbstractString) = nothing
function write(gp::Process, str::AbstractString)
    global state
    if state.verbosity
        printstyled(color=:yellow     , "GNUPLOT ($(gp.sid)) $str\n")
    end
    w = write(gp.pin, strip(str) * "\n")
    w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    #flush(gp.pin)
    return w
end

# --------------------------------------------------------------------
writeread(gp::Session, str::AbstractString) = nothing
function writeread(gp::Process, str::AbstractString)
    global state
    write(gp, "print 'GNUPLOT_CAPTURE_BEGIN'")
    write(gp, strip(str))
    write(gp, "print 'GNUPLOT_CAPTURE_END'")
    flush(gp.pin)
    out = Vector{String}()
    while true
        l = take!(gp.channel)
        l == "GNUPLOT_CAPTURE_END"  &&  break
        push!(out, l)
    end
    return out
end


# --------------------------------------------------------------------
setWindowTitle(session::Session) = nothing
function setWindowTitle(session::Process)
    term = writeread(session, "print GPVAL_TERM")[1]
    if term in ("aqua", "x11", "qt", "wxt")
        opts = writeread(session, "print GPVAL_TERMOPTIONS")[1]
        if findfirst("title", opts) == nothing
            write(session, "set term $term $opts title 'Gnuplot.jl: $(session.sid)'")
        end
    end
end


# --------------------------------------------------------------------
function reset(gp::○Session)
    gp.datas = Vector{DataSource}()
    gp.plots = [SinglePlot()]
    gp.curmid = 1
    write(gp, "reset session")
    setWindowTitle(gp)
    return nothing
end


# --------------------------------------------------------------------
function setmulti(gp::○Session, mid::Int)
    @assert mid >= 0 "Multiplot ID must be a >= 0"
    for i in length(gp.plots)+1:mid
        push!(gp.plots, SinglePlot())
    end
    (mid > 0)  &&  (gp.curmid = mid)
end


# --------------------------------------------------------------------
function newdatasource(gp::○Session, args...; name="")
    toString(n::Number) = @sprintf("%.4g", n)

    (name == "")  &&  (name = string("data", length(gp.datas)))
    name = "\$$name"

    # Check dimensions
    maxDim = 0
    for iarg in 1:length(args)
        d = args[iarg]

        ok = false
        if typeof(d) <: Number
            ok = true
        elseif typeof(d) <: AbstractArray
            if typeof(d[1]) <: Number
                ok = true
            end
            if typeof(d[1]) <: ColorTypes.RGB
                ok = true
            end
        end
        if ndims(d) > maxDim
            maxDim = ndims(d)
        end

        @assert ok "Invalid argument at position $iarg"
        @assert maxDim <= 3 "Array dimensions must be <= 3"
    end

    dimX = 0
    dimY = 0
    dimZ = 0
    count1D = 0
    for iarg in 1:length(args)
        d = args[iarg]
        if ndims(d) == 0
            @assert maxDim == 0 "Input data are ambiguous: use use all scalar floats or arrays of floats"
        elseif ndims(d) == 1
            count1D += 1
            if maxDim == 1
                (iarg == 1)  &&  (dimX = length(d))
                @assert dimX == length(d) "Array size are incompatible"
            else
                (iarg == 1)  &&  (dimX = length(d))
                (maxDim == 2)  &&  (iarg == 2)  &&  (dimY = length(d))
                (maxDim == 3)  &&  (iarg == 3)  &&  (dimZ = length(d))
                @assert iarg <= maxDim "2D and 3D data must be given at the end of argument list"
            end
        elseif ndims(d) == 2
            if iarg == 1
                dimX = (size(d))[1]
                dimY = (size(d))[2]
            end
            @assert dimX == (size(d))[1] "Array size are incompatible"
            @assert dimY == (size(d))[2] "Array size are incompatible"
            @assert dimZ == 0 "Mixing 2D and 3D data is not allowed"
        elseif ndims(d) == 3
            if iarg == 1
                dimX = (size(d))[1]
                dimY = (size(d))[2]
                dimZ = (size(d))[3]
            end
            @assert dimX == (size(d))[1] "Array size are incompatible"
            @assert dimY == (size(d))[2] "Array size are incompatible"
            @assert dimZ == (size(d))[3] "Array size are incompatible"
        end
    end
    if (dimZ > 0)  &&  (count1D != 0)  &&  (count1D != 3)
        error("Either zero or three 1D arrays must be given before 3D data")
    elseif (dimY > 0)  &&  (count1D != 0)  &&  (count1D != 2)
        error("Either zero or two 1D arrays must be given before 2D data")
    end

    # Prepare data
    accum = Vector{String}()
    v = "$name << EOD"
    push!(accum, v)

    if dimZ > 0 # 3D
        for ix in 1:dimX
            for iy in 1:dimY
                for iz in 1:dimZ
                    if count1D == 0
                        v = string(ix) * " " * string(iy) * " " * string(iz)
                    else
                        v = string(args[1][ix]) * " " * string(args[2][iy]) * " " * string(args[3][iz])
                    end
                    for iarg in count1D+1:length(args)
                        d = args[iarg]
                        v *= " " * string(d[ix,iy,iz])
                    end
                    push!(accum, v)
                end
            end
            push!(accum, "")
        end
    elseif dimY > 0  # 2D
        for ix in 1:dimX
            for iy in 1:dimY
                if count1D == 0
                    v = string(ix) * " " * string(iy)
                else
                    v = string(args[1][ix]) * " " * string(args[2][iy])
                end
                for iarg in count1D+1:length(args)
                    d = args[iarg]
                    if typeof(d[ix,iy]) <: ColorTypes.RGB
                        tmp = d[ix,iy]
                        v *= " " * string(float(tmp.r)*255) * " " * string(float(tmp.g)*255) * " " * string(float(tmp.b)*255)
                    else
                        v *= " " * toString(d[ix,iy])
                    end
                end
                push!(accum, v)
            end
            push!(accum, "")
        end
    elseif dimX > 0  # 1D
        for ix in 1:dimX
            v = ""
            for iarg in 1:length(args)
                d = args[iarg]
                v *= " " * string(d[ix])
            end
            push!(accum, v)
        end
    else # scalars
        v = ""
        for iarg in 1:length(args)
            d = args[iarg]
            v *= " " * string(d)
        end
        push!(accum, v)
    end

    push!(accum, "EOD")
    tmp = DataSource(name, accum)
    push!(gp.datas, tmp)
    dump(gp, tmp)
    return name
end


# --------------------------------------------------------------------
"""
  # newcmd

  Send a command to gnuplot process and store it in the current session.
"""
function newcmd(gp::○Session, v::String; mid::Int=0)
    setmulti(gp, mid)
    (v != "")  &&  (push!(gp.plots[gp.curmid].cmds, v))
    (length(gp.plots) == 1)  &&  (write(gp, v))
    return nothing
end

function newcmd(gp::○Session; mid::Int=0, args...)
    for v in parseKeywords(;args...)
        newcmd(gp, v, mid=mid)
    end
    return nothing
end


# --------------------------------------------------------------------
function newplotelem(gp::○Session, name, opt=""; mid=0)
    setmulti(gp, mid)
    push!(gp.plots[gp.curmid].elems, "$name $opt")
end


# --------------------------------------------------------------------
function quitsession(gp::○Session) 
    global state
    delete!(state.sessions, gp.sid)
    return 0
end

function quitsession(gp::○Process) 
    close(gp.pin)
    close(gp.pout)
    close(gp.perr)
    wait( gp.proc)
    exitCode = gp.proc.exitcode
    invoke(quitsession, Tuple{○Session}, gp)
    return exitCode
end


# --------------------------------------------------------------------
iterate(gp::○Session) = ("#ID: $(gp.sid)", (true, 1, 1))
function iterate(gp::○Session, state)
    (onData, mid, ii) = state
    if onData
        if mid <= length(gp.datas)
            if ii <= length(gp.datas[mid].lines)
                return (gp.datas[mid].lines[ii], (true, mid, ii+1))
            end
            return iterate(gp, (true, mid+1, 1))
        end
        return ("", (false, 1, 1))
    end

    if mid <= length(gp.plots)
        if ii <= length(gp.plots[mid].cmds)
            return (gp.plots[mid].cmds[ii], (false, mid, ii+1))
        end
        s = (gp.plots[mid].flag3d  ?  "splot "  :  "plot ") * " \\\n  " *
            join(gp.plots[mid].elems, ", \\\n  ")
        return (s, (false, mid+1, 1))
    end

    if mid == length(gp.plots)+1
        s = ""
        (length(gp.plots) > 1)  &&  (s *= "unset multiplot;")
        return (s, (false, mid+1, 1))
    end
    
    return nothing
end


# --------------------------------------------------------------------
# dump
#
# Dump all data/commands in a session into one of the selected recipient(s)
#
function convert(::Type{Vector{String}}, gp::○Session)
    out = Vector{String}()
    for l in gp
        push!(out, l)
    end
    return out
end


dump(gp::○Session, d::○DataSource) = nothing
function dump(gp::○Process, d::○DataSource)
    global state
    if state.verbosity
        for ii in 1:length(d.lines)
            v = d.lines[ii]
            printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) $v\n")
            if ii == state.printlines
                printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) ...\n")
                if ii < length(d.lines)
                    v = d.lines[end]
                    printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) $v\n")
                end
                break
            end
        end
    end
    w = write(gp.pin, "\n")
    w = write(gp.pin, join(d.lines, "\n"))
    w = write(gp.pin, "\n")
    w = write(gp.pin, "\n")
    flush(gp.pin)
end

dump(gp::○Session; term=("", "")) = nothing
dump(sid::Symbol ; term=("", "")) = dump(getsession(sid), term=term)
dump(            ; term=("", "")) = dump(getsession()   , term=term)
function dump(gp::○Process; term=("", ""))
    if term[1] != ""
        write(gp, "set term $(term[1])")
        write(gp, "set output '$(term[2])'")
    end

    i = (false, 1, 1) # Skip data sources
    while (next = iterate(gp, i)) != nothing
        (s, i) = next
        write(gp, s)
    end

    if term[1] != ""
        write(gp, "set output")
    end
end


dump(sid::Symbol, f::IO; term=("", "")) = dump(getsession(sid), f, term=term)
dump(             f::IO; term=("", "")) = dump(getsession()   , f, term=term)
function dump(gp::○Session, f::IO; term=("", ""))
    if term[1] != ""
        println(f, "set term $(term[1])")
        println(f, "set output '$(term[2])'")
    end

    for l in gp
        println(f, l)
    end
    
    if term[1] != ""
        println(f, "set output")
    end
end


dump(sid::Symbol, file::AbstractString; term=("", "")) = dump(getsession(sid), file, term=term)
dump(             file::AbstractString; term=("", "")) = dump(getsession()   , file, term=term)
function dump(gp::○Session, file::AbstractString; term=("", ""))
    f = open(file, "w")
    dump(gp, f, term=term)
    close(f) 
end


# --------------------------------------------------------------------
function driver(args...; flag3d=false)
    if length(args) == 0
        gp = getsession()
        dump(gp)
        return nothing
    end

    data = Vector{Any}()
    dataname = ""
    dataplot = nothing

    function dataCompleted()
        if length(data) > 0
            last = newdatasource(gp, data...; name=dataname)
            (dataplot != nothing)  &&  (newplotelem(gp, last, dataplot))
        end
        data = Vector{Any}()
        dataname = ""
        dataplot = nothing
    end
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

    gp = nothing
    term = ("", "")
    doDump  = true
    doReset = true

    for loop in 1:2
        if loop == 2
            (gp == nothing)  &&  (gp = getsession())
            doReset  &&  reset(gp)
            gp.plots[gp.curmid].flag3d = flag3d
        end

        for iarg in 1:length(args)
            arg = args[iarg]

            if typeof(arg) == Symbol
                if arg == :-
                    (loop == 1)  &&  (iarg < length(args)) &&  (doReset = false)
                    (loop == 1)  &&  (iarg >  1)           &&  (doDump  = false)
                else
                    (loop == 1)  &&  (gp = getsession(arg))
                end
            elseif isa(arg, Tuple)  &&  length(arg) == 2  &&  isa(arg[1], Symbol)
                if arg[1] == :term
                    if loop == 1
                        if typeof(arg[2]) == String
                            term = (deepcopy(arg[2]), "")
                        elseif length(arg[2]) == 2
                            term = deepcopy(arg[2])
                        else
                            error("The term tuple must contain at most two strings")
                        end
                    end
                #elseif arg[1] == :verb
                #    (loop == 1)  &&  (state.verbosity = arg[2])
                else
                    (loop == 2)  &&  newcmd(gp; [arg]...) # A cmd keyword
                end
            elseif isa(arg, Int)
                (loop == 2)  &&  (@assert arg > 0)
                (loop == 2)  &&  (dataplot = ""; dataCompleted())
                (loop == 2)  &&  setmulti(gp, arg)
            elseif isa(arg, String)
                # Either a dataname, a plot or a command
                if loop == 2
                    if arg[1] == '$'
                        dataname = arg[2:end]
                        dataCompleted()
                    elseif length(data) > 0
                        dataplot = arg
                        dataCompleted()
                    else
                        (isPlot, flag3d, cmd) = isPlotCmd(arg)
                        if isPlot
                            gp.plots[gp.curmid].flag3d = flag3d
                            newplotelem(gp, cmd)
                        else
                            newcmd(gp, arg)
                        end
                    end
                end
            elseif typeof(arg) == PackedDataAndCmds
                if loop == 2
                    last = newdatasource(gp, arg.data..., name=arg.name)
                    for v in arg.cmds;  newcmd(gp, v); end
                    for v in arg.plot; newplotelem(gp, last, v); end
                end
            else
                (loop == 2)  &&  push!(data, arg) # a data set
            end
        end
    end

    dataplot = ""
    dataCompleted()
    (doDump)  &&  (dump(gp)) # ; term=term))

    return nothing
end


#_____________________________________________________________________
#                         EXPORTED FUNCTIONS
#_____________________________________________________________________

# --------------------------------------------------------------------
"""
  # gnuplot

  Initialize a new session and (optionally) the associated Gnuplot process

  ## Arguments:
  - `sid`: the session name (a Julia symbol);

  ## Optional keywords:
  - `dry`: a boolean specifying whether the session should be a *dry* one, i.e. with no underlying gnuplot process (`default false`);

  - `cmd`: a string specifying the complete file path to a gnuplot executable (default="gnuplot").
"""
function gnuplot(sid::Symbol; dry=false, cmd="gnuplot")
    function readTask(sid, stream, channel)
        global state
        saveOutput = false

        while isopen(stream)
            line = convert(String, readline(stream))
            if line == "GNUPLOT_CAPTURE_BEGIN"
                saveOutput = true
            else
                (saveOutput)  &&  (put!(channel, line))
                if line == "GNUPLOT_CAPTURE_END"
                    saveOutput = false
                elseif line != ""
                    printstyled(color=:cyan, "GNUPLOT ($sid) -> $line\n")
                    #(state.verbosity >= 1)  &&  (printstyled(color=:cyan, "GNUPLOT ($sid) -> $line\n"))
                end
            end
        end
        global state
        delete!(state.sessions, sid)
        return nothing
    end

    global state

    if !dry
        CheckGnuplotVersion(cmd)
        session = Session(sid)

        pin  = Base.Pipe()
        pout = Base.Pipe()
        perr = Base.Pipe()
        proc = run(pipeline(`$cmd`, stdin=pin, stdout=pout, stderr=perr), wait=false)
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

        out = Process(getfield.(Ref(session), fieldnames(Session))..., pin, pout, perr, proc, chan)
    else
        out = Session(sid)
    end
    state.sessions[sid] = out

    (!dry)  &&  (setWindowTitle(out))
    return out
end

function gnuplot(;args...)
    global state
    return gnuplot(state.default, args...)
end


# --------------------------------------------------------------------
"""
  # quit

  Quit the session and the associated gnuplot process (if any).
"""
function quit(sid::Symbol)
    global state
    if !(sid in keys(state.sessions))
        error("Gnuplot session $sid do not exists")
    end
    return quitsession(state.sessions[sid])
end

"""
  # quitall

  Quit all the sessions and the associated gnuplot processes.
"""
function quitall()
    global state
    for sid in keys(state.sessions)
        quit(sid)
    end
    return nothing
end



# --------------------------------------------------------------------
"""
# @gp

The `@gp` macro, and its companion `@gsp` (for `splot` operations)
allows to exploit all of the **Gnuplot** package functionalities
using an extremely efficient and concise syntax.  Both macros accept
the same syntax, described below:

The macros accepts any number of arguments, with the following
meaning:

- a symbol: the name of the session to use;
- a string: a command (e.g. "set key left") or plot specification
  (e.g. "with lines");
- a string starting with a `\$` sign: specifies a data set name;
- an `Int` > 0: set the current plot destination (if multiplot is
  enabled);
- a keyword: set the keyword value (see below);
- any other type: a dataset to be passed to Gnuplot.  Each dataset
  must be terminated by either: a string starting with a `\$` sign
  (i.e. the data set name) or a string with the plot specifications
  (e.g. "with lines");
- the `:-` symbol, used as first argument, avoids resetting the
  Gnuplot session.  Used as last argument avoids immediate execution
  of the plot/splot command.  This symbol can be used to split a
  single call into multiple ones.

All entries are optional, and there is no mandatory order.  The plot
specification can either be: a complete plot/splot command (e.g.,
"plot sin(x)", both "plot" and "splot" can be abbreviated to "p" and
"s" respectively), or a partial specification starting with the
"with" clause (if it follows a data set).

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

The symbol for the above-mentioned keywords may also be used in a
shortened form, as long as there is no ambiguity with other
keywords.  E.g. you can use: `xr=(1,10)` in place of
`xrange=(1,10)`.

Beside the above-mentioned keyword the following can also be used
(although with no symbol shortening):

- `verb`: 0 or 1, to set the verbosity level;
- `file`: send all the data and command to a file rather than
  to a Gnuplot process;
- `stream`: send all the data and command to a stream rather than
  to a Gnuplot process;
- `term`: `"a string"`, or `("a string", "a filename")`: to specify
  the terminal (and optionally the output file);

## Examples:

### Simple examples with no data:
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

quitall()
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
@gp :- "fit f(x) \$name u 1:2:3 via a, b, c;"       :-
@gp :- "set multiplot layout 2,1"                     :-
@gp :- "plot \$name w points" ylab="Data and model" :-
@gp :- "plot \$name u 1:(f(\\\$1)) w lines"         :-
@gp :- 2 xlab="X label" ylab="Residuals"              :-
@gp :- "plot \$name u 1:((f(\\\$1)-\\\$2) / \\\$3):(1) w errorbars notit"

# Retrieve values fr a, b and c
a = parse(Float64, gpeval("print a"))
b = parse(Float64, gpeval("print b"))
c = parse(Float64, gpeval("print c"))
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
    out = Expr(:macrocall, Symbol("@gp"), LineNumberNode(1, "Gnuplot.jl"))
    push!(out.args, args...)
    push!(out.args, Expr(:kw, :flag3d, true))
    return esc(out)
end


# # --------------------------------------------------------------------
# """
#   # repl
#
#   Read/evaluate/print/loop
# """
# function repl(sid::Symbol)
#     verb = state.verbosity
#     state.verbosity = 0
#     gp = getsession(sid)
#     while true
#         line = readline(stdin)
#         (line == "")  &&  break
#         answer = send(gp, line, true)
#         for line in answer
#             println(line)
#         end
#     end
#     state.verbosity = verb
#     return nothing
# end
# function repl()
#     global state
#     return repl(state.default)
# end


# --------------------------------------------------------------------
"""
  # gpeval

  Directly execute commands on the underlying gnuplot process, and return the result(s).
  functions.

  ## Examples:
  ```
  gpeval("print GPVAL_TERM")
  gpeval("plot sin(x)")
  ```
"""
function gpeval(sid::Symbol, s::Vector{String})
    global state
    gp = getsession(sid)
    answer = Vector{String}()
    for v in s
        push!(answer, writeread(gp, v)...)
    end
    return join(answer, "\n")
end
function gpeval(s::String)
    global state
    gpeval(state.default, [s])
end
gpeval(sid::Symbol, s::String) = gpeval(sid, [s])


# --------------------------------------------------------------------
function setverb(b::Bool)
    global state
    state.verbosity = b
end

# --------------------------------------------------------------------
function hist(v::Vector{T}; addright=false, closed::Symbol=:left, args...) where T <: AbstractFloat
    i = findall(isfinite.(v))
    hh = fit(Histogram, v[i]; closed=closed, args...)
    if addright == 0
        return PackedDataAndCmds([hh.edges[1], [hh.weights;0]], "", [], ["w steps notit"])
    end
    return PackedDataAndCmds([hh.edges[1], [0;hh.weights]], "", [], ["w fsteps notit"])
end

end #module
