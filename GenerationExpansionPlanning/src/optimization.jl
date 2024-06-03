export run_optimisation

"""
    run_optimisation(data::ExperimentData, optimizer_factory, lowerbound=nothing, line_capacities_bidirectional::Bool)::ExperimentResult

    create and optimize model. line_capacities_bidirectional is used to specify whether you ar using bidirectional capacity lines or directional
"""
function run_optimisation(data::ExperimentData, optimizer_factory, line_capacities_bidirectional::Bool, lowerbound=nothing)::ExperimentResult
    # 1. Extract data into local variables
    @info "Reading the sets"
    N = data.locations
    G = data.generation_technologies
    NG = data.generators
    T = data.time_steps
    L = data.transmission_lines

    @info "Converting dataframes to dictionaries"
    filter!(row -> row.time_step ∈ T, data.demand)
    filter!(row -> row.time_step ∈ T, data.generation_availability)
    demand = dataframe_to_dict(data.demand, [:location, :time_step], :demand)
    generation_availability = dataframe_to_dict(data.generation_availability, [:location, :technology, :time_step], :availability)
    investment_cost = dataframe_to_dict(data.generation, [:location, :technology], :investment_cost)
    variable_cost = dataframe_to_dict(data.generation, [:location, :technology], :variable_cost)
    unit_capacity = dataframe_to_dict(data.generation, [:location, :technology], :unit_capacity)
    ramping_rate = dataframe_to_dict(data.generation, [:location, :technology], :ramping_rate)

    if line_capacities_bidirectional
        export_capacity = dataframe_to_dict(data.transmission_capacities, [:from, :to], :export_capacity)
        import_capacity = dataframe_to_dict(data.transmission_capacities, [:from, :to], :import_capacity)
    else
        transmission_capacity = dataframe_to_dict(data.transmission_capacities, [:from, :to], :capacity)
    end

    @info "Solving the problem"
    dt = @elapsed begin
        # 2. Add variables to the model
        @info "Populating the model"
        model = JuMP.Model(optimizer_factory)
        @info "Adding the variables"
        @variable(model, 0 ≤ total_investment_cost)
        @variable(model, 0 ≤ total_operational_cost)
        @variable(model, 0 ≤ investment[n ∈ N, g ∈ G; (n, g) ∈ NG], integer = !data.relaxation)
        @variable(model, 0 ≤ production[n ∈ N, g ∈ G, T; (n, g) ∈ NG])

        if line_capacities_bidirectional
            @variable(model,
            -import_capacity[n_from, n_to] ≤
            line_flow[n_from ∈ N, n_to ∈ N, t ∈ T; (n_from, n_to) ∈ L] ≤
            export_capacity[n_from, n_to]
        )
        else
            @variable(model,
                0 ≤
                line_flow[n_from ∈ N, n_to ∈ N, t ∈ T; (n_from, n_to) ∈ L] ≤
                transmission_capacity[n_from, n_to]
            )
        end
        @variable(model, 0 ≤ loss_of_load[n ∈ N, t ∈ T] ≤ demand[n, t])

        @info "Precomputing expressions"
        investment_MW = @expression(model, [n ∈ N, g ∈ G; (n, g) ∈ NG], unit_capacity[n, g] * investment[n, g])

        # 3. Add an objective to the model
        @info "Adding the objective"
        @objective(model, Min, total_investment_cost + total_operational_cost)

        # 4. Add constraints to the model
        @info "Adding the constraints"
        @info "Adding the cost constraints"
        @constraint(model, total_investment_cost == sum(investment_cost[n, g] * investment_MW[n, g] for (n, g) ∈ NG))
        @constraint(model,
            total_operational_cost
            ==
            sum(variable_cost[n, g] * production[n, g, t] for (n, g) ∈ NG, t ∈ T)
            +
            data.value_of_lost_load * sum(loss_of_load[n, t] for n ∈ N, t ∈ T)
        )

        # Node balance
        @info "Adding the balance constraints"
        @constraint(model, [n ∈ N, t ∈ T],
            sum(production[n, g, t] for g ∈ G if (n, g) ∈ NG)
            +
            sum(line_flow[n_from, n_to, t] for (n_from, n_to) ∈ L if n_to == n)
            -
            sum(line_flow[n_from, n_to, t] for (n_from, n_to) ∈ L if n_from == n)
            +
            loss_of_load[n, t]
            ==
            demand[n, t]
        )

        # Maximum production
        @info "Adding the maximum production constraints"
        # for technologies without the availability profile, the availability is 
        # always equal to 100%, that is, 1.0. This is why we use
        # get(generation_availability, (n, g, t), 1.0) and not
        # generation_availability[n, g, t]
        @constraint(model, [n ∈ N, g ∈ G, t ∈ T; (n, g) ∈ NG],
            production[n, g, t] ≤ get(generation_availability, (n, g, t), 1.0) * investment_MW[n, g]
        )

        @info "Adding the ramping constraints"
        ramping = @expression(model, [n ∈ N, g ∈ G, t ∈ T; t > 1 && (n, g) ∈ NG],
            production[n, g, t] - production[n, g, t-1]
        )
        for (n, g, t) ∈ eachindex(ramping)
            # Ramping up
            @constraint(model, ramping[n, g, t] ≤ ramping_rate[n, g] * investment_MW[n, g])
            # Ramping down
            @constraint(model, ramping[n, g, t] ≥ -ramping_rate[n, g] * investment_MW[n, g])
        end

        if lowerbound !== nothing
            @info "Setting upper bound"
            set_optimizer_attribute(model, "Cutoff", lowerbound)
        end 

        # 5. Solve the model
        @info "Solving the model"
        optimize!(model)
    end

    investment_type = if data.relaxation
        Float64
    else
        Int
    end
    investment_decisions_units = jump_variable_to_df(investment; dim_names=(:location, :technology), value_name=:units, value_type=investment_type)
    investment_decisions_MW = jump_variable_to_df(investment_MW; dim_names=(:location, :technology), value_name=:capacity)
    investment_decisions = leftjoin(investment_decisions_MW, investment_decisions_units, on=[:location, :technology])

    production_decisions = jump_variable_to_df(production; dim_names=(:location, :technology, :time_step), value_name=:production)
    line_flow_decisions = jump_variable_to_df(line_flow; dim_names=(:from, :to, :time_step), value_name=:flow)
    loss_of_load_decisions = jump_variable_to_df(loss_of_load; dim_names=(:location, :time_step), value_name=:loss_of_load)

    return ExperimentResult(
        value.(total_investment_cost),
        value.(total_operational_cost),
        investment_decisions,
        production_decisions,
        line_flow_decisions,
        loss_of_load_decisions,
        dt
    )
end
