[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "FACT ADAMS Pallet List_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"FACT ADAMS Pallet List" = let
    // Connect to SharePoint site
    Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
    // Filter for the specific file
    Filtered = Table.SelectRows(Source, each Text.Contains([Folder Path], "Shared Documents/PowerBI Projects/DL") and [Name] = "Adams Pallet Project.XLSX"),
    // Check if file exists
    GetFile = if Table.RowCount(Filtered) > 0 then Filtered{0}[Content] else error "File not found",
    // Read Excel workbook
    ExcelData = Excel.Workbook(GetFile, null, true),
    // Get the first sheet named "Sheet1" (case-insensitive)
    SheetFiltered = Table.SelectRows(ExcelData, each Text.Lower([Name]) = "sheet1" and [Kind] = "Sheet"),
    // Check if sheet exists
    SheetData = if Table.RowCount(SheetFiltered) > 0 then SheetFiltered{0}[Data] else error "Sheet1 not found",
    // Promote headers
    PromotedHeaders = Table.PromoteHeaders(SheetData, [PromoteAllScalars = true]),
    // Change column types safely
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
            {"Receiving Stor. Loc.", type text}, {"Plant", type text}, {"Order", type text}, {"Material", type text}, {"Material Description", type text},
            {"Reversed", type text}, {"Quantity", Int64.Type}, {"Pal. Num.", type text}, {"Confirmation", type text}, {"Counter", type text},
            {"Number", type text}, {"Entered on", type date}, {"Entered by", Int64.Type}, {"SU Num", type text}, {"Posting date", type date},
            {"Posting time", type datetime}, {"Message text", type text}, {"Posting date_1", type date}, {"Cancelled confirm.", Int64.Type},
            {"Shift", type text}, {"Pal. Num._2", Int64.Type}, {"Confirmation text", type text}, {"Cogi Error", type text}
        },
        "en-US"
    ),
    // Add Days since produced
    #"Days since produced" = Table.AddColumn(
        ChangedTypes,
        "Days Since Produced",
        each Duration.Days(Date.From(DateTime.LocalNow()) - [Entered on]),
        Int64.Type
    ),
    // Add UniqueKey (always populated)
    AddedUniqueKey = Table.AddColumn(
        #"Days since produced",
        "UniqueKey",
        each Text.From([Order]) & " " & Text.From([Quantity]) & " " & Text.From([#"Pal. Num."]),
        type text
    ),
    // Add UniqueKey+Blanks (blank if Days Since Produced is null, 0, 1, or 2)
    AddedUniqueKeyBlanks = Table.AddColumn(
        AddedUniqueKey,
        "UniqueKey+Blanks",
        each if List.Contains({null, 0, 1, 2}, [Days Since Produced]) 
             then "" 
             else [UniqueKey],
        type text
    )
in
    AddedUniqueKeyBlanks;
shared #"FACT ADAMS Pallet List_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "FACT ADAMS Pallet List", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
