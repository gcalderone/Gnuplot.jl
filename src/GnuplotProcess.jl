module GnuplotProcess

import Base.reset

export GPProcess, gpexec, quit, terminal, terminals, gpvars

# ---------------------------------------------------------------------
function gpversion(cmd)
    proc = open(`$cmd --version`, read=true)
    s = String(read(proc))
    if !success(proc)
        error("An error occurred while running: " * string(cmd))
    end

    s = split(s, " ")
    ver = ""
    for token in s
        try
            return VersionNumber("$token")
        catch
        end
    end
    error("Can't identify gnuplot version")
end


# ---------------------------------------------------------------------
mutable struct Options
    cmd::String
    verbose::Bool
    Options() = new("gnuplot", false)
end


# ---------------------------------------------------------------------
struct GPProcess
    sid::Symbol
    options::Options
    pin::Base.Pipe;
    perr::Base.Pipe;
    proc::Base.Process;
    channel::Channel{String};

    function GPProcess(sid::Symbol, options=Options())
        ver = gpversion(options.cmd)
        @assert ver >= v"5.0" "gnuplot ver. >= 5.0 is required, but " * string(ver) * " was found."

        pin  = Base.Pipe()
        pout = Base.Pipe()
        perr = Base.Pipe()
        proc = run(pipeline(`$(options.cmd)`, stdin=pin, stdout=pout, stderr=perr), wait=false)

        # Close unused sides of the pipes
        Base.close(pout.in)
        Base.close(perr.in)
        Base.close(pin.out)
        Base.start_reading(pout.out)
        Base.start_reading(perr.out)

        out = new(sid, deepcopy(options), pin, perr, proc, Channel{String}(10000))

        # Start reading tasks
        @async readTask(out)
        @async while !eof(pout) # see PR #51
            write(stdout, readavailable(pout))
        end

        # The stderr of the gnuplot process goes to Julia which can parse
        # UTF8 characters (regardless of the terminal).
        gpexec(out, "set encoding utf8")
        reset(out)
        return out
    end
end


# ---------------------------------------------------------------------
function readTask(gp::GPProcess)
    pagerTokens() = ["Press return for more:"]

    captureID = 0
    function gpreadline()
        line = ""
        while true
            c = read(gp.perr, Char)
            (c == '\r')  &&  continue
            (c == '\n')  &&  break
            line *= c
            for token in pagerTokens()  # handle pager interaction
                if (length(line) == length(token))  &&  (line == token)
                    # GNUPLOT_CAPTURE_END may be lost when pager is
                    # running: send it again.
                    captureID += 1
                    write(gp.pin, "\nprint 'GNUPLOT_CAPTURE_END $(captureID)'\n")
                    line = ""
                end
            end
        end
        return line
    end

    try
        saveOutput = false
        while isopen(gp.perr)
            line = gpreadline()

            if line == "GNUPLOT_CAPTURE_BEGIN"
                saveOutput = true
            elseif line == "GNUPLOT_CAPTURE_END $(captureID)"
                saveOutput = false
                put!(gp.channel, "GNUPLOT_CAPTURE_END")
                captureID = 0
            elseif !isnothing(findfirst("GNUPLOT_CAPTURE_END", line))
                ;# old GNUPLOT_CAPTURE_END, ignore it
            else
                if line != ""
                    if gp.options.verbose  ||  !saveOutput
                        printstyled(color=:cyan, "GNUPLOT ($(gp.sid)) -> $line\n")
                    end
                end
                (saveOutput)  &&  (put!(gp.channel, line))
            end
        end
    catch err
        if isopen(gp.perr)
            @error "Error occurred in readTask for session $(gp.sid)"
            @show(err)
        else
            put!(gp.channel, "GNUPLOT_CAPTURE_END")
        end
    end
    if gp.options.verbose
        printstyled(color=:red, "GNUPLOT ($(gp.sid)) Process terminated\n")
    end
end


# ---------------------------------------------------------------------
function sendcmd(gp::GPProcess, str::AbstractString)
    if gp.options.verbose  &&  isnothing(findfirst("GNUPLOT_CAPTURE_", str))
        printstyled(color=:light_yellow, "GNUPLOT ($(gp.sid)) $str\n")
    end
    w = write(gp.pin, strip(str) * "\n")
    w <= 0  &&  error("Writing on gnuplot STDIN pipe returned $w")
    flush(gp.pin)
    return w
end


# ---------------------------------------------------------------------
function sendcmd_capture_reply(gp::GPProcess, str::AbstractString)    
    sendcmd(gp, "print 'GNUPLOT_CAPTURE_BEGIN'")
    sendcmd(gp, str)
    sendcmd(gp, "print 'GNUPLOT_CAPTURE_END 0'")

    out = Vector{String}()
    while true
        l = take!(gp.channel)
        l == "GNUPLOT_CAPTURE_END"  &&  break
        push!(out, l)
    end
    return join(out, "\n")
end


# ---------------------------------------------------------------------
function gpexec(gp::GPProcess, str::AbstractString)
    out = sendcmd_capture_reply(gp, str)
    verbose = gp.options.verbose
    gp.options.verbose = false
    errno = sendcmd_capture_reply(gp, "print GPVAL_ERRNO")
    if errno != "0"
        errmsg = sendcmd_capture_reply(gp, "print GPVAL_ERRMSG")
        gp.options.verbose = verbose
        write(gp.pin, "reset error\n")
        error("Gnuplot error: $errmsg")
    end
    gp.options.verbose = verbose
    return out
end


# ---------------------------------------------------------------------
function reset(gp::GPProcess)
    if gp.options.verbose
        printstyled(color=:light_black, "GNUPLOT ($(gp.sid)) -------------------------------------------\n")
    end
    gpexec(gp, "unset multiplot")
    gpexec(gp, "set output")
    gpexec(gp, "reset session")
    return nothing
end


# ---------------------------------------------------------------------
callback_exit(gp::GPProcess, exitcode::Int) = nothing

function quit(gp::GPProcess)
    close(gp.pin)
    close(gp.perr)
    wait( gp.proc)
    exitcode = gp.proc.exitcode
    callback_exit(gp, exitcode)
    return exitcode
end


# --------------------------------------------------------------------
terminal(gp::GPProcess) = gpexec(gp, "print GPVAL_TERM, ' ', GPVAL_TERMOPTIONS")
terminals(gp::GPProcess) = string.(split(strip(gpexec(gp, "print GPVAL_TERMINALS")), " "))


# --------------------------------------------------------------------
function gpvars(gp::GPProcess)
    vars = string.(strip.(split(gpexec(gp, "show var all"), '\n')))

    out = Dict{Symbol, Union{String, Real}}()
    for v in vars
        if length(v) > 6
            if v[1:6] == "GPVAL_"
                v = v[7:end]
            end
        end
        s = string.(strip.(split(v, '=')))
        if length(s) == 2
            key = Symbol(s[1])
            if s[2][1] == '"'
                out[key] = s[2][2:prevind(s[2], end, 1)]
            else
                try
                    out[key] = Meta.parse(s[2])
                catch
                    out[key] = s[2]
                end
            end
        end
    end
    return (; zip(keys(out), values(out))...)
end

end
