# How to Use

In julia REPL, add the environment variable for your Gurobi installation

```julia
ENV["GUROBI_HOME"] = "PATH_TO_GUROBI"
```

Then go to the package mode by pressing <kbd>]</kbd>, and activate the environment in the current directory:
```
pkg> activate .
pkg> add Gurobi
pkg> develop ./GenerationExpansionPlanning
```

Press <kbd>backspace</kbd> to return to Julia REPL.

You should be able to run `main.jl` or your own scripts using `GenerationExpansionPlanning` module now.

# Mathematical formulation

## Sets
| **Name**                  | **Description**         |
|---------------------------|-------------------------|
| $N$                       | locations (nodes)       |
| $G$                       | generation technologies |
| $NG \subseteq N \times G$ | generation units        |
| $T$                       | time steps              |
| $L$                       | transmission lines      |

## Parameters
| **Name**                  | **Symbol**        | **Index Sets** | **Description**                             | **Unit** |
|---------------------------|-------------------|----------------|---------------------------------------------|----------|
| `demand`                  | $D$               | $N \times T$   | Demand                                      | MW       |
| `generation_availability` | $A$               | $NG \times T$  | Generation availability (load factor)       | 1/unit   |
| `investment_cost`         | $I$               | $NG$           | Investment cost                             | EUR/MW   |
| `variable_cost`           | $V$               | $NG$           | Variable production cost                    | EUR/MWh  |
| `unit_capacity`           | $U$               | $NG$           | Capacity per each invested unit             | MW/unit  |
| `ramping_rate`            | $R$               | $NG$           | Ramping rate                                | 1/unit   |
| `export_capacity`         | $L^{\text{exp}}$  | $L$            | Maximum transmission export capacity (A->B) | MW       |
| `import_capacity`         | $L^{\text{imp}}$  | $L$            | Maximum transmission import capacity (A<-B) | MW       |
| `data.value_of_lost_load` | $V^{\text{loss}}$ |                | Value of lost load                          | EUR/MWh  |
| `data.relaxation`         |                   |                | Solve the LP relaxation?                    | Bool     |

## Variables
| **Name**                 | **Symbol**        | **Index Sets** | **Domain**                          | **Description**                             | **Unit** |
|--------------------------|-------------------|----------------|-------------------------------------|---------------------------------------------|----------|
| `total_investment_cost`  | $c^{\text{inv}}$  |                | $\mathbb{R}_+$                      | Total investment cost                       | EUR      |
| `total_operational_cost` | $c^{\text{op}}$   |                | $\mathbb{R}_+$                      | Total operatinal cost                       | EUR      |
| `investment`             | $i$               | $NG$           | $\mathbb{Z}_+$                      | Generation investment                       | units    |
| `production`             | $p$               | $NG \times T$  | $\mathbb{R}_+$                      | Generation production                       | MW       |
| `line_flow`              | $f$               | $L \times T$   | $[-L^{\text{imp}}, L^{\text{exp}}]$ | Transmission line flow                      | MW       |
| `loss_of_load`           | $p^{\text{loss}}$ | $N \times T$   | $\mathbb{R}_+$                      | Loss of load                                | MW       |


## Problem Formulation

$$\begin{aligned}
\text{minimize}
&& c^{\text{inv}} &+ c^{\text{op}} \\
\text{subject to:} \\
\text{investment cost} && c^{\text{inv}} &= \sum_{(n, g) \in NG} I_{n,g} \cdot U_{n,g} \cdot i_{n,g} \\
\text{operational cost} && c^{\text{op}} &= \sum_{(n, g) \in NG} \sum_{t \in T} V_{n,g} \cdot p_{n,g,t} + \sum_{n \in N} \sum_{t \in T} V^{\text{loss}} \cdot p^{\text{loss}}_{n,t} \\
\end{aligned}$$

$$\begin{aligned}
\text{node balance} && D_{n,t} &= \sum_{g \in G: (n,g) \in NG} p_{n,g,t} + \sum_{(n^{\text{from}}, n^{\text{to}}) \in L : n^{\text{to}} = n} f_{n^{\text{from}}, n^{\text{to}}, t} - \sum_{(n^{\text{from}}, n^{\text{to}}) \in L : n^{\text{from}} = n} f_{n^{\text{from}}, n^{\text{to}}, t} + p^{\text{loss}}_{n,t} && \forall n \in N\, \forall t \in T \\
\end{aligned}$$

$$\begin{aligned}
\text{maximum capacity} && p_{n, g, t} &\leq A_{n, g, t} \cdot U_{n,g} \cdot i_{n,g} && \forall (n, g) \in NG\, \forall t \in T \\
\text{ramping up} && p_{n, g, t} - p_{n, g, t-1} &\leq R_{n,g} \cdot U_{n,g} \cdot i_{n,g} && \forall (n, g) \in NG\, \forall t \in T \setminus \{ 1 \} \\
\text{ramping down} && p_{n, g, t} - p_{n, g, t-1} &\geq -R_{n,g} \cdot U_{n,g} \cdot i_{n,g} && \forall (n, g) \in NG\, \forall t \in T \setminus \{ 1 \} \\
\end{aligned}$$
