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
    @assert all((dims .== 1)  .|  (dims .== maximum(dims))) "Array size are incompatible"

    accum = Vector{String}()

    # All 1D
    if firstMultiDim == 0
        # @info "Case 1"
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
        # @info "Case 2"
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
            # @info "Case 3"
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
            # @info "Case 4"
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


"""
    Dataset

Abstract type for all dataset structures.
"""
abstract type Dataset end

"""
    DatasetText

A dataset whose data are stored as a text buffer.

Transmission to gnuplot may be slow for large datasets, but no temporary file is involved, and the dataset can be saved directly into a gnuplot script.  Also, the constructor allows to build more flexible datasets (i.e. mixing arrays with different dimensions).

Constructors are defined as follows:
```julia
DatasetText(data::Vector{String})
DatasetText(data::Vararg{AbstractArray, N}) where N
```
In the second form the type of elements of each array must be one of `Real`, `AbstractString` and `Missing`.
"""
mutable struct DatasetText <: Dataset
    preview::Vector{String}
    data::String
    DatasetText(::Val{:inner}, preview, data) = new(preview, data)
end

DatasetText(args::Vararg{AbstractArray, N}) where N = DatasetText(arrays2datablock(args...))
function DatasetText(data::Vector{String})
    preview = (length(data) <= 4  ?  deepcopy(data)  :  [data[1:4]..., "..."])
    d = DatasetText(Val(:inner), preview, join(data, "\n"))
    return d
end


# ---------------------------------------------------------------------
"""
    DatasetBin

A dataset whose data are stored as a binary file.

Ensure best performances for large datasets, but involve use of a temporary file.  When saving a script the file is stored in a directory with the same name as the main script file.

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
#=
The following is dismissed since `binary matrix` do not allows to use
keywords such as `rotate`.

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
# using Base.Threads
function DatasetBin(VM::Vararg{AbstractMatrix, N}) where N
    for i in 2:N
        @assert size(VM[i]) == size(VM[1])
    end
    s = size(VM[1])
    # path = tempname()
    # run(`mkfifo $path`)
    # Base.Threads.@spawn begin
    # io = open(path, "w")
    (path, io) = mktemp()
    for i in 1:s[1]
        for j in 1:s[2]
            for k in 1:N
                write(io, Float32(VM[k][i,j]))
            end
        end
    end
    close(io)
    # end # use "volatile" keyword
    source = " '$path' binary array=(" * join(string.(reverse(s)), ", ") * ")"
    # Note: can't add `using` here, otherwise we can't append `flipy`.
    return DatasetBin(Val(:inner), path, source)
end


# ---------------------------------------------------------------------
function DatasetBin(cols::Vararg{AbstractVector, N}) where N
    source = "binary record=$(length(cols[1])) format='"
    types = Vector{DataType}()
    #(length(cols) == 1)  &&  (source *= "%int")
    for i in 1:length(cols)
        @assert length(cols[1]) == length(cols[i])
        if     isa(cols[i][1], Int32);   push!(types, Int32);   source *= "%int32"
        elseif isa(cols[i][1], Int);     push!(types, Int64);   source *= "%int64"
        elseif isa(cols[i][1], Float32); push!(types, Float32); source *= "%float32"
        elseif isa(cols[i][1], Float64); push!(types, Float64); source *= "%float64"
        elseif isa(cols[i][1], Char);    push!(types, Char);    source *= "%char"
        else
            error("Unsupported data on column $i: $(typeof(cols[i][1]))")
        end
    end
    source *= "'"

    (path, io) = mktemp()
    source = " '$path' $source"
    for row in 1:length(cols[1])
        #(length(cols) == 1)  &&  (write(io, convert(Int32, row)))
        for col in 1:length(cols)
            write(io, convert(types[col], cols[col][row]))
        end
    end
    close(io)

    #=
    The following using clause is needed to cope with the following case:
    x = randn(10001)
    @gp  x x x "w p lc pal"  # Error: Not enough columns for variable color
    @gsp x x x "w p lc pal"  # this works regardless of the using clause

    But adding this clause here implies we should check for duplicated
    using clause in collect_commands()
    =#
    source *= " using " * join(1:N, ":")
    return DatasetBin(Val(:inner), path, source)
end


# ---------------------------------------------------------------------
function useBinaryMethod(args...)
    @assert options.preferred_format in [:auto, :bin, :text] "Unexpected value for `options.preferred_format`: $(options.preferred_format)"
    binary = false
    if options.preferred_format == :bin
        binary = true
    elseif options.preferred_format == :auto
        if (length(args) == 1)  &&  isa(args[1], AbstractMatrix)
            binary = true
        elseif all(ndims.(args) .== 1)  &&  all(Base.:<:.(eltype.(args), Real))
            s = sum(length.(args))
            if s > 1e4
                binary = true
            end
        end
    end
    return binary
end


# ---------------------------------------------------------------------
function Dataset(args)
    if useBinaryMethod(args...)
        try
            return DatasetBin(args...)
        catch err
            isa(err, MethodError)  ||  rethrow()
        end
    end
    return DatasetText(args...)
end

