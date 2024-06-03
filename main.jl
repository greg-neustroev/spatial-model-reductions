using GenerationExpansionPlanning
using Gurobi

# Step 1: Read the experiment config
@info "Reading the config"
# config_path = "case_studies/stylized_EU/config.toml"
config_path = "case_studies/7_locations_chain/config.toml"
# config_path = "case_studies/8_locations/config.toml"
# config_path = "case_studies/8_locations_chain/config.toml"
# config_path = "case_studies/stylized_EU_directional/config.toml"
# config_path = "case_studies/2_locations/config.toml"
config = read_config(config_path)

# Step 2: Parse the data
@info "Parsing the config data"
experiment_data = ExperimentData(config[:input])

# Step 3: Run the experiments
@info "Running the experiments defined by $config_path"
experiment_result = run_experiment(experiment_data, Gurobi.Optimizer, config[:line_capacities_bidirectional])

# Step 4: Save the results
output_config = config[:output]
save_result(experiment_result, output_config)
