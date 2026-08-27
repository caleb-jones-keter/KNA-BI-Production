[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "YM6P US Import Spare Parts_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"YM6P US Import Spare Parts" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "YM6P US Import Spare Parts", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "Source Column", each "YM6P"), {{"Source Column", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Today", each DateTime.Date(DateTime.LocalNow())), {{"Today", type date}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "Data Source Country", each "USA"), {{"Data Source Country", type text}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Material_Country_Key", each Text.Combine({[Material],  [Data Source Country]}, " | ")), {{"Material_Country_Key", type text}}),
  #"Added custom 4" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 3", "Material and Description", each [Material] & " - " & [Material Description]), {{"Material and Description", type text}})
in
  #"Added custom 4";
shared #"YM6P US Import Spare Parts_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Fact YM6p Open US Spare Parts", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Spare Parts Notes_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Spare Parts Notes" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Spare Parts Notes", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Finished Goods EDB_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Finished Goods EDB" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "Finished Goods EDB", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 3", "Country Short", each if [Country] = "UNITED STATES" then "USA" else if [Country] = "CANADA" then "Canada" else null), {{"Country Short", type text}}),
  #"Added custom 1" = Table.AddColumn(#"Added custom", "Material_Country_Key", each Text.Combine({Text.From([#"Code:SKU Level _c4_"]), [Country Short]}, " | ")),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom 1", {{"Material_Country_Key", type text}}),
  #"Quantity sold last year" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Changed column type",
        "Quantity_LastYear",
        each 
            let
                // Try to get a valid date
                dailyDate = try Date.From([#"Daily Date _MM/dd/yyyy_"]) otherwise null,
                // Try to get a valid number
                qty = try Number.From([Quantity]) otherwise 0,
                lastYear = Date.Year(DateTime.LocalNow()) - 1
            in
                if dailyDate <> null and Date.Year(dailyDate) = lastYear then qty else 0
    ),
    {{"Quantity_LastYear", type number}}
),
  #"YTD Sales" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Quantity sold last year",
        "YTD Quantity",
        each 
            let
                currentDate = Date.From(DateTime.LocalNow()),
                startOfYear = #date(Date.Year(currentDate), 1, 1),
                dailyDate = try Date.FromText([Daily Date]) otherwise null,
                qty = try Number.From([Quantity]) otherwise 0
            in
                if dailyDate <> null and dailyDate >= startOfYear and dailyDate <= currentDate then qty else 0
    ),
    {{"YTD Quantity", type number}}
),
  #"Customer Demand CY" = Table.TransformColumnTypes(Table.AddColumn(#"YTD Sales", "Customer Demand This Year", each if Date.Year(Date.From([#"Daily Date _MM/dd/yyyy_"])) = Date.Year(DateTime.LocalNow()) then [#"Customer Demand"] else 0), {{"Customer Demand This Year", type number}}),
  #"Customer Demand LY" = Table.TransformColumnTypes(Table.AddColumn(#"Customer Demand CY", "Customer Demand Last Year", each if Date.Year(Date.From([#"Daily Date _MM/dd/yyyy_"])) = Date.Year(DateTime.LocalNow()) - 1 then [#"Customer Demand"] else 0), {{"Customer Demand Last Year", type number}}) 
in
  #"Customer Demand LY";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Finished Goods Notes_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Finished Goods Notes" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Finished Goods Notes", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Spare Parts Notes_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Spare Parts Notes", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"Finished Goods EDB_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Finished Goods EDB", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"Finished Goods Notes_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Finished Goods Notes", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "SP (FG Product Link)_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"SP (FG Product Link)" = let
  Source = #"Finished Goods EDB",
  #"Removed columns" = Table.RemoveColumns(Source, {"Code:Country _c2_", "Code:SKU Level _c4_", "Quantity", "Customer Demand", "Daily Date _MM/dd/yyyy_", "US DOLLAR_Sap Material Type", "Country", "PC Business Unit", "SKU Level", "Daily Date", "Country Short"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns", {"Material_Country_Key"})
in
  #"Removed duplicates";
shared #"SP (FG Product Link)_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "SP _FG Product Link_", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "SP ZMM02_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"SP ZMM02" = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "ZMM02", ItemKind = "Table"]}[Data],
  #"Appended query" = Table.Combine({#"Navigation 2", #"Additional zmm02 SP info"}),
    #"Added Custom" = Table.AddColumn(
        #"Appended query",
        "Country Assignment",
        each 
            let
                plnt = [Plnt]
            in
                if List.Contains({"60", "65", "67", "68", "73"}, plnt) then "USA"
                else if List.Contains({"66", "69"}, plnt) then "Canada"
                else "Needs Assignment"
    ),
    #"Changed Type" = Table.TransformColumnTypes(#"Added Custom", {{"Country Assignment", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed Type", "Material_Country_Key", each Text.Combine({Text.From([Material]), [Country Assignment]}, " | ")), {{"Material_Country_Key", type text}}),
  #"Sorted rows" = Table.Sort(#"Added custom 1", {{"MS", Order.Ascending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"Material_Country_Key"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed duplicates", {{"Standard price", type text}, {"per", type text}})
in
    #"Changed column type";
shared #"SP ZMM02_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "SP ZMM02", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Last sale date_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Last sale date" = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "2018 to 2024 Sales", ItemKind = "Table"]}[Data],
    #"Appended query" = Table.Combine({#"Navigation 2", #"Finished Goods EDB"}),
    #"Removed columns" = Table.RemoveColumns(#"Appended query", {
        "Daily Date _MM/dd/yyyy_", 
        "Country Short", 
        "Material_Country_Key", 
        "Customer Demand"
    }),
  #"Replaced value" = Table.ReplaceValue(#"Removed columns", null, 0, Replacer.ReplaceValue, {"Quantity__2018_2019_2020_2021_2022_2023_2024_"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Replaced value", null, 0, Replacer.ReplaceValue, {"Quantity"}),
  #"Added custom" = Table.AddColumn(#"Replaced value 1", "Combined QTY", each [Quantity__2018_2019_2020_2021_2022_2023_2024_] + [Quantity]),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"Combined QTY", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "US Daily Date", each Date.From(DateTimeZone.SwitchZone(DateTimeZone.From(DateTime.FromText([Daily Date], "en-GB")), 0))), {{"US Daily Date", type date}}),
  #"Removed columns 1" = Table.RemoveColumns(#"Added custom 1", {"Quantity__2018_2019_2020_2021_2022_2023_2024_", "Quantity", "Daily Date"}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Removed columns 1", "Max US Daily Date by SKU Level", each let
            sku = [#"Code:SKU Level _c4_"],
            filtered = Table.SelectRows(#"Removed columns 1", each [#"Code:SKU Level _c4_"] = sku and [Combined QTY] > 0),
            maxDate = List.Max(List.Transform(filtered[US Daily Date], Date.From))
        in
            maxDate), {{"Max US Daily Date by SKU Level", type date}}),
  #"Removed columns 2" = Table.RemoveColumns(#"Added custom 2", {"Country", "Code:Country _c2_", "US Daily Date", "Combined QTY", "SKU Level", "PC Business Unit", "US DOLLAR_Sap Material Type","Quantity_LastYear", "YTD Quantity"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns 2", {"Code:SKU Level _c4_"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed duplicates", {{"Code:SKU Level _c4_", "Material"}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Renamed columns", {{"Material", type text}}),
  #"Renamed columns 1" = Table.RenameColumns(#"Changed column type 1", {{"Max US Daily Date by SKU Level", "Last Sale Date"}}),
  #"Removed errors" = Table.ReplaceErrorValues(
    #"Renamed columns 1",
    {{"Last Sale Date", #date(1900,1,1)}}
)

in
    #"Removed errors";
shared #"Last sale date_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  TableNavigation = Navigation_2{[Id = "Last sale date", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"Additional zmm02 SP info" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Additional zmm02 SP info", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "SP FG Quantities_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"SP FG Quantities" = let
  Source = #"Finished Goods EDB",
  #"Grouped rows" = Table.Group(Source, {"Material_Country_Key"}, {{"Quantity Last Year", each List.Sum([Quantity_LastYear]), type nullable number}, {"Quantity YTD", each List.Sum([YTD Quantity]), type nullable number}, {"CY Demand", each List.Sum([Customer Demand This Year]), type nullable number}, {"LY Demand", each List.Sum([Customer Demand Last Year]), type nullable number}})
in
  #"Grouped rows";
shared #"SP FG Quantities_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "SP FG Quantities", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
