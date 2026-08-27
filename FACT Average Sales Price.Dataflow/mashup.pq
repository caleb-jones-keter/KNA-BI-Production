[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "FACT YS10N_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"FACT YS10N Average Sales Price" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT YS10N All", ItemKind = "Table"]}[Data],

    // Get today's date
    Today = Date.From(DateTime.LocalNow()),

    // Get the date one year ago
    OneYearAgo = Date.AddYears(Today, -1),

    // Filter rows: only last year, excluding today and future
    FilteredRows = Table.SelectRows(
        #"Navigation 3",
        each [Combined Date] <> null 
            and [Combined Date] >= OneYearAgo 
            and [Combined Date] < Today
    ),
  #"Filtered rows" = Table.SelectRows(FilteredRows, each [Material] <> null and [Material] <> ""),
  #"Grouped rows" = Table.Group(#"Filtered rows", {"Material"}, {{"Combined Qty", each List.Sum(List.Transform([Combined Qty], Number.Abs)), type nullable number}, {"Net Value USD", each List.Sum([Net Value USD]), type nullable number}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Grouped rows", "Average Sales Price", each [Net Value USD] / [Combined Qty]), {{"Average Sales Price", Currency.Type}})
in
    #"Added custom";
shared #"FACT YS10N_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "FACT YS10N Average Sales Price", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
