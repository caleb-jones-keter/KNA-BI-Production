[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"DIM Account" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT YS10N All", ItemKind = "Table"]}[Data],
  #"Removed other columns" = Table.SelectColumns(#"Navigation 2", {"Payer", "Material"}),
  #"Filtered rows" = Table.SelectRows(#"Removed other columns", each ([Payer] <> null and [Payer] <> "") and ([Material] <> null and [Material] <> "")),
  #"Appended query" = Table.Combine({#"Filtered rows", #"FACT Forecast Adjusted"}),
  #"Removed duplicates" = Table.Distinct(#"Appended query", {"Payer", "Material"}),
  #"Merged queries" = Table.NestedJoin(#"Removed duplicates", {"Payer"}, #"DIM Customer", {"Payer Key"}, "Customer", JoinKind.LeftOuter),
  #"Expanded Customer" = Table.ExpandTableColumn(#"Merged queries", "Customer", {"Customer Groups", "Payer & Desc","Payer Types.Detail","Payer Types.Type"}, {"Customer Groups", "Payer & Desc","Payer Types.Detail","Payer Types.Type"}),
  #"Removed duplicates 1" = Table.Distinct(#"Expanded Customer", {"Payer", "Material"})
in
  #"Removed duplicates 1";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
shared #"FACT Forecast Adjusted" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT Forecast Adjusted", ItemKind = "Table"]}[Data],
  #"Removed other columns" = Table.SelectColumns(#"Navigation 2", {"Payer", "Material"})
in
  #"Removed other columns";
shared #"DIM Customer" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Customer", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
