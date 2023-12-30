abstract type AbstractGPSpec end

# A gnuplot spec belonging to a specific plot when multiplot is in use
abstract type AbstractGPSpecMid <: AbstractGPSpec end

mutable struct GPCommand <: AbstractGPSpecMid
    mid::Int
    cmd::String
    GPCommand(mid::Int, cmd::AbstractString) = new(mid, deepcopy(string(cmd)))
    GPCommand(mid::Int, cmds::Vector{<: AbstractString}) = new(mid, join(string.(cmds), ";\n"))
end

struct GPNamedDataset <: AbstractGPSpec
    name::String
    data::DatasetText
end

struct GPPlotCommand <: AbstractGPSpecMid
    mid::Int
    is3d::Bool
    cmd::String
end

struct GPPlotWithData <: AbstractGPSpecMid
    mid::Int
    is3d::Bool
    data::Dataset
    cmd::String
end


# ---------------------------------------------------------------------
"""
    parseKeywords(; kws...)

Parse keywords and return corresponding gnuplot commands.  The accepted keywords are:
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
"""
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
function parseAsPlotCommand(mid::Int, s::String)
    (length(s) >= 2)  &&  (s[1:2] ==  "p "    )  &&  (return GPPlotCommand(mid, false, strip(s[2:end])))
    (length(s) >= 3)  &&  (s[1:3] ==  "pl "   )  &&  (return GPPlotCommand(mid, false, strip(s[3:end])))
    (length(s) >= 4)  &&  (s[1:4] ==  "plo "  )  &&  (return GPPlotCommand(mid, false, strip(s[4:end])))
    (length(s) >= 5)  &&  (s[1:5] ==  "plot " )  &&  (return GPPlotCommand(mid, false, strip(s[5:end])))
    (length(s) >= 2)  &&  (s[1:2] ==  "s "    )  &&  (return GPPlotCommand(mid, true , strip(s[2:end])))
    (length(s) >= 3)  &&  (s[1:3] ==  "sp "   )  &&  (return GPPlotCommand(mid, true , strip(s[3:end])))
    (length(s) >= 4)  &&  (s[1:4] ==  "spl "  )  &&  (return GPPlotCommand(mid, true , strip(s[4:end])))
    (length(s) >= 5)  &&  (s[1:5] ==  "splo " )  &&  (return GPPlotCommand(mid, true , strip(s[5:end])))
    (length(s) >= 6)  &&  (s[1:6] ==  "splot ")  &&  (return GPPlotCommand(mid, true , strip(s[6:end])))
    return GPCommand(mid, s)
end


"""
    parseSpecs(args...; kws...)

Parse plot spec and convert them in a form suitable to be sent to the underlying gnuplot process.
The function accepts any number of arguments, with the following meaning:

- a leading `Int` (>= 1) is interpreted as the plot destination in a multi-plot session;

- one, or a group of consecutive, array(s) of either `Real` or `String` build up a dataset.  The different arrays are accessible as columns 1, 2, etc. from the `gnuplot` process.  The number of required input arrays depends on the chosen plot style (see `gnuplot` documentation);

- a string occurring before a dataset is interpreted as a `gnuplot` command (e.g. `set grid`).  If the string begins with "plot" or "splot" it is interpreted as the corresponding gnuplot commands (note: "plot" and "splot" can be abbreviated to "p" and "s" respectively, or "pl" and "spl", etc.);

- a string occurring immediately after a dataset is interpreted as a *plot element* for the dataset, by which you can specify `using` clause, `with` clause, line styles, etc..  All keywords may be abbreviated following gnuplot conventions.

- an input in the form `"\\\$name"=>(array1, array2, etc...)` is interpreted as a named dataset.  Note that the dataset name must always start with a "`\$`";

- any object `<:AbstractGPSpec` or `Vector{<:AbstractGPSpec}` is simply appended to the output.

- any other data type is processed through an implicit recipe. If a suitable recipe do not exists an error is raised.

All keywords will be processed via the `Gnuplot.parseKeywords` function.
"""
parseSpecs() = Vector{AbstractGPSpec}()
function parseSpecs(_args...; default_mid=1, is3d=false, kws...)
    args = Vector{Any}([_args...])

    # First pass: check data types, search for mid, run implicit recipes and splat Vector{<: AbstractGPSpec}
    mid = 0
    pos = 1
    while pos <= length(args)
        arg = args[pos]
        if isa(arg, Int)                        ;    # ==> multiplot ID
            @assert mid == 0 "Multiplot ID can only be specified once"
            @assert pos == 1 "Multiplot ID must be specified before plot specs"
            @assert arg >= 1 "Multiplot ID must be a positive integer"
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
            @assert length(arg) > 0 "Empty arrays are not allowed"
        elseif isa(arg, Dataset)                ;    # ==> a Dataset object
        elseif hasmethod(recipe, tuple(typeof(arg))) # ==> implicit recipe
            # @info which(recipe, tuple(typeof(arg)))  # debug
            deleteat!(args, pos)
            pe = recipe(arg)
            if isa(pe, AbstractGPSpec)
                insert!(args, pos, pe)
            elseif isa(pe, Vector)  &&  all(isa.(pe, AbstractGPSpec))
                for p in reverse(pe)
                    insert!(args, pos, p)
                end
            else
                error("Recipe must return an AbstractGPSpec or Vector{<: AbstractGPSpec}")
            end
            continue
        elseif isa(arg, Vector{<: AbstractGPSpec})# ==> explicit recipe (vector)
            deleteat!(args, pos)
            for i in length(arg):-1:1
                insert!(args, pos, arg[i])
            end
        elseif isa(arg, AbstractGPSpec)      ;    # ==> explicit recipe (scalar)
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
    (mid == 0)  &&  (mid = default_mid)
    out_specs = Vector{AbstractGPSpec}()
    s = parseKeywords(; kws...)
    (s != "")  &&  push!(out_specs, GPCommand(mid, s))

    pos = 1
    while pos <= length(args)
        arg = args[pos]

        if isa(arg, Int)                         # ==> multiplot ID
            ;
        elseif isa(arg, String)                  # ==> a plotspec or a command
            push!(out_specs, parseAsPlotCommand(mid, arg))
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
            push!(out_specs, GPPlotWithData(mid, is3d, arg, cmd))
        elseif isa(arg, AbstractGPSpec)
            push!(out_specs, arg)
        else
            error("Unexpected argument with type " * string(typeof(arg)))
        end
        pos += 1
    end

    return out_specs
end
