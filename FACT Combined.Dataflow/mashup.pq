[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"FACT Combined" = let
  Source = #"FACT Future",
  Combiner = Table.Combine({Source,#"FACT MB51 Grouped"}),
  #"Changed Type" = Table.TransformColumnTypes(Combiner, {{"Combined Date", type date}, {"LH SOURCE", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed Type", {{"_MrrContainers_.status", "EnfoPak_MrrContainers_.status"}})
in
  #"Renamed columns";
shared #"FACT MB51 Grouped" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT MB51 Grouped", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.AddColumn(#"Navigation 3", "LH SOURCE", each "FACT MB51 Grouped")
in
  #"Added custom";
shared #"FACT Future" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT Future", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.AddColumn(#"Navigation 3", "LH SOURCE", each "FACT Future")
in
  #"Added custom";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
