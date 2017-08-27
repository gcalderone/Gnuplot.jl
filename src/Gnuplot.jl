module Gnuplot

using AbbrvKW

export gp_getStartup, gp_getSpawnCmd, gp_getVerbose, gp_setOption,
       gp_handles, gp_current, gp_setCurrent, gp_new, gp_exit, gp_exitAll,
       gp_send, gp_reset, gp_cmd, gp_data, gp_plot, gp_multi, gp_next, gp_dump,
       @gp_str, @gp, @gpw, gp_load, gp_terminals, gp_terminal


######################################################################
# Structure definitions
######################################################################

"""
Structure containing the `Pipe` and `Process` objects associated to a
Gnuplot process.
"""
mutable struct GnuplotProc
    pin::Base.Pipe
    pout::Base.Pipe
    perr::Base.Pipe
    proc::Base.Process
    channel::Channel{String}

"""
Start a new gnuplot process using the command given in the `cmd` argument.
"""
    function GnuplotProc(cmd::String)
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

        return this
	end
end


#---------------------------------------------------------------------
"""
Structure containing a single command and the associated multiplot index
"""
mutable struct MultiCmd
  cmd::String    # command
  id::Int        # multiplot index
end

"""
Structure containing the state of a single gnuplot session.
"""
mutable struct GnuplotState
  blockCnt::Int           # data blocks counter
  cmds::Vector{MultiCmd}  # gnuplot commands
  data::Vector{String}    # data blocks
  plot::Vector{MultiCmd}  # plot specifications associated to each data block
  splot::Bool             # plot / splot session
  lastDataName::String    # name of the last data block
  multiID::Int            # current multiplot index (0 if no multiplot)

  GnuplotState() = new(1, Vector{MultiCmd}(), Vector{String}(), Vector{MultiCmd}(), false, "", 0)
end


#---------------------------------------------------------------------
"""
Structure containing the global package state.
"""
mutable struct MainState
  colorOut::Symbol              # gnuplot STDOUT is printed with this color
  colorIn::Symbol               # gnuplot STDIN is printed with this color
  verboseLev::Int               # verbosity level (0 - 3), default: 3
  gnuplotCmd::String            # command used to start the gnuplot process
  startup::String               # commands automatically sent to each new gnuplot process
  procs::Vector{GnuplotProc}    # array of currently active gnuplot process and pipes
  states::Vector{GnuplotState}  # array of gnuplot sessions
  handles::Vector{Int}          # handles of gnuplot sessions
  curPos::Int                   # index in the procs, states and handles array of current session

  MainState() = new(:cyan, :yellow, 3,
                    "", "",
                    Vector{GnuplotProc}(), Vector{GnuplotState}(), Vector{Int}(),
                    0)
end


######################################################################
# Private functions
######################################################################

"""
Check gnuplot is runnable with the command given in `main.gnuplotCmd`.
Also check that gnuplot version is >= 4.7 (required to use data
blocks).
"""
function checkGnuplotVersion()
    cmd = `$(main.gnuplotCmd) --version`
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
        error("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    gp_log(1, "Found gnuplot version: " * string(ver))
end


#---------------------------------------------------------------------
"""
Logging facility (each line is prefixed with the session handle.)

Printing occur only if the logging level is >= current verbosity
level.
"""
function gp_log(level::Int, s::String; id=nothing, color=nothing)
    if (main.verboseLev < level)
        return
    end

    color == nothing  &&  (color = main.colorOut)

    prefix = ""
    if (id == nothing)  &&  (main.curPos > 0)
        id = main.handles[main.curPos]
    end
    prefix = string("GP(", id, ")")

    a = split(s, "\n")
    for v in a
        print_with_color(color, "$prefix $v\n")
    end
end


#---------------------------------------------------------------------
"""
Read gnuplot outputs, and optionally redirect to a `Channel`.

This fuction is supposed to be run in a `Task`.
"""
function gp_readTask(sIN, channel; kw...)
    saveOutput::Bool = false
    while isopen(sIN)
        line = convert(String, readline(sIN))

        if line == "GNUPLOT_JL_SAVE_OUTPUT"
            saveOutput = true
            gp_log(4, "|start of captured data =========================")
        else
            if saveOutput
                put!(channel, line)
            end

            if line == "GNUPLOT_JL_SAVE_OUTPUT_END"
                saveOutput = false
                gp_log(4, "|end of captured data ===========================")
            elseif line != ""
                if saveOutput
                    gp_log(3, "|  " * line; kw...)
                else
                    gp_log(2, "   " * line; kw...)
                end
            end
        end
    end

    gp_log(1, "pipe closed"; kw...)
end


#---------------------------------------------------------------------
"""
Return a unique data block name
"""
@AbbrvKW function gp_mkBlockName(;prefix::Union{Void,String}=nothing)
    if prefix == nothing
        prefix = string("d", gp_current())
    end

    cur = main.states[main.curPos]
    name = string(prefix, "_", cur.blockCnt)
    cur.blockCnt += 1

    return name
end


#---------------------------------------------------------------------
"""
Return the GnuplotProc structure of current session, or start a new
gnuplot process if none is running.
"""
function gp_getProcOrStartIt()
    if main.curPos == 0
        gp_log(1, "Starting a new gnuplot process...")
        id = gp_new()
    end

    p = main.procs[main.curPos]

    if !Base.process_running(p.proc)
        error("The current gnuplot process is no longer running.")
    end

    return p
end


######################################################################
# Get/set package options
######################################################################

"""
# Gnuplot.gp_getStartup

Return the gnuplot command to be executed at the beginning of each session.
"""
gp_getStartup() = main.startup

"""
# Gnuplot.gp_getSpawnCmd

Return the command to spawn a gnuplot process.
"""
gp_getSpawnCmd() = main.gnuplotCmd

"""
# Gnuplot.gp_getVerbose

Return the verbosity level.
"""
gp_getVerbose() = main.verboseLev


#---------------------------------------------------------------------
"""
# Gnuplot.gp_setOption

Set package options.

## Example:
```
gp_setOption(cmd="/path/to/gnuplot", verb=2, startup="set term wxt")
```

## Keywords:
- `cmd::String`: command to spawn a gnuplot process;
- `startup::String`: gnuplot command to be executed at the beginning of each session;
- `verbose::Int`: verbosity level (in the range 0 ÷ 4)

## See also: `gp_getStartup`, `gp_getSpawnCmd` and `gp_getVerbose`.
"""
@AbbrvKW function gp_setOption(;cmd::Union{Void,String}=nothing,
                               startup::Union{Void,String}=nothing,
                               verbose::Union{Void,Int}=nothing)
    if startup != nothing
        main.startup = startup
    end

    if cmd != nothing
        main.gnuplotCmd = cmd
        checkGnuplotVersion()
    end

    if verbose != nothing
        @assert (0 <= verbose <= 4)
        main.verboseLev = verbose
    end

    return nothing
end


######################################################################
# Handle multiple gnuplot instances
######################################################################

"""
# Gnuplot.gp_handles

Return a `Vector{Int}` of  available session handles.
"""
function gp_handles()
    return deepcopy(main.handles)
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_current

Return the handle of the current session.
"""
function gp_current()
    return main.handles[main.curPos]
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_setCurrent

Change the current session handle.

## Arguments:
- `handle::Int`: the handle of the session to select as current.

## See also:
- `gp_current`: return the current session handle;
- `gp_handles`: return the list of available handles.
"""
function gp_setCurrent(handle)
    i = find(main.handles .== handle)
    @assert length(i) == 1
    i = i[1]
    @assert Base.process_running(main.procs[i].proc)

    main.curPos = i
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_new

Create a new session (by starting a new gnuplot process), make it the
current one, and return the new handle.

E.g., to compare the look and feel of two terminals:
```
id1 = gp_new()
gp_send("set term qt")
gp_send("plot sin(x)")

id2 = gp_new()
gp_send("set term wxt")
gp_send("plot sin(x)")

gp_setCurrent(id1)
gp_send("set title 'My title'")
gp_send("replot")

gp_setCurrent(id2)
gp_send("set title 'My title'")
gp_send("replot")

gp_exitAll()
```
"""
function gp_new()
    if length(main.handles) > 0
        newhandle = max(main.handles...) + 1
    else
        newhandle = 1
    end

    if main.gnuplotCmd == ""
        gp_setOption(cmd="gnuplot")
    end

    push!(main.procs,  GnuplotProc(main.gnuplotCmd))
    push!(main.states, GnuplotState())
    push!(main.handles, newhandle)
    main.curPos = length(main.handles)

    # Start reading tasks for STDOUT and STDERR
    @async gp_readTask(main.procs[end].pout, main.procs[end].channel, id=newhandle)
    @async gp_readTask(main.procs[end].perr, main.procs[end].channel, id=newhandle)

    if main.startup != ""
        gp_cmd(main.startup)
    end

    gp_log(1, "New session started with handle $newhandle")
    return newhandle
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_exit

Close current session and quit the corresponding gnuplot process.
"""
function gp_exit()
    if main.curPos == 0
        return
    end

    p = main.procs[main.curPos]
    close(p.pin)
    close(p.pout)
    close(p.perr)
    wait(p.proc)
    @assert !Base.process_running(p.proc)

    gp_log(1, string("Process exited with status ", p.proc.exitcode))

    deleteat!(main.procs , main.curPos)
    deleteat!(main.states, main.curPos)
    deleteat!(main.handles   , main.curPos)

    if length(main.handles) > 0
        gp_setCurrent(max(main.handles...))
    else
        main.curPos = 0
    end

    return p.proc.exitcode
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_exitAll

Repeatedly call `gp_exit` until all sessions are closed.
"""
function gp_exitAll()
    while length(main.handles) > 0
        gp_exit()
    end
end


######################################################################
# Send data and commands to Gnuplot
######################################################################

"""
# Gnuplot.gp_send

Send a string to the current session's gnuplot STDIN.

The commands sent through `gp_send` are not stored in the current
session (use `gp_cmd` to save commands in the current session).

## Example:
```
println("Current terminal: ", gp_send("print GPVAL_TERM", capture=true))
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `capture::Bool`: if `true` waits until gnuplot provide a complete reply, and return it as a `Vector{String}`.  Otherwise return `nothing` immediately.
"""
@AbbrvKW function gp_send(cmd::String; capture::Bool=false)
    p = gp_getProcOrStartIt()

    if capture
        write(p.pin, "print 'GNUPLOT_JL_SAVE_OUTPUT'\n")
        gp_log(4, "-> Start capture", color=main.colorIn)
    end

    for s in split(cmd, "\n")
        w = write(p.pin, strip(s) * "\n")
        gp_log(2, "-> $s" , color=main.colorIn)
        w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    end

    if capture
        write(p.pin, "print 'GNUPLOT_JL_SAVE_OUTPUT_END'\n")
        gp_log(4, "-> End capture", color=main.colorIn)
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
# Gnuplot.gp_reset

Send a 'reset session' command to gnuplot and delete all commands,
data, and plots in the current session.
"""
function gp_reset()
    gp_send("reset session", capture=true)
    main.states[main.curPos] = GnuplotState()
    if main.startup != ""
        gp_cmd(main.startup)
    end
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_cmd

Send a command to gnuplot process and store it in the current session.
A few, commonly used, commands may be specified through keywords (see
below).

## Examples:
```
gp_cmd("set grid")
gp_cmd("set key left", xrange=(1,3))
gp_cmd(title="My title", xlab="X label", xla="Y label")
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `multiID::Int`: ID of the plot the commands belongs to (only useful for multiplots);
- `splot::Bool`: set to `true` for a "splot" gnuplot session, `false` for a "plot" one;
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
@AbbrvKW function gp_cmd(cmd::String=""; 
                         splot::Union{Void,Bool}=nothing,
                         multiID::Union{Void,Int}=nothing,
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

    gp_getProcOrStartIt()
    cur = main.states[main.curPos]
    splot == nothing  ||  (cur.splot = splot)
    mID = multiID == nothing  ?  cur.multiID  :  multiID

    if cmd != ""
        push!(cur.cmds, MultiCmd(cmd, mID))
        if mID == 0
            gp_send(cmd)
        end
    end

    xrange == nothing ||  gp_cmd(multiID=mID, "set xrange [" * join(xrange, ":") * "]")
    yrange == nothing ||  gp_cmd(multiID=mID, "set yrange [" * join(yrange, ":") * "]")
    zrange == nothing ||  gp_cmd(multiID=mID, "set zrange [" * join(zrange, ":") * "]")

    title  == nothing ||  gp_cmd(multiID=mID, "set title  '" * title  * "'")
    xlabel == nothing ||  gp_cmd(multiID=mID, "set xlabel '" * xlabel * "'")
    ylabel == nothing ||  gp_cmd(multiID=mID, "set ylabel '" * ylabel * "'")
    zlabel == nothing ||  gp_cmd(multiID=mID, "set zlabel '" * zlabel * "'")

    xlog   == nothing ||  gp_cmd(multiID=mID, (xlog  ?  ""  :  "un") * "set logscale x")
    ylog   == nothing ||  gp_cmd(multiID=mID, (ylog  ?  ""  :  "un") * "set logscale y")
    zlog   == nothing ||  gp_cmd(multiID=mID, (zlog  ?  ""  :  "un") * "set logscale z")
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_data

Send data to the gnuplot process, store it in the current session, and return the
name of the data block (to be later used with `gp_plot`).

## Example:
```
x = collect(1.:10)

# Automatically generated data block name
name1 = gp_data(x, x.^2)

# Specify a prefix for the data block name, a sequential counter will
# be appended to ensure the black names are unique
name2 = gp_data(x, x.^2.2, prefix="MyPrefix")

# Specify the whole data block name.  NOTE: avoid using the same name
# multiple times!
name3 = gp_data(x, x.^1.8, name="MyChosenName")

gp_plot(name1)
gp_plot(name2)
gp_plot(name3)
gp_dump()
```

## Arguments:
- `data::Vararg{AbstractArray{T,1},N} where {T<:Number,N}`: the data to be sent to gnuplot;

## Keywords:
- `name::String`: data block name.  If not given an automatically generated one will be used;
- `prefix::String`: prefix for data block name (an automatic counter will be appended);
"""
function gp_data(data::Vararg{AbstractArray{T,1},N};
                 name::Union{Void,String}=nothing,
                 prefix::Union{Void,String}=nothing) where {T<:Number,N}
    gp_getProcOrStartIt()
    cur = main.states[main.curPos]

    if name == nothing
        name = gp_mkBlockName(pre=prefix)
    end
    name = "\$$name"

    for i in 2:length(data)
        @assert length(data[1]) == length(data[i])
    end

    v = "$name << EOD"
    push!(cur.data, v)
    gp_send(v)
    for i in 1:length(data[1])
        v = ""
        for j in 1:length(data)
            v *= " " * string(data[j][i])
        end
        push!(cur.data, v)
        gp_send(v)
    end
    v = "EOD"
    push!(cur.data, v)
    gp_send(v)

    cur.lastDataName = name

    return name
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_plot

Add a new plot/splot comand to the current session

## Example:
```
x = collect(1.:10)

gp_data(x, x.^2)
gp_plot(last=true, "w l tit 'Pow 2'") # "" means use the last inserted data block

src = gp_data(x, x.^2.2)
gp_plot("\$src w l tit 'Pow 2.2'")

# Re use the same data block
gp_plot("\$src u 1:(\\\$2+10) w l tit 'Pow 2.2, offset=10'")

gp_dump() # Do the plot
```

## Arguments:
- `spec::String`: plot command (see Gnuplot manual) without the leading "plot" string;

## Keywords:
- `file::String`: if given the plot command will be prefixed with `'\$file'`;
- `lastData::Bool`: if true the plot command will be prefixed with the last inserted data block name;
- `multiID::Int`: ID of the plot the command belongs to (only useful for multiplots);
"""
@AbbrvKW function gp_plot(spec::String;
                          lastData::Bool=false,
                          file::Union{Void,String}=nothing,
                          multiID::Union{Void,Int}=nothing)

    gp_getProcOrStartIt()
    cur = main.states[main.curPos]
    mID = multiID == nothing  ?  cur.multiID  :  multiID

    src = ""
    if lastData
        src = cur.lastDataName
    elseif file != nothing 
        src = "'" * file * "'"
    end
    push!(cur.plot, MultiCmd("$src $spec", mID))
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_multi

Initialize a multiplot (through the "set multiplot" Gnuplot command).

## Arguments:
- `multiCmd::String`: multiplot command (see Gnuplot manual) without the leading "set multiplot" string;

## See also: `gp_next`.
"""
function gp_multi(multiCmd::String="")
    gp_getProcOrStartIt()
    cur = main.states[main.curPos]
    if cur.multiID != 0
        error("Current multiplot ID is $cur.multiID, while it should be 0")
    end

    gp_next()
    gp_cmd("set multiplot $multiCmd")
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_next

Select next slot for multiplot sessions.
"""
function gp_next()
    gp_getProcOrStartIt()
    cur = main.states[main.curPos]
    cur.multiID += 1
end


#---------------------------------------------------------------------
"""
# Gnuplot.gp_dump

Send all necessary commands to gnuplot to actually do the plot.
Optionally, the commands may be sent to a file.  In any case the
commands are returned as `Vector{String}`.

## Keywords:
- `all::Bool`: if true all commands and data will be sent again to gnuplot, if they were already sent (equivalent to `data=true, cmd=true`);
- `cmd::Bool`: if true all commands will be sent again to gnuplot, if they were already sent;
- `data::Bool`: if true all data will be sent again to gnuplot, if they were already sent;
- `dry::Bool`: if true no command/data will be sent to gnuplot;
- `file::String`: filename to redirect all outputs.  Implies `all=true, dry=true`.
"""
@AbbrvKW function gp_dump(; all::Bool=false,
                          dry::Bool=false,
                          cmd::Bool=false,
                          data::Bool=false,
                          file::Union{Void,String}=nothing)
    
    if main.curPos == 0
        return ""
    end

    if file != nothing 
        all = true
        dry = true
    end

    cur = main.states[main.curPos]
    out = Vector{String}()

    all  &&  (push!(out, "reset session"))

    if data || all
        for s in cur.data
            push!(out, s)
        end
    end

    for id in 0:cur.multiID
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

    if cur.multiID > 0
        push!(out, "unset multiplot")
    end
        
    if file != nothing 
        sOut = open(file, "w")
        for s in out; println(sOut, s); end
        close(sOut)
    end

    if !dry
        for s in out; gp_send(s); end
        gp_send("", capture=true)
    end

    return join(out, "\n")
end


######################################################################
# Facilities
######################################################################

"""
# Gnuplot.@gp_str

Call `gp_send` with a non-standard string literal.

NOTE: this is supposed to be used interactively on the REPL, not in
functions.

Example:
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
    gp_send(s)
end


#---------------------------------------------------------------------
"""
# Gnuplot.@gp

Allow
Main driver for the Gnuplot.jl package

This macro expands into proper calls to `gp_reset`, `gp_cmd`,
`gp_data`, `gp_plot` and `gp_dump` in a single call, hence it is a very
simple and quick way to produce (even very complex) plots.

The syntax is as follows:
```
@gp( ["a command"],            # passed to gp_cmd
     [Symbol=(Value | Expr)]   # passed to gp_cmd as a keyword
     [one or more (Expression | Array) "plot spec"],  # passed to gp_data and gp_plot
     etc...
)
```

Note that each entry is optional.  The only mandatory sequence is the
plot specification string (to be passed to `gp_plot`) which must
follow one (or more) data block(s).  If the data block is the last
argument in the call an empty plot specification string is used.

The following example:
```
@gp "set key left" title="My title" xr=(1,5) collect(1.:10) "with lines tit 'Data'"
```
- sets the legend on the left;
- sets the title of the plot
- sets the X axis range
- pass the 1:10 range as data block
- tells gnuplot to draw the data with lines
- sets the title of the data block
...all of this is done in one line!

The above example epands as follows:
```
gp_reset()
begin
    gp_cmd("set key left")
    gp_cmd(title="My title")
    gp_cmd(xr=(1, 5))
    gp_data(collect(1.0:10))
    gp_plot(last=true, "with lines tit 'Data'")
end
gp_dump()
```


Further Example:
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
```
"""
macro gp(args...)
    if length(args) == 0
        return :()
    end

    exprBlock = Expr(:block)

    exprData = Expr(:call)
    push!(exprData.args, :gp_data)

    pendingPlot = false
    pendingMulti = false
    for arg in args
        #println(typeof(arg), " ", arg)

        if isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :next)
            push!(exprBlock.args, :(gp_next()))
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :plot)
            pendingPlot = true
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :multi)
            pendingMulti = true
        elseif (isa(arg, Expr)  &&  (arg.head == :string))  ||  isa(arg, String)
            # Either a plot or cmd string
            if pendingPlot
                if length(exprData.args) > 1
                    push!(exprBlock.args, exprData)
                    exprData = Expr(:call)
                    push!(exprData.args, :gp_data)
                end

                push!(exprBlock.args, :(gp_plot(last=true, $arg)))
                pendingPlot = false
            elseif pendingMulti
                push!(exprBlock.args, :(gp_multi($arg)))
                pendingMulti = false
            else
                push!(exprBlock.args, :(gp_cmd($arg)))
            end
        elseif (isa(arg, Expr)  &&  (arg.head == :(=)))
            # A cmd keyword
            sym = arg.args[1]
            val = arg.args[2]
            push!(exprBlock.args, :(gp_cmd($sym=$val)))
        else
            # A data set
            push!(exprData.args, arg)
            pendingPlot = true
        end
    end
    #dump(exprBlock)

    if pendingPlot  &&  length(exprData.args) >= 2
        push!(exprBlock.args, exprData)
        push!(exprBlock.args, :(gp_plot(last=true, "")))
    end

    return esc(exprBlock)
end


#---------------------------------------------------------------------
"""
# Gnuplot.@gpw

Wraps a `@gp` call between `gp_reset()` and `gp_dump()` calls.
"""
macro gpw(args...)
    esc_args = Vector{Any}()
    for arg in args
        push!(esc_args, esc(arg))
    end
    e = :(@gp_($(esc_args...)))

    f = Expr(:block)
    push!(f.args, esc(:( gp_reset())))
    push!(f.args, e)
    push!(f.args, esc(:( gp_dump())))

    return f
end

#---------------------------------------------------------------------
"""
# Gnuplot.gp_load
"""
gp_load(file::String) = gp_send("load '$file'", capture=true)


#---------------------------------------------------------------------
gp_terminals() = gp_send("print GPVAL_TERMINALS", capture=true)
gp_terminal()  = gp_send("print GPVAL_TERM", capture=true)


######################################################################
# Module initialization
######################################################################
const main = MainState()

end #module
