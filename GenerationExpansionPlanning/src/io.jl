export read_config, dataframe_to_dict, jump_variable_to_df, save_result

"""
    keys_to_symbols(dict::AbstractDict{String,Any}; recursive::Bool=true)::Dict{Symbol,Any}

Create a new dictionary that is identicals to `dict`, except all of the keys 
are converted from strings to
[symbols](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols).
Symbols are [interned](https://en.wikipedia.org/wiki/String_interning) and are
faster to work with when they serve as unique identifiers.
"""
function keys_to_symbols(
    dict::AbstractDict{String,Any};
    recursive::Bool=true
)::Dict{Symbol,Any}
    return Dict(Symbol(k) =>
        if recursive && typeof(v) <: Dict
            keys_to_symbols(v)
        else
            v
        end
                for (k, v) in dict
    )
end

"""
    read_config(config_path::AbstractString)::Dict{Symbol,Any}

Parse the contents of the config file `config_path` into a dictionary. The file
must be in TOML format.
"""
function read_config(config_path::AbstractString)::Dict{Symbol,Any}
    current_dir = pwd()  # current working directory
    full_path = (current_dir, config_path) |> joinpath |> abspath  # full path to the config file

    # read config to a dictionary and change keys to symbols
    config = full_path |> TOML.parsefile |> keys_to_symbols

    # aliases for input config dictionaries 
    data_config = config[:input][:data]
    sets_config = config[:input][:sets]

    # find the input directory
    config_dir = full_path |> dirname  # directory where the config is located
    input_dir = (config_dir, data_config[:dir]) |> joinpath |> abspath  # input data directory

    # read the dataframes from files

    function read_file!(path::AbstractString, key::Symbol, format::Symbol)
        if format ≡ :CSV
            data_config[key] = (path, data_config[key]) |> joinpath |> CSV.File |> DataFrame
            string_columns = findall(col -> eltype(col) <: AbstractString, eachcol(data_config[key]))
            data_config[key][!, string_columns] = Symbol.(data_config[key][!, string_columns])
        elseif format ≡ :TOML
            data_config[key] = (path, data_config[key]) |> joinpath |> TOML.parsefile |> keys_to_symbols
        end
    end

    read_file!(input_dir, :demand, :CSV)
    read_file!(input_dir, :generation_availability, :CSV)
    read_file!(input_dir, :generation, :CSV)
    read_file!(input_dir, :transmission_lines, :CSV)
    read_file!(input_dir, :scalars, :TOML)

    # remove the directory entry as it has been added to the file paths
    # and therefore it is no longer needed
    delete!(data_config, :dir)

    # resolve the sets

    if sets_config[:time_steps] == "auto"
        t_min = min(minimum(data_config[:demand].time_step), minimum(data_config[:generation_availability].time_step))
        t_max = max(maximum(data_config[:demand].time_step), maximum(data_config[:generation_availability].time_step))
        sets_config[:time_steps] = t_min:t_max
    end

    if sets_config[:locations] == "auto"
        sets_config[:locations] =
            data_config[:demand].location ∪
            data_config[:generation_availability].location ∪
            data_config[:generation].location ∪
            data_config[:transmission_lines].from ∪
            data_config[:transmission_lines].to
    end

    if sets_config[:generators] == "auto"
        sets_config[:generators] =
            Tuple.(map(collect, zip(data_config[:generation].location, data_config[:generation].technology)))
    end
    sets_config[:generation_technologies] = unique([g[2] for g ∈ sets_config[:generators]])

    if sets_config[:transmission_lines] == "auto"
        sets_config[:transmission_lines] =
            Tuple.(map(collect, zip(data_config[:transmission_lines].from, data_config[:transmission_lines].to)))
    end

    config[:output][:dir] = (config_dir, config[:output][:dir]) |> joinpath |> abspath
    config[:line_capacities_bidirectional] = data_config[:line_capacities_bidirectional]

    return config
end

"""
    dataframe_to_dict(
        df::AbstractDataFrame,
        keys::Union{Symbol, Vector{Symbol}},
        value::Symbol
    ) -> Dict

Convert the dataframe `df` to a dictionary using columns `keys` as keys and
`value` as values. `keys` can contain more than one column symbol, in which case
a tuple key is constructed.
"""
function dataframe_to_dict(
    df::AbstractDataFrame,
    keys::Union{Symbol,Vector{Symbol}},
    value::Symbol
)::Dict
    return if typeof(keys) <: AbstractVector
        Dict(Tuple.(eachrow(df[!, keys])) .=> Vector(df[!, value]))
    else
        Dict(Vector(df[!, keys]) .=> Vector(df[!, value]))
    end
end

"""
Returns a `DataFrame` with the values of the variables from the JuMP container
`variable`. The column names of the `DataFrame` can be specified for the
indexing columns in `dim_names`, and the name and type of the data value column
by a Symbol `value_name` (e.g., `:Value`) and a DataType `value_type`.
"""
function jump_variable_to_df(variable::AbstractArray{T,N};
    dim_names::NTuple{N,Symbol},
    value_name::Symbol=:value,
    value_type::DataType=Float64) where {T<:Union{VariableRef,AffExpr},N}

    if isempty(variable)
        return DataFrame()
    end
    values = value.(variable)
    df = DataFrame(Containers.rowtable(values), [dim_names..., value_name])
    if value_type <: Integer
        df[!, value_name] = round.(df[:, value_name])
    end
    df[!, value_name] = convert.(value_type, df[:, value_name])
    filter!(row -> row[value_name] ≠ 0.0, df)
    return df
end


function save_result(result::ExperimentResult, config::Dict{Symbol,Any})
    dir = config[:dir]
    mkpath(dir)

    function save_dataframe(df::AbstractDataFrame, file::String)
        full_path = (dir, file) |> joinpath
        CSV.write(full_path, df)
    end

    save_dataframe(result.investment, config[:investment])
    save_dataframe(result.production, config[:production])
    save_dataframe(result.line_flow, config[:line_flow])
    save_dataframe(result.loss_of_load, config[:loss_of_load])

    scalar_data = Dict(
        :total_investment_cost => result.total_investment_cost,
        :total_operational_cost => result.total_operational_cost,
        :runtime => result.runtime,
    )
    fname = (dir, config[:scalars]) |> joinpath
    open(fname, "w") do io
        TOML.print(io, scalar_data)
    end
end

function store_relaxed_data(data::ExperimentData)
    dir = "inputs"
    mkpath(dir)

    function save_dataframe(df::AbstractDataFrame, file::String)
        full_path = (dir, file) |> joinpath
        CSV.write(full_path, df)
    end

    save_dataframe(data.demand, "relaxed_demand.csv")
    save_dataframe(data.generation_availability, "relaxed_generation_availability.csv")
    save_dataframe(data.generation, "relaxed_generation.csv")
    save_dataframe(data.transmission_capacities, "relaxed_transmission_capacities.csv")
end
