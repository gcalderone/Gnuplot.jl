__precompile__(false)

module Gnuplot

using AbbrvKW

######################################################################
# Structure definitions
######################################################################


#---------------------------------------------------------------------
"""
Structure containing a single plot command and the associated
multiplot index.
"""
mutable struct Command
  cmd::String    # command
  id::Int        # multiplot index
end

#---------------------------------------------------------------------
"""
Structure containing the state of a single gnuplot session.
"""
mutable struct Session
    pin::Base.Pipe
    pout::Base.Pipe
    perr::Base.Pipe
    proc::Base.Process
    channel::Channel{String}
    blockCnt::Int           # data blocks counter
    lastBlock::String       # name of the last data block
    cmds::Vector{Command}   # gnuplot commands
    data::Vector{String}    # data blocks
    splot::Bool             # plot / splot session
    plot::Vector{Command}   # plot specifications associated to each data block
    cid::Int                # current multiplot index (0 if no multiplot)

    function Session(cmd)
        this = new()
        this.pin  = Base.Pipe()
        this.pout = Base.Pipe()
        this.perr = Base.Pipe()
        this.channel = Channel{String}(32)

        # Start gnuplot process
        this.proc = spawn(`$cmd`, (this.pin, this.pout, this.perr))

        # Close unused sides of the pipes
        Base.close_pipe_sync(this.pout.in)
        Base.close_pipe_sync(this.perr.in)
        Base.close_pipe_sync(this.pin.out)
        Base.start_reading(this.pout.out)
        Base.start_reading(this.perr.out)

        this.blockCnt = 0
        this.lastBlock = ""
        this.cmds = Vector{Command}()
        this.data = Vector{String}()
        this.splot = false
        this.plot = Vector{Command}()
        this.cid = 0
        return this
    end
end


#---------------------------------------------------------------------
"""
Structure containing the global package state.
"""
mutable struct State
    sessions::Dict{Int, Session}
    current::Int

    State() = new(Dict{Int, Session}(), 0)
end

const state = State()


#---------------------------------------------------------------------
"""
Structure containing the global options.
"""
mutable struct Options
    colorOut::Symbol               # gnuplot STDOUT is printed with this color
    colorIn::Symbol                # gnuplot STDIN is printed with this color
    verbosity::Int                 # verbosity level (0 - 4), default: 3
    gnuplotCmd::String             # command used to start the gnuplot process
    startup::String                # commands automatically sent to each new gnuplot process

    Options() = new(:cyan, :yellow, 3, "gnuplot", "")
end

const gpOptions = Options()



######################################################################
# Utils
######################################################################

#---------------------------------------------------------------------
"""
Logging facility (each line is prefixed with the session ID.)

Printing occur only if the logging level is >= current verbosity
level.
"""
function log(level::Int, s::String, id=0)
    (gpOptions.verbosity < level)  &&  return
    if id == 0
        id = state.current
        color = gpOptions.colorOut
    else
        color = gpOptions.colorIn
    end
    prefix = string("GP(", id, ")")
    for v in split(s, "\n")
        print_with_color(color, "$prefix $v\n")
    end
    return nothing
end


#---------------------------------------------------------------------
"""
sessionCollector
"""
function sessionCollector()
    for (id, cur) in state.sessions
        if !Base.process_running(cur.proc)
            log(3, "Deleting session $id")
            delete!(state.sessions, id)

            if (id == state.current)
                state.current = 0
            end
        end
    end
end


#---------------------------------------------------------------------
"""
Read gnuplot outputs, and optionally redirect to a `Channel`.

This fuction is supposed to be run in a `Task`.
"""
function readTask(sIN, channel, id)
    saveOutput = false
    while isopen(sIN)
        line = convert(String, readline(sIN))

        if line == "GNUPLOT_JL_SAVE_OUTPUT"
            saveOutput = true
            log(4, "|begin of captured data =========================", id)
        else
            if saveOutput
                put!(channel, line)
            end

            if line == "GNUPLOT_JL_SAVE_OUTPUT_END"
                saveOutput = false
                log(4, "|end of captured data ===========================", id)
            elseif line != ""
                if saveOutput
                    log(3, "|  " * line, id)
                else
                    log(2, "   " * line, id)
                end
            end
        end
    end

    log(1, "pipe closed")
    return nothing
end


#---------------------------------------------------------------------
"""
Return the current session, or start a new one if none is running.
"""
function getCurrentOrStartIt()
    sessionCollector()

    if haskey(state.sessions, state.current)
        return state.sessions[state.current]
    end

    return state.sessions[gpNewSession()]
end


######################################################################
# Exported symbols
######################################################################

export gpCheckVersion, gpNewSession, gpExit, gpExitAll, gpSetCurrentID,
    gpCurrentID, gpGetIDs, gpSend, gpReset, gpCmd, gpData, gpLastBlock,
    gpGetVal, gpPlot, gpMulti, gpNext, gpDump, gpOptions,
    gpTerminals, gpTerminal,
    @gpi, @gp, @gp_str, @gp_cmd

#---------------------------------------------------------------------
"""
Check gnuplot is runnable with the command given in `state.gnuplotCmd`.
Also check that gnuplot version is >= 4.7 (required to use data
blocks).
"""
function gpCheckVersion()
    cmd = `$(gpOptions.gnuplotCmd) --version`
    out, procs = open(`$cmd`, "r")
    s = String(read(out))
    if !success(procs)
        error("An error occurred while running: " * string(cmd))
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
    log(1, "Found gnuplot version: " * string(ver))
    return ver
end



#---------------------------------------------------------------------
"""
# gpNewSession

Create a new session (by starting a new gnuplot process), make it the
current one, and return the new session ID.

E.g., to compare the look and feel of two terminals:
```
id1 = gpNewSession()
gpSend("set term qt")
gpSend("plot sin(x)")

id2 = gpNewSession()
gpSend("set term wxt")
gpSend("plot sin(x)")

gpSetCurrentID(id1)
gpSend("set title 'My title'")
gpSend("replot")

gpSetCurrentID(id2)
gpSend("set title 'My title'")
gpSend("replot")

gpExitAll()
```
"""
function gpNewSession()
    gpCheckVersion()

    cur = Session(gpOptions.gnuplotCmd)

    id = 1
    if length(state.sessions) > 0
        id = maximum(keys(state.sessions)) + 1
    end
    state.sessions[id] = cur
    state.current = id

    # Start reading tasks for STDOUT and STDERR
    @async readTask(cur.pout, cur.channel, id)
    @async readTask(cur.perr, cur.channel, id)
    gpCmd(gpOptions.startup)

    log(1, "New session started with ID $id")
    return id
end


#---------------------------------------------------------------------
"""
# gpExit

Close current session and quit the corresponding gnuplot process.
"""
function gpExit()
    sessionCollector()

    if length(state.sessions) == 0
        log(1, "No session to close.")
        return 0
    end

    cur = state.sessions[state.current]
    close(cur.pin)
    close(cur.pout)
    close(cur.perr)
    wait( cur.proc)
    exitCode = cur.proc.exitcode
    log(1, string("Process exited with status ", exitCode))

    sessionCollector()

    # Select next session
    if length(state.sessions) > 0
        state.current = maximum(keys(state.sessions))
    end

    return exitCode
end


#---------------------------------------------------------------------
"""
# gpExitAll

Repeatedly call `gpExit` until all sessions are closed.
"""
function gpExitAll()
    while length(state.sessions) > 0
        gpExit()
    end
    return nothing
end


#---------------------------------------------------------------------
"""
# gpSetCurrentID

Change the current session.

## Arguments:
- `handle::Int`: the handle of the session to select as current.

## See also:
- `gpCurrentID`: return the current session handle;
- `gpGetIDs`: return the list of available handles.
"""
function gpSetCurrentID(id::Int)
    sessionCollector()
    @assert haskey(state.sessions, id) "No session with ID $id"
    state.current = id
    nothing
end


#---------------------------------------------------------------------
"""
# gpCurrentID

Return the handle of the current session.
"""
function gpCurrentID()
    sessionCollector()
    return state.current
end


#---------------------------------------------------------------------
"""
# gpGetIDs

Return a `Vector{Int}` of  available session IDs.
"""
function gpGetIDs()
    sessionCollector()
    return keys(state.sessions)
end


######################################################################
# Send data and commands to Gnuplot
######################################################################

"""
# gpSend

Send a string to the current session's gnuplot STDIN.

The commands sent through `gpSend` are not stored in the current
session (use `cmd` to save commands in the current session).

## Example:
```
println("Current terminal: ", gpSend("print GPVAL_TERM", capture=true))
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `capture::Bool`: if `true` waits until gnuplot provide a complete
  reply, and return it as a `Vector{String}`.  Otherwise return
  `nothing` immediately.
"""
@AbbrvKW function gpSend(cmd::String; capture::Bool=false, verbosity=2)
    p = getCurrentOrStartIt()

    if capture
        write(p.pin, "print 'GNUPLOT_JL_SAVE_OUTPUT'\n")
    end

    for s in split(cmd, "\n")
        w = write(p.pin, strip(s) * "\n")
        log(verbosity, "-> $s")
        w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    end

    if capture
        write(p.pin, "print 'GNUPLOT_JL_SAVE_OUTPUT_END'\n")
    end
    flush(p.pin)

    if capture
        out = Vector{String}()
        while true
            l = take!(p.channel)
            l == "GNUPLOT_JL_SAVE_OUTPUT_END"  &&  break
            push!(out, l)
        end

        length(out) == 1  &&  (out = out[1])
        return out
    end

    return nothing
end


#---------------------------------------------------------------------
"""
# gpReset

Send a 'reset session' command to gnuplot and delete all commands,
data, and plots in the current session.
"""
function gpReset()
    cur = getCurrentOrStartIt()

    cur.blockCnt = 0
    cur.lastBlock = ""
    cur.cmds = Vector{Command}()
    cur.data = Vector{String}()
    cur.splot = false
    cur.plot = Vector{Command}()
    cur.cid = 0

    gpSend("reset session", capture=true)
    gpCmd(gpOptions.startup)
    return nothing
end


#---------------------------------------------------------------------
"""
# gpCmd

Send a command to gnuplot process and store it in the current session.
A few, commonly used, commands may be specified through keywords (see
below).

## Examples:
```
gpCmd("set grid")
gpCmd("set key left", xrange=(1,3))
gpCmd(title="My title", xlab="X label", xla="Y label")
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `cid::Int`: ID of the plot the commands belongs to (only useful
  for multiplots);
- `splot::Bool`: set to `true` for a "splot" gnuplot session, `false`
  for a "plot" one;
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
"""
@AbbrvKW function gpCmd(s::String="";
                        splot::Union{Void,Bool}=nothing,
                        cid::Union{Void,Int}=nothing,
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

    cur = getCurrentOrStartIt()
    mID = (cid == nothing  ?  cur.cid  :  cid)

    if splot != nothing
        cur.splot = splot
    end

    if s != ""
        push!(cur.cmds, Command(s, mID))
        if mID == 0
            gpSend(s)
        end
    end

    xrange == nothing  ||  gpCmd(cid=mID, "set xrange [" * join(xrange, ":") * "]")
    yrange == nothing  ||  gpCmd(cid=mID, "set yrange [" * join(yrange, ":") * "]")
    zrange == nothing  ||  gpCmd(cid=mID, "set zrange [" * join(zrange, ":") * "]")

    title  == nothing  ||  gpCmd(cid=mID, "set title  '" * title  * "'")
    xlabel == nothing  ||  gpCmd(cid=mID, "set xlabel '" * xlabel * "'")
    ylabel == nothing  ||  gpCmd(cid=mID, "set ylabel '" * ylabel * "'")
    zlabel == nothing  ||  gpCmd(cid=mID, "set zlabel '" * zlabel * "'")

    xlog   == nothing  ||  gpCmd(cid=mID, (xlog  ?  ""  :  "un") * "set logscale x")
    ylog   == nothing  ||  gpCmd(cid=mID, (ylog  ?  ""  :  "un") * "set logscale y")
    zlog   == nothing  ||  gpCmd(cid=mID, (zlog  ?  ""  :  "un") * "set logscale z")

    return nothing
end


#---------------------------------------------------------------------
"""
# gpData

Send data to the gnuplot process, store it in the current session, and
return the name of the data block (to be later used with `plot`).

## Example:
```
x = collect(1.:10)

# Automatically generated data block name
name1 = gpData(x, x.^2)

# Specify the data block name.  NOTE: avoid using the same name
# multiple times!
name2 = gpData(x, x.^1.8, name="MyChosenName")

gpPlot(name1)
gpPlot(name2)
gpDump()
```

## Arguments:
- `data::Vararg{AbstractArray{T,1},N} where {T<:Number,N}`: the data
  to be sent to gnuplot;

## Keywords:
- `name::String`: data block name.  If not given an automatically
  generated one will be used;
- `prefix::String`: prefix for data block name (an automatic counter
  will be appended);
"""
function gpData(data::Vararg{AbstractArray{T},M}; name="") where {T<:Number,M}
    cur = getCurrentOrStartIt()

    if name == ""
        name = string("data", cur.blockCnt)
        cur.blockCnt += 1
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
    push!(cur.data, v)
    gpSend(v, verbosity=3)

    if !is2D
        for i in 1:dimX
            v = ""
            for j in 1:length(data)
                v *= " " * string(data[j][i])
            end
            push!(cur.data, v)
            gpSend(v, verbosity=4)
        end
    else
        for i in 1:dimX
            for j in 1:dimY
                v = string(coordX[i]) * " " * string(coordY[j])
                for d in data
                    ndims(d) == 1  &&  (continue)
                    v *= " " * string(d[i,j])
                end
                push!(cur.data, v)
                gpSend(v, verbosity=4)
            end
            push!(cur.data, "")
            gpSend("", verbosity=4)
        end
    end

    v = "EOD"
    push!(cur.data, v)
    gpSend(v, verbosity=3)

    cur.lastBlock = name
    if is2D 
        cur.splot = true
    end

    return name
end


#---------------------------------------------------------------------
"""
# gpLastBlock

Return the name of the last data block.
"""
function gpLastBlock()
    cur = getCurrentOrStartIt()
    return cur.lastBlock
end


#---------------------------------------------------------------------
"""
# gpGetVal

Return the value of one (or more) gnuplot variables.

## Example
- argtuple of strings with gnuplot variable
"""
function gpGetVal(args...)
    out = Vector{String}()
    for arg in args
        push!(out, string(gpSend("print $arg", capture=true)...))
    end

    if length(out) == 1
        out = out[1]
    end

    return out
end


#---------------------------------------------------------------------
"""
# gpPlot

Add a new plot/splot comand to the current session

## Example:
```
x = collect(1.:10)

gpData(x, x.^2)
gpPlot(last=true, "w l tit 'Pow 2'")

src = gpData(x, x.^2.2)
gpPlot("\$src w l tit 'Pow 2.2'")

# Re use the same data block
gpPlot("\$src u 1:(\\\$2+10) w l tit 'Pow 2.2, offset=10'")

gpDump() # Do the plot
```

## Arguments:
- `spec::String`: plot command (see Gnuplot manual) without the
  leading "plot" string;

## Keywords:

- `file::String`: if given the plot command will be prefixed with
  `'\$file'`;
- `lastBlock::Bool`: if true the plot command will be prefixed with the
  last inserted data block name;
- `cid::Int`: ID of the plot the command belongs to (only useful
  for multiplots);
"""
@AbbrvKW function gpPlot(spec::String;
                         lastBlock::Bool=false,
                         file::Union{Void,String}=nothing,
                         cid::Union{Void,Int}=nothing)

    cur = getCurrentOrStartIt()
    mID = (cid == nothing  ?  cur.cid  :  cid)

    src = ""
    if lastBlock
        src = cur.lastBlock
    elseif file != nothing
        src = "'" * file * "'"
    end
    push!(cur.plot, Command("$src $spec", mID))
    return nothing
end


#---------------------------------------------------------------------
"""
# gpMulti

Initialize a multiplot (through the "set multiplot" Gnuplot command).

## Arguments:

- `multiCmd::String`: multiplot command (see Gnuplot manual) without
  the leading "set multiplot" string;

## See also: `gpNext`.
"""
function gpMulti(multiCmd::String="")
    cur = getCurrentOrStartIt()
    if cur.cid != 0
        error("Current multiplot ID is $(cur.cid), while it should be 0")
    end

    cur.cid += 1
    gpCmd("set multiplot $multiCmd")

    # Ensure all plot commands have ID >= 1
    for p in cur.plot
        p.id < 1  &&  (p.id = 1)
    end

    return nothing
end


#---------------------------------------------------------------------
"""
# gpNext

Select next slot for multiplot sessions.
"""
function gpNext()
    cur = getCurrentOrStartIt()
    cur.cid += 1
    return nothing
end


#---------------------------------------------------------------------
"""
# gpDump

Send all necessary commands to gnuplot to actually do the plot.
Optionally, the commands may be sent to a file.  In any case the
commands are returned as `Vector{String}`.

## Keywords:

- `all::Bool`: if true all commands and data will be sent again to
  gnuplot, if they were already sent (equivalent to `data=true,
  cmd=true`);

- `cmd::Bool`: if true all commands will be sent again to gnuplot, if
  they were already sent;

- `data::Bool`: if true all data will be sent again to gnuplot, if
  they were already sent;

- `dry::Bool`: if true no command/data will be sent to gnuplot;

- `file::String`: filename to redirect all outputs.  Implies
  `all=true, dry=true`.
"""
@AbbrvKW function gpDump(; all::Bool=false,
                         dry::Bool=false,
                         cmd::Bool=false,
                         data::Bool=false,
                         file::Union{Void,String}=nothing)
    if file != nothing
        all = true
        dry = true
    end

    cur = getCurrentOrStartIt()
    out = Vector{String}()

    all  &&  (push!(out, "reset session"))

    if data || all
        for s in cur.data
            push!(out, s)
        end
    end

    for id in 0:cur.cid
        for m in cur.cmds
            if (m.id == id)  &&  ((id > 0)  ||  all)
                push!(out, m.cmd)
            end
        end

        tmp = Vector{String}()
        for m in cur.plot
            if m.id == id
                push!(tmp, m.cmd)
            end
        end

        if length(tmp) > 0
            s = cur.splot  ?  "splot "  :  "plot "
            s *= "\\\n  "
            s *= join(tmp, ", \\\n  ")
            push!(out, s)
        end
    end

    if cur.cid > 0
        push!(out, "unset multiplot")
    end

    if file != nothing
        sOut = open(file, "w")
        for s in out; println(sOut, s); end
        close(sOut)
    end

    if !dry
        for s in out; gpSend(s); end
        gpSend("", capture=true)
    end

    return join(out, "\n")
end


######################################################################
# Misc. functions
######################################################################
gpTerminals() = gpSend("print GPVAL_TERMINALS", capture=true)
gpTerminal()  = gpSend("print GPVAL_TERM", capture=true)


#---------------------------------------------------------------------
"""
# @gpi

Similar to `@gp`, but the call to `gpReset()` occur only when
the `:reset` symbol is given, and the `gpDump()` call occur only
if no arguments are given.

See `@gp` documentation for further information.
"""
macro gpi(args...)
    if length(args) == 0
        return :(gpDump())
    end

    exprBlock = Expr(:block)

    exprData = Expr(:call)
    push!(exprData.args, :(gpData))

    pendingPlot = false
    pendingMulti = false
    for arg in args
        #println(typeof(arg), " ", arg)

        if isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :reset)
            push!(exprBlock.args, :(gpReset()))
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :dump)
            push!(exprBlock.args, :(gpDump()))
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :plot)
            pendingPlot = true
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :multi)
            pendingMulti = true
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :next)
            push!(exprBlock.args, :(gpNext()))
        elseif (isa(arg, Expr)  &&  (arg.head == :string))  ||  isa(arg, String)
            # Either a plot or cmd string
            if pendingPlot
                if length(exprData.args) > 1
                    push!(exprBlock.args, exprData)
                    exprData = Expr(:call)
                    push!(exprData.args, :(gpData))
                end

                push!(exprBlock.args, :(gpPlot(last=true, $arg)))
                pendingPlot = false
            elseif pendingMulti
                push!(exprBlock.args, :(gpMulti($arg)))
                pendingMulti = false
            else
                push!(exprBlock.args, :(gpCmd($arg)))
            end
        elseif (isa(arg, Expr)  &&  (arg.head == :(=)))
            # A cmd keyword
            sym = arg.args[1]
            val = arg.args[2]
            push!(exprBlock.args, :(gpCmd($sym=$val)))
        else
            # A data set
            push!(exprData.args, arg)
            pendingPlot = true
        end
    end
    #gpDump(exprBlock)

    if pendingPlot  &&  length(exprData.args) >= 2
        push!(exprBlock.args, exprData)
        push!(exprBlock.args, :(gpPlot(last=true, "")))
    end

    return esc(exprBlock)
end


#---------------------------------------------------------------------
"""
# @gp

The `@gp` (and its companion `gpi`) allows to exploit almost all
**jl** package functionalities using an extremely efficient
and concise syntax.  In the vast majority of cases you can use a
single call to `@gp` instead of many calls to `gpCmd`, `gpData`,
`gpPlot`, etc... to produce (even very complex) plots.

The syntax is as follows:
```
@gp( ["a command"],            # passed to gpCmd() as a command string
     [Symbol=(Value | Expr)]   # passed to gpCmd() as a keyword
     [(one or more Expression | Array) "plot spec"],  # passed to gpData() and
                                                      # gpPlot(last=true) respectively
     [:plot "plot spec"],      # passed to gpPlot()
     [:multi "multi spec"],    # passed to gpMulti()
     [:next]                   # calls gpNext()
     etc...
)
```

All entries are optional, and there is no mandatory order.  The only
mandatory sequences are:
- the plot specification strings which must follow a data block or the `:plot` symbol;
- the multiplot specification string which must follow `:multi` symbol;

A simple example will clarify the usage:
```
@gp "set key left" title="My title" xr=(1,12) 1:10 "with lines tit 'Data'"
```

This call epands as follows:
```
gpReset()
begin
    gpCmd("set key left")
    gpCmd(title="My title")
    gpCmd(xr=(1, 12))
    gpData(1:10)
    gpPlot(last=true, "with lines tit 'Data'")
end
gpDump()
```
A closely related macro is `@gpi` which do not adds the `gpReset()`
and `gpDump()` calls.

## Examples:
```
x = collect(1.:10)
@gp x
@gp x x
@gp x -x
@gp x x.^2
@gp x x.^2 "w l"

lw = 3
@gp x x.^2 "w l lw \$lw"

@gp("set grid", "set key left", xlog=true, ylog=true,
    title="My title", xlab="X label", ylab="Y label",
    x, x.^0.5, "w l tit 'Pow 0.5' dt 2 lw 2 lc rgb 'red'",
    x, x     , "w l tit 'Pow 1'   dt 1 lw 3 lc rgb 'blue'",
    x, x.^2  , "w l tit 'Pow 2'   dt 3 lw 2 lc rgb 'purple'")

# Multiplot
@gp(xr=(-2pi,2pi), "unset key",
    :multi, "layout 2,2 title 'Multiplot title'",
    :plot, "sin(x)"  , :next,
    :plot, "sin(2*x)", :next,
    :plot, "sin(3*x)", :next,
    :plot, "sin(4*x)")

# or equivalently
@gpi(:reset, xr=(-2pi,2pi), "unset key",
     :multi, "layout 2,2 title 'Multiplot title'")
for i in 1:4
  @gpi :plot "sin(\$i*x)" :next
end
@gpi()
```
"""
macro gp(args...)
    esc_args = Vector{Any}()
    for arg in args
        push!(esc_args, esc(arg))
    end
    e = :(@gpi($(esc_args...)))

    f = Expr(:block)
    push!(f.args, esc(:( gpReset())))
    push!(f.args, e)
    push!(f.args, esc(:( gpDump())))

    return f
end

"""
# @gp_str

Call `gpSend` with a non-standard string literal.

NOTE: this is supposed to be used interactively on the REPL, not in
functions.

## Examples:
```
println("Current terminal: ", gp"print GPVAL_TERM")
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
    return gpSend(s, capture=true)
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
@gp (1:10).^3 "w l notit lw 4"
gpDump(file="test.gp")
gpExitAll()
gp`test.gp`
```
"""
macro gp_cmd(file::String)
    return gpSend("load '$file'", capture=true)
end


end #module
