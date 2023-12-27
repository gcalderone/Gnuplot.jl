# ---------------------------------------------------------------------
"""
    GPPlotCommands

Specifications for a plot item based on a single dataset.

# Fields
- `mid::Int`: multiplot ID (use 0 for single plots);
- `is3d::Bool`: true if the data are supposed to be displayed in a 3D plot;
- `cmds::Vector{String}`: commands to set plot properties;
- `name::String`: name of the dataset (use "" to automatically generate a unique name);
- `data::Dataset`: a dataset
- `plot::Vector{String}`: plot specifications for the associated `Dataset`;

The constructor is defined as follows:
```julia
GPPlotCommands(;mid::Int=0, is3d::Bool=false,
          cmds::Union{String, Vector{String}}=Vector{String}(),
          name::String="",
          data::Dataset=DatasetEmpty(),
          plot::Union{String, Vector{String}}=Vector{String}(),
          kwargs...)
```
No field is mandatory, i.e. even `Gnuplot.GPPlotCommands()` provides a valid structure.
The constructor also accept all the keywords accepted by `parseKeywords`.
"""


abstract type AbstractGPCommand end
has_dataset(::AbstractGPCommand) = false

mutable struct GPCommand <: AbstractGPCommand
    mid::Int
    cmd::String
    GPCommand(cmd::AbstractString; mid::Int=1) = new(mid, deepcopy(string(cmd)))
    GPCommand(cmds::Vector{<: AbstractString}; mid::Int=1) = new(mid, join(string.(cmds), ";\n"))
end

mutable struct GPNamedDataset <: AbstractGPCommand
    name::String
    data::Dataset
    GPNamedDataset(name::AbstractString, data::Dataset) =
        new(mid, name, string(data))
end
has_dataset(::GPNamedDataset) = true

mutable struct GPPlotCommand <: AbstractGPCommand
    mid::Int
    is3d::Bool
    cmd::String
    GPPlotCommand(cmd::AbstractString; mid::Int=1, is3d::Bool=false) =
        new(mid, is3d, string(cmd))
end

mutable struct GPPlotDataCommand <: AbstractGPCommand
    mid::Int
    is3d::Bool
    data::Dataset
    cmd::String

    GPPlotDataCommand(data::Dataset, cmd::AbstractString; mid::Int=1, is3d::Bool=false) =
        new(mid, is3d, data, string(cmd))
end
has_dataset(::GPPlotDataCommand) = true



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
function parseStrAsCommand(s::String, mid::Int)
    (length(s) >= 2)  &&  (s[1:2] ==  "p "    )  &&  (return GPPlotCommand(strip(s[2:end]), mid=mid))
    (length(s) >= 3)  &&  (s[1:3] ==  "pl "   )  &&  (return GPPlotCommand(strip(s[3:end]), mid=mid))
    (length(s) >= 4)  &&  (s[1:4] ==  "plo "  )  &&  (return GPPlotCommand(strip(s[4:end]), mid=mid))
    (length(s) >= 5)  &&  (s[1:5] ==  "plot " )  &&  (return GPPlotCommand(strip(s[5:end]), mid=mid))
    (length(s) >= 2)  &&  (s[1:2] ==  "s "    )  &&  (return GPPlotCommand(strip(s[2:end]), mid=mid, is3d=true))
    (length(s) >= 3)  &&  (s[1:3] ==  "sp "   )  &&  (return GPPlotCommand(strip(s[3:end]), mid=mid, is3d=true))
    (length(s) >= 4)  &&  (s[1:4] ==  "spl "  )  &&  (return GPPlotCommand(strip(s[4:end]), mid=mid, is3d=true))
    (length(s) >= 5)  &&  (s[1:5] ==  "splo " )  &&  (return GPPlotCommand(strip(s[5:end]), mid=mid, is3d=true))
    (length(s) >= 6)  &&  (s[1:6] ==  "splot ")  &&  (return GPPlotCommand(strip(s[6:end]), mid=mid, is3d=true))
    return GPCommand(s, mid=mid)
end


# ---------------------------------------------------------------------
function parseArguments(_args...)
    args = Vector{Any}([_args...])

    # First pass: check for session names and `:-`
    out_sid = nothing
    out_doReset = length(args) != 0
    out_doDump = true
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if typeof(arg) == Symbol
            if arg == :-
                if pos == 1
                    out_doReset = false
                elseif pos == length(args)
                    out_doDump  = false
                else
                    error("Symbol `:-` has a meaning only if it is at first or last position in argument list.")
                end
            else
                @assert isnothing(out_sid) "Only one session at a time can be addressed"
                out_sid = arg
            end
            deleteat!(args, pos)
        else
            pos += 1
        end
    end
    isnothing(out_sid)  &&  (out_sid = options.default)

    # Second pass: check data types, run implicit recipes and splat
    # Vector{GPPlotDataCommands}
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if isa(arg, Int)                             # ==> multiplot index
            @assert arg > 0 "Multiplot index must be a positive integer"
        elseif isa(arg, AbstractString)              # ==> a plotspec or a command
            args[pos] = string(strip(arg))
        elseif isa(arg, Tuple)  &&                   # ==> a keyword/value pair
            length(arg) == 2    &&
            isa(arg[1], Symbol)                 ;
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
            ((nonmissingtype(eltype(arg)) <: Real)    ||
            (nonmissingtype(eltype(arg)) <: AbstractString));
        elseif isa(arg, Real)                        # ==> a dataset column with only one row
            args[pos] = [arg]
        elseif isa(arg, Dataset)                ;    # ==> a Dataset object
        elseif hasmethod(recipe, tuple(typeof(arg))) # ==> implicit recipe
            # @info which(recipe, tuple(typeof(arg)))  # debug
            deleteat!(args, pos)
            pe = recipe(arg)
            if isa(pe, AbstractGPCommand)
                insert!(args, pos, pe)
            elseif isa(pe, Vector{<: AbstractGPCommand})
                for i in 1:length(pe)
                    insert!(args, pos, pe[i])
                end
            else
                error("Recipe must return an AbstractGPCommand or Vector{<: AbstractGPCommand}")
            end
            continue
        elseif isa(arg, Vector{<: AbstractGPCommand})    # ==> explicit recipe (vector)
            deleteat!(args, pos)
            for i in length(arg):-1:1
                insert!(args, pos, arg[i])
            end
        elseif isa(arg, GPPlotDataCommands)     ;    # ==> explicit recipe (scalar)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end

        pos += 1
    end

    # Third pass: convert data into Dataset objects
    pos = 1
    accum = Vector{AbstractArray}()
    while pos <= length(args)
        arg = args[pos]
        taken = false

        if isa(arg, AbstractArray)
            if nonmissingtype(eltype(arg)) != eltype(arg)
                @assert nonmissingtype(eltype(arg)) <: AbstractFloat "Missing values are supported only on arrays of floats"
                arg = replace(arg, missing => NaN)
            end
            tt = eltype(arg)

            # Try to convert into Int, Float64 and String
            if (tt  <: Integer)  &&  !(tt <: Int)
                arg = convert(Array{Int}, arg)
            elseif (tt  <: AbstractFloat)  &&  !(tt <: Float64)
                arg = convert(Array{Float64}, arg)
            elseif (tt  <: AbstractString)  &&  !(tt <: String)
                arg = convert(Array{String}, arg)
            end

            tt = eltype(arg)
            if  (tt <: Real)  ||
                (tt <: AbstractString)
                push!(accum, arg)
                deleteat!(args, pos)
                taken = true
            end
        end

        if !taken  ||  (pos > length(args))
            if length(accum) > 0
                mm = extrema(length.(accum))
                if mm[1] == 0   # empty Dataset
                    @assert mm[1] == mm[2] "At least one input array is empty, while other(s) are not"
                    d = DatasetEmpty()
                else
                    d = Dataset(accum)
                end
                insert!(args, pos, d)
                empty!(accum)
            end

            pos += 1
        end
    end

    # Fourth pass: collect specs
    mid = 1
    cmds = Vector{String}()
    out_specs = Vector{AbstractGPCommand}()
    pos = 1
    while pos <= length(args)
        arg = args[pos]

        if isa(arg, Int)                         # ==> multiplot index
            mid = arg
        elseif isa(arg, Tuple)  &&               # ==> a keyword/value pair
            length(arg) == 2    &&
            isa(arg[1], Symbol)
            push!(out_specs, GPCommand(parseKeywords(; [arg]...), mid=mid))
        elseif isa(arg, String)                  # ==> a plotspec or a command
            push!(out_specs, parseStrAsCommand(arg, mid))
        elseif isa(arg, Pair)                    # ==> name => dataset pair
            name = arg[1]
            @info "AAA" arg[2]
            @info arg[1] arg[2] typeof(arg[2])
            @assert  isa(arg[2], Dataset)
            @assert !isa(arg[2], DatasetEmpty)
            push!(out_specs, GPNamedDataset(arg[1], arg[2]))
        elseif isa(arg, Dataset)                 # ==> Unnamed Dataset
            if !isa(arg, DatasetEmpty)
                cmd = ""
                if (pos < length(args))  &&  isa(args[pos+1], String)
                    cmd = args[pos+1]
                    deleteat!(args, pos+1)
                end
                @info cmd
                push!(out_specs, GPPlotDataCommand(arg, cmd, mid=mid))
            end
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end
        pos += 1
    end

    return (out_sid, out_doReset, out_doDump, out_specs)
end
