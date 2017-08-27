######################################################################
# MODULE GnuplotInternals (private functions and definitions)
######################################################################
module p_

importall Gnuplot
const P_ = Gnuplot


import StatsBase.countmap


function findAbbrv(symLong::Vector{Symbol})
    if length(symLong) == 0 
        return symLong
    end

    out = Dict()
    for sym in symLong
        out[sym] = Vector{Symbol}()
    end

    symAbbr = deepcopy(symLong)
    symStr = convert.(String, symLong)
    kwCount = length(symLong)

    # Max length of string representation of keywords
    maxLen = maximum(length.(symStr))

    # Identify all abbreviations
    for len in 1:maxLen
        for i in 1:kwCount
            s = symStr[i]
            if length(s) >= len
                s = s[1:len]
                push!(symLong, symLong[i])
                push!(symAbbr, convert(Symbol, s))
                push!(symStr , s)
            end
        end
    end
    symStr = nothing # no longer needed

    # Identify unique abbreviations
    abbrCount = 0
    for (sym, count) in countmap(symAbbr)
        if count == 1
            i = find(symAbbr .== sym)
            @assert length(i) == 1
            i = i[1]
            if symLong[i] != symAbbr[i]
                push!(out[symLong[i]], symAbbr[i])
                abbrCount += 1
            end
        end
    end

    for (key, val) in out
        sort!(out[key])
    end

    return (out, abbrCount)
end


macro AbbrvKW(func)
    @assert func.head == :function "Not a function"

    if length(func.args[1].args) <= 1
        # Empty parameter list"
        return esc(func)
    end

    if (typeof(func.args[1].args[2]) != Expr)  ||
        (func.args[1].args[2].head != :parameters)
        # No keywords given
        return esc(func)
    end
    
    sym = Vector{Symbol}() # Symbol, long version
    typ = Dict()           # Data type
    splat = Symbol()
    splatFound = false    
    for k in func.args[1].args[2].args
        @assert typeof(k) == Expr "Expr expected"
        @assert k.head in (:kw, :(...)) "Expected :kw or :..., got $(k.head)"

        #dump(k)
        if k.head == :kw
            @assert typeof(k.args[1]) in (Expr, Symbol) "Expected Expr or Symbol"

            if typeof(k.args[1]) == Symbol
                push!(sym, k.args[1])
                typ[sym[end]] = :Any
            elseif typeof(k.args[1]) == Expr
                @assert k.args[1].head == :(::) "Expected :(::), got $(k.args[1].head)"
                push!(sym, k.args[1].args[1])
                typ[sym[end]] = k.args[1].args[2]
            end
        elseif k.head == :(...)
            splat = k.args[1]
            splatFound = true
        end
    end

    # Find abbreviations
    (abbr, count) = findAbbrv(sym)
    if count == 0
        # No abbreviations found
        return esc(func)
    end

    # Add a splat variable if not present
    if !splatFound
        splat = :_abbrvkw_
        a = :($splat...)
        a = a.args[1]
        push!(func.args[1].args[2].args, a)
        a = nothing
    end

    # Build output Expr
    expr = Expr(:block)
    push!(expr.args, :(_ii_ = 1))
    push!(expr.args, Expr(:while, :(_ii_ <= length($splat)), Expr(:block)))

    for (sym, tup) in abbr
        length(tup) > 0 || continue
        tup = tuple(tup...)
        push!(expr.args[end].args[end].args,
              :(
                if $(splat)[_ii_][1] in $tup
                typeassert($(splat)[_ii_][2], $(typ[sym]))
                $(sym) = $(splat)[_ii_][2]
                deleteat!($splat, _ii_)
                continue
                end
                ))
    end
    push!(expr.args[end].args[end].args, :(_ii_ += 1))
    push!(expr.args, :(_ii_ = nothing))

    if !splatFound
        push!(expr.args, :(if length($splat) !=0 ;
                           error("Unrecognized keyword abbreviation(s): " * string($splat))
                           end))
        push!(expr.args, :($splat = nothing))
    end

    @assert length(func.args) == 2 "Function Expr has " * string(length(func.args)) * " args"
    @assert func.args[2].head == :block "Function block is not a block, but " * string(func.args[2].head)

    prepend!(func.args[2].args, [expr])
    #@show func
    return esc(func)
end


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
Structure containing a single plot command and the associated
multiplot index.
"""
mutable struct MultiCmd
  cmd::String    # command
  id::Int        # multiplot index
end

"""
Structure containing the state of a single gnuplot session.
"""
mutable struct GnuplotSession
  blockCnt::Int           # data blocks counter
  cmds::Vector{MultiCmd}  # gnuplot commands
  data::Vector{String}    # data blocks
  plot::Vector{MultiCmd}  # plot specifications associated to each data block
  splot::Bool             # plot / splot session
  lastDataName::String    # name of the last data block
  multiID::Int            # current multiplot index (0 if no multiplot)

  GnuplotSession() = new(1, Vector{MultiCmd}(), Vector{String}(), 
                         Vector{MultiCmd}(), false, "", 0)
end


#---------------------------------------------------------------------
"""
Structure containing the global package state.
"""
mutable struct MainState
  colorOut::Symbol               # gnuplot STDOUT is printed with this color
  colorIn::Symbol                # gnuplot STDIN is printed with this color
  verboseLev::Int                # verbosity level (0 - 3), default: 3
  gnuplotCmd::String             # command used to start the gnuplot process
  startup::String                # commands automatically sent to each new gnuplot process
  procs::Vector{GnuplotProc}     # array of currently active gnuplot process and pipes
  states::Vector{GnuplotSession} # array of gnuplot sessions
  handles::Vector{Int}           # handles of gnuplot sessions
  curPos::Int                    # index in the procs, states and handles array of current session

  MainState() = new(:cyan, :yellow, 1,
                    "", "", Vector{GnuplotProc}(), Vector{GnuplotSession}(), 
                    Vector{Int}(), 0)
end


######################################################################
# Functions
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

    if ver < v"4.6"
        error("gnuplot ver. >= 4.7 is required, but " * string(ver) * " was found.")
    end
    log(1, "Found gnuplot version: " * string(ver))
    return ver
end


#---------------------------------------------------------------------
"""
Logging facility (each line is prefixed with the session handle.)

Printing occur only if the logging level is >= current verbosity
level.
"""
function log(level::Int, s::String; id=nothing, color=nothing)
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
    return nothing
end


#---------------------------------------------------------------------
"""
Read gnuplot outputs, and optionally redirect to a `Channel`.

This fuction is supposed to be run in a `Task`.
"""
function readTask(sIN, channel; kw...)
    saveOutput::Bool = false
    while isopen(sIN)
        line = convert(String, readline(sIN))

        if line == "GNUPLOT_JL_SAVE_OUTPUT"
            saveOutput = true
            log(4, "|start of captured data =========================")
        else
            if saveOutput
                put!(channel, line)
            end

            if line == "GNUPLOT_JL_SAVE_OUTPUT_END"
                saveOutput = false
                log(4, "|end of captured data ===========================")
            elseif line != ""
                if saveOutput
                    log(3, "|  " * line; kw...)
                else
                    log(2, "   " * line; kw...)
                end
            end
        end
    end

    log(1, "pipe closed"; kw...)
    return nothing
end


#---------------------------------------------------------------------
"""
Return a unique data block name
"""
function mkBlockName(;prefix::Union{Void,String}=nothing)
    if prefix == nothing
        prefix = string("d", main.handles[main.curPos])
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
function getProcOrStartIt()
    if main.curPos == 0
        log(1, "Starting a new gnuplot process...")
        id = P_.session()
    end

    p = main.procs[main.curPos]

    if !Base.process_running(p.proc)
        error("The current gnuplot process is no longer running.")
    end

    return p
end


######################################################################
# Module initialization
######################################################################
const main = MainState()

end #module
