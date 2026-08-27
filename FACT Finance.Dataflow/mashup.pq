[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"2025A" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/2026%20Import%20Logistics%20P&L.xlsx"), null, false),
  #"2025A_sheet" = Source{[Item = "2025A", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"2025A_sheet", [PromoteAllScalars = true]),
  #"Removed bottom rows" = Table.RemoveLastN(#"Promoted headers", 90),
  #"Removed blank rows" = Table.SelectRows(#"Removed bottom rows", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
  #"Removed other columns" = Table.SelectColumns(#"Removed blank rows", {"012", "011", "010", "009", "008", "007", "006", "005", "004", "003", "002", "001", "Code: Account Detail", "Code: Cost Center Detail", "Account Detail", "Cost Center Detail", "BA-Level4-Posting Level", "Roll Up 2", "Roll Up 1"}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Removed other columns", {{"Code: Cost Center Detail", type text}, {"Code: Account Detail", type text}}),
  #"Unpivoted columns" = Table.UnpivotOtherColumns(#"Changed column type 2", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail"}, "Attribute", "Value"),
  #"Renamed columns" = Table.RenameColumns(#"Unpivoted columns", {{"Attribute", "Month"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Month", Int64.Type}}),
  #"Changed column type 3" = Table.TransformColumnTypes(#"Changed column type", {{"Month", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 3", "Finance Key", each [#"Code: Cost Center Detail"] & "-" & [#"Code: Account Detail"] & "-" & [Month]), {{"Finance Key", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Data Source", each "2025A"), {{"Data Source", type text}})
in
  #"Added custom 1";
shared #"2026B" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/2026%20Import%20Logistics%20P&L.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "2026B", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Removed blank rows" = Table.SelectRows(#"Promoted headers", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Removed blank rows", {{"Code: Cost Center Detail", type text}, {"Code: Account Detail", type text}}),
  #"Removed other columns" = Table.SelectColumns(#"Changed column type 2", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail", "001", "002", "003", "004", "005", "006", "007", "008", "009", "010", "011", "012"}),
  #"Unpivoted columns" = Table.UnpivotOtherColumns(#"Removed other columns", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail"}, "Attribute", "Value"),
  #"Renamed columns" = Table.RenameColumns(#"Unpivoted columns", {{"Attribute", "Month"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Month", Int64.Type}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Changed column type", {{"Month", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "Finance Key", each [#"Code: Cost Center Detail"] & "-" & [#"Code: Account Detail"] & "-" & [Month]), {{"Finance Key", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Data Source", each "2026B"), {{"Data Source", type text}})
in
  #"Added custom 1";
shared #"2026A" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/2026%20Import%20Logistics%20P&L.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "2026A", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Removed blank rows" = Table.SelectRows(#"Promoted headers", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
  #"Removed other columns" = Table.SelectColumns(#"Removed blank rows", {"012", "011", "010", "009", "008", "007", "006", "005", "004", "003", "002", "001", "Code: Account Detail", "Code: Cost Center Detail", "Account Detail", "Cost Center Detail", "BA-Level4-Posting Level", "Roll Up 2", "Roll Up 1"}),
  #"Unpivoted columns" = Table.UnpivotOtherColumns(#"Removed other columns", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail"}, "Attribute", "Value"),
  #"Renamed columns" = Table.RenameColumns(#"Unpivoted columns", {{"Attribute", "Month"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Month", Int64.Type}}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Changed column type", {{"Month", type text}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Changed column type 2", {{"Code: Account Detail", type text}, {"Code: Cost Center Detail", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "Finance Key", each [#"Code: Cost Center Detail"] & "-" & [#"Code: Account Detail"] & "-" & [Month]), {{"Finance Key", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Data Source", each "2026A"), {{"Data Source", type text}})
in
  #"Added custom 1";
shared #"FACT Finance Init" = let
// Combine tables
Source = Table.Combine({#"2026A", #"2026B", #"2025A",#"2026F"}),

// Ensure Data Source exists and is typed
#"Changed column type" = Table.TransformColumnTypes(Source, {
    {"Code: Account Detail", type text},
    {"Value", Currency.Type},
    {"Roll Up 1", type text},
    {"Roll Up 2", type text},
    {"BA-Level4-Posting Level", type text},
    {"Cost Center Detail", type text},
    {"Account Detail", type text},
    {"Code: Cost Center Detail", type text},
    {"Month", Int64.Type},
    {"Data Source", type text}
}),
  #"Removed columns" = Table.RemoveColumns(#"Changed column type", {"Account Detail"}),


// Pivot the table
PivotedTable = Table.Pivot(
    #"Removed columns",
    List.Distinct(Source[Data Source]),   // The column values to become headers
    "Data Source",                        // Column containing the pivot keys
    "Value",                               // Column containing the values to aggregate
    List.Sum                               // Aggregation function
),
  Custom = #"Changed column type",
  #"Removed other columns" = Table.SelectColumns(Custom, {"Code: Account Detail", "Account Detail"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"Code: Account Detail"}),
  #"Merged queries" = Table.NestedJoin(#"PivotedTable", {"Code: Account Detail"}, #"Removed duplicates", {"Code: Account Detail"}, "AccountDetail", JoinKind.LeftOuter),
  #"Expanded AccountDetail" = Table.ExpandTableColumn(#"Merged queries", "AccountDetail", {"Account Detail"}, {"Account Detail"}),
  #"Reordered columns" = Table.ReorderColumns(#"Expanded AccountDetail", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail", "Month", "Finance Key", "2026A", "2026B", "2025A"}),
  #"Merged queries 1" = Table.NestedJoin(#"Reordered columns", {"Code: Account Detail"}, #"DIM Categories", {"Account Detail Code"}, "DIM Categories", JoinKind.LeftOuter),
  #"Expanded DIM Categories" = Table.ExpandTableColumn(#"Merged queries 1", "DIM Categories", {"Account Detail", "Group Code", "Group Description", "Category Code", "Category Description", "Before & After", "New Detail", "New Category", "F/V", "Exclusion"}, {"Account Detail.1", "Group Code", "Group Description", "Category Code", "Category Description", "Before & After", "New Detail", "New Category", "F/V", "Exclusion"}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Expanded DIM Categories", {{"Group Description", type text}, {"Category Description", type text}, {"Category Code", type text}, {"Before & After", type text}})
in
#"Changed column type 1";
shared #"DIM Categories" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/Finance%20Categories.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column2", type text}, {"Column3", type text}}),
  #"Promoted headers" = Table.PromoteHeaders(#"Changed column type", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Group Description", type text}, {"Category Code", type text}, {"Category Description", type text}, {"Before & After", type text}, {"New Detail", type text}, {"New Category", type text}, {"F/V", type text}, {"Exclusion", type text}})
in
  #"Changed column type 1";
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
shared Depot = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/2026%20Import%20Logistics%20P&L.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Depot", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Removed blank rows" = Table.SelectRows(#"Promoted headers", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed blank rows", {{"Month", Int64.Type}, {"Depot Charges", Currency.Type}})
in
  #"Changed column type";
shared #"Depot & Rent" = let
  Source = #"FACT Finance Init",
  #"Filtered rows" = Table.SelectRows(Source, each ([#"Code: Account Detail"] = "471182") and ([Cost Center Detail] = "DHL Savannah")),
  #"Grouped rows" = Table.Group(#"Filtered rows", {"Month"}, {{"2026A", each List.Sum([2026A]), type nullable number}}),
  #"Merged queries" = Table.NestedJoin(#"Grouped rows", {"Month"}, Depot, {"Month"}, "Depot", JoinKind.LeftOuter),
  #"Expanded Depot" = Table.ExpandTableColumn(#"Merged queries", "Depot", {"Depot Charges"}, {"Depot Charges"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded Depot", "Rent", each [2026A] - [Depot Charges]), {{"Rent", Currency.Type}})
in
  #"Added custom";
[BindToDefaultDestination = true]
shared #"FACT Finance" = let
  Source = #"FACT Finance Init",
  #"Merged queries 2" = Table.NestedJoin(Source, {"Month"}, #"Depot & Rent", {"Month"}, "Depot & Rent", JoinKind.LeftOuter),
  #"Expanded Depot & Rent" = Table.ExpandTableColumn(#"Merged queries 2", "Depot & Rent", {"Depot Charges", "Rent"}, {"Depot Charges", "Rent"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Depot & Rent", {{"2026A", "2026A Old"}}),
  #"Added custom" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Renamed columns",
        "2026A",
        each if ([#"Code: Account Detail"] = "471182" and [Cost Center Detail] = "DHL Savannah") 
            then [Depot Charges] + 0
        else if ([#"Code: Account Detail"] = "471180" and [Cost Center Detail] = "DHL Savannah") 
            then [2026A Old] + [Rent]
        else [2026A Old]
    ),
    {{"2026A", Currency.Type}}
),
  #"Added custom 1" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Added custom",
        "Fixed Category",
        each if (List.Contains({"451080", "472465", "471182"}, [#"Code: Account Detail"]) 
                 and [Cost Center Detail] = "DHL Savannah") 
            then "Overflow"
        else if [#"New Category"] = "External Warehouse" and [Cost Center Detail] = "Savannah 102 Ecom" then "Overflow"
        else [New Category]
    ),
    {{"Fixed Category", type text}}
),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "True 2026", each if [Account Detail.1] = "Demurrage (New G/L)" and [Month] = 1 and [Cost Center Detail] = "DHL Savannah" then [2026A]-603000 else [2026A]), {{"True 2026", Currency.Type}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "True 2025", each if [Account Detail.1] = "Demurrage (New G/L)" and [Month] = 9 and [Cost Center Detail] = "DHL Savannah" then [2025A]+603000 else [2025A]), {{"True 2025", Currency.Type}})
in
#"Added custom 3";
[BindToDefaultDestination = true]
shared #"2026F" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/ImportLogistics/Shared%20Documents/Finance/P&L/2026/2026%20Import%20Logistics%20P&L.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "2026F", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Removed blank rows" = Table.SelectRows(#"Promoted headers", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
  #"Removed other columns" = Table.SelectColumns(#"Removed blank rows", {"012", "011", "010", "009", "008", "007", "006", "005", "004", "003", "002", "001", "Code: Account Detail", "Code: Cost Center Detail", "Account Detail", "Cost Center Detail", "BA-Level4-Posting Level", "Roll Up 2", "Roll Up 1"}),
  #"Unpivoted columns" = Table.UnpivotOtherColumns(#"Removed other columns", {"Roll Up 1", "Roll Up 2", "BA-Level4-Posting Level", "Cost Center Detail", "Account Detail", "Code: Cost Center Detail", "Code: Account Detail"}, "Attribute", "Value"),
  #"Renamed columns" = Table.RenameColumns(#"Unpivoted columns", {{"Attribute", "Month"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Month", Int64.Type}}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Changed column type", {{"Month", type text}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Changed column type 2", {{"Code: Account Detail", type text}, {"Code: Cost Center Detail", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "Finance Key", each [#"Code: Cost Center Detail"] & "-" & [#"Code: Account Detail"] & "-" & [Month]), {{"Finance Key", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Data Source", each "2026F"), {{"Data Source", type text}})
in
  #"Added custom 1";
