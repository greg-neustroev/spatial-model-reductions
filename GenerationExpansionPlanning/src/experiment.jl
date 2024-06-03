export run_experiment

function run_experiment(data::ExperimentData, optimizer_factory, line_capacities_bidirectional::Bool)::ExperimentResult
    benchmark_relaxations(data, optimizer_factory, line_capacities_bidirectional)

    return run_optimisation(data, optimizer_factory, line_capacities_bidirectional, nothing)
end

function benchmark_relaxations(data::ExperimentData, optimizer_factory, line_capacities_bidirectional::Bool)
    @assert line_capacities_bidirectional == false "TODO relaxations are only possible with directional line capacities right now. try running case_studies/stylized_EU_directional"
    @info "doing experiments"
    results_df = DataFrame(n_clusters=Int[], clusters=Vector{Set{Symbol}}[], objective=Float64[], runtime=Float64[])
    dendogram = create_clusters_hierarchy(data)
    i = 2
    while i <= length(data.locations)
        data_relaxed, clusters = relaxation_iteration(data, dendogram, i)
        relaxed_experiment_result = run_optimisation(data_relaxed, optimizer_factory, line_capacities_bidirectional, nothing)
        objective = relaxed_experiment_result.total_investment_cost + relaxed_experiment_result.total_operational_cost
        push!(results_df,  (i, clusters, objective, relaxed_experiment_result.runtime))
        i = i * 2
    end
    # for i = length(data.locations)-1:-1:2
    #     data_relaxed, clusters = relaxation_iteration(data, dendogram, i)
    #     # store_relaxed_data(data_relaxed)
    #     relaxed_experiment_result = run_optimisation(data_relaxed, optimizer_factory, line_capacities_bidirectional, nothing)
    #     objective = relaxed_experiment_result.total_investment_cost + relaxed_experiment_result.total_operational_cost
    #     push!(results_df,  (i, clusters, objective, relaxed_experiment_result.runtime))
    # end

    @info "finished benchmarks"
    
    # write DataFrame out to CSV file
    CSV.write("results.csv", results_df)
end

function create_clusters_hierarchy(data::ExperimentData)::Hclust
    edges = []
    capacities = []
    location_indices = Dict(location => i for (i, location) ∈ enumerate(data.locations))

    for line in eachrow(data.transmission_capacities)
        source = location_indices[line.from]
        dest = location_indices[line.to]
        # capacity = mean([line.export_capacity, line.import_capacity])  # Use average capacity from both ways
        capacity = line.capacity
        push!(edges, (source, dest))
        push!(capacities, capacity)
    end

    # Create a distance matrix where the distance is inversely related to capacity
    n = length(data.locations)
    dist_matrix = fill(Inf, n, n)

    for (i, edge) in enumerate(edges)
        source, dest = edge
        dist = 1 / capacities[i]
        dist_matrix[source, dest] = dist
        dist_matrix[dest, source] = dist  # Assuming undirected graph
    end 

    # Perform hierarchical clustering using single linkage
    return hclust(dist_matrix, linkage=:single)
end