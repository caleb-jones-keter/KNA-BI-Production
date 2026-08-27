[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "fact_dummy250950data_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared fact_dummy250950data = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "fact_dtc_rate_matrix", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each [material] = "252140"),

    // Group, sort each subtable by cost ascending, keep the first row
    #"Grouped rows" =
        Table.Group(
            #"Filtered rows",
            {"material", "dest_zip_clean"},
            {
                {"BestRow",
                    (t as table) as table =>
                        Table.FirstN(
                            Table.Sort(t, {{"total_cost", Order.Ascending}}),
                            1
                        ),
                    type table
                }
            }
        ),

    // Expand the columns you care about from the winning row
    #"Expanded BestRow" =
        Table.ExpandTableColumn(
            #"Grouped rows",
            "BestRow",
            {"total_cost", "ship_point", "ship_type"},
            {"min_total_cost", "best_ship_point", "best_ship_type"}
        ),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded BestRow", {{"min_total_cost", type number}, {"best_ship_point", type text}, {"best_ship_type", type text}})
in
    #"Changed column type";
shared fact_dummy250950data_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, PreserveOrder = null]),
  Navigation_1 = Pattern{[workspaceId = "0ff64ee2-e4e8-4574-af9a-a67ff4998667"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "b7b9a4bd-259d-4ebd-9792-d6f8c49a72e8"]}[Data],
  TableNavigation = Navigation_2{[Id = "fact_dummy250950data", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "FACT YS10N_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"FACT YS10N" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT YS10N Base", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Product_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM USA CA Zips_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM USA CA Zips" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM USA CA Zips", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"FACT YS10N_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, PreserveOrder = null]),
  Navigation_1 = Pattern{[workspaceId = "0ff64ee2-e4e8-4574-af9a-a67ff4998667"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "b7b9a4bd-259d-4ebd-9792-d6f8c49a72e8"]}[Data],
  TableNavigation = Navigation_2{[Id = "FACT YS10N", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DIM Product_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, PreserveOrder = null]),
  Navigation_1 = Pattern{[workspaceId = "0ff64ee2-e4e8-4574-af9a-a67ff4998667"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "b7b9a4bd-259d-4ebd-9792-d6f8c49a72e8"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM Product", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DIM USA CA Zips_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, PreserveOrder = null]),
  Navigation_1 = Pattern{[workspaceId = "0ff64ee2-e4e8-4574-af9a-a67ff4998667"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "b7b9a4bd-259d-4ebd-9792-d6f8c49a72e8"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM USA CA Zips", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[BindToDefaultDestination = true]
shared #"fact_dummy250950data No Vegas" = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "fact_dtc_rate_matrix", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each ([material] = "252140") and ([ship_point] <> "SpreeTail Vegas")),

    // Group, sort each subtable by cost ascending, keep the first row
    #"Grouped rows" =
        Table.Group(
            #"Filtered rows",
            {"material", "dest_zip_clean"},
            {
                {"BestRow",
                    (t as table) as table =>
                        Table.FirstN(
                            Table.Sort(t, {{"total_cost", Order.Ascending}}),
                            1
                        ),
                    type table
                }
            }
        ),

    // Expand the columns you care about from the winning row
    #"Expanded BestRow" =
        Table.ExpandTableColumn(
            #"Grouped rows",
            "BestRow",
            {"total_cost", "ship_point", "ship_type"},
            {"min_total_cost", "best_ship_point", "best_ship_type"}
        ),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded BestRow", {{"min_total_cost", type number}, {"best_ship_point", type text}, {"best_ship_type", type text}})
in
    #"Changed column type";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "0ff64ee2-e4e8-4574-af9a-a67ff4998667"]}[Data]{[lakehouseId = "b7b9a4bd-259d-4ebd-9792-d6f8c49a72e8"]}[Data];
[BindToDefaultDestination = true]
shared #"fact_dummy250950data No Rancho" = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "fact_dtc_rate_matrix", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each ([material] = "252140") and ([ship_point] <> "Rancho")),

    // Group, sort each subtable by cost ascending, keep the first row
    #"Grouped rows" =
        Table.Group(
            #"Filtered rows",
            {"material", "dest_zip_clean"},
            {
                {"BestRow",
                    (t as table) as table =>
                        Table.FirstN(
                            Table.Sort(t, {{"total_cost", Order.Ascending}}),
                            1
                        ),
                    type table
                }
            }
        ),

    // Expand the columns you care about from the winning row
    #"Expanded BestRow" =
        Table.ExpandTableColumn(
            #"Grouped rows",
            "BestRow",
            {"total_cost", "ship_point", "ship_type"},
            {"min_total_cost", "best_ship_point", "best_ship_type"}
        ),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded BestRow", {{"min_total_cost", type number}, {"best_ship_point", type text}, {"best_ship_type", type text}})
in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"fact_dummy250950data Pivot" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "fact_dtc_rate_matrix_pivot", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 3", each [material] = "252140")
in
  #"Filtered rows";
