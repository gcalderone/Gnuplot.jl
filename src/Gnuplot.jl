module Gnuplot

using StatsBase, ColorSchemes, ColorTypes, Colors, StructC14N, DataStructures
using REPL, ReplMaker

import Base.reset
import Base.write
import Base.show

export session_names, dataset_names, palette_names, linetypes, palette,
    terminal, terminals, test_terminal,
    stats, @gp, @gsp, save, gpexec,
    boxxy, contourlines, hist, recipe, gpvars, gpmargins, gpranges


# ╭───────────────────────────────────────────────────────────────────╮
# │                        TYPE DEFINITIONS                           │
# │                     User data representation                      │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
"""
    SessionID

A structure identifying a specific session.  Used in the `show` interface.
"""
struct SessionID
    sid::Symbol
    dump::Bool
end


"""
    Dataset

Abstract type for all dataset structures.
"""
abstract type Dataset end

"""
    DatasetEmpty

An empty dataset.
"""
struct DatasetEmpty <: Dataset
end

"""
    DatasetText

A dataset whose data are stored as a text buffer.

Transmission to gnuplot may be slow for large datasets, but no temporary file is involved, and the dataset can be saved directly into a gnuplot script.  Also, the constructor allows to build more flexible datasets (i.e. mixing arrays with different dimensions).

Constructors are defined as follows:
```julia
DatasetText(data::Vector{String})
DatasetText(data::Vararg{AbstractArray, N}) where N =
```
In the second form the type of elements of each array must be one of `Real`, `AbstractString` and `Missing`.
"""
mutable struct DatasetText <: Dataset
    preview::Vector{String}
    data::String
    DatasetText(::Val{:inner}, preview, data) = new(preview, data)
end

"""
    DatasetBin

A dataset whose data are stored as a binary file.

Ensure best performances for large datasets, but involve use of a temporary files.  When saving a script the file is stored in a directory with the same name as the main script file.

Constructors are defined as follows:
```julia
DatasetBin(cols::Vararg{AbstractMatrix, N}) where N
DatasetBin(cols::Vararg{AbstractVector, N}) where N
```
In both cases the element of the arrays must be a numeric type.
"""
mutable struct DatasetBin <: Dataset
    file::String
    source::String
    DatasetBin(::Val{:inner}, file, source) = new(file, source)
end

# ---------------------------------------------------------------------
"""
    PlotElement

Structure containing element(s) of a plot (commands, data, plot specifications) that can be used directly in `@gp` and `@gsp` calls.

# Fields
- `mid::Int`: multiplot ID (use 0 for single plots);
- `is3d::Bool`: true if the data are supposed to be displayed in a 3D plot;
- `cmds::Vector{String}`: commands to set plot properties;
- `name::String`: name of the dataset (use "" to automatically generate a unique name);
- `data::Dataset`: a dataset
- `plot::Vector{String}`: plot specifications for the associated `Dataset`;

The constructor is defined as follows:
```julia
PlotElement(;mid::Int=0, is3d::Bool=false,
            cmds::Union{String, Vector{String}}=Vector{String}(),
            name::String="",
            data::Dataset=DatasetEmpty(),
            plot::Union{String, Vector{String}}=Vector{String}(),
            kwargs...)
```
No field is mandatory, i.e. even `Gnuplot.PlotElement()` provides a valid structure.
The constructor also accept all the keywords accepted by `parseKeywords`.
"""
mutable struct PlotElement
    mid::Int
    is3d::Bool
    cmds::Vector{String}
    name::String
    data::Dataset
    plot::Vector{String}

    function PlotElement(;mid::Int=0, is3d::Bool=false,
                          cmds::Union{String, Vector{String}}=Vector{String}(),
                          name::String="",
                          data::Dataset=DatasetEmpty(),
                          plot::Union{String, Vector{String}}=Vector{String}(),
                          kwargs...)
        c = isa(cmds, String)  ? [cmds] : cmds
        push!(c, parseKeywords(; kwargs...))
        new(mid, is3d, deepcopy(c), name, data,
            isa(plot, String)  ? [plot] : deepcopy(plot))
    end
end


function show(v::PlotElement)
    if isa(v.data, DatasetText)
        data = "DatasetText"
    elseif isa(v.data, DatasetBin)
        data = "DatasetBin: \n" * v.data.source
    else
        data = "DatasetEmpty"
    end
    plot = length(v.plot) > 0  ?  join(v.plot, "\n")  :  []
    @info("PlotElement", mid=v.mid, is3d=v.is3d, cmds=join(v.cmds, "\n"),
          name=v.name, data, plot=plot)
end

function show(v::Vector{PlotElement})
    for p in v
        show(p)
        println()
    end
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                        TYPE DEFINITIONS                           │
# │                    Sessions data structures                       │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
mutable struct SinglePlot
    cmds::Vector{String}
    elems::Vector{String}
    is3d::Bool
    SinglePlot() = new(Vector{String}(), Vector{String}(), false)
end


# ---------------------------------------------------------------------
abstract type Session end

mutable struct DrySession <: Session
    sid::Symbol                         # session ID
    datas::OrderedDict{String, Dataset} # data sets
    plots::Vector{SinglePlot}           # commands and plot commands (one entry for each plot of the multiplot)
    curmid::Int                         # current multiplot ID
end


# ---------------------------------------------------------------------
mutable struct GPSession <: Session
    sid::Symbol                         # session ID
    datas::OrderedDict{String, Dataset} # data sets
    plots::Vector{SinglePlot}           # commands and plot commands (one entry for each plot of the multiplot)
    curmid::Int                         # current multiplot ID
    pin::Base.Pipe;
    pout::Base.Pipe;
    perr::Base.Pipe;
    proc::Base.Process;
    channel::Channel{String};
end


# ---------------------------------------------------------------------
"""
    Options

Structure containing the package global options, accessible through `Gnuplot.options`.

# Fields
- `dry::Bool`: whether to use *dry* sessions, i.e. without an underlying Gnuplot process (default: `false`)
- `cmd::String`: command to start the Gnuplot process (default: `"gnuplot"`)
- `default::Symbol`: default session name (default: `:default`)
- `term::String`: default terminal for interactive use (default: empty string, i.e. use gnuplot settings);
- `mime::Dict{DataType, String}`: dictionary of MIME types and corresponding gnuplot terminals.  Used to export images with [`save()`](@ref) and [The show mechanism](@ref);
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
        MIME"image/svg+xml"   => "svg background rgb 'white' dynamic",
        MIME"image/png"       => "pngcairo",
        MIME"image/jpeg"      => "jpeg",
        MIME"application/pdf" => "pdfcairo",
        MIME"text/html"       => "canvas mousing",
        MIME"text/plain"      => "dumb")
    init::Vector{String} = Vector{String}()
    verbose::Bool = false
    preferred_format::Symbol = :auto
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                         GLOBAL VARIABLES                          │
# ╰───────────────────────────────────────────────────────────────────╯
const sessions = OrderedDict{Symbol, Session}()
const options = Options()


# ╭───────────────────────────────────────────────────────────────────╮
# │                         LOW LEVEL FUNCTIONS                       │
# ╰───────────────────────────────────────────────────────────────────╯
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
                cblabel=AbstractString,
                xlog=Bool,
                ylog=Bool,
                zlog=Bool,
                cblog=Bool,
                margins=Union{AbstractString,NamedTuple},
                lmargin=Union{AbstractString,Real},
                rmargin=Union{AbstractString,Real},
                bmargin=Union{AbstractString,Real},
                tmargin=Union{AbstractString,Real})

    kw = canonicalize(template; kwargs...)
    out = Vector{String}()
    ismissing(kw.xrange ) || (push!(out, replace("set xrange  [" * join(kw.xrange , ":") * "]", "NaN"=>"*")))
    ismissing(kw.yrange ) || (push!(out, replace("set yrange  [" * join(kw.yrange , ":") * "]", "NaN"=>"*")))
    ismissing(kw.zrange ) || (push!(out, replace("set zrange  [" * join(kw.zrange , ":") * "]", "NaN"=>"*")))
    ismissing(kw.cbrange) || (push!(out, replace("set cbrange [" * join(kw.cbrange, ":") * "]", "NaN"=>"*")))
    ismissing(kw.key    ) || (push!(out, "set key " * kw.key  * ""))
    ismissing(kw.title  ) || (push!(out, "set title   \"" * kw.title  * "\""))
    ismissing(kw.xlabel ) || (push!(out, "set xlabel  \"" * kw.xlabel * "\""))
    ismissing(kw.ylabel ) || (push!(out, "set ylabel  \"" * kw.ylabel * "\""))
    ismissing(kw.zlabel ) || (push!(out, "set zlabel  \"" * kw.zlabel * "\""))
    ismissing(kw.cblabel) || (push!(out, "set cblabel \"" * kw.cblabel * "\""))
    ismissing(kw.xlog   ) || (push!(out, (kw.xlog  ?  ""  :  "un") * "set logscale x"))
    ismissing(kw.ylog   ) || (push!(out, (kw.ylog  ?  ""  :  "un") * "set logscale y"))
    ismissing(kw.zlog   ) || (push!(out, (kw.zlog  ?  ""  :  "un") * "set logscale z"))
    ismissing(kw.cblog  ) || (push!(out, (kw.cblog ?  ""  :  "un") * "set logscale cb"))

    if !ismissing(kw.margins)
        if isa(kw.margins, AbstractString)
            push!(out, "set margins $(kw.margins)")
        else
            push!(out, "set margins at screen $(kw.margins.l), at screen $(kw.margins.r), at screen $(kw.margins.b), at screen $(kw.margins.t)")
        end
    end
    ismissing(kw.lmargin) ||  push!(out, (kw.lmargin == ""  ?  "unset lmargin"  :  "set lmargin at screen $(kw.lmargin)"))
    ismissing(kw.rmargin) ||  push!(out, (kw.rmargin == ""  ?  "unset rmargin"  :  "set rmargin at screen $(kw.rmargin)"))
    ismissing(kw.bmargin) ||  push!(out, (kw.bmargin == ""  ?  "unset bmargin"  :  "set bmargin at screen $(kw.bmargin)"))
    ismissing(kw.tmargin) ||  push!(out, (kw.tmargin == ""  ?  "unset tmargin"  :  "set tmargin at screen $(kw.tmargin)"))

    return join(out, ";\n")
end


# ---------------------------------------------------------------------
"""
    arrays2datablock(args::Vararg{AbstractArray, N}) where N

Convert one (or more) arrays into a `Vector{String}`.

This function performs the conversion from Julia arrays to a textual representation suitable to be sent to gnuplot as an *inline data block*.
"""
function arrays2datablock(args::Vararg{AbstractArray, N}) where N
    tostring(v::AbstractString) = "\"" * string(v) * "\""
    tostring(v::Real) = string(v)
    tostring(::Missing) = "?"
    #tostring(c::ColorTypes.RGB) = string(Int(c.r*255)) * " " * string(Int(c.g*255)) * " " * string(Int(c.b*255))
    @assert length(args) > 0

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
        # @info "Case 0" # debug
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
        # @info "Case 1" # debug
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
        # @info "Case 2" # debug
        @assert minimum(lengths) == maximum(lengths) "Array size are incompatible"
        i = 1
        for CIndex in CartesianIndices(size(args[1]'))
            indices = Tuple(CIndex)
            (i > 1)  &&  (indices[end-1] == 1)  &&  (push!(accum, ""))  # blank line
            if length(args) == 1
                # Add independent indices (starting from zero, useful when plotting "with image")
                v = join(string.(getindex.(Ref(Tuple(indices)), 1:ndims(args[1])) .- 1), " ")
            else
                # Do not add independent indices since there is no way to distinguish a "z" array from additional arrays
                v = ""
            end
            for iarg in 1:length(args)
                d = args[iarg]'
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
            # @info "Case 3" # debug
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
            # @info "Case 4" # debug
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
    out = DrySession(sid, OrderedDict{String, Dataset}(), [SinglePlot()], 1)
    sessions[sid] = out
    return out
end


# ---------------------------------------------------------------------
pagerTokens() = ["Press return for more:"]

function GPSession(sid::Symbol)
    function readTask(sid, stream, channel)
        function gpreadline(stream)
            line = ""
            while true
                c = read(stream, Char)
                (c == '\r')  &&  continue
                (c == '\n')  &&  break
                if c == Char(0x1b)  # sixel
                    buf = Vector{UInt8}()
                    push!(buf, UInt8(c))
                    while true
                        c = read(stream, Char)
                        push!(buf, UInt8(c))
                        (c == Char(0x1b))  &&  break
                    end
                    c = read(stream, Char)
                    push!(buf, UInt8(c))
                    write(stdout, buf)
                    continue
                end
                line *= c
                for token in pagerTokens()  # handle pager interaction
                    if (length(line) == length(token))  &&  (line == token)
                        return line
                    end
                end
            end
            return line
        end

        saveOutput = false
        while isopen(stream)
            line = gpreadline(stream)
            if line == "GNUPLOT_CAPTURE_BEGIN"
                saveOutput = true
            elseif line == "GNUPLOT_CAPTURE_END"
                put!(channel, line)
                saveOutput = false
            else
                if line != ""
                    if options.verbose  ||  !saveOutput
                        printstyled(color=:cyan, "GNUPLOT ($sid) -> $line\n")
                    end
                end
                (saveOutput)  &&  (put!(channel, line))
            end
        end
        delete!(sessions, sid)
        return nothing
    end

    session = DrySession(sid)
    if !options.dry
        try
            gpversion()
        catch
            @warn "Cound not start a gnuplot process with command \"$(options.cmd)\".  Enabling dry sessions..."
            options.dry = true
            sessions[sid] = session
            return session
        end
    end

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

    out = GPSession(getfield.(Ref(session), fieldnames(DrySession))...,
                    pin, pout, perr, proc, chan)
    sessions[sid] = out

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


function gp_write_table(args...; kw...)
    @assert !Gnuplot.options.dry "Feature not available in *dry* mode."
    tmpfile = Base.Filesystem.tempname()
    sid = Symbol("j", Base.Libc.getpid())
    gp = getsession(sid)
    reset(gp)
    gpexec(sid, "set term unknown")
    driver(sid, "set table '$tmpfile'", args...; kw...)
    gpexec(sid, "unset table")
    quit(sid)
    out = readlines(tmpfile)
    rm(tmpfile)
    return out
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                       write() and writeread()                     │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------

"""
    write(gp, str)

Send a string to gnuplot's STDIN.

The commands sent through `write` are not stored in the current session (use `add_cmd` to save commands in the current session).
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


write(gp::DrySession, name::String, d::Dataset) = nothing
write(gp::GPSession, name::String, d::DatasetBin) = nothing
function write(gp::GPSession, name::String, d::DatasetText)
    if options.verbose
        printstyled(color=:light_black,      "GNUPLOT ($(gp.sid)) ", name, " << EOD\n")
        printstyled(color=:light_black, join("GNUPLOT ($(gp.sid)) " .* d.preview, "\n") * "\n")
        printstyled(color=:light_black,      "GNUPLOT ($(gp.sid)) ", "EOD\n")
    end
    out =  write(gp.pin, name * " << EOD\n")
    out += write(gp.pin, d.data)
    out += write(gp.pin, "\nEOD\n")
    flush(gp.pin)
    return out
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
        if l in pagerTokens()
            # Consume all data from the pager
            while true
                write(gp, "")
                sleep(0.5)
                if isready(gp.channel)
                    while isready(gp.channel)
                        push!(out, take!(gp.channel))
                    end
                else
                    options.verbose = false
                    write(gp, "print 'GNUPLOT_CAPTURE_END'")
                    options.verbose = verbose
                    break
                end
            end
        else
            l == "GNUPLOT_CAPTURE_END"  &&  break
            push!(out, l)
        end
    end
    return out
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                       Dataset CONSTRUCTORS                        │
# ╰───────────────────────────────────────────────────────────────────╯

#=
The following is dismissed since `binary matrix` do not allows to use
keywords such as `rotate`.
# ---------------------------------------------------------------------
function write_binary(M::Matrix{T}) where T <: Real
    x = collect(1:size(M)[1])
    y = collect(1:size(M)[2])

    MS = Float32.(zeros(length(x)+1, length(y)+1))
    MS[1,1] = length(x)
    MS[1,2:end] = y
    MS[2:end,1] = x
    MS[2:end,2:end] = M

    (path, io) = mktemp()
    write(io, MS)
    close(io)
    return (path, " '$path' binary matrix")
end
=#

# ---------------------------------------------------------------------
function DatasetBin(VM::Vararg{AbstractMatrix, N}) where N
    for i in 2:N
        @assert size(VM[i]) == size(VM[1])
    end
    s = size(VM[1])
    (path, io) = mktemp()

    for i in 1:s[1]
        for j in 1:s[2]
            for k in 1:N
                write(io, Float32(VM[k][i,j]))
            end
        end
    end
    source = " '$path' binary array=(" * join(string.(reverse(s)), ", ") * ")"
    # Note: can't add `using` here, otherwise we can't append `flipy`.
    close(io)
    return DatasetBin(Val(:inner), path, source)
end


# ---------------------------------------------------------------------
function DatasetBin(cols::Vararg{AbstractVector, N}) where N
    source = "binary record=$(length(cols[1])) format='"
    types = Vector{DataType}()
    (length(cols) == 1)  &&  (source *= "%int")
    for i in 1:length(cols)
        @assert length(cols[1]) == length(cols[i])
        if     isa(cols[i][1], Int32);   push!(types, Int32);   source *= "%int"
        elseif isa(cols[i][1], Int);     push!(types, Int32);   source *= "%int"
        elseif isa(cols[i][1], Float32); push!(types, Float32); source *= "%float"
        elseif isa(cols[i][1], Float64); push!(types, Float32); source *= "%float"
        elseif isa(cols[i][1], Char);    push!(types, Char);    source *= "%char"
        else
            error("Unsupported data on column $i: $(typeof(cols[i][1]))")
        end
    end
    source *= "'"

    (path, io) = mktemp()
    source = " '$path' $source"
    for row in 1:length(cols[1])
        (length(cols) == 1)  &&  (write(io, convert(Int32, row)))
        for col in 1:length(cols)
            write(io, convert(types[col], cols[col][row]))
        end
    end
    close(io)

    #=
    The following is needed to cope with the following case:
    x = randn(10001)
    @gp x x x "w p lc pal"
    =#
    source *= " using " * join(1:N, ":") * " "
    return DatasetBin(Val(:inner), path, source)
end


# ---------------------------------------------------------------------
DatasetText(args::Vararg{AbstractArray, N}) where N =
    DatasetText(arrays2datablock(args...))
function DatasetText(data::Vector{String})
    preview = (length(data) <= 4  ?  deepcopy(data)  :  [data[1:4]..., "..."])
    d = DatasetText(Val(:inner), preview, join(data, "\n"))
    return d
end


# ╭───────────────────────────────────────────────────────────────────╮
# │              PRIVATE FUNCTIONS TO MANIPULATE SESSIONS             │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
function enableExportThroughShow()
    # Trick to check whether we are running in a IJulia or Juno
    # session.  Copied from Gaston.jl.
    return ((isdefined(Main, :IJulia)  &&  Main.IJulia.inited)  ||
            (isdefined(Main, :Juno)    &&  Main.Juno.isactive()))
end


function reset(gp::Session)
    delete_binaries(gp)
    gp.datas = OrderedDict{String, Dataset}()
    gp.plots = [SinglePlot()]
    gp.curmid = 1
    gpexec(gp, "unset multiplot")
    gpexec(gp, "set output")
    gpexec(gp, "reset session")

    # When the `show()` method is enabled ignore options.term and set
    # the unknown terminal
    if enableExportThroughShow()
        gpexec(gp, "set term unknown")
    else
        (options.term != "")  &&  gpexec(gp, "set term " * options.term)

        # Set window title (if not already set)
        term = writeread(gp, "print GPVAL_TERM")[1]
        if term in ("aqua", "x11", "qt", "wxt")
            opts = writeread(gp, "print GPVAL_TERMOPTIONS")[1]
            if findfirst("title", opts) == nothing
                writeread(gp, "set term $term $opts title 'Gnuplot.jl: $(gp.sid)'")
            end
        end
    end

    # Note: the reason to keep Options.term and .init separate are:
    # - .term can be overriden by enableExportThroughShow()
    # - .init is dumped in scripts, while .term is not
    add_cmd.(Ref(gp), options.init)
    return nothing
end


# ---------------------------------------------------------------------
function setmulti(gp::Session, mid::Int)
    @assert mid >= 1 "Multiplot ID must be a >= 1"
    while length(gp.plots) < mid
        push!(gp.plots, SinglePlot())
    end
    gp.curmid = mid
end


# ---------------------------------------------------------------------
newDatasetName(gp::Session) = string("\$data", length(gp.datas)+1)


# ---------------------------------------------------------------------
function useBinaryMethod(args...)
    @assert options.preferred_format in [:auto, :bin, :text] "Unexpected value for `options.preferred_format`: $(options.preferred_format)"
    binary = false
    if options.preferred_format == :bin
        binary = true
    elseif options.preferred_format == :auto
        if (length(args) == 1)  &&  isa(args[1], AbstractMatrix)
            binary = true
        elseif all(ndims.(args) .== 1)
            s = sum(length.(args))
            if s > 1e4
                binary = true
            end
        end
    end
    return binary
end


# ---------------------------------------------------------------------
function Dataset(accum)
    if useBinaryMethod(accum...)
        try
            return DatasetBin(accum...)
        catch err
            isa(err, MethodError)  ||  rethrow()
        end
    end
    return DatasetText(accum...)
end


# ---------------------------------------------------------------------
function add_cmd(gp::Session, v::String)
    (v != "")  &&  (push!(gp.plots[gp.curmid].cmds, v))
    (length(gp.plots) == 1)  &&  (gpexec(gp, v))  # execute now to check against errors
    return nothing
end


# ---------------------------------------------------------------------
function add_plot(gp::Session, plotspec)
    push!(gp.plots[gp.curmid].elems, plotspec)
end


# ---------------------------------------------------------------------
function delete_binaries(gp::Session)
    for (name, d) in gp.datas
        if isa(d, DatasetBin)  &&  (d.file != "")
            rm(d.file, force=true)
        end
    end
end


# ---------------------------------------------------------------------
function quit(gp::DrySession)
    delete_binaries(gp)
    delete!(sessions, gp.sid)
    return 0
end

function quit(gp::GPSession)
    close(gp.pin)
    close(gp.pout)
    close(gp.perr)
    wait( gp.proc)
    exitCode = gp.proc.exitcode
    delete_binaries(gp)
    delete!(sessions, gp.sid)
    return exitCode
end


# --------------------------------------------------------------------
function stats(gp::Session, name::String)
    @info sid=gp.sid name=name source=gp.datas[name].source
    println(gpexec(gp, "stats " * gp.datas[name].source))
end
stats(gp::Session) = for (name, d) in gp.datas
    stats(gp, name)
end


# ╭───────────────────────────────────────────────────────────────────╮
# │             gpexec(), execall(), amd savescript()                 │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
gpexec(gp::DrySession, command::String) = ""
function gpexec(gp::GPSession, command::String)
    answer = Vector{String}()
    push!(answer, writeread(gp, command)...)

    verbose = options.verbose
    options.verbose = false
    errno = writeread(gp, "print GPVAL_ERRNO")
    options.verbose = verbose
    @assert length(errno) == 1
    if errno[1] != "0"
        @error "\n" * join(answer, "\n")
        errmsg = writeread(gp, "print GPVAL_ERRMSG")
        write(gp.pin, "reset error\n")
        error("Gnuplot error: $errmsg")
    end

    return join(answer, "\n")
end


# ---------------------------------------------------------------------
execall(gp::DrySession; term::AbstractString="", output::AbstractString="") = nothing
function execall(gp::GPSession; term::AbstractString="", output::AbstractString="")
    gpexec(gp, "reset")
    if term != ""
        former_term = writeread(gp, "print GPVAL_TERM")[1]
        former_opts = writeread(gp, "print GPVAL_TERMOPTIONS")[1]
        gpexec(gp, "set term $term")
    end
    (output != "")  &&  gpexec(gp, "set output '$output'")

    for i in 1:length(gp.plots)
        d = gp.plots[i]
        for j in 1:length(d.cmds)
            gpexec(gp, d.cmds[j])
        end
        if length(d.elems) > 0
            s = (d.is3d  ?  "splot "  :  "plot ") * " \\\n  " *
                join(d.elems, ", \\\n  ")
            gpexec(gp, s)
        end
    end
    (length(gp.plots) > 1)  &&  gpexec(gp, "unset multiplot")
    (output != "")  &&  gpexec(gp, "set output")
    if term != ""
        gpexec(gp, "set term $former_term $former_opts")
    end
    return nothing
end


# ---------------------------------------------------------------------
function savescript(gp::Session, filename; term::AbstractString="", output::AbstractString="")
    function copy_binary_files(gp, filename)
        function data_dirname(path)
            dir = dirname(path)
            (dir == "")  &&  (dir = ".")
            base = basename(path)
            s = split(base, ".")
            if length(s) > 1
                base = join(s[1:end-1], ".")
            end
            base *= "_data/"
            out = dir * "/" * base
            return out
        end

        path_from = Vector{String}()
        path_to   = Vector{String}()
        datapath  = data_dirname(filename)
        for (name, d) in gp.datas
            if isa(d, DatasetBin)  &&  (d.file != "")
                if (length(path_from) == 0)
                    #isdir(datapath)  &&  rm(datapath, recursive=true)
                    mkpath(datapath)
                end
                to = datapath * basename(d.file)
                cp(d.file, to, force=true)
                push!(path_from, d.file)
                push!(path_to,   to)
            end
        end
        return (path_from, path_to)
    end
    function redirect_elements(elems, path_from, path_to)
        (length(path_from) == 0)  &&  (return elems)

        out = deepcopy(elems)
        for i in 1:length(out)
            for j in 1:length(path_from)
                tmp = replace(out[i], path_from[j] => path_to[j])
                out[i] = tmp
            end
        end
        return out
    end

    stream = open(filename, "w")

    println(stream, "reset session")
    if term != ""
        println(stream, "set term $term")
    end
    (output != "")  &&  println(stream, "set output '$output'")

    paths = copy_binary_files(gp, filename)
    for (name, d) in gp.datas
        if isa(d, DatasetText)
            println(stream, name * " << EOD")
            println(stream, d.data)
            println(stream, "EOD")
        end
    end

    for i in 1:length(gp.plots)
        d = gp.plots[i]
        for j in 1:length(d.cmds)
            println(stream, d.cmds[j])
        end
        if length(d.elems) > 0
            s = (d.is3d  ?  "splot "  :  "plot ") * " \\\n  " *
                join(redirect_elements(d.elems, paths...), ", \\\n  ")
            println(stream, s)
        end
    end
    (length(gp.plots) > 1)  &&  println(stream, "unset multiplot")
    println(stream, "set output")
    close(stream)
    return nothing
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                  parseArgument() amd driver()                     │
# ╰───────────────────────────────────────────────────────────────────╯
# ---------------------------------------------------------------------
function parseArguments(_args...)
    function parseCmd(s::String)
        (isplot, is3d, cmd) = (false, false, s)
        (length(s) >= 2)  &&  (s[1:2] ==  "p "    )  &&  ((isplot, is3d, cmd) = (true, false, strip(s[2:end])))
        (length(s) >= 3)  &&  (s[1:3] ==  "pl "   )  &&  ((isplot, is3d, cmd) = (true, false, strip(s[3:end])))
        (length(s) >= 4)  &&  (s[1:4] ==  "plo "  )  &&  ((isplot, is3d, cmd) = (true, false, strip(s[4:end])))
        (length(s) >= 5)  &&  (s[1:5] ==  "plot " )  &&  ((isplot, is3d, cmd) = (true, false, strip(s[5:end])))
        (length(s) >= 2)  &&  (s[1:2] ==  "s "    )  &&  ((isplot, is3d, cmd) = (true, true , strip(s[2:end])))
        (length(s) >= 3)  &&  (s[1:3] ==  "sp "   )  &&  ((isplot, is3d, cmd) = (true, true , strip(s[3:end])))
        (length(s) >= 4)  &&  (s[1:4] ==  "spl "  )  &&  ((isplot, is3d, cmd) = (true, true , strip(s[4:end])))
        (length(s) >= 5)  &&  (s[1:5] ==  "splo " )  &&  ((isplot, is3d, cmd) = (true, true , strip(s[5:end])))
        (length(s) >= 6)  &&  (s[1:6] ==  "splot ")  &&  ((isplot, is3d, cmd) = (true, true , strip(s[6:end])))
        return (isplot, is3d, string(cmd))
    end

    # First pass: check for `:-` and session names
    sid = options.default
    doDump  = true
    doReset = true
    if length(_args) == 0
        return (sid, doReset, doDump, Vector{PlotElement}())
    end
    for iarg in 1:length(_args)
        arg = _args[iarg]

        if typeof(arg) == Symbol
            if arg == :-
                if iarg == 1
                    doReset = false
                elseif iarg == length(_args)
                    doDump  = false
                else
                    @warn "Symbol `:-` at position $iarg in argument list has no meaning."
                end
            else
                @assert (sid == options.default) "Only one session at a time can be addressed"
                sid = arg
            end
        end
    end

    # Second pass: check data types, run implicit recipes and splat
    # Vector{PlotElement}
    args = Vector{Any}([_args...])
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if isa(arg, Symbol)                          # session ID (already handled)
            deleteat!(args, pos)
            continue
        elseif isa(arg, Int)                         # ==> multiplot index
            @assert arg > 0 "Multiplot index must be a positive integer"
        elseif isa(arg, AbstractString)              # ==> a plotspec or a command
            deleteat!(args, pos)
            insert!(args, pos, string(strip(arg)))
        elseif isa(arg, Tuple)  &&                   # ==> a keyword/value pair
            length(arg) == 2    &&
                isa(arg[1], Symbol)             ;
            # Delay until fourth pass to avoid misinterpreting a
            # keyword as a plotspec. E.g.: @gp x x.^2 ylog=true
        elseif isa(arg, Pair)                        # ==> a named dataset
            @assert typeof(arg[1]) == String "Dataset name must be a string"
            @assert arg[1][1] == '$' "Dataset name must start with a dollar sign"
            deleteat!(args, pos)
            for i in length(arg[2]):-1:1
                insert!(args, pos, arg[2][i])
            end
            insert!(args, pos, string(strip(arg[1])) => nothing)
        elseif isa(arg, AbstractArray) &&            # ==> a dataset column
            ((valtype(arg) <: Real)    ||
             (valtype(arg) <: AbstractString))  ;
        elseif isa(arg, Real)                        # ==> a dataset column with only one row
            args[pos] = [arg]
        elseif isa(arg, Dataset)                ;    # ==> a Dataset object
        elseif hasmethod(recipe, tuple(typeof(arg))) # ==> implicit recipe
            # @info which(recipe, tuple(typeof(arg)))  # debug
            deleteat!(args, pos)
            insert!(args, pos, recipe(arg))
            continue
        elseif isa(arg, Vector{PlotElement})         # ==> explicit recipe (vector)
            deleteat!(args, pos)
            for i in length(arg):-1:1
                insert!(args, pos, arg[i])
            end
        elseif isa(arg, PlotElement)            ;    # ==> explicit recipe (scalar)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end

        pos += 1
    end

    # Third pass: convert data into Dataset objetcs
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if isa(arg, AbstractArray)   &&      # ==> beginning of a dataset
            ((valtype(arg) <: Real)  ||
             (valtype(arg) <: AbstractString))

            # Collect all data
            accum = Vector{AbstractArray}()
            while isa(arg, AbstractArray)  &&
                ((valtype(arg) <: Real)    ||
                 (valtype(arg) <: AbstractString))
                push!(accum, arg)
                deleteat!(args, pos)
                if pos <= length(args)
                    arg = args[pos]
                else
                    break
                end
            end

            mm = extrema(length.(accum))
            if mm[1] == 0
                # empty Dataset
                @assert mm[1] == mm[2] "At least one input array is empty, while other(s) are not"
                d = DatasetEmpty()
            else
                d = Dataset(accum)
            end
            insert!(args, pos, d)
        end
        pos += 1
    end

    # Fourth pass: collect PlotElement objects
    mid = 0
    name = ""
    cmds = Vector{String}()
    elems = Vector{PlotElement}()
    pos = 1
    while pos <= length(args)
        arg = args[pos]

        if isa(arg, Int)                         # ==> multiplot index
            if length(cmds) > 0
                push!(elems, PlotElement(mid=mid, cmds=cmds))
                empty!(cmds)
            end
            mid = arg
            name = ""
            empty!(cmds)
        elseif isa(arg, Tuple)  &&               # ==> a keyword/value pair
            length(arg) == 2    &&
                isa(arg[1], Symbol)
            push!(cmds, parseKeywords(; [arg]...))
        elseif isa(arg, String)                  # ==> a plotspec or a command
            (isPlot, is3d, s) = parseCmd(arg)
            if isPlot
                push!(elems, PlotElement(mid=mid, is3d=is3d, cmds=cmds, plot=s))
                empty!(cmds)
            else
                push!(cmds, s)
            end
            name = ""
        elseif isa(arg, Pair)                    # ==> dataset name
            name = arg[1]
        elseif isa(arg, Dataset)                 # ==> A Dataset
            spec = Vector{String}()
            if name == ""  # only unnamed data sets have an associated plot spec
                spec = ""
                if (pos < length(args))  &&
                    isa(args[pos+1], String)
                    spec = args[pos+1]
                    deleteat!(args, pos+1)
                end
            end
            if !isa(arg, DatasetEmpty)
                push!(elems, PlotElement(mid=mid, cmds=cmds, name=name, data=arg, plot=spec))
            end
            name = ""
            empty!(cmds)
        elseif isa(arg, PlotElement)
            if length(cmds) > 0
                push!(elems, PlotElement(mid=mid, cmds=cmds))
                empty!(cmds)
            end
            name = ""
            (mid != 0)  &&  (arg.mid = mid)
            push!(elems, arg)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end
        pos += 1
    end
    if length(cmds) > 0
        push!(elems, PlotElement(mid=mid, cmds=cmds))
        empty!(cmds)
    end

    return (sid, doReset, doDump, elems)
end


function driver(_args...; is3d=false)
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

    if length(_args) == 0
        gp = getsession()
        execall(gp)
        return SessionID(gp.sid, true)
    end

    (sid, doReset, doDump, elems) = parseArguments(_args...)
    gp = getsession(sid)
    doReset  &&  reset(gp)

    # Set curent multiplot ID and sort elements
    for elem in elems
        if elem.mid == 0
            elem.mid = gp.curmid
        end
    end
    elems = elems[sortperm(getfield.(elems, :mid))]
    # show(elems)  # debug

    # Set dataset names and send them to gnuplot process
    for elem in elems
        (elem.name == "")  &&  (elem.name = newDatasetName(gp))
        if  !isa(elem.data, DatasetEmpty)  &&
            !haskey(gp.datas, elem.name)
            gp.datas[elem.name] = elem.data
            write(gp, elem.name, elem.data)
        end
    end

    for elem in elems
        (elem.mid > 0)  &&  setmulti(gp, elem.mid)
        gp.plots[gp.curmid].is3d = (is3d | elem.is3d)

        for cmd in elem.cmds
            add_cmd(gp, cmd)
        end

        if !isa(elem.data, DatasetEmpty)
            for spec in elem.plot
                if isa(elem.data, DatasetBin)
                    source = dropDuplicatedUsing(elem.data.source, spec)
                    add_plot(gp, source * " " * spec)
                else
                    add_plot(gp, elem.name * " " * spec)
                end
            end
        else
            for spec in elem.plot
                for (name, data) in gp.datas
                    if isa(data, DatasetBin)
                        source = dropDuplicatedUsing(elem.data.source, spec)
                        spec = replace(spec, name => source)
                    end
                end
                add_plot(gp, spec)
            end
        end
    end

    (doDump)  &&  (execall(gp))
    return SessionID(gp.sid, doDump)
end


# ╭───────────────────────────────────────────────────────────────────╮
# │        NON-EXPORTED FUNCTIONS MEANT TO BE INVOKED BY USERS        │
# ╰───────────────────────────────────────────────────────────────────╯
"""
    Gnuplot.version()

Return the **Gnuplot.jl** package version.
"""
version() = v"1.2.1-dev"

# ---------------------------------------------------------------------
"""
    Gnuplot.gpversion()

Return the gnuplot application version.

Raise an error if version is < 5.0 (required to use data blocks).
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

    if ver < v"5.0"
        error("gnuplot ver. >= 5.0 is required, but " * string(ver) * " was found.")
    end
    return ver
end


# ---------------------------------------------------------------------
"""
    Gnuplot.quit(sid::Symbol)

Quit the session identified by `sid` and the associated gnuplot process (if any).
"""
function quit(sid::Symbol)
    (sid in keys(sessions))  ||  (return 0)
    return quit(sessions[sid])
end

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




# ╭───────────────────────────────────────────────────────────────────╮
# │                       EXPORTED FUNCTIONS                          │
# ╰───────────────────────────────────────────────────────────────────╯
# --------------------------------------------------------------------
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
gpexec(sid::Symbol, s::String) = gpexec(getsession(sid), s)
gpexec(s::String) = gpexec(getsession(), s)


# --------------------------------------------------------------------
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

- a `PlotElement` object is expanded in its fields and processed as one of the previous arguments;

- any other data type is processed through an implicit recipe. If a suitable recipe do not exists an error is raised.
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
    @gsp args...

This macro accepts the same syntax as [`@gp`](@ref), but produces a 3D plot instead of a 2D one.
"""
macro gsp(args...)
    out = Expr(:macrocall, Symbol("@gp"), LineNumberNode(1, nothing))
    push!(out.args, args...)
    push!(out.args, Expr(:kw, :is3d, true))
    return esc(out)
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
save(           ; kw...) = execall(getsession()   ; kw...)
save(sid::Symbol; kw...) = execall(getsession(sid); kw...)
save(             file::AbstractString; kw...) = savescript(getsession()   , file, kw...)
save(sid::Symbol, file::AbstractString; kw...) = savescript(getsession(sid), file, kw...)

save(mime::Type{T}; kw...) where T <: MIME = save(options.default, mime; kw...)
function save(sid::Symbol, mime::Type{T}; kw...) where T <: MIME
    if mime in keys(options.mime)
        term = strip(options.mime[mime])
        if term != ""
            return save(sid; term=term, kw...)
        end
    end
    @error "No terminal is defined for $mime.  Check `Gnuplot.options.mime` dictionary."
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                     Interfacing Julia's show                      │
# ╰───────────────────────────────────────────────────────────────────╯
# --------------------------------------------------------------------
function internal_show(io::IO, mime::Type{T}, gp::SessionID) where T <: MIME
    if gp.dump  &&  enableExportThroughShow()
        if mime in keys(options.mime)
            term = strip(options.mime[mime])
            if term != ""
                file = tempname()
                save(gp.sid, term=term, output=file)
                write(io, read(file))
                rm(file; force=true)
            end
        end
    end
    nothing
end

show(gp::SessionID) = nothing
show(io::IO, gp::SessionID) = nothing
show(io::IO, mime::MIME"image/svg+xml", gp::SessionID) = internal_show(io, typeof(mime), gp)
show(io::IO, mime::MIME"image/png"    , gp::SessionID) = internal_show(io, typeof(mime), gp)
show(io::IO, mime::MIME"text/html"    , gp::SessionID) = internal_show(io, typeof(mime), gp)


# ╭───────────────────────────────────────────────────────────────────╮
# │                     HIGH LEVEL FACILITIES                         │
# ╰───────────────────────────────────────────────────────────────────╯
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
            gpexec(gp, "set term wxt  noenhanced size 600,300")
        elseif "qt" in terms
            gpexec(gp, "set term qt   noenhanced size 600,300")
        elseif "aqua" in terms
            gpexec(gp, "set term aqua noenhanced size 600,300")
        else
            @warn "None of the `wxt`, `qt` and `aqua` terminals are available.  Output may look strange..."
        end
    else
        gpexec(gp, "set term unknown")
    end
    @gp :- :splash "set margin 0"  "set border 0" "unset tics" :-
    @gp :- :splash xr=[-0.3,1.7] yr=[-0.3,1.1] :-
    @gp :- :splash "set origin 0,0" "set size 1,1" :-
    @gp :- :splash "set label 1 at graph 1,1 right offset character -1,-1 font 'Verdana,20' tc rgb '#4d64ae' ' Ver: " * string(version()) * "' " :-
    @gp :- :splash "set arrow 1 from graph 0.05, 0.15 to graph 0.95, 0.15 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
    @gp :- :splash "set arrow 2 from graph 0.15, 0.05 to graph 0.15, 0.95 size 0.2,20,60  noborder  lw 9 lc rgb '#4d64ae'" :-
    @gp :- :splash ["0.35 0.65 @ 13253682", "0.85 0.65 g 3774278", "1.3 0.65 p 9591203"] "w labels notit font 'Mono,160' tc rgb var"
    (outputfile == "")  ||  save(:splash, term="pngcairo transparent noenhanced size 600,300", output=outputfile)
    nothing
end


# --------------------------------------------------------------------
"""
    dataset_names(sid::Symbol)
    dataset_names()

Return a vector with all dataset names for the `sid` session.  If `sid` is not provided the default session is considered.
"""
dataset_names(sid::Symbol) = string.(keys(getsession(sid).datas))
dataset_names() = dataset_names(options.default)

# --------------------------------------------------------------------
"""
    session_names()

Return a vector with all currently active sessions.
"""
session_names() = Symbol.(keys(sessions))

# --------------------------------------------------------------------
"""
    stats(sid::Symbol,name::String)
    stats(name::String)
    stats(sid::Symbol)
    stats()

Print a statistical summary for the `name` dataset, belonging to `sid` session.  If `name` is not provdied a summary is printed for each dataset in the session.  If `sid` is not provided the default session is considered.

This function is actually a wrapper for the gnuplot command `stats`.
"""
stats(sid::Symbol, name::String) = stats(getsession(sid), name)
stats(name::String) = stats(options.default, name)
stats(sid::Symbol) = stats(getsession(sid))
stats() = for (sid, d) in sessions
    stats(sid)
end


# ---------------------------------------------------------------------
"""
    palette_names()

Return a vector with all available color schemes for the [`palette`](@ref) and [`linetypes`](@ref) function.
"""
palette_names() = Symbol.(keys(ColorSchemes.colorschemes))


"""
    linetypes(cmap::ColorScheme; lw=1, ps=1, dashed=false, rev=false)
    linetypes(s::Symbol; lw=1, ps=1, dashed=false, rev=false)

Convert a `ColorScheme` object into a string containing the gnuplot commands to set up *linetype* colors.

If the argument is a `Symbol` it is interpreted as the name of one of the predefined schemes in [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1).

If `rev=true` the line colors are reversed.  If a numeric or string value is provided through the `lw` and `ps` keywords thay are used to set the line width and the point size respectively.  If `dashed` is true the linetypes with index greater than 1 will be displayed with dashed pattern.
"""
linetypes(s::Symbol; kwargs...) = linetypes(colorschemes[s]; kwargs...)
function linetypes(cmap::ColorScheme; lw=1, ps=1, dashed=false, rev=false)
    out = Vector{String}()
    push!(out, "unset for [i=1:256] linetype i")
    for i in 1:length(cmap.colors)
        if rev
            color = cmap.colors[end - i + 1]
        else
            color = cmap.colors[i]
        end
        dt = (dashed  ?  "$i"  :  "solid")
        push!(out, "set linetype $i lc rgb '#" * Colors.hex(color) * "' lw $lw dt $dt pt $i ps $ps")
    end
    return join(out, "\n") * "\nset linetype cycle " * string(length(cmap.colors)) * "\n"
end


"""
    palette(cmap::ColorScheme; rev=false)
    palette(s::Symbol; rev=false)

Convert a `ColorScheme` object into a string containing the gnuplot commands to set up the corresponding palette.

If the argument is a `Symbol` it is interpreted as the name of one of the predefined schemes in [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1). If `rev=true` the palette is reversed.
"""
palette(s::Symbol; rev=false) = palette(colorschemes[s], rev=rev)
function palette(cmap::ColorScheme; rev=false)
    levels = Vector{String}()
    for x in LinRange(0, 1, length(cmap.colors))
        if rev
            color = get(cmap, 1-x)
        else
            color = get(cmap, x)
        end
        push!(levels, "$x '#" * Colors.hex(color) * "'")
    end
    return "set palette defined (" * join(levels, ", ") * ")\nset palette maxcol $(length(cmap.colors))\n"
end


# --------------------------------------------------------------------
"""
    terminals()

Return a `Vector{String}` with the names of all the available gnuplot terminals.
"""
terminals() = string.(split(strip(gpexec("print GPVAL_TERMINALS")), " "))


# --------------------------------------------------------------------
"""
    terminal(sid::Symbol)
    terminal()

Return a `String` with the current gnuplot terminal (and its options) of the process associated to session `sid`, or to the default session (if `sid` is not provided).
"""
terminal(sid::Symbol=options.default) = gpexec(getsession(sid), "print GPVAL_TERM") * " " * gpexec(getsession(sid), "print GPVAL_TERMOPTIONS")


# --------------------------------------------------------------------
"""
    test_terminal(term=nothing; linetypes=nothing, palette=nothing)

Run the `test` and `test palette` commands on a gnuplot terminal.

If no `term` is given it will use the default terminal. If `lt` and `pal` are given they are used as input to the [`linetypes`](@ref) and [`palette`](@ref) function repsetcively to load the associated color scheme.

# Examples
```julia
test_terminal()
test_terminal("wxt", lt=:rust, pal=:viridis)
```
"""
function test_terminal(term=nothing; lt=nothing, pal=nothing)
    quit(:test_term)
    quit(:test_palette)
    if !isnothing(term)
        gpexec(:test_term    , "set term $term")
        gpexec(:test_palette , "set term $term")
    end
    s = (isnothing(lt)  ?  ""  :  linetypes(lt))
    gpexec(:test_term    , "$s; test")
    s = (isnothing(pal)  ?  ""  :  palette(pal))
    gpexec(:test_palette , "$s; test palette")
end


# --------------------------------------------------------------------
"""
    Histogram1D

A 1D histogram data.

# Fields
- `bins::Vector{Float64}`: bin center values;
- `counts::Vector{Float64}`: counts in the bins;
- `binsize::Float64`: size of each bin;
"""
mutable struct Histogram1D
    bins::Vector{Float64}
    counts::Vector{Float64}
    binsize::Float64
end

"""
    Histogram2D

A 2D histogram data.

# Fields
- `bins1::Vector{Float64}`: bin center values along first dimension;
- `bins2::Vector{Float64}`: bin center values along second dimension;
- `counts::Vector{Float64}`: counts in the bins;
- `binsize1::Float64`: size of each bin along first dimension;
- `binsize2::Float64`: size of each bin along second dimension;
"""
mutable struct Histogram2D
    bins1::Vector{Float64}
    bins2::Vector{Float64}
    counts::Matrix{Float64}
    binsize1::Float64
    binsize2::Float64
end


# --------------------------------------------------------------------
"""
    hist(v::Vector{T}; range=extrema(v), bs=NaN, nbins=0, pad=true) where T <: Real

Calculates the histogram of the values in `v` and returns a [`Histogram1D`](@ref) structure.

# Arguments
- `v`: a vector of values to compute the histogra;
- `range`: values of the left edge of the first bin and of the right edge of the last bin;
- `bs`: size of histogram bins;
- `nbins`: number of bins in the histogram;
- `pad`: if true add one dummy bins with zero counts before the first bin and after the last.

If `bs` is given `nbins` is ignored.

# Example
```julia
v = randn(1000)
h = hist(v, bs=0.5)
@gp h  # preview
@gp h.bins h.counts "w histep notit"
```
"""
function hist(v::Vector{T}; range=[NaN,NaN], bs=NaN, nbins=0, pad=true) where T <: Real
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


"""
    hist(v1::Vector{T1 <: Real}, v2::Vector{T2 <: Real}; range1=[NaN,NaN], bs1=NaN, nbins1=0, range2=[NaN,NaN], bs2=NaN, nbins2=0)

Calculates the 2D histogram of the values in `v1` and `v2` and returns a [`Histogram2D`](@ref) structure.

# Arguments
- `v1`: a vector of values along the first dimension;
- `v2`: a vector of values along the second dimension;
- `range1`: values of the left edge of the first bin and of the right edge of the last bin, along the first dimension;
- `range1`: values of the left edge of the first bin and of the right edge of the last bin, along the second dimension;
- `bs1`: size of histogram bins along the first dimension;
- `bs2`: size of histogram bins along the second dimension;
- `nbins1`: number of bins along the first dimension;
- `nbins2`: number of bins along the second dimension;

If `bs1` (`bs2`) is given `nbins1` (`nbins2`) is ignored.

# Example
```julia
v1 = randn(1000)
v2 = randn(1000)
h = hist(v1, v2, bs1=0.5, bs2=0.5)
@gp h  # preview
@gp "set size ratio -1" "set auto fix" h.bins1 h.bins2 h.counts "w image notit"
```
"""
function hist(v1::Vector{T1}, v2::Vector{T2};
              range1=[NaN,NaN], bs1=NaN, nbins1=0,
              range2=[NaN,NaN], bs2=NaN, nbins2=0) where {T1 <: Real, T2 <: Real}
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
"""
    boxxy(x, y; xmin=NaN, ymin=NaN, xmax=NaN, ymax=NaN, cartesian=false)
    boxxy(h::Histogram2D)

"""
boxxy(h::Histogram2D) = boxxy(h.bins1, h.bins2, h.counts, cartesian=true)
function boxxy(x, y, aux...; xmin=NaN, ymin=NaN, xmax=NaN, ymax=NaN, cartesian=false)
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
        return Dataset(x, y, xlow, xhigh, ylow, yhigh, aux...)
    end
    i = repeat(1:length(x), outer=length(y))
    j = repeat(1:length(y), inner=length(x))
    return Dataset([x[i], y[j], xlow[i], xhigh[i], ylow[j], yhigh[j], aux...])
end


# --------------------------------------------------------------------
"""
    Path2d

A path in 2D.

# Fields
- `x::Vector{Float64}`
- `y::Vector{Float64}`
"""
struct Path2d
    x::Vector{Float64}
    y::Vector{Float64}
    Path2d() = new(Vector{Float64}(), Vector{Float64}())
end


"""
    IsoContourLines

Coordinates of all contour lines of a given level.

# Fields
 - `paths::Vector{Path2d}`: vector of [`Path2d`](@ref) objects, one for each continuous path;
 - `data::Vector{String}`: vector with string representation of all paths (ready to be sent to gnuplot);
 - `z::Float64`: level of the contour lines.
"""
struct IsoContourLines
    paths::Vector{Path2d}
    data::Dataset
    z::Float64
    function IsoContourLines(paths::Vector{Path2d}, z)
        @assert length(z) == 1
        # Prepare Dataset object
        data = Vector{String}()
        for i in 1:length(paths)
            append!(data, arrays2datablock(paths[i].x, paths[i].y, z .* fill(1., length(paths[i].x))))
            push!(data, "")
            push!(data, "")
        end
        return new(paths, DatasetText(data), z)
    end
end


"""
    contourlines(x::Vector{Float64}, y::Vector{Float64}, z::Matrix{Float64}, cntrparam="level auto 10")
    contourlines(h::Histogram2D, cntrparam="level auto 10")

Compute paths of contour lines for 2D data, and return a vector of [`IsoContourLines`](@ref) object.

!!! note
    This feature is not available in *dry* mode and will raise an error if used.

# Arguments:
- `x`, `y`: Coordinates;
- `z`: the levels on which iso contour lines are to be calculated
- `cntrparam`: settings to compute contour line paths (see gnuplot documentation for `cntrparam`).

# Example
```julia
x = randn(5000);
y = randn(5000);
h = hist(x, y, nbins1=20, nbins2=20);
clines = contourlines(h, "levels discrete 15, 30, 45");

# Use implicit recipe
@gp clines

# ...or use IsoContourLines fields:
@gp "set size ratio -1"
for i in 1:length(clines)
    @gp :- clines[i].data "w l t '\$(clines[i].z)' lw \$i dt \$i"
end
```
"""
contourlines(h::Histogram2D, args...) = contourlines(h.bins1, h.bins2, h.counts, args...)
function contourlines(x::Vector{Float64}, y::Vector{Float64}, z::Matrix{Float64},
                      cntrparam="level auto 10")
    lines = gp_write_table("set contour base", "unset surface",
                           "set cntrparam $cntrparam", x, y, z, is3d=true)

    level = NaN
    path = Path2d()
    paths = Vector{Path2d}()
    levels = Vector{Float64}()
    for l in lines
        l = strip(l)
        if (l == "")  ||
            !isnothing(findfirst("# Contour ", l))
            if length(path.x) > 2
                push!(paths, path)
                push!(levels, level)
            end
            path = Path2d()

            if l != ""
                level = Meta.parse(strip(split(l, ':')[2]))
            end
            continue
        end
        (l[1] == '#')  &&  continue

        n = Meta.parse.(split(l))
        @assert length(n) == 3
        push!(path.x, n[1])
        push!(path.y, n[2])
    end
    if length(path.x) > 2
        push!(paths, path)
        push!(levels, level)
    end
    @assert length(paths) > 0
    i = sortperm(levels)
    paths  = paths[ i]
    levels = levels[i]

    # Join paths with the same level
    out = Vector{IsoContourLines}()
    for zlevel in unique(levels)
        i = findall(levels .== zlevel)
        push!(out, IsoContourLines(paths[i], zlevel))
    end
    return out
end


# ╭───────────────────────────────────────────────────────────────────╮
# │                        GNUPLOT REPL                               │
# ╰───────────────────────────────────────────────────────────────────╯
# --------------------------------------------------------------------
"""
    Gnuplot.init_repl(; start_key='>')

Install a hook to replace the common Julia REPL with a gnuplot one.  The key to start the REPL is the one provided in `start_key` (default: `>`).

Note: the gnuplot REPL operates only on the default session.
"""
function repl_init(; start_key='>')
    function repl_exec(s)
        for s in writeread(getsession(), s)
            println(s)
        end
        nothing
    end

    function repl_isvalid(s)
        input = strip(String(take!(copy(REPL.LineEdit.buffer(s)))))
        (length(input) == 0)  ||  (input[end] != '\\')
    end

    initrepl(repl_exec,
             prompt_text="gnuplot> ",
             prompt_color = :blue,
             start_key=start_key,
             mode_name="Gnuplot",
             completion_provider=REPL.LineEdit.EmptyCompletionProvider(),
             valid_input_checker=repl_isvalid)
end



# ╭───────────────────────────────────────────────────────────────────╮
# │                  ACCESS GNUPLOT VARIABLES                         │
# ╰───────────────────────────────────────────────────────────────────╯
# --------------------------------------------------------------------
"""
    gpvars(sid::Symbol)
    gpvars()

Return a `NamedTuple` with all currently defined gnuplot variables.  If the `sid` argument is not provided, the default session is considered.
"""
gpvars() = gpvars(options.default)
function gpvars(sid::Symbol)
    gp = getsession(sid)
    vars = string.(strip.(split(gpexec("show var all"), '\n')))

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
                out[key] = s[2][2:end-1]
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


# --------------------------------------------------------------------
"""
    gpmargins(sid::Symbol)
    gpmargins()

Return a `NamedTuple` with keys `l`, `r`, `b` and `t` containing respectively the left, rigth, bottom and top margins of the current plot (in screen coordinates).
"""
gpmargins() = gpmargins(options.default)
function gpmargins(sid::Symbol)
    vars = gpvars()
    l = vars.TERM_XMIN / (vars.TERM_XSIZE / vars.TERM_SCALE)
    r = vars.TERM_XMAX / (vars.TERM_XSIZE / vars.TERM_SCALE)
    b = vars.TERM_YMIN / (vars.TERM_YSIZE / vars.TERM_SCALE)
    t = vars.TERM_YMAX / (vars.TERM_YSIZE / vars.TERM_SCALE)
    return (l=l, r=r, b=b, t=t)
end

"""
    gpranges(sid::Symbol)
    gpranges()

Return a `NamedTuple` with keys `x`, `y`, `z` and `cb` containing respectively the current plot ranges for the X, Y, Z and color box axis.
"""
gpranges() = gpranges(options.default)
function gpranges(sid::Symbol)
    vars = gpvars()
    x = [vars.X_MIN, vars.X_MAX]
    y = [vars.Y_MIN, vars.Y_MAX]
    z = [vars.Z_MIN, vars.Z_MAX]
    c = [vars.CB_MIN, vars.CB_MAX]
    return (x=x, y=y, z=z, cb=c)
end

include("recipes.jl")

end #module
