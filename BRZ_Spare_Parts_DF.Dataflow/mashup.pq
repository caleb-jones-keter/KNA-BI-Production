[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"RPA Report TW" = let
    Source =
        Lakehouse.Contents(null),

    Navigation =
        Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],

    #"Navigation 1" =
        Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],

    #"Navigation 2" =
        #"Navigation 1"{[Id = "New Spare Parts List", ItemKind = "Table"]}[Data],

    // ✅ Clean errors
    CleanErrors =
        Table.ReplaceErrorValues(
            #"Navigation 2",
            List.Transform(Table.ColumnNames(#"Navigation 2"), each {_, null})
        ),

    // ✅ Replace #N/A
    ReplaceInvalidValues =
        Table.ReplaceValue(
            CleanErrors,
            "#N/A",
            null,
            Replacer.ReplaceValue,
            Table.ColumnNames(CleanErrors)
        ),

    // ✅ Add Data Source (static now since no file name)
    DataSource =
        Table.AddColumn(
            ReplaceInvalidValues,
            "Data Source",
            each "Lakehouse - New Spare Parts List",
            type text
        ),

    DataSourceOrder =
        Table.AddColumn(
            DataSource,
            "Data Source Order",
            each "1",
            type text
        ),

    #"Changed column type" =
        Table.TransformColumnTypes(
            DataSourceOrder,
            {
                {"Country", type text},
                {"CountryKey_SKU", type text},
                {"GMD24", type text},
                {"KUNNR", type text},
                {"Product Color Code", type text},
                {"Product Color Desc", type text},
                {"Product SKU", type text},
                {"Qty Spare Parts per ptoduct", type text},
                {"set/apart", type text},
                {"Sign", type text},
                {"SP_IML", type text},
                {"Spare Part Name", type text},
                {"Spare Part Previous Version", type text},
                {"Spare Part Size", type text},
                {"Spare Part SKU", type text},
                {"STD.PROD.SITE _SOURCE_ GMD 5 desc", type text},
                {"Unique_key", type text},
                {"ZZIMLCODE_SKU", type text},
                {"Data Source", type text},
                {"Data Source Order", type text}
            }
        )

in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"RPA Report LW" = let
    // ✅ New Lakehouse source
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
    RawData = #"Navigation 1"{[Id = "Last week spare part list", ItemKind = "Table"]}[Data],

    // ✅ Normalize column names
    CleanColumnNames =
        Table.TransformColumnNames(
            RawData,
            each
                if Text.Contains(_, "[") and Text.Contains(_, "]")
                then Text.BetweenDelimiters(_, "[", "]")
                else _
        ),

    // ✅ Clean errors
    CleanErrors =
        Table.ReplaceErrorValues(
            CleanColumnNames,
            List.Transform(Table.ColumnNames(CleanColumnNames), each {_, null})
        ),

    // ✅ Force all columns to text
    AllText =
        Table.TransformColumnTypes(
            CleanErrors,
            List.Transform(Table.ColumnNames(CleanErrors), each {_, type text})
        ),

    // ✅ Static metadata (since no file name anymore)
    DataSource =
        Table.AddColumn(
            AllText,
            "Data Source",
            each "Last week spare part list",
            type text
        ),

    DataSourceOrder =
        Table.AddColumn(
            DataSource,
            "Data Source Order",
            each "2",
            type text
        ),

    LastUpdated =
        Table.AddColumn(
            DataSourceOrder,
            "Last Updated",
            each DateTime.LocalNow(),
            type datetime
        )

in
    LastUpdated;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"Dim Product IL" = // Dim Product IL
let
    Source = PowerPlatform.Dataflows([]),
  Navigation = Source{[Id = "Workspaces"]}[Data],
  #"Navigation 1" = Navigation{[workspaceId = "c2419776-dec6-4cc0-8fa3-af708bd179cf"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[dataflowId = "0e7938c7-e044-4a50-98ee-135d46b2ea62"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[entity = "Dim_Product", version = ""]}[Data]

in
#"Navigation 3";
[BindToDefaultDestination = true]
shared #"IL Date Key" = let
    Source = PowerPlatform.Dataflows([]),
  Navigation = Source{[Id = "Workspaces"]}[Data],
  #"Navigation 1" = Navigation{[workspaceId = "c2419776-dec6-4cc0-8fa3-af708bd179cf"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[dataflowId = "0e7938c7-e044-4a50-98ee-135d46b2ea62"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[entity = "Dim_Date", version = ""]}[Data]

in
#"Navigation 3";
[BindToDefaultDestination = true]
shared #"Finished Goods Notes" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/NASpareParts", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/")),
  Navigation = #"Filtered rows"{[Name = "Spare Part Notes.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Finished Goods  Notes", Kind = "Sheet"]}[Data],
  #"Removed top rows" = Table.Skip(#"Navigation 1", 3),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"NA Finished Good", type text}, {"Name", type text}, {"Business Area", type text}, {"Factory", type text}, {"Parent 17 Number", type text}, {"Wty", type text}, {"FG Comment", type text}, {"FG Wty. Sale Date", type text}, {"FG Wty. Sale Location", type text}, {"FG  - Spare Part Status", type text}, {"Active in Current SP report?", type text}}),
  #"Replaced value" = Table.ReplaceValue(
    #"Changed column type",
    "N/A",
    null,
    Replacer.ReplaceValue,
    {"NA Finished Good", "Name", "Business Area", "Factory", "Parent 17 Number", "Wty", "FG Comment", "FG Wty. Sale Date", "FG Wty. Sale Location", "FG  - Spare Part Status", "Active in Current SP report?"}
),
  #"Removed columns" = Table.RemoveColumns(#"Replaced value", {"Active in Current SP report?"})

in
  #"Removed columns";
[BindToDefaultDestination = true]
shared #"Spare Parts Notes" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/NASpareParts", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/")),
  Navigation = #"Filtered rows"{[Name = "Spare Part Notes.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Spare Part Notes", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column7", type text}, {"Column8", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 4),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"SP Item #", type text}, {"SP Description", type text}, {"Color Code", type text}, {"Factory", type text}, {"Sign", type text}, {"Replacement Item (old or new)", type text}, {"Comment", type text}, {"Status", type text}})
in
  #"Changed column type 1";
[BindToDefaultDestination = true]
shared #"Finished Goods EDB" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/NASpareParts", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/")),
  Navigation = #"Filtered rows"{[Name = "EBB Finished Goods.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Removed columns" = Table.RemoveColumns(#"Navigation 1", {"Column10"}),
  #"Removed top rows" = Table.Skip(#"Removed columns", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Promoted headers", "Daily Date (MM/dd/yyyy)", each Date.ToText(Date.FromText([#"Daily Date"], "en-GB"), "MM/dd/yyyy")), {{"Daily Date (MM/dd/yyyy)", type text}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"Code:Country (c2)", Int64.Type}, {"Code:SKU Level (c4)", Int64.Type}, {"Quantity#(lf)(2025,2026,2027)", Int64.Type}, {"Customer Demand (APO)#(lf)(2025,2026,2027)", Int64.Type}, {"Daily Date (MM/dd/yyyy)", type date}, {"US DOLLAR#(lf)Sap Material Type", type text}, {"Country", type text}, {"PC Business Unit", type text}, {"SKU Level", type text}, {"Daily Date", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type 1", {{"Quantity#(lf)(2025,2026,2027)", "Quantity"}, {"Customer Demand (APO)#(lf)(2025,2026,2027)", "Customer Demand"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared #"Additional zmm02 SP info" = let
    // SharePoint site root (IMPORTANT: site only, not full file path)
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC",
        [ApiVersion = 15]
    ),

    // Filter to your specific file
    FilteredFile =
        Table.SelectRows(
            Source,
            each [Name] = "ZMM02 SP.XLSX"
        ),

    // Get file content
    FileContent =
        FilteredFile{0}[Content],

    // Read Excel workbook
    ExcelData =
        Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Plnt", type text}, {"Old material no.", type text}, {"Material", type text}, {"Material Description", type text}, {"MS", type text}, {"MTyp", type text}, {"Material Type", type text}, {"Standard price", type text}, {"Crcy", type text}, {"per", type text}, {"ABC", type text}, {"#### MRP", type text}, {"Profit Ctr", type text}, {"Typ", type text}, {"MRPC", type text}, {"ProcType", type text}, {"Matl Group", type text}, {"SPT", type text}, {"BUn", type text}, {"Min. Lot Sze", type text},  {"BUn_1", type text}, {"SortGrp_012_T", type text}, {"Max. Lot Size", type text}, {"SortGrp_019", type text}, {"BUn_2", type text}, {"SortGrp_019_T", type text}, {"Rounding val.", type text},  {"BUn_3", type text}, {"PrTime", type text}, {"TiHi", type text}, {"Code number", type text}, {"Orig", type text}, {"Planning time fence", type text}, {"MRP", type text}, {"Net Weight", type text}, {"WUn", type text}, {"Volume", type text}, {"VUn", type text}, {"MS_4", type text}, {"MPN", type text}, {"ValCl", type text}, {"PlanPrice 1", type text}, {"Crcy_5", type text}, {"WUn_6", type text}, {"Bulk", type text}, {"Alt.Gross Weight", type text}, {"Main Mold", type text}, {"WUn_7", type text}, {"Item classification", type text}, {"VUn_8", type text}, {"Item classification_9", type text}, {"Alt. Volume", type text}, {"Planning category", type text}, {"VUn_10", type text}, {"Planning category_11", type text}, {"Unit of Dimension", type text}, {"Pr", type text}, {"Alt.Height", type text}, {"Preference indicator in export", type text}, {"Unit of Dimension_12", type text}, {"Vdr decl.", type text}, {"Alt. Width", type text}, {"Indicator: Vendor declaration", type text}, {"Unit of Dimension_13", type text}, {"Ct", type text}, {"Alt.Length", type text}, {"Unit of Dimension_14", type text}, {"EAN/UPC", type text}, {"EAN number", type text}, {"Denom.", type text}, {"A.scrap", type text}, {"B", type text}, {"Stor", type text}, {"Customer No.", type text}, {"VUn_15", type text}, {"WUn_16", type text}, {"St", type text}, {"SPTC", type text}, {"MovAvgPrice", type text}, {"Crcy_17", type text}, {"Pr.", type text}, {"#### #""# MRP", type text}, {"Clt", type text}, {"BUn_18", type text}, {"For.", type text}, {"Size/dimensions", type text}, {"Ct_19", type text}, {"PP date 1", type text}, {"Language", type text}, {"Av", type text}, {"Prod./insp. memo", type text}, {"PGr", type text}, {"PI", type text}, {"OTol", type text}, {"Reorder Point", type text}, {"BUn_20", type text}, {"Follow-Up Material", type text}, {"Consumption mode", type text}, {"Bwd cons. per.", type text}, {"Fwd cons.period", type text}, {"SLoc", type text}, {"D", type text}, {"CoPr", type text}, {"Created", type text}, {"###.###.MR", type text}, {"Color", type text}, {"Special Procurement Type for C", type text}, {"I/C", type text}, {"Ext. Material Grp", type text}, {"Color Description", type text}, {"Pallet Type", type text}, {"Seas/NonSeasIndic", type text}, {"SparePartInd.", type text}, {"IML Code", type text}, {"PalHeight", type text}, {"PalHeightUOM", type text}, {"Packaging feature", type text}, {"MatFrtGp", type text}, {"AltUnit_NetWeight", type text}, {"WUn_21", type text}, {"MRPpr", type text}, {"SortGrp_031", type text}, {"SortGrp_031_T", type text}, {"Code Pack Desc.", type text}, {"Pallet Type Description", type text}, {"IML Description", type text}, {"BUn_22", type text}, {"Col", type text}, {"Basic material", type text}, {"Gross Weight", type text}, {"WUn_23", type text}, {"PalHeightUOM_24", type text}, {"ItCGr", type text}, {"Material Group Desc.", type text}, {"BUn_25", type text}})

in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"SP BOM" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Sorted rows" = Table.Sort(Source, {{"Date created", Order.Descending}}),
  Navigation = #"Sorted rows"{[Name = "Spare Parts BOM.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "SP BOM", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"SP Parent SKU", Int64.Type}, {"SP Description", type text}, {"Replacement Item", type text}, {"SP Child SKU", Int64.Type}, {"Conversion", Int64.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Last week spare part list" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Last week spare part list", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
