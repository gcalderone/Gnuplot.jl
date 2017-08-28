module Gnuplot

using AbbrvKW

include("GnuplotInternals.jl")
importall .p_

######################################################################
# Get/set options
######################################################################

"""
# Gnuplot.getStartup

Return the gnuplot command(s) to be executed at the beginning of each
session.
"""
getStartup() = p_.main.startup

"""
# Gnuplot.getSpawnCmd

Return the command to spawn a gnuplot process.
"""
getSpawnCmd() = p_.main.gnuplotCmd

"""
# Gnuplot.getVerbose

Return the verbosity level.
"""
getVerbose() = p_.main.verboseLev


#---------------------------------------------------------------------
"""
# Gnuplot.setOption

Set package options.

## Example:
```
gp.setOption(cmd="/path/to/gnuplot", verb=2, startup="set term wxt")
```

## Keywords:
- `cmd::String`: command to spawn a gnuplot process;
- `startup::String`: gnuplot command to be executed at the beginning
  of each session;
- `verbose::Int`: verbosity level (in the range 0 ÷ 4)

The package options can beretrieved with: `gp.getStartup`,
`gp.getSpawnCmd` and `gp.getVerbose`.
"""
@AbbrvKW function setOption(;cmd::Union{Void,String}=nothing,
                            startup::Union{Void,String}=nothing,
                            verbose::Union{Void,Int}=nothing)
    if startup != nothing
        p_.main.startup = startup
    end

    if cmd != nothing
        p_.main.gnuplotCmd = cmd
        p_.checkGnuplotVersion()
    end

    if verbose != nothing
        @assert (0 <= verbose <= 4)
        p_.main.verboseLev = verbose
    end

    return nothing
end


######################################################################
# Functions to handle multiple gnuplot instances
######################################################################

#---------------------------------------------------------------------
"""
# Gnuplot.handles

Return a `Vector{Int}` of  available session handles.
"""
function handles()
    return deepcopy(p_.main.handles)
end


"""
# Gnuplot.current

Return the handle of the current session.
"""
function current()
    p_.getProcOrStartIt()
    return p_.main.handles[p_.main.curPos]
end


#---------------------------------------------------------------------
"""
# Gnuplot.setCurrent

Change the current session.

## Arguments:
- `handle::Int`: the handle of the session to select as current.

## See also:
- `gp.current`: return the current session handle;
- `gp.handles`: return the list of available handles.
"""
function setCurrent(handle)
    i = find(p_.main.handles .== handle)
    @assert length(i) == 1
    i = i[1]
    @assert Base.process_running(p_.main.procs[i].proc)

    p_.main.curPos = i
end


#---------------------------------------------------------------------
"""
# Gnuplot.session

Create a new session (by starting a new gnuplot process), make it the
current one, and return the new handle.

E.g., to compare the look and feel of two terminals:
```
id1 = gp.session()
gp.send("set term qt")
gp.send("plot sin(x)")

id2 = gp.session()
gp.send("set term wxt")
gp.send("plot sin(x)")

gp.setCurrent(id1)
gp.send("set title 'My title'")
gp.send("replot")

gp.setCurrent(id2)
gp.send("set title 'My title'")
gp.send("replot")

gp.exitAll()
```
"""
function session()
    if length(p_.main.handles) > 0
        newhandle = max(p_.main.handles...) + 1
    else
        newhandle = 1
    end

    if p_.main.gnuplotCmd == ""
        p_.main.gnuplotCmd = "gnuplot"
        p_.checkGnuplotVersion()
    end

    push!(p_.main.procs,  p_.GnuplotProc(p_.main.gnuplotCmd))
    push!(p_.main.states, p_.GnuplotSession())
    push!(p_.main.handles, newhandle)
    p_.main.curPos = length(p_.main.handles)

    # Start reading tasks for STDOUT and STDERR
    @async p_.readTask(p_.main.procs[end].pout, p_.main.procs[end].channel, id=newhandle)
    @async p_.readTask(p_.main.procs[end].perr, p_.main.procs[end].channel, id=newhandle)

    if p_.main.startup != ""
        cmd(p_.main.startup)
    end

    p_.log(1, "New session started with handle $newhandle")
    return newhandle
end


#---------------------------------------------------------------------
"""
# Gnuplot.exit

Close current session and quit the corresponding gnuplot process.
"""
function exit()
    if p_.main.curPos == 0
        return 0
    end

    p = p_.main.procs[p_.main.curPos]
    close(p.pin)
    close(p.pout)
    close(p.perr)
    wait(p.proc)
    @assert !Base.process_running(p.proc)

    p_.log(1, string("Process exited with status ", p.proc.exitcode))

    deleteat!(p_.main.procs  , p_.main.curPos)
    deleteat!(p_.main.states , p_.main.curPos)
    deleteat!(p_.main.handles, p_.main.curPos)

    if length(p_.main.handles) > 0
        setCurrent(max(p_.main.handles...))
    else
        p_.main.curPos = 0
    end

    return p.proc.exitcode
end


#---------------------------------------------------------------------
"""
# Gnuplot.exitAll

Repeatedly call `gp.exit` until all sessions are closed.
"""
function exitAll()
    while length(p_.main.handles) > 0
        exit()
    end
    return nothing
end


######################################################################
# Send data and commands to Gnuplot
######################################################################

"""
# Gnuplot.send

Send a string to the current session's gnuplot STDIN.

The commands sent through `gp.send` are not stored in the current
session (use `gp.cmd` to save commands in the current session).

## Example:
```
println("Current terminal: ", gp.send("print GPVAL_TERM", capture=true))
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `capture::Bool`: if `true` waits until gnuplot provide a complete
  reply, and return it as a `Vector{String}`.  Otherwise return
  `nothing` immediately.
"""
@AbbrvKW function send(cmd::String; capture::Bool=false)
    p = p_.getProcOrStartIt()

    if capture
        write(p.pin, "print 'GNUPLOT_JL_SAVE_OUTPUT'\n")
    end

    for s in split(cmd, "\n")
        w = write(p.pin, strip(s) * "\n")
        p_.log(2, "-> $s", color=p_.main.colorIn)
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

######################################################################
# Handle session, and send data/commands to Gnuplot
######################################################################

#---------------------------------------------------------------------
"""
# Gnuplot.reset

Send a 'reset session' command to gnuplot and delete all commands,
data, and plots in the current session.
"""
function reset()
    send("reset session", capture=true)
    p_.main.states[p_.main.curPos] = p_.GnuplotSession()
    if p_.main.startup != ""
        cmd(p_.main.startup)
    end
    return nothing
end


#---------------------------------------------------------------------
"""
# Gnuplot.cmd

Send a command to gnuplot process and store it in the current session.
A few, commonly used, commands may be specified through keywords (see
below).

## Examples:
```
gp.cmd("set grid")
gp.cmd("set key left", xrange=(1,3))
gp.cmd(title="My title", xlab="X label", xla="Y label")
```

## Arguments:
- `cmd::String`: command to be sent.

## Keywords:
- `multiID::Int`: ID of the plot the commands belongs to (only useful
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
@AbbrvKW function cmd(s::String="";
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

    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]
    splot == nothing  ||  (cur.splot = splot)
    mID = multiID == nothing  ?  cur.multiID  :  multiID

    if s != ""
        push!(cur.cmds, p_.MultiCmd(s, mID))
        if mID == 0
            send(s)
        end
    end

    xrange == nothing ||  cmd(multiID=mID, "set xrange [" * join(xrange, ":") * "]")
    yrange == nothing ||  cmd(multiID=mID, "set yrange [" * join(yrange, ":") * "]")
    zrange == nothing ||  cmd(multiID=mID, "set zrange [" * join(zrange, ":") * "]")

    title  == nothing ||  cmd(multiID=mID, "set title  '" * title  * "'")
    xlabel == nothing ||  cmd(multiID=mID, "set xlabel '" * xlabel * "'")
    ylabel == nothing ||  cmd(multiID=mID, "set ylabel '" * ylabel * "'")
    zlabel == nothing ||  cmd(multiID=mID, "set zlabel '" * zlabel * "'")

    xlog   == nothing ||  cmd(multiID=mID, (xlog  ?  ""  :  "un") * "set logscale x")
    ylog   == nothing ||  cmd(multiID=mID, (ylog  ?  ""  :  "un") * "set logscale y")
    zlog   == nothing ||  cmd(multiID=mID, (zlog  ?  ""  :  "un") * "set logscale z")

    return nothing
end


#---------------------------------------------------------------------
"""
# Gnuplot.data

Send data to the gnuplot process, store it in the current session, and
return the name of the data block (to be later used with `gp.plot`).

## Example:
```
x = collect(1.:10)

# Automatically generated data block name
name1 = gp.data(x, x.^2)

# Specify a prefix for the data block name, a sequential counter will
# be appended to ensure the black names are unique
name2 = gp.data(x, x.^2.2, prefix="MyPrefix")

# Specify the whole data block name.  NOTE: avoid using the same name
# multiple times!
name3 = gp.data(x, x.^1.8, name="MyChosenName")

gp.plot(name1)
gp.plot(name2)
gp.plot(name3)
gp.dump()
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
function data(data::Vararg{AbstractArray{T,1},N};
                 name::Union{Void,String}=nothing,
                 prefix::Union{Void,String}=nothing) where {T<:Number,N}
    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]

    if name == nothing
        name = p_.mkBlockName(prefix=prefix)
    end
    name = "\$$name"

    for i in 2:length(data)
        @assert length(data[1]) == length(data[i])
    end

    v = "$name << EOD"
    push!(cur.data, v)
    send(v)

    origVerb = p_.main.verboseLev
    for i in 1:length(data[1])
        v = ""
        for j in 1:length(data)
            v *= " " * string(data[j][i])
        end
        push!(cur.data, v)

        if i>3  &&  i<=(length(data[1])-3)  &&   p_.main.verboseLev < 4
            p_.log(2, "...", color=p_.main.colorIn)            
            p_.main.verboseLev = 0
        else
            p_.main.verboseLev = origVerb
        end

        send(v)
    end
    p_.main.verboseLev = origVerb

    v = "EOD"
    push!(cur.data, v)
    send(v)

    cur.lastDataName = name

    return name
end


#---------------------------------------------------------------------
"""
# Gnuplot.lastData

Return the name of the last data block.
"""
function lastData()
    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]
    return cur.lastDataName
end


#---------------------------------------------------------------------
"""
# Gnuplot.getVal

Return the value of one (or more) gnuplot variables.

## Example
- argtuple of strings with gnuplot variable 
"""
function getVal(args...)
    out = Vector{String}()
    for arg in args
        push!(out, string(send("print $arg", capture=true)...))
    end

    if length(out) == 1
        out = out[1]
    end

    return out
end


#---------------------------------------------------------------------
"""
# Gnuplot.plot

Add a new plot/splot comand to the current session

## Example:
```
x = collect(1.:10)

gp.data(x, x.^2)
gp.plot(last=true, "w l tit 'Pow 2'")

src = gp.data(x, x.^2.2)
gp.plot("\$src w l tit 'Pow 2.2'")

# Re use the same data block
gp.plot("\$src u 1:(\\\$2+10) w l tit 'Pow 2.2, offset=10'")

gp.dump() # Do the plot
```

## Arguments:
- `spec::String`: plot command (see Gnuplot manual) without the
  leading "plot" string;

## Keywords:

- `file::String`: if given the plot command will be prefixed with
  `'\$file'`;
- `lastData::Bool`: if true the plot command will be prefixed with the
  last inserted data block name;
- `multiID::Int`: ID of the plot the command belongs to (only useful
  for multiplots);
"""
@AbbrvKW function plot(spec::String;
                       lastData::Bool=false,
                       file::Union{Void,String}=nothing,
                       multiID::Union{Void,Int}=nothing)

    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]
    mID = multiID == nothing  ?  cur.multiID  :  multiID

    src = ""
    if lastData
        src = cur.lastDataName
    elseif file != nothing
        src = "'" * file * "'"
    end
    push!(cur.plot, p_.MultiCmd("$src $spec", mID))
    return nothing
end


#---------------------------------------------------------------------
"""
# Gnuplot.multi

Initialize a multiplot (through the "set multiplot" Gnuplot command).

## Arguments:

- `multiCmd::String`: multiplot command (see Gnuplot manual) without
  the leading "set multiplot" string;

## See also: `gp.next`.
"""
function multi(multiCmd::String="")
    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]
    if cur.multiID != 0
        error("Current multiplot ID is $cur.multiID, while it should be 0")
    end

    cur.multiID += 1
    cmd("set multiplot $multiCmd")

    # Ensure all plot commands have ID >= 1
    for p in cur.plot
        p.id < 1  &&  (p.id = 1)
    end

    return nothing
end


#---------------------------------------------------------------------
"""
# Gnuplot.next

Select next slot for multiplot sessions.
"""
function next()
    p_.getProcOrStartIt()
    cur = p_.main.states[p_.main.curPos]
    cur.multiID += 1
    return nothing
end


#---------------------------------------------------------------------
"""
# Gnuplot.dump

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
@AbbrvKW function dump(; all::Bool=false,
                          dry::Bool=false,
                          cmd::Bool=false,
                          data::Bool=false,
                          file::Union{Void,String}=nothing)

    if p_.main.curPos == 0
        return ""
    end

    if file != nothing
        all = true
        dry = true
    end

    cur = p_.main.states[p_.main.curPos]
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
        for s in out; send(s); end
        send("", capture=true)
    end

    return join(out, "\n")
end


######################################################################
# Misc. functions
######################################################################
terminals() = send("print GPVAL_TERMINALS", capture=true)
terminal()  = send("print GPVAL_TERM", capture=true)


######################################################################
# Exported symbols
######################################################################

export @gpi, @gp, @gp_str, @gp_cmd

#---------------------------------------------------------------------
"""
# Gnuplot.@gpi

Similar to `@gp`, but the call to `Gnuplot.reset()` occur only when
the `:reset` symbol is given, and the `Gnuplot.dump()` call occur only
if no arguments are given.

See `@gp` documentation for further information.
"""
macro gpi(args...)
    if length(args) == 0
        return :(Gnuplot.dump())
    end

    exprBlock = Expr(:block)

    exprData = Expr(:call)
    push!(exprData.args, :(Gnuplot.data))

    pendingPlot = false
    pendingMulti = false
    for arg in args
        #println(typeof(arg), " ", arg)

        if isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :reset)
            push!(exprBlock.args, :(Gnuplot.reset()))
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :plot)
            pendingPlot = true
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :multi)
            pendingMulti = true
        elseif isa(arg, Expr)  &&  (arg.head == :quote)  &&  (arg.args[1] == :next)
            push!(exprBlock.args, :(Gnuplot.next()))
        elseif (isa(arg, Expr)  &&  (arg.head == :string))  ||  isa(arg, String)
            # Either a plot or cmd string
            if pendingPlot
                if length(exprData.args) > 1
                    push!(exprBlock.args, exprData)
                    exprData = Expr(:call)
                    push!(exprData.args, :(Gnuplot.data))
                end

                push!(exprBlock.args, :(Gnuplot.plot(last=true, $arg)))
                pendingPlot = false
            elseif pendingMulti
                push!(exprBlock.args, :(Gnuplot.multi($arg)))
                pendingMulti = false
            else
                push!(exprBlock.args, :(Gnuplot.cmd($arg)))
            end
        elseif (isa(arg, Expr)  &&  (arg.head == :(=)))
            # A cmd keyword
            sym = arg.args[1]
            val = arg.args[2]
            push!(exprBlock.args, :(Gnuplot.cmd($sym=$val)))
        else
            # A data set
            push!(exprData.args, arg)
            pendingPlot = true
        end
    end
    #dump(exprBlock)

    if pendingPlot  &&  length(exprData.args) >= 2
        push!(exprBlock.args, exprData)
        push!(exprBlock.args, :(Gnuplot.plot(last=true, "")))
    end

    return esc(exprBlock)
end


#---------------------------------------------------------------------
"""
# Gnuplot.@gp

The `@gp` (and its companion `gpi`) allows to exploit almost all
**Gnuplot.jl** package functionalities using an extremely efficient
and concise syntax.  In the vast majority of cases you can use a
single call to `@gp` instead of many calls to `gp.cmd`, `gp.data`,
`gp.plot`, etc... to produce (even very complex) plots.

The syntax is as follows:
```
@gp( ["a command"],            # passed to gp.cmd() as a command string
     [Symbol=(Value | Expr)]   # passed to gp.cmd() as a keyword
     [(one or more Expression | Array) "plot spec"],  # passed to gp.data() and
                                                      # gp.plot(last=true) respectively
     [:plot "plot spec"],      # passed to gp.plot()
     [:multi "multi spec"],    # passed to gp.multi()
     [:next]                   # calls gp.next()
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
Gnuplot.reset()
begin 
    Gnuplot.cmd("set key left")
    Gnuplot.cmd(title="My title")
    Gnuplot.cmd(xr=(1, 12))
    Gnuplot.data(1:10)
    Gnuplot.plot(last=true, "with lines tit 'Data'")
end
Gnuplot.dump()
```
A closely related macro is `@gpi` which do not adds the `Gnuplot.reset()`
and `Gnuplot.dump()` calls.

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
    push!(f.args, esc(:( Gnuplot.reset())))
    push!(f.args, e)
    push!(f.args, esc(:( Gnuplot.dump())))

    return f
end

"""
# Gnuplot.@gp_str

Call `gp.send` with a non-standard string literal.

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
    return Gnuplot.send(s, capture=true)
end


#---------------------------------------------------------------------
"""
# Gnuplot.@gp_cmd

Call the gnuplot "load" command passing the filename given as
non-standard string literal.

NOTE: this is supposed to be used interactively on the REPL, not in
functions.

Example:
```
@gp (1:10).^3 "w l notit lw 4"
gp.dump(file="test.gp")
gp.exitAll()
gp`test.gp`
```
"""
macro gp_cmd(file::String)
    return Gnuplot.send("load '$file'", capture=true)
end


end #module
