import random
import os

def get_clusters(locations):
    if len(locations) == 0:
        return []
    if len(locations) == 1:
        return locations[0]
    clustered_locations = []
    for i in range(0, len(locations), 2):
        if i + 1 >= len(locations):
            clustered_locations.append([locations[i]])
        else:            
            clustered_locations.append([locations[i], locations[i+1]])
    return get_clusters(clustered_locations)


def create_chain_clusters(chain_length):
    locations = []
    for i in range(chain_length):
        locations.append([f"l{i}"])
    
    return get_clusters(locations)    
    
    
def create_clique_case_study(name, n, time_steps):
    folder = f'case_studies/{name}'
    input_folder = f'{folder}/inputs'

    # Create folders
    if not os.path.exists(folder):
        os.makedirs(folder)
    if not os.path.exists(input_folder):
        os.makedirs(input_folder)


    # Demands
    demands = ["location,time_step,demand"]
    for location in range(n):
        for time_step in range(time_steps):
            demands.append(f"l{location},{time_step},100")

    with open(f'{input_folder}/demand.csv', 'w+') as f:
        f.write('\n'.join(demands) + '\n')


    # Generation availability
    generation_av = ["location,technology,time_step,availability"]
    # TODO add generation availability
    with open(f'{input_folder}/generation_availability.csv', 'w+') as f:
        f.write('\n'.join(generation_av) + '\n')


    # Generation
    generation = ["technology,location,investment_cost,variable_cost,unit_capacity,ramping_rate"]

    for location in range(n):
        generation.append(f"Gas,l{location},23.33333333,0.05,250,0.75")

    with open(f'{input_folder}/generation.csv', 'w+') as f:
        f.write('\n'.join(generation) + '\n')

    # transmission_lines
    transmission_lines = ["from,to,capacity"]
    for i in range(n-1):
        transmission_lines.append(
            f"l{i},l{i+1},{random.randint(1, 20) * 10}"
        )

    with open(f'{input_folder}/transmission_lines2.csv', 'w+') as f:
        f.write("\n".join(transmission_lines))

    with open(f'{input_folder}/scalars.toml', 'w+') as f:
        f.write("""# Value of lost load (cost of not supplying energy) [kEUR/MWh]
value_of_lost_load = 3.0
# If true, an LP relaxation of the problem will be solved
relaxation = false
    """)

    with open(f'{folder}/config.toml', 'w+') as f:
        f.write(f"""[input.data]
# input directory with the files
dir = "inputs"
demand = "demand.csv"
generation_availability = "generation_availability.csv"
generation = "generation.csv"
transmission_lines = "transmission_lines2.csv"
scalars = "scalars.toml"
line_capacities_bidirectional = false
clusters = {create_chain_clusters(n)}
[input.sets]
time_steps = "auto"
locations = "auto"
transmission_lines = "auto"
generators = "auto"
[output]
dir = "output"
investment = "investment.csv"
production = "production.csv"
line_flow = "line_flow.csv"
loss_of_load = "loss_of_load.csv"
scalars = "scalars.toml"
                """)
    
    
n = 5
create_clique_case_study(f"n_chain", n, 100)