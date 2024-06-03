export ExperimentData, ExperimentResult

"""
Data needed to run a single experiment (i.e., a single optimization model)
"""
struct ExperimentData
    # Sets
    time_steps::Vector{Int}
    locations::Vector{Symbol}
    transmission_lines::Vector{Tuple{Symbol,Symbol}}
    generators::Vector{Tuple{Symbol,Symbol}}
    generation_technologies::Vector{Symbol}

    # Dataframes
    demand::AbstractDataFrame
    generation_availability::AbstractDataFrame
    generation::AbstractDataFrame
    transmission_capacities::AbstractDataFrame

    # Scalars
    value_of_lost_load::Float64
    relaxation::Bool

    function ExperimentData(config_dict::Dict)
        sets = config_dict[:sets]
        data = config_dict[:data]
        scalars = data[:scalars]

        return new(
            sets[:time_steps],
            sets[:locations],
            sets[:transmission_lines],
            sets[:generators],
            sets[:generation_technologies],
            data[:demand],
            data[:generation_availability],
            data[:generation],
            data[:transmission_lines],
            scalars[:value_of_lost_load],
            scalars[:relaxation],
        )
    end
end

struct ExperimentResult
    total_investment_cost::Float64
    total_operational_cost::Float64
    investment::AbstractDataFrame
    production::AbstractDataFrame
    line_flow::AbstractDataFrame
    loss_of_load::AbstractDataFrame
    runtime::Float64

    function ExperimentResult(
        total_investment_cost::Float64,
        total_operational_cost::Float64,
        investment::DataFrame,
        production::DataFrame,
        line_flow::DataFrame,
        loss_of_load::DataFrame,
        runtime::Float64
    )
        return new(
            total_investment_cost,
            total_operational_cost,
            investment,
            production,
            line_flow,
            loss_of_load,
            runtime
        )
    end
end
