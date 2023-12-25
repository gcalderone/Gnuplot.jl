# ---------------------------------------------------------------------
"""
    PlotSpecs

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
PlotSpecs(;mid::Int=0, is3d::Bool=false,
          cmds::Union{String, Vector{String}}=Vector{String}(),
          name::String="",
          data::Dataset=DatasetEmpty(),
          plot::Union{String, Vector{String}}=Vector{String}(),
          kwargs...)
```
No field is mandatory, i.e. even `Gnuplot.PlotSpecs()` provides a valid structure.
The constructor also accept all the keywords accepted by `parseKeywords`.
"""
mutable struct PlotSpecs
    mid::Int
    is3d::Bool
    cmds::Vector{String}
    name::String
    data::Dataset
    plot::String

    function PlotSpecs(;mid::Int=1, is3d::Bool=false,
                       cmds::Union{String, Vector{String}}=Vector{String}(),
                       name::String="",
                       data::Dataset=DatasetEmpty(),
                       plot::String="")
        if isa(cmds, String)
            if cmds != ""
                cmds = [cmds]
            end
        end        
        new(mid, is3d, cmds, name, data, plot)
    end
end


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

    # First pass: check for session names and `:-`
    sid = nothing
    args = Vector{Any}([_args...])
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if  (typeof(arg) == Symbol)  &&
            (arg != :-)
            @assert isnothing(sid) "Only one session at a time can be addressed"
            sid = arg
            deleteat!(args, pos)
            continue
        end
        pos += 1
    end
    isnothing(sid)  &&  (sid = options.default)

    if length(args) == 0
        doReset = false
    else
        doReset = true
    end
    doDump = true
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if typeof(arg) == Symbol
            @assert arg == :-
            if pos == 1
                doReset = false
            elseif pos == length(args)
                doDump  = false
            else
                @warn "Symbol `:-` has a meaning only if it is at first or last position in argument list."
            end
            deleteat!(args, pos)
            continue
        end
        pos += 1
    end

    # Second pass: check data types, run implicit recipes and splat
    # Vector{PlotSpecs}
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
            ((nonmissingtype(eltype(arg)) <: Real)    ||
             (nonmissingtype(eltype(arg)) <: AbstractString))  ;
        elseif isa(arg, Real)                        # ==> a dataset column with only one row
            args[pos] = [arg]
        elseif isa(arg, Dataset)                ;    # ==> a Dataset object
        elseif hasmethod(recipe, tuple(typeof(arg))) # ==> implicit recipe
            # @info which(recipe, tuple(typeof(arg)))  # debug
            deleteat!(args, pos)
            pe = recipe(arg)
            if isa(pe, PlotSpecs)
                insert!(args, pos, pe)
            elseif isa(pe, Vector{PlotSpecs})
                for i in 1:length(pe)
                    insert!(args, pos, pe[i])
                end
            else
                error("Recipe must return a PlotSpecs or Vector{PlotSpecs}")
            end
            continue
        elseif isa(arg, Vector{PlotSpecs})         # ==> explicit recipe (vector)
            deleteat!(args, pos)
            for i in length(arg):-1:1
                insert!(args, pos, arg[i])
            end
        elseif isa(arg, PlotSpecs)            ;    # ==> explicit recipe (scalar)
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

    # Fourth pass: collect PlotSpecs objects
    mid = 1
    name = ""
    cmds = Vector{String}()
    elems = Vector{PlotSpecs}()
    pos = 1
    while pos <= length(args)
        arg = args[pos]

        if isa(arg, Int)                         # ==> multiplot index
            if length(cmds) > 0
                push!(elems, PlotSpecs(mid=mid, cmds=cmds))
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
                push!(elems, PlotSpecs(mid=mid, is3d=is3d, cmds=cmds, plot=s))
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
                push!(elems, PlotSpecs(mid=mid, cmds=cmds, name=name, data=arg, plot=spec))
            end
            name = ""
            empty!(cmds)
        elseif isa(arg, PlotSpecs)
            if length(cmds) > 0
                push!(elems, PlotSpecs(mid=mid, cmds=cmds))
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
        push!(elems, PlotSpecs(mid=mid, cmds=cmds))
        empty!(cmds)
    end

    return (sid, doReset, doDump, elems)
end
