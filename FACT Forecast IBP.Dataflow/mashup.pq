[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
shared #"DIM BOM Component" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Plant%2067%20BOMs%206-25-25.xlsx"), null, true),
  Sheet1_Sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
  #"Promoted Headers" = Table.PromoteHeaders(Sheet1_Sheet, [PromoteAllScalars=true]),
  #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Plnt", type text}, {"Old material no.", Int64.Type}, {"Material", type text}, {"Material Number", type text}, {"Item", Int64.Type}, {"ICt", type text}, {"Component", type text}, {"BOM component", type text}, {"SPT", type text}, {"BOM Usg", Int64.Type}, {"AltBOM", Int64.Type}, {"Alternative Text", type text}, {"SortStrng", type text}, {"Quantity", Int64.Type}, {"Un", type text}, {"Base quantity", Int64.Type}}),
  #"Removed Columns" = Table.RemoveColumns(#"Changed Type",{"Old material no.", "Item", "ICt", "AltBOM", "Alternative Text", "SortStrng", "Plnt", "SPT", "BOM Usg", "Un", "Material Number", "BOM component"}),
  #"Sorted Rows1" = Table.Sort(#"Removed Columns",{{"Material", Order.Ascending}}),
  #"Added Custom" = Table.AddColumn(#"Sorted Rows1", "BOM Type", each "Component"),
  #"Removed Other Columns" = Table.SelectColumns(#"Added Custom",{"Material", "Component", "Quantity", "BOM Type"})
in
    #"Removed Other Columns";
[BindToDefaultDestination = true]
shared #"FACT EDB Budget- QTY" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "EDB Budget- QTY", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"Code:SKU Level _c6_", type text}}),
  #"Added custom" = Table.AddColumn(#"Changed column type", "MRP SKU KEY", each [MRP Area] & "|" & [#"Code:SKU Level _c6_"]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"MRP SKU KEY", type text}})
in
  #"Changed column type 1";
shared Margin = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Margin", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"FACT EDB Budget- Finance" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "EDB Budget- Finance", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "MRP SKU KEY", each [MRP Area] & "|" & [#"Code:SKU Level _c6_"]), {{"MRP SKU KEY", type text}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"Code:Payer _c5_", Int64.Type}}),
  #"Merged queries" = Table.NestedJoin(#"Changed column type", {"Code:SKU Level _c6_", "Customer Groups"}, Margin, {"Code:SKU Level _c4_", "Customer Groups"}, "Margin", JoinKind.LeftOuter),
  #"Expanded Margin" = Table.ExpandTableColumn(#"Merged queries", "Margin", {"DC WO Fixed", "Direct Contribution", "DC WO Fixed/NS _%_", "Direct Contribution/ Net Sales _%_"}, {"DC WO Fixed", "Direct Contribution", "DC WO Fixed/NS _%_", "Direct Contribution/ Net Sales _%_"}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Expanded Margin", {{"Direct Contribution/ Net Sales _%_", Percentage.Type}, {"DC WO Fixed/NS _%_", Percentage.Type}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type 1", {{"Committed Net Sales _APO___2026_2027_01-06/28_", "Committed Net Sales _APO___"}, {"3+9 Net Sales__2026_2027_01-06/28_", "3+9 Net Sales"}, {"6+6 Net Sales__2026_2027_01-06/28_", "6+6 Net Sales"}, {"9+3 Net Sales__2026_2027_01-06/28_", "9+3 Net Sales"}, {"Customer Demand Net sales _APO___2026_2027_01-06/28_", "Customer Demand Net sales _APO_"}, {"Net Sales - Budget__2026_2027_01-06/28_", "Net Sales - Budget"}})
in
  #"Renamed columns";
shared #"DIM BOM FG" = let
  Source = #"DIM BOM Component",
  #"DIM BOM FG Removed Other Columns" = Table.SelectColumns(Source,{"Material", "Quantity"}),
  #"DIM BOM FG Removed Duplicates" = Table.Distinct(#"DIM BOM FG Removed Other Columns", {"Material"}),
  #"DIM BOM FG Duplicated Column" = Table.DuplicateColumn(#"DIM BOM FG Removed Duplicates", "Material", "Component"),
  #"DIM BOM FG Added BOM Type" = Table.AddColumn(#"DIM BOM FG Duplicated Column", "BOM Type", each "Finished Goods")
in
  #"DIM BOM FG Added BOM Type";
[BindToDefaultDestination = true]
shared #"DIM BOM Combined" = let
  #"Appended Query" = Table.Combine({#"DIM BOM Component", #"DIM BOM FG"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Appended Query", {{"BOM Type", type text}})
in
  #"Changed column type";
shared #"DIM IBP Customer" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM IBP Customer", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"EDB APO" = let
  // 1. Combine source tables
  //FACT EDB APO Forecast
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/EDB%20Export%20w%20MRP.xlsx"), null, true),
  EDBPlusExcel_Sheet = Source{[Item="EDBPlusExcel",Kind="Sheet"]}[Data],
  #"Removed Other Columns - Unused" = Table.SelectColumns(EDBPlusExcel_Sheet,{"Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14"}),
  #"Removed Top Rows" = Table.Skip(#"Removed Other Columns - Unused",1),
  #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
  #"Renamed columns 2" = Table.RenameColumns(
    #"Promoted Headers", {
      {"Committed Demand (APO)#(lf)(2024,2025,2026,2027)", "Committed Demand (APO)#(lf)(2026)"}, 
      {"Customer Demand (APO)#(lf)(2024,2025,2026,2027)", "Customer Demand (APO) (2026)"}, 
      {"Promotion QTY (APO)#(lf)(2024,2025,2026,2027)", "Promotion QTY (APO)#(lf)(2026)"}, 
      {"Forecast Override QTY (APO)#(lf)(2024,2025,2026,2027)", "Forecast Override QTY (APO)#(lf)(2026)"}, 
      {"Code:Payer (c4)", "Payer Code"}
    }
  ),
  #"Removed Other Columns - Unnessecary" = Table.SelectColumns(#"Renamed columns 2", {"Code:SKU Level (c1)", "Payer Code", "Daily Date", "MRP Area", "Customer Demand (APO) (2026)"}),
  #"Split Date by Delimiter" = Table.SplitColumn(#"Removed Other Columns - Unnessecary", "Daily Date", Splitter.SplitTextByDelimiter("/", QuoteStyle.Csv), {"Daily Date.1", "Daily Date.2", "Daily Date.3"}),
  #"Merged Date Columns" = Table.CombineColumns(#"Split Date by Delimiter",{"Daily Date.2", "Daily Date.1", "Daily Date.3"},Combiner.CombineTextByDelimiter("/", QuoteStyle.None),"Initial Date"),
  #"Today Dynamic" = Table.AddColumn(#"Merged Date Columns", "Today", each DateTime.LocalNow(), type date),
  #"Changed Type1" = Table.TransformColumnTypes(#"Today Dynamic", {{"Initial Date", type date}, {"MRP Area", type text}, {"Payer Code", type text}, {"Code:SKU Level (c1)", type text}, {"Today", type date}, {"Customer Demand (APO) (2026)", Int64.Type}}),
  #"Filtered rows" = Table.SelectRows(#"Changed Type1", each [Initial Date] < #date(2026, 8, 1)),
  #"Duplicated Column" = Table.DuplicateColumn(#"Filtered rows", "Initial Date", "SOW"),
  #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated Column",{{"SOW", Date.StartOfWeek, type date}}),
  #"Renamed columns" = Table.RenameColumns(#"Calculated Start of Week", {{"Customer Demand (APO) (2026)", "Combined Qty"}, {"Payer Code", "Payer"}, {"Code:SKU Level (c1)", "Material"}}),
  #"Added Today SOW" = Table.AddColumn(
    #"Renamed columns",
    "Today SOW",
    each Date.From(Date.StartOfWeek([Today])),
    type date
),
  #"Added ""Remaining?""" = Table.AddColumn(#"Added Today SOW", "Remaining?", each if [SOW] >= [Today SOW] then "Yes" else "No", type text),
  #"Added Data Source ID" = Table.AddColumn(#"Added ""Remaining?""", "Data Source", each "EDB APO", type text),
  #"Merged queries" = Table.NestedJoin(#"Added Data Source ID", {"Payer"}, #"DIM IBP Customer", {"Payer Key"}, "DIM IBP Customer", JoinKind.LeftOuter),
  #"Expanded DIM IBP Customer" = Table.ExpandTableColumn(#"Merged queries", "DIM IBP Customer", {"IBP Customer Code"}, {"IBP Customer Code"}),
  #"Grouped rows" = Table.Group(
    #"Expanded DIM IBP Customer",
    {"Material", "IBP Customer Code", "MRP Area", "Today", "Today SOW", "Remaining?", "SOW", "Data Source"},
    {{"Combined Qty", each -List.Sum([Combined Qty]), Int64.Type}}
),
  #"Renamed columns 1" = Table.RenameColumns(#"Grouped rows", {{"SOW", "Combined Date"}}),
  #"Added MRP + SKU Key" = Table.AddColumn(#"Renamed columns 1", "MRPSKU Key", each [MRP Area]&"|"&[Material], type text),
  #"Duplicated column 1" = Table.DuplicateColumn(#"Added MRP + SKU Key", "Combined Date", "SOW")
in
  #"Duplicated column 1";
[BindToDefaultDestination = true]
shared #"FACT Forecast Initial" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  FilteredFile =
    Table.SelectRows(
      Source,
      each [Name] = "EDB IBP Export.xlsx"
    ),

  File = FilteredFile{0}[Content],

  Workbook = Excel.Workbook(File, null, true),
  Navigation = Workbook{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Removed top rows" = Table.Skip(Navigation, 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"US DOLLAR#(lf)SKU Level", type text}, {"Code:SKU Level (c1)", type text}, {"Months", type date}, {"Customer Groups", type text}, {"Code:Customer Groups (c3)", type text}, {"IBP Customer", type text}, {"Code:IBP Customer (c4)", type text}, {"Daily Date", type text}, {"MRP Area", type text}, {"Final Forecasted Demand -IBP#(lf)(08-12/26,2027,2028)", Int64.Type}, {"Promotions Addition NA -IBP#(lf)(08-12/26,2027,2028)", Int64.Type}}),
  #"Removed other columns" = Table.SelectColumns(#"Changed column type", {"Code:SKU Level (c1)", "Code:IBP Customer (c4)", "Daily Date", "MRP Area", "Final Forecasted Demand -IBP#(lf)(08-12/26,2027,2028)"}),
  #"Split Date by Delimiter" = Table.SplitColumn(#"Removed other columns", "Daily Date", Splitter.SplitTextByDelimiter("/", QuoteStyle.Csv), {"Daily Date.1", "Daily Date.2", "Daily Date.3"}),
  #"Merged Date Columns" = Table.CombineColumns(#"Split Date by Delimiter",{"Daily Date.2", "Daily Date.1", "Daily Date.3"},Combiner.CombineTextByDelimiter("/", QuoteStyle.None),"Initial Date"),
  #"Today Dynamic" = Table.AddColumn(#"Merged Date Columns", "Today", each DateTime.LocalNow(), type date),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Today Dynamic", {{"Initial Date", type date}, {"Today", type date}}),
  #"Filtered rows" = Table.SelectRows(#"Changed column type 1", each [Initial Date] > #date(2026, 7, 31)),
  #"Duplicated Column" = Table.DuplicateColumn(#"Filtered rows", "Initial Date", "SOW"),
  #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated Column",{{"SOW", Date.StartOfWeek, type date}}),
  #"Renamed columns" = Table.RenameColumns(#"Calculated Start of Week", {{"Final Forecasted Demand -IBP#(lf)(08-12/26,2027,2028)", "Combined Qty"}, {"Code:SKU Level (c1)", "Material"}, {"Code:IBP Customer (c4)", "IBP Customer Code"}}),
  #"Added Today SOW" = Table.AddColumn(
    #"Renamed columns",
    "Today SOW",
    each Date.From(Date.StartOfWeek([Today])),
    type date
),
  #"Added ""Remaining?""" = Table.AddColumn(#"Added Today SOW", "Remaining?", each if [SOW] >= [Today SOW] then "Yes" else "No", type text),
  #"Added Data Source ID" = Table.AddColumn(#"Added ""Remaining?""", "Data Source", each "EDB IBP", type text),
  #"Grouped rows" = Table.Group(
    #"Added Data Source ID",
    {"Material", "IBP Customer Code", "MRP Area", "Today", "Today SOW", "Remaining?", "SOW", "Data Source"},
    {{"Combined Qty", each -List.Sum([Combined Qty]), Int64.Type}}
),
  #"Renamed columns 1" = Table.RenameColumns(#"Grouped rows", {{"SOW", "Combined Date"}}),
  #"Added MRP + SKU Key" = Table.AddColumn(#"Renamed columns 1", "MRPSKU Key", each [MRP Area]&"|"&[Material], type text),
  #"Duplicated column 1" = Table.DuplicateColumn(#"Added MRP + SKU Key", "Combined Date", "SOW"),
  #"Appended query" = Table.Combine({#"Duplicated column 1", #"EDB APO"})

in
  #"Appended query";
[BindToDefaultDestination = true]
shared #"FACT Component Forecast Initial" = let
  #"Merged Queries" = Table.NestedJoin(#"FACT Forecast Initial", {"Material"}, #"DIM BOM Combined", {"Material"}, "DIM BOM Component", JoinKind.LeftOuter),
  #"Expanded DIM BOM Component" = Table.ExpandTableColumn(#"Merged Queries", "DIM BOM Component", {"Component", "Quantity", "BOM Type"}, {"Component", "Quantity", "BOM Type"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DIM BOM Component", "Component ADJ", each if [Component] = null or [Component] = "" then [Material] else [Component]), {{"Component ADJ", type text}}),
  #"Added BOM Forecast" = Table.AddColumn(#"Added custom", "BOM Forecast", each if [Quantity]=null then [Combined Qty] else [Quantity]*[Combined Qty]),
  #"Removed columns" = Table.RemoveColumns(#"Added BOM Forecast", {"MRPSKU Key"}),
  #"Added MRP + SKU Key" = Table.AddColumn(#"Removed columns", "MRPSKU Key", each [MRP Area]&"|"&[Component ADJ]),
  #"PayerMrpSkuSow" = Table.AddColumn(#"Added MRP + SKU Key", "IBP_PayerMrpSkuSow", each [IBP Customer Code]&"|"&[MRPSKU Key]&"|"&Date.ToText([Combined Date]), type text),
  // #"Reordered columns" = Table.ReorderColumns(#"FACT EDB APO Forecast Init2", {"Material", "Payer", "MRP Area", "Today", "Today SOW", "Remaining?", "Combined Date", "Data Source", "Combined Qty", "MRPSKU Key", "Component", "Quantity", "BOM Type", "Component ADJ", "BOM Forecast", "PayerMrpSkuSow"}),
  #"Removed columns 1" = Table.RemoveColumns(#"PayerMrpSkuSow", {"Material"}),
  // #"Reordered columns 1" = Table.ReorderColumns(#"Removed columns 1", {"Component ADJ", "Payer", "MRP Area", "Today", "Today SOW", "Remaining?", "Combined Date", "Data Source", "Combined Qty", "MRPSKU Key", "SOW", "Component", "Quantity", "BOM Type", "BOM Forecast", "PayerMrpSkuSow"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns 1", {{"Component ADJ", "Material"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {/*{"PayerMrpSkuSow", type text}, */{"BOM Forecast", Int64.Type}, {"MRPSKU Key", type text}, {"Data Source", type text}, {"Remaining?", type text}, {"Today SOW", type date}, {"Combined Qty", Int64.Type}}),
  #"Merged queries 1" = Table.NestedJoin(#"Changed column type", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged queries 1", "DIM Product", {"Cont_Qty", "TL Qty"}, {"DIM Product.Cont_Qty", "DIM Product.TL Qty"}),
  #"CombinedQty_per_ContQty_fcst" = Table.AddColumn(#"Expanded DIM Product", "CombinedQty_per_ContQty_fcst", each [Combined Qty] / [DIM Product.Cont_Qty], type number),
  #"CombinedQty_per_TLQty_fcst" = Table.AddColumn(#"CombinedQty_per_ContQty_fcst", "CombinedQty_per_TLQty_fcst", each [Combined Qty] / [DIM Product.TL Qty], type number)
in
  #"CombinedQty_per_TLQty_fcst";
shared #"DIM Product" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"Payer Types" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM IBP Payer Type", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"FACT YS10N Open" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT YS10N Open", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"FACT Component Forecast Initial (2)" = let
  Source = #"FACT Component Forecast Initial",
  #"Filter rows" = Table.SelectRows(Source, each [Today SOW] = [SOW]),
  #"Filtered rows" = Table.SelectRows(#"Filter rows", each ([BOM Forecast] <> 0)),
  #"Grouped rows" = Table.Group(#"Filtered rows", {"MRPSKU Key"}, {{"Sum", each List.Sum([BOM Forecast]), type nullable number}})
in
  #"Grouped rows";
shared #"Component Forecast (Remove Max Sales Date)" = let
  //Add Max Sales Date to YS10N
  #"Max Sales Date" = Table.Group(#"FACT YS10N Open", {"MRPSKU Key", "IBP Customer Code"}, {{"Max Sales Date", each List.Max([Combined Date]), type nullable date}}),
  //Add Max Sales Date to Forecast
  #"Merged Queries1" = Table.NestedJoin(#"FACT Component Forecast Initial", {"MRPSKU Key", "IBP Customer Code"}, #"Max Sales Date", {"MRPSKU Key", "IBP Customer Code"}, "Max Sales Date", JoinKind.LeftOuter),
  #"Expanded Max Sales Date" = Table.ExpandTableColumn(#"Merged Queries1", "Max Sales Date", {"Max Sales Date"}, {"Max Sales Date"}),
  #"Merged queries" = Table.NestedJoin(#"Expanded Max Sales Date", {"IBP Customer Code"}, #"Payer Types", {"IBP Customer Code"}, "Payer Types", JoinKind.LeftOuter),
  #"Expanded Payer Types 1" = Table.ExpandTableColumn(#"Merged queries", "Payer Types", {"Detail", "Payer Type", "Payer Type Key"}, {"Payer Types.Detail", "Payer Types.Type", "Payer Types.TypeKey"}),
  //Add check to ensure special Payers aren't past their Max Sales Date
  #"Added Custom1" = Table.AddColumn(#"Expanded Payer Types 1", "Check Date", each if [Payer Types.TypeKey] = "1" then [Max Sales Date] else null, type date),
  #"Added Custom2" = Table.AddColumn(#"Added Custom1", "Custom", each if [Check Date] = null then "Keep" else if [Combined Date] <= [Check Date] then "Remove" else "Keep"),
  #"Filtered Rows1" = Table.SelectRows(#"Added Custom2", each ([Custom] = "Keep"))

in
  #"Filtered Rows1";
shared #"YS10N PayerMRPSKUSOW" = let
  Source = #"FACT YS10N Open",
  #"Filtered rows" = Table.SelectRows(Source, each [Combined Date] >= [Today]),
  #"Forecast ChangesGrouped Rows" = Table.Group(#"Filtered rows", {"IBP_PayerMrpSkuSow"}, {{"SOW Qty", each List.Sum([Combined Qty]), type nullable number}})
in
  #"Forecast ChangesGrouped Rows";
shared Sales = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT MB51 Material_Movements Initial", ItemKind = "Table"]}[Data],
  #"Filter rows" = Table.SelectRows(#"Navigation 3", each [Today SOW] = [SOW]),
  #"Filter rows 1" = Table.SelectRows(#"Filter rows", each [Movement Type] = "601"),
  #"Grouped rows" = Table.Group(#"Filter rows 1", {"MRPSKU Key", "SOW"}, {{"Sales Qty", each List.Sum([Combined Qty]), type nullable number}}),
  #"Merged queries" = Table.NestedJoin(#"Grouped rows", {"MRPSKU Key"}, #"FACT Component Forecast Initial (2)", {"MRPSKU Key"}, "FACT Component Forecast Initial (2)", JoinKind.LeftOuter),
  #"Expanded FACT Component Forecast Initial (2)" = Table.ExpandTableColumn(#"Merged queries", "FACT Component Forecast Initial (2)", {"Sum"}, {"Sum"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded FACT Component Forecast Initial (2)", "Adj %", each List.Max({
1-Value.Divide([Sales Qty],[Sum]),0})), {{"Adj %", type number}})
in
  #"Added custom";
[BindToDefaultDestination = true]
shared #"FACT Forecast Adjusted" = let
  Source = #"Component Forecast (Remove Max Sales Date)",
  #"Merged queries" = Table.NestedJoin(Source, {"IBP_PayerMrpSkuSow"}, #"YS10N PayerMRPSKUSOW", {"IBP_PayerMrpSkuSow"}, "YS10N IBP_PayerMrpSkuSow", JoinKind.LeftOuter),
  #"Expanded YS10N IBP_PayerMrpSkuSow" = Table.ExpandTableColumn(#"Merged queries", "YS10N IBP_PayerMrpSkuSow", {"SOW Qty"}, {"Sales Qty"}),
  #"Replaced value" = Table.ReplaceValue(#"Expanded YS10N IBP_PayerMrpSkuSow", null, 0, Replacer.ReplaceValue, {"Sales Qty"}),
  #"Removed columns" = Table.RemoveColumns(#"Replaced value", {"Combined Qty"}),
  #"Merged queries 1" = Table.NestedJoin(#"Removed columns", {"MRPSKU Key", "SOW"}, Sales, {"MRPSKU Key", "SOW"}, "Sales", JoinKind.LeftOuter),
  #"Expanded Sales" = Table.ExpandTableColumn(#"Merged queries 1", "Sales", {"Adj %"}, {"Adj %"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Expanded Sales", null, 1, Replacer.ReplaceValue, {"Adj %"}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Replaced value 1", "Custom (2)", each [Today] - [Today SOW]), {{"Custom (2)", Int64.Type}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "Week %", 
    each if [#"Today SOW"] <> [#"SOW"] then 1
    else if [#"Custom (2)"] = 0 then 1
    else if [#"Custom (2)"] = 1 then 0.95
    else if [#"Custom (2)"] = 2 then 0.77
    else if [#"Custom (2)"] = 3 then 0.59
    else if [#"Custom (2)"] = 4 then 0.41
    else if [#"Custom (2)"] = 5 then 0.23
    else 0.05), {{"Week %", type number}}
  ),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Combined Qty", each List.Min({[BOM Forecast]*List.Min({[#"Adj %"],[#"Week %"]}) - [Sales Qty],0})), {{"Combined Qty", Int64.Type}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"Custom", type text}})
in
  #"Changed column type 1";
