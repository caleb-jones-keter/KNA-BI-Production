[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"RPA Report LW" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "RPA Report LW", ItemKind = "Table"]}[Data],
  #"Spare Part Key" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 3", "Spare Part Key", each Text.Combine({[Product SKU], [Spare Part SKU], [GMD24], [Country]}, " | ")), {{"Spare Part Key", type text}}),
  #"Removed duplicates" = Table.Distinct(#"Spare Part Key", {"Spare Part Key"})

in
  #"Removed duplicates";
shared #"RPA Report TW" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "RPA Report TW", ItemKind = "Table"]}[Data],
  #"Spare Part Key" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 3", "Spare Part Key", each Text.Combine({[Product SKU], [Spare Part SKU], [GMD24], [Country]}, " | ")), {{"Spare Part Key", type text}}),
  #"Removed duplicates" = Table.Distinct(#"Spare Part Key", {"Spare Part Key"})
in
  #"Removed duplicates";
shared #"New Spare Parts" = let
  Source = Table.NestedJoin(#"RPA Report TW", {"Spare Part Key"}, #"RPA Report LW", {"Spare Part Key"}, "RPA Report LW", JoinKind.LeftAnti),
  #"New Spare Part" = Table.AddColumn(Source, "Status", each "New Spare Part"),
  #"Changed column type" = Table.TransformColumnTypes(#"New Spare Part", {{"Status", type text}})
in
  #"Changed column type";
shared #"Missing Spare Parts" = let
  Source = Table.NestedJoin(#"RPA Report LW", {"Spare Part Key"}, #"RPA Report TW", {"Spare Part Key"}, "RPA Report TW", JoinKind.LeftAnti),
  #"Missing Spare Part" = Table.AddColumn(Source, "Status", each "Missing Spare Part"),
  #"Changed column type" = Table.TransformColumnTypes(#"Missing Spare Part", {{"Status", type text}})
in
  #"Changed column type";
shared #"New & Missing Spare Parts List" = let
  Source = Table.Combine({#"New Spare Parts", #"Missing Spare Parts"})
in
  Source;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "FACT RPA Report MPL_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"FACT RPA Report MPL" = let
  Source = Table.Combine({#"RPA Report TW", #"RPA Report LW"}),
  #"Sorted rows" = Table.Sort(Source, {{"Data Source Order", Order.Ascending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"Spare Part Key"}),
  #"Merged queries" = Table.NestedJoin(#"Removed duplicates", {"Spare Part Key"}, #"New & Missing Spare Parts List", {"Spare Part Key"}, "FACT New Spare Parts List", JoinKind.LeftOuter),
  #"Expanded FACT New Spare Parts List" = Table.ExpandTableColumn(#"Merged queries", "FACT New Spare Parts List", {"Status"}, {"Status"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded FACT New Spare Parts List", {{"Status", type text}}),
  #"Replaced value" = Table.ReplaceValue(#"Changed column type", null, "Existing Spare Part", Replacer.ReplaceValue, {"Status"}),
  Material_Country_Key = Table.TransformColumnTypes(Table.AddColumn(#"Replaced value", "Material_Country_Key", each Text.Combine({[Product SKU], [Country]}, " | ")), {{"Material_Country_Key", type text}}),
  #"Merged queries 1" = Table.NestedJoin(Material_Country_Key, {"Product SKU"}, #"Last sale date", {"Material"}, "Last sale date", JoinKind.LeftOuter),
  #"Expanded Last sale date" = Table.ExpandTableColumn(#"Merged queries 1", "Last sale date", {"Last Sale Date"}, {"Last Sale Date.1"}),
  #"Merged queries 2" = Table.NestedJoin(#"Expanded Last sale date", {"Product SKU"}, #"Warranty Period", {"NA Finished Good"}, "Warranty Period", JoinKind.LeftOuter),
  #"Expanded Warranty Period" = Table.ExpandTableColumn(#"Merged queries 2", "Warranty Period", {"Warranty _Year_"}, {"Warranty _Year_"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Expanded Warranty Period", null, 0, Replacer.ReplaceValue, {"Warranty _Year_"}),

    #"Added custom" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Replaced value 1",
                "Last Warranty Date",
                each
                    let
                        saleDate = try Date.From([Last Sale Date.1]) otherwise null,
                        warrantyYears = try Number.RoundDown([Warranty _Year_]) otherwise 0
                    in
                        if saleDate <> null
                        then Date.AddYears(saleDate, warrantyYears)
                        else null
            ),
            {{"Last Warranty Date", type date}}
        ),

    #"Grouped rows" =
        Table.Group(
            #"Added custom",
            {"Spare Part SKU"},
            {
                {
                    "Max SP Warranty Date",
                    each List.Max([Last Warranty Date]),
                    type nullable date
                }
            }
        ),

    #"Merged Max Warranty" =
        Table.NestedJoin(
            #"Added custom",
            {"Spare Part SKU"},
            #"Grouped rows",
            {"Spare Part SKU"},
            "MaxWarranty",
            JoinKind.LeftOuter
        ),

    #"Expanded Max Warranty" =
        Table.ExpandTableColumn(
            #"Merged Max Warranty",
            "MaxWarranty",
            {"Max SP Warranty Date"}
        ),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded Max Warranty", "Spare Part SKU | Country", each [Spare Part SKU] & " | " & [Country]), {{"Spare Part SKU | Country", type text}}),
  #"Merged queries 3" = Table.NestedJoin(#"Added custom 1", {"Spare Part SKU | Country"}, #"SP ZMM02", {"Material_Country_Key"}, "SP ZMM02", JoinKind.LeftOuter),
  #"Expanded SP ZMM02" = Table.ExpandTableColumn(#"Merged queries 3", "SP ZMM02", {"MS", "Material Type", "Reorder Point"}, {"SP ZMM02.MS", "SP ZMM02.Material Type", "SP ZMM02.Reorder Point"}),
  #"Merged queries 4" = Table.NestedJoin(#"Expanded SP ZMM02", {"Material_Country_Key"}, #"SP FG Quantities", {"Material_Country_Key"}, "SP FG Quantities", JoinKind.LeftOuter),
  #"Expanded SP FG Quantities" = Table.ExpandTableColumn(#"Merged queries 4", "SP FG Quantities", {"Quantity Last Year", "Quantity YTD", "CY Demand", "LY Demand"}, {"Quantity Last Year", "Quantity YTD", "CY Demand", "LY Demand"}),
  #"Merged queries 5" = Table.NestedJoin(#"Expanded SP FG Quantities", {"Product SKU"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged queries 5", "DIM Product", {"Description", "PC Business Unit"}, {"Product Name", "Business Unit"}),
  #"Added custom 2" = Table.AddColumn(#"Expanded DIM Product", "Product SKU & DESC", each [Product SKU] & " " & [Product Name]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom 2", {{"Product SKU & DESC", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type 1", {{"Product Color Desc", "Color Code"}})
in
    #"Renamed columns";
shared #"FACT RPA Report MPL_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "FACT RPA Report MPL", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"Last sale date" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Last sale date", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Warranty Period" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Warranty Period", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"SP ZMM02" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "SP ZMM02", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"SP FG Quantities" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "SP FG Quantities", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "New Spare Parts List_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"New Spare Parts List" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "CRM_SPARE_PARTS", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"MATNR_SKU", Int64.Type}, {"Spare_Part_SKU", Int64.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "Product SKU", each [MATNR_SKU]), {{"Product SKU", type text}}),
  #"Added custom 1" = 
Table.TransformColumnTypes(Table.AddColumn(#"Added custom","Spare Part SKU", each [Spare_Part_SKU]), {{"Spare Part SKU", type text}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom 1", {"Spare_Part_SKU", "MATNR_SKU"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"Spare_Part_SKU_Desc", "Spare Part Name"}, {"QUANTITY", "Qty Spare Parts per ptoduct"}, {"SP_SET", "set/apart"}, {"SP_PRE_VERSION", "Spare Part Previous Version"}, {"SP_LABEL", "Sign"}, {"SPARE_PART_SIZE", "Spare Part Size"}, {"SP_COLOR", "Product Color Code"}, {"SP_COLOR_Desc", "Product Color Desc"}, {"CountryName_SKU", "Country"}, {"Group_Key_SKU", "GMD24"}, {"Group_Name_SKU", "STD.PROD.SITE (SOURCE) GMD 5 desc"}}),
  #"Removed columns 1" = Table.RemoveColumns(#"Renamed columns", {"Prod_SKU_Desc", "MRP_type"})
in
  #"Removed columns 1";
shared CRM_PRODUCT = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "CRM_PRODUCT", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared CRM_SPARE_PARTS_LIST = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "CRM_SPARE_PARTS_LIST", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"New Spare Parts List_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "New Spare Parts List", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
