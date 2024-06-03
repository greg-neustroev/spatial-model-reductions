
import pandas as pd


df = pd.read_csv("case_studies/8_locations_chain/inputs/transmission_lines.csv")

df_export = df[["from", "to", "export_capacity"]]
df_export = df_export.rename(columns={"export_capacity": "capacity"})

df_import = df[["to", "from", "import_capacity"]]
df_import = df_import.rename(columns={"import_capacity": "capacity", "from": "to", "to": "from"})

df_combined = pd.concat([df_import, df_export])

df_combined.to_csv("case_studies/8_locations_chain/inputs/transmission_lines2.csv", index=False)