__precompile__(true)

module Gnuplot

using AbbrvKW

import Base.send
import Base.reset


######################################################################
# Exported symbols
######################################################################

export CheckGnuplotVersion, GnuplotSession, GnuplotProc,
    GnuplotQuit, GnuplotQuitAll, GnuplotGet, setCurrent, getCurrent,
    @gp, @gpi, @gp_str, @gp_cmd


######################################################################
# Structure definitions
######################################################################

#---------------------------------------------------------------------
mutable struct inputData
    str::String
    sent::Bool
    inputData(str::String) = new(str, false)
end

mutable struct inputPlot
    cmds::Vector{String}
    plot::Vector{String}
    splot::Bool
    inputPlot() = new(Vector{String}(), Vector{String}(), false)
end


#---------------------------------------------------------------------
mutable struct GnuplotSession
    id::Int
    blockCnt::Int           # data blocks counter
    data::Vector{inputData} # data blocks
    plot::Vector{inputPlot} # commands and plot commands
    multiID::Int
    defCmd::String
end


#---------------------------------------------------------------------
mutable struct GnuplotProc
    id::Int
    pin::Base.Pipe
    pout::Base.Pipe
    perr::Base.Pipe
    proc::Base.Process
    channel::Channel{String}
    verbosity::Int                 # verbosity level (0 - 4), default: 3
    session::GnuplotSession
end


######################################################################
# Global variables and functions to handle it
######################################################################

#---------------------------------------------------------------------
mutable struct GlobalState
    obj::Dict{Int, Union{GnuplotSession,GnuplotProc}}
    id::Int
    GlobalState() = new(Dict{Int, Union{GnuplotSession,GnuplotProc}}(), 0)
end
const g_state = GlobalState()

function newID()
    global g_state
    countProc = 0
    newID = 0
    for (id, obj) in g_state.obj
        (id > newID)  &&  (newID = id)
        (typeof(obj) == GnuplotProc)  &&  (countProc += 1)
    end
    @assert countProc <= 10 "Too many Gnuplot processes are running."
    newID += 1
    return newID
end


######################################################################
# Private functions
######################################################################

#---------------------------------------------------------------------
"""
Logging facility

Printing occur only if the logging level is >= current verbosity
level.
"""
function logIn(gp::GnuplotProc, s::AbstractString)
    (gp.verbosity < 1)  &&  return nothing
    print_with_color(:yellow     , "GNUPLOT ($(gp.id)) -> $s\n")
    return nothing
end

function logData(gp::GnuplotProc, s::AbstractString)
    (gp.verbosity < 4)  &&  return nothing
    print_with_color(:light_black, "GNUPLOT ($(gp.id)) -> $s\n")
    return nothing
end

function logOut(gp::GnuplotProc, s::AbstractString)
    (gp.verbosity < 2)  &&  return nothing
    print_with_color(:cyan       , "GNUPLOT ($(gp.id))    $s\n")
    return nothing
end

function logErr(gp::GnuplotProc, s::AbstractString)
    (gp.verbosity < 3)  &&  return nothing
    print_with_color(:cyan       , "GNUPLOT ($(gp.id))    $s\n")
    return nothing
end

function logCaptured(gp::GnuplotProc, s::AbstractString)
    (gp.verbosity < 3)  &&  return nothing
    print_with_color(:green      , "GNUPLOT ($(gp.id))    $s\n")
    return nothing
end


#---------------------------------------------------------------------
"""
Read gnuplot outputs and optionally redirect to a `Channel`.

This fuction is supposed to be run in a `Task`.
"""
function readTask(gp::GnuplotProc, useStdErr::Bool)
    saveOutput = false

    sIN = gp.pout
    if useStdErr
        sIN = gp.perr
    end

    while isopen(sIN)
        line = convert(String, readline(sIN))

        if line == "GNUPLOT_CAPTURE_BEGIN"
            saveOutput = true
        else
            if saveOutput
                put!(gp.channel, line)
            end

            if line == "GNUPLOT_CAPTURE_END"
                saveOutput = false
            elseif line != ""
                if saveOutput
                    logCaptured(gp, line)
                else
                    if useStdErr
                        logErr(gp, line)
                    else
                        logOut(gp, line)
                    end
                end
            end
        end
    end

    logOut(gp, "pipe closed")

    global g_state
    delete!(g_state.obj, gp.id)

    return nothing
end


#---------------------------------------------------------------------
@AbbrvKW function parseKeywords(;
                                xrange::Union{Void,NTuple{2, Number}}=nothing,
                                yrange::Union{Void,NTuple{2, Number}}=nothing,
                                zrange::Union{Void,NTuple{2, Number}}=nothing,
                                title::Union{Void,String}=nothing,
                                xlabel::Union{Void,String}=nothing,
                                ylabel::Union{Void,String}=nothing,
                                zlabel::Union{Void,String}=nothing,
                                xlog::Union{Void,Bool}=nothing,
                                ylog::Union{Void,Bool}=nothing,
                                zlog::Union{Void,Bool}=nothing)

    out = Vector{String}()
    xrange == nothing  ||  (push!(out, "set xrange [" * join(xrange, ":") * "]"))
    yrange == nothing  ||  (push!(out, "set yrange [" * join(yrange, ":") * "]"))
    zrange == nothing  ||  (push!(out, "set zrange [" * join(zrange, ":") * "]"))
    title  == nothing  ||  (push!(out, "set title  '" * title  * "'"))
    xlabel == nothing  ||  (push!(out, "set xlabel '" * xlabel * "'"))
    ylabel == nothing  ||  (push!(out, "set ylabel '" * ylabel * "'"))
    zlabel == nothing  ||  (push!(out, "set zlabel '" * zlabel * "'"))
    xlog   == nothing  ||  (push!(out, (xlog  ?  ""  :  "un") * "set logscale x"))
    ylog   == nothing  ||  (push!(out, (ylog  ?  ""  :  "un") * "set logscale y"))
    zlog   == nothing  ||  (push!(out, (zlog  ?  ""  :  "un") * "set logscale z"))
    return out
end


#---------------------------------------------------------------------
"""
# send

Send a string to gnuplot's STDIN.

The commands sent through `send` are not stored in the current
session (use `addCmd` to save commands in the current session).

## Example:
```
gp = GnuplotProc()
send(gp, "plot sin(x)")
```

## Arguments:
- `gp`: a GnuplotProc or GnuplotSession object;
- `str::String`: command to be sent.
"""
function send(gp::GnuplotProc, str::AbstractString, capture=false)
    (capture)  &&  (write(gp.pin, "print 'GNUPLOT_CAPTURE_BEGIN'\n"))
    w = write(gp.pin, strip(str) * "\n")
    logIn(gp, str)
    w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    (capture)  &&  (write(gp.pin, "print 'GNUPLOT_CAPTURE_END'\n"))
    flush(gp.pin)

    out = Vector{String}()
    if capture
        while true
            l = take!(gp.channel)
            l == "GNUPLOT_CAPTURE_END"  &&  break
            push!(out, l)
        end
    end
    return out
end


#---------------------------------------------------------------------
"""
# reset

Delete all commands, data, and plots in the gnuplot session.
"""
function reset(gp::GnuplotSession)
    gp.blockCnt = 0
    gp.data = Vector{inputData}()
    gp.plot = [inputPlot()]
    gp.multiID = 1
    addCmd(gp, gp.defCmd)
    return nothing
end

"""
# reset

Send a 'reset session' command to gnuplot and delete all commands,
data, and plots in the associated session.
"""
function reset(gp::GnuplotProc)
    reset(gp.session)
    send(gp, "reset session")
    send(gp, gp.session.defCmd)
    return nothing
end


#---------------------------------------------------------------------
function addData(gp::GnuplotSession, data::Vararg{AbstractArray{T},M}; name="") where {T<:Number,M}
    if name == ""
        name = string("data", gp.blockCnt)
        gp.blockCnt += 1
    end
    name = "\$$name"

    # Check dimensions
    dimX = (size(data[1]))[1]
    dimY = 0
    is2D = false
    first1D = 0
    coordX = Vector{Float64}()
    coordY = Vector{Float64}()
    for i in length(data):-1:1
        d = data[i]
        @assert ndims(d) <=2 "Array dimensions must be <= 2"

        if ndims(d) == 2
            dimY == 0  &&  (dimY = (size(d))[2])
            @assert dimX == (size(d))[1] "Array size are incompatible"
            @assert dimY == (size(d))[2] "Array size are incompatible"
            @assert first1D == 0 "2D data must be given at the end of argument list"
            is2D = true
        end

        if ndims(d) == 1
            if !is2D
                @assert dimX == (size(d))[1] "Array size are incompatible"
            else
                @assert i <= 2 "When 2D data are given only the first two arrays must be 1D"

                if i == 1
                    @assert dimX == (size(d))[1] "Array size are incompatible"
                end
                if i == 2
                    @assert dimY == (size(d))[1] "Array size are incompatible"
                end
            end

            first1D = i
        end
    end
    if is2D
        if ndims(data[1]) == 1
            @assert ndims(data[2]) == 1 "Only one coordinate of a 2D dataset has been given"
            coordX = deepcopy(data[1])
            coordY = deepcopy(data[2])
        else
            coordX = collect(1.:1.:dimX)
            coordY = collect(1.:1.:dimY)
        end
    end

    v = "$name << EOD"
    push!(gp.data, inputData(v))

    if !is2D
        for i in 1:dimX
            v = ""
            for j in 1:length(data)
                v *= " " * string(data[j][i])
            end
            push!(gp.data, inputData(v))
        end
    else
        for i in 1:dimX
            for j in 1:dimY
                v = string(coordX[i]) * " " * string(coordY[j])
                for d in data
                    ndims(d) == 1  &&  (continue)
                    v *= " " * string(d[i,j])
                end
                push!(gp.data, inputData(v))
            end
            push!(gp.data, inputData(""))
        end
    end

    v = "EOD"
    push!(gp.data, inputData(v))

    return (name, is2D)
end


function addData(gp::GnuplotProc, data::Vararg{AbstractArray{T},M}; name="") where {T<:Number,M}
    name = addData(gp.session, data..., name=name)

    first = true
    count = 0
    for v in gp.session.data
        (v.sent)  &&  (continue)
        if gp.verbosity >= 4
            (v.str == "EOD")  &&  (count = -1)
            if count < 4
                logData(gp, v.str)
            elseif count == 4
                logData(gp, "...")
            end
            count += 1
        end
        w = write(gp.pin, v.str*"\n")
        v.sent = true
    end

    return name
end


#---------------------------------------------------------------------
function setMultiID(gp::GnuplotSession, id::Int)
    @assert id >= 0 "Multiplot ID must be a >= 0"
    for i in length(gp.plot)+1:id
        push!(gp.plot, inputPlot())
    end
    (id > 0)  &&  (gp.multiID = id)
end
setMultiID(gp::GnuplotProc, id::Int) = setMultiID(gp.session, id)


#---------------------------------------------------------------------
function setSplot(gp::GnuplotSession, splot::Bool)
    if splot
        gp.plot[gp.multiID].splot = splot
    end
end
setSplot(gp::GnuplotProc, splot::Bool) = setSplot(gp.session, splot)



#---------------------------------------------------------------------
"""
# addCmd

Send a command to gnuplot process and store it in the current session.
"""
function addCmd(gp::GnuplotSession, v::String; id::Int=0)
    setMultiID(gp, id)
    (v != "")  &&  (push!(gp.plot[gp.multiID].cmds, v))
    return nothing
end

function addCmd(gp::GnuplotSession; id::Int=0, args...)
    for v in parseKeywords(;args...)
        addCmd(gp, v, id=id)
    end
    return nothing
end

function addCmd(gp::GnuplotProc, s::String; id::Int=0)
    addCmd(gp.session, s, id=id)
    (length(gp.session.plot) == 1)  &&  (send(gp, s))
end

function addCmd(gp::GnuplotProc; id::Int=0, args...)
    for v in parseKeywords(;args...)
        addCmd(gp, v, id=id)
    end
end


#---------------------------------------------------------------------
function addPlot(gp::GnuplotSession, name, opt=""; id=0)
    setMultiID(gp, id)
    push!(gp.plot[gp.multiID].plot, "$name $opt")
end

addPlot(gp::GnuplotProc, name, opt=""; id=0) = addPlot(gp.session, name, opt, id=id)


#---------------------------------------------------------------------
"""
# gpDump

Send all necessary commands to gnuplot to actually do the plot.
Optionally, the commands may be sent to a file or returned as a
`Vector{String}`.
"""
@AbbrvKW function gpDump(gp::Union{GnuplotSession,GnuplotProc};
                         term=("", ""), file="", stream=nothing, asArray=false)

    session = (typeof(gp) == GnuplotProc  ?  gp.session  :  gp)
    ret = Vector{String}()

    dump2Gp  = false
    dumpCmds = false
    dumpData = false

    if file == ""          &&
        stream == nothing  &&
        asArray == false
        # No outut is selected
        if typeof(gp) == GnuplotProc
            dump2Gp = true
        else
            stream = STDOUT
        end
    end

    if  file != ""        ||
        stream != nothing ||
        asArray
        dumpCmds = true
        dumpData = true
    end

    if !dumpCmds
        dumpCmds = (length(session.plot) > 1)
    end

    # Open output file
    if file != ""
        sfile = open(file, "w")
        dumpData = true
    end

    function gpDumpInt(s::String)
        (file != "")         &&  (println(sfile , s))
        (stream != nothing)  &&  (println(stream, s))
        (asArray)            &&  (push!(ret, s))
        (dump2Gp)            &&  (send(gp, s))
        return nothing
    end

    if dumpData
        gpDumpInt("reset session")
        for v in session.data; gpDumpInt(v.str); end
    end

    (term[1] != "")  &&  (gpDumpInt("set term $(term[1])"))
    (term[2] != "")  &&  (gpDumpInt("set output '$(term[2])'"))

    for id in 1:length(session.plot)
        if dumpCmds
            for s in session.plot[id].cmds
                gpDumpInt(s)
            end
        end

        plot = Vector{String}()
        for s in session.plot[id].plot; push!(plot, s); end
        if length(plot) > 0
            s = (session.plot[id].splot  ?  "splot "  :  "plot ") * " \\\n  " *
                join(plot, ", \\\n  ")
            gpDumpInt(s)
        end
    end

    (length(session.plot) > 1)  &&  (gpDumpInt("unset multiplot"))

    (term[2] != "")  &&  (gpDumpInt("set output"))
    (file != "")  &&  (close(sfile))

    return ret
end


#---------------------------------------------------------------------
function gpDriver(args...)
    gp = nothing
    for arg in args
        if  typeof(arg) == GnuplotProc   ||
            typeof(arg) == GnuplotSession
            gp = arg
        end
    end
    if gp == nothing
        gp = getCurrent()
    end

    if length(args) == 0
        #gpDump(gp)
        return nothing
    end

    eData = Vector{Any}()
    dataName = ""
    addDump  = false
    term = ("", "")
    file=""
    stream=nothing

    function endOfData(associatedPlot=nothing)
        if length(eData) > 0
            (last, splot) = addData(gp, eData...; name=dataName)
            if associatedPlot != nothing
                setSplot(gp, splot)
                addPlot(gp, last, associatedPlot)
            end
        end
        eData = Vector{Any}()
        dataName = ""
    end
    function endOfStream(forceDump::Bool)
        endOfData("")
        (forceDump  ||  addDump)  &&  (gpDump(gp; term=term, file=file, stream=stream))
        addDump  = false
        term = ("", "")
        file=""
        stream=nothing
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

    for iarg in 1:length(args)
        arg = args[iarg]

        if  typeof(arg) == GnuplotProc   ||
            typeof(arg) == GnuplotSession
            continue
        elseif typeof(arg) == Symbol
            if arg == :.
                addDump = true
            elseif arg == :splot
                setSplot(gp, true)
            else
                dataName = string(arg)
                endOfData()
            end
        elseif isa(arg, Int)
            if arg == 0
                reset(gp)
            else
                endOfData("")
                setMultiID(gp, arg)
            end
        elseif isa(arg, String)
            # Either a plot or cmd string
            if length(eData) > 0
                endOfData(arg)
            else
                (isPlot, splot, cmd) = isPlotCmd(arg)
                if isPlot
                    setSplot(gp, splot)
                    addPlot(gp, cmd)
                else
                    addCmd(gp, arg)
                end
            end
        elseif isa(arg, Tuple)  &&  length(arg) == 2  &&  isa(arg[1], Symbol)
            if arg[1] == :term
                if typeof(arg[2]) == String
                    term  = (deepcopy(arg[2]), "")
                elseif length(arg[2]) == 2
                    term  = deepcopy(arg[2])
                else
                    error("The term tuple must contain at most two strings")
                end
            elseif arg[1] == :verb
                gp = gp
                gp.verbosity = arg[2]
            elseif arg[1] == :file
                file = arg[2]
            elseif arg[1] == :stream
                stream = arg[2]
            else
                # A cmd keyword
                addCmd(gp; arg)
            end
        else
            # A data set
            push!(eData, arg)
        end
    end
    endOfStream(false)

    return nothing
end


######################################################################
# Public functions
######################################################################

#---------------------------------------------------------------------
"""
# CheckGnuplotVersion

Check whether  gnuplot is runnable with the command given in `cmd`.
Also check that gnuplot version is >= 4.7 (required to use data
blocks).
"""
function CheckGnuplotVersion(cmd::String)
    icmd = `$(cmd) --version`
    out, procs = open(`$icmd`, "r")
    s = String(read(out))
    if !success(procs)
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
        warn("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    if ver < v"4.6"
        error("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    info("Running gnuplot version: " * string(ver))
    return ver
end


#---------------------------------------------------------------------
"""
# GnuplotSession

Initialize a new session without any underlying Gnuplot process.  This
is intended to use the package facilities to save the Gnuplot commands
and data in a script file, rather than sending them to an actual
process.

The newly created session becomes the default sink for the @gp macro.
"""
function GnuplotSession(;default="")
    global g_state
    id = newID()
    out = GnuplotSession(id, 0, Vector{inputData}(),
                         [inputPlot()], 1, default)
    g_state.obj[id] = out
    return out
end


#---------------------------------------------------------------------
"""
# GnuplotProc

Initialize a new session (see `GnuplotSession`) and the
associated Gnuplot process.

The newly created session becomes the default sink for the @gp macro.
"""
function GnuplotProc(cmd="gnuplot"; default="")
    global g_state
    CheckGnuplotVersion(cmd)

    pin  = Base.Pipe()
    pout = Base.Pipe()
    perr = Base.Pipe()
    proc = spawn(`$cmd`, (pin, pout, perr))

    id = newID()
    out = GnuplotProc(id, pin, pout, perr, proc,
                      Channel{String}(32), 4,
                      GnuplotSession(id, 0, Vector{inputData}(),
                                     [inputPlot()], 1, default)
                      )
    g_state.obj[id] = out

    # Close unused sides of the pipes
    Base.close_pipe_sync(out.pout.in)
    Base.close_pipe_sync(out.perr.in)
    Base.close_pipe_sync(out.pin.out)
    Base.start_reading(out.pout.out)
    Base.start_reading(out.perr.out)

    # Start reading tasks
    @async readTask(out, false)
    @async readTask(out, true)
    return out
end


#---------------------------------------------------------------------
"""
# GnuplotQuit

Close the current session and the associated gnuplot process (if any).
"""
function GnuplotQuit(gp::GnuplotSession)
    global g_state
    delete!(g_state.obj, gp.id)
    return 0
end

function GnuplotQuit(gp::GnuplotProc)
    close(gp.pin)
    close(gp.pout)
    close(gp.perr)
    wait( gp.proc)
    exitCode = gp.proc.exitcode
    logOut(gp, string("Process exited with status ", exitCode))
    GnuplotQuit(gp.session)
    return exitCode
end

function GnuplotQuit(id::Int)
    global g_state
    if !(id in keys(g_state.obj))
        error("Gnuplot ID $id do not exists")
    end
    return GnuplotQuit(g_state.obj[id])
end


#---------------------------------------------------------------------
"""
# GnuplotQuitAll

Close all the started sessions and the associated gnuplot processes.
"""
function GnuplotQuitAll()
    global g_state
    for (id, obj) in g_state.obj
        GnuplotQuit(obj)
    end
    return 0
end


#---------------------------------------------------------------------
"""
# GnuplotGet

Return the value of one (or more) gnuplot variables.

## Example
```
println("Current gnuplot terminal is: ", GnuplotGet("GPVAL_TERM"))
```
"""
function GnuplotGet(gp::GnuplotProc, var::String)
    out = Vector{String}()
    answer = send(gp, "print $var", true)
    for line in answer
        if length(search(line, "undefined variable:")) > 0
            error(line)
        end
        push!(out, line)
    end
    return join(out, "\n")
end
GnuplotGet(var::String) = GnuplotGet(getCurrent(), var)


#---------------------------------------------------------------------
"""
# setCurrent
"""
function setCurrent(gp::GnuplotProc)
    @assert (gp.id in keys(g_state.obj)) "Invalid Gnuplot ID: $id"
    g_state.id = gp.id
end

function setCurrent(gp::GnuplotSession)
    @assert (gp.id in keys(g_state.obj)) "Invalid Gnuplot ID: $id"
    g_state.id = gp.id
end


#---------------------------------------------------------------------
function getCurrent()
    global g_state
    if !(g_state.id in keys(g_state.obj))
        info("Creating default Gnuplot process...")
        out = GnuplotProc()
        setCurrent(out)
    end
    return g_state.obj[g_state.id]
end


#---------------------------------------------------------------------
"""
# @gp

The `@gp` (and its companion `@gpi`) allows to exploit all of the
**Gnuplot** package functionalities using an extremely efficient and
concise syntax.

The `@gp` accepts any number of arguments, with the following meaning:
- a string: a command (e.g. "set key left") or plot specification;
- a `GnuplotProc` or `GnuplotSession` object: set the current sink;
- a symbol: specifies the data set name;
- an `Int`: if >0 set the current plot destination (if multiplot is
  enabled).  If 0 reset the whole session.
- a keyword: set the keyword value (see below);
- any other data type: data to be passed to Gnuplot.  Each dataset
  must be terminated by either: a symbol (i.e. the data set name) or a
  string with the plot specifications (e.g. "with lines").

All entries are optional, and there is no mandatory order.  The plot
specification can either be: a complete plot/splot command (e.g.,
"plot sin(x)", both "plot" and "splot" can be abbreviated to "p" and
"s" respectively), or a partial specification starting with the "with"
clause (if it follows a data set).

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

The symbol for the above-mentioned keywords may also be used in a
shortened form, as long as there is no ambiguity with other keywords.
E.g. you can use: `xr=(1,10)` in place of `xrange=(1,10)`.

Beside the above-mentioned keyword the following can also be used
(although with no symbol shortening):

- verb=Int: a number between 0 and 4, to set the verbosity level;
- file="A string": send all the data and command to a file rather than
  to a Gnuplot process;
- stream=A stream: send all the data and command to a stream rather than
  to a Gnuplot process;
- term="a string", or term=("a string", "a filename"): to specify the
  terminal (and optionally the output file);


A rather simple example for the usage of `@gp` is as follows:
```
@gp "set key left" tit="My title" xr=(1,12) 1:10 "with lines tit 'Data'"
```

In general, the `@gp` macro tries to figure out the appropriate
meaning of each arugment to allows an easy and straightforward use of
the underlying Gnuplot process.

The `@gp` macro always send a "reset session" command to Gnuplot at
the beginning, and always run all the given commands at the end,
i.e. it is supposed to be used in cases where all data/commands are
provided in a single `@gp` call.

To split the call in several statements, avoiding a session reset at
the beginning and an automatic execution of all commands at then, you
should use the `@gpi` macro instead, with exaclty the same syntax as
`@gp`.  The `@gpi` macro also accepts the following arguments:
- the `0` number to reset the whole session;
- the `:.` symbol to send all commands to Gnuplot.


## Examples:
```
# Simple examples with no data
@gp "plot sin(x)"
@gp "plot sin(x)" "pl cos(x)"
@gp "plo sin(x)" "s cos(x)"

# Split a `@gp` call in two
@gpi 0 "plot sin(x)"
@gpi "plot cos(x)" :.

# Insert a 3 second pause between one plot and the next
@gp "plot sin(x)" 2 xr=(-2pi,2pi) "pause 3" "plot cos(4*x)"

# Simple examples with data:
x = collect(1.:10)
@gp x
@gp x x
@gp x -x
@gp x x.^2
@gp x x.^2 "w l"

lw = 3
@gp x x.^2 "w l lw \$lw"

# A more complex example
@gp("set grid", "set key left", xlog=true, ylog=true,
    title="My title", xlab="X label", ylab="Y label",
    x, x.^0.5, "w l tit 'Pow 0.5' dt 2 lw 2 lc rgb 'red'",
    x, x     , "w l tit 'Pow 1'   dt 1 lw 3 lc rgb 'blue'",
    x, x.^2  , "w l tit 'Pow 2'   dt 3 lw 2 lc rgb 'purple'")


# Multiplot example:
@gp(xr=(-2pi,2pi), "unset key",
    "set multi layout 2,2 title 'Multiplot title'",
    1, "p sin(x)"  ,
    2, "p sin(2*x)",
    3, "p sin(3*x)",
    4, "p sin(4*x)")

# or equivalently
@gpi 0 xr=(-2pi,2pi) "unset key" "set multi layout 2,2 title 'Multiplot title'"
for i in 1:4
  @gpi i "p sin(\$i*x)"
end
@gpi :.


# Multiple gnuplot instances
gp1 = GnuplotProc(default="set term wxt")
gp2 = GnuplotProc(default="set term qt")

@gp gp1 "plot sin(x)"
@gp gp2 "plot sin(x)"

GnuplotQuitAll()


# Further examples
x = linspace(-2pi, 2pi, 100);
y = 1.5 * sin.(0.3 + 0.7x) ;
noise = randn(length(x))./2;
e = 0.5 * ones(x);

@gp verb=2 x y :aa "plot \\\$aa w l" "pl \\\$aa u 1:(2*\\\$2) w l"
@gp randn(Float64, 30, 50)

@gp("set key horizontal", "set grid",
    xrange=(-7,7), ylabel="Y label",
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, e, "w errorbars t 'Data'");


@gpi 0 "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"
@gpi x y+noise e :aa
@gpi "fit f(x) \\\$aa u 1:2:3 via a, b, c;"
@gpi "set multiplot layout 2,1"
@gpi "plot \\\$aa w points tit 'Data'" ylab="Data and model"
@gpi "plot \\\$aa u 1:(f(\\\$1)) w lines tit 'Best fit'"
@gpi 2 xlab="X label" ylab="Residuals"
@gpi "plot \\\$aa u 1:((f(\\\$1)-\\\$2) / \\\$3):(1) w errorbars notit"  :.

```
"""
macro gp(args...)
    esc_args = Vector{Any}()
    for arg in args
        push!(esc_args, esc(arg))
    end
    e = :(@gpi(0, $(esc_args...), :.))

    return e
end


"""
# @gpi

See documentation for `@gp`.
"""
macro gpi(args...)
    out = Expr(:call)
    push!(out.args, :(Gnuplot.gpDriver))
    for iarg in 1:length(args)
        arg = args[iarg ]
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


#---------------------------------------------------------------------
"""
# @gp_str

Send a non-standard string literal to Gnuplot

NOTE: this is supposed to be used interactively on the REPL, not in
functions.

## Examples:
```
gp"print GPVAL_TERM"
gp"plot sin(x)"

gp"
set title \\"3D surface from a grid (matrix) of Z values\\"
set xrange [-0.5:4.5]
set yrange [-0.5:4.5]

set grid
set hidden3d
\$grid << EOD
5 4 3 1 0
2 2 0 0 1
0 0 0 1 0
0 0 0 2 3
0 1 2 4 3
EOD
splot '\$grid' matrix with lines notitle
"
```
"""
macro gp_str(s::String)
    for v in split(s, "\n")
        send(getCurrent(), string(v))
    end
    return nothing
end


#---------------------------------------------------------------------
"""
# @gp_cmd

Call the gnuplot "load" command passing the filename given as
non-standard string literal.

NOTE: this is supposed to be used interactively on the REPL, not in
functions.

Example:
```
@gp (1:10).^3 "w l notit lw 4" file="test.gp"
gp`test.gp`
```
"""
macro gp_cmd(file::String)
    return send(getCurrent(), "load '$file'")
end

end #module
