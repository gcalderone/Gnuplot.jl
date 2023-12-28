abstract type AbstractGPInput end

struct GPCommand <: AbstractGPInput
    mid::Int
    cmd::String
    GPCommand(cmd::AbstractString; mid::Int=1) = new(mid, deepcopy(string(cmd)))
    GPCommand(cmds::Vector{<: AbstractString}; mid::Int=1) = new(mid, join(string.(cmds), ";\n"))
end

struct GPNamedDataset <: AbstractGPInput
    name::String
    data::DatasetText
    GPNamedDataset(name::AbstractString, data::DatasetText) =
        new(string(name), data)
end

struct GPPlotCommand <: AbstractGPInput
    mid::Int
    is3d::Bool
    cmd::String
    GPPlotCommand(cmd::AbstractString; mid::Int=1, is3d::Bool=false) =
        new(mid, is3d, string(cmd))
end

struct GPPlotDataCommand <: AbstractGPInput
    mid::Int
    is3d::Bool
    data::Dataset
    cmd::String

    GPPlotDataCommand(data::Dataset, cmd::AbstractString; mid::Int=1, is3d::Bool=false) =
        new(mid, is3d, data, string(cmd))
end


# ---------------------------------------------------------------------
function parseKeywords(; kws...)
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

    kw = canonicalize(template; kws...)
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
function parseAsPlotCommand(s::String, mid::Int)
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


parseSpecs() = Vector{AbstractGPInput}()
function parseSpecs(_args...; default_mid=1, is3d=false, kws...)
    args = Vector{Any}([_args...])

    # First pass: check data types, search for mid, run implicit recipes and splat Vector{GPPlotDataCommands}
    pos = 1
    mid = nothing
    while pos <= length(args)
        arg = args[pos]
        if isa(arg, Int)                        ;    # ==> multiplot ID
            @assert isnothing(mid) "Multiplot ID can only be specified once"
            @assert pos == 1 "Multiplot ID must be specified before plot specs."
            mid = arg
        elseif isa(arg, AbstractString)              # ==> a plotspec or a command
            args[pos] = string(strip(arg))
        elseif isa(arg, Pair)                        # ==> a named dataset
            @assert typeof(arg[1]) == String "Dataset name must be a string"
            @assert arg[1][1] == '$' "Dataset name must start with a dollar sign"
            if !isa(arg[2], Dataset)
                deleteat!(args, pos)
                accum = [arg[2][i] for i in 1:length(arg[2])]
                insert!(args, pos, arg[1] => DatasetText(accum...))
            end
        elseif isa(arg, AbstractArray) &&            # ==> a dataset column
            ((nonmissingtype(eltype(arg)) <: Real)    ||
            (nonmissingtype(eltype(arg)) <: AbstractString));
        elseif isa(arg, Dataset)                ;    # ==> a Dataset object
        elseif hasmethod(recipe, tuple(typeof(arg))) # ==> implicit recipe
            # @info which(recipe, tuple(typeof(arg)))  # debug
            deleteat!(args, pos)
            pe = recipe(arg)
            if isa(pe, AbstractGPInput)
                insert!(args, pos, pe)
            elseif isa(pe, Vector)  &&  all(isa.(pe, AbstractGPInput))
                for p in reverse(pe)
                    insert!(args, pos, p)
                end
            else
                error("Recipe must return an AbstractGPInput or Vector{<: AbstractGPInput}")
            end
            continue
        elseif isa(arg, Vector{<: AbstractGPInput})# ==> explicit recipe (vector)
            deleteat!(args, pos)
            for i in length(arg):-1:1
                insert!(args, pos, arg[i])
            end
        elseif isa(arg, AbstractGPInput)      ;    # ==> explicit recipe (scalar)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end
        pos += 1
    end

    # Second pass: convert data into Dataset objects
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
            if (tt <: Integer)  &&  !(tt <: Int)
                arg = convert(Array{Int}, arg)
            elseif (tt <: AbstractFloat)  &&  !(tt <: Float64)
                arg = convert(Array{Float64}, arg)
            elseif (tt <: AbstractString)  &&  !(tt <: String)
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
                d = Dataset(accum)
                insert!(args, pos, d)
                empty!(accum)
            end

            pos += 1
        end
    end

    # Third pass: collect specs
    isnothing(mid)  &&  (mid = default_mid)
    out_specs = Vector{AbstractGPInput}()
    s = parseKeywords(; kws...)
    (s != "")  &&  push!(out_specs, GPCommand(s, mid=mid))

    pos = 1
    while pos <= length(args)
        arg = args[pos]

        if isa(arg, Int)                         # ==> multiplot ID
            ;
        elseif isa(arg, String)                  # ==> a plotspec or a command
            push!(out_specs, parseAsPlotCommand(arg, mid))
        elseif isa(arg, Pair)                    # ==> name => dataset pair
            name = arg[1]
            @assert  isa(arg[2], Dataset)
            push!(out_specs, GPNamedDataset(arg[1], arg[2]))
        elseif isa(arg, Dataset)                 # ==> Unnamed Dataset
            cmd = ""
            if (pos < length(args))  &&  isa(args[pos+1], String)
                cmd = args[pos+1]
                deleteat!(args, pos+1)
            end
            push!(out_specs, GPPlotDataCommand(arg, cmd, mid=mid, is3d=is3d))
        elseif isa(arg, AbstractGPInput)
            push!(out_specs, arg)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end
        pos += 1
    end

    return out_specs
end
