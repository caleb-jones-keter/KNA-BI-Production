[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Fact Adams WMS 373_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Fact Adams WMS 373" = let
    // Load Excel file from SharePoint
    Source = Excel.Workbook(
        Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Adams%20WHSE%20373%20WMS.XLSX"), 
        null, 
        true
    ),

    // Navigate to Sheet1
    #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],

    // Promote headers
    #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),

    // Change column types
    #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {
        {"Inventory item", Int64.Type}, {"Storage Type", type text}, {"Storage Bin", type text}, {"Material", Int64.Type}, 
        {"Total Stock", type number}, {"Available stock", type number}, {"Pick quantity", Int64.Type}, {"Stock for putaway", Int64.Type}, 
        {"Storage Unit Type", type text}, {"Base Unit of Measure", type text}, {"Storage Unit", type text}, 
        {"Document no. of last stock change", Int64.Type}, {"Last movement", type date}, {"Time", type datetime}, 
        {"Putaway block", type text}, {"Stock Removal Block", type text}, {"Blocking reason", type text}, {"Inventory active", type text}, 
        {"No.of storage units", Int64.Type}, {"Maximum no.of SUs", Int64.Type}, {"Inventory method", type text}, {"Last inventory", type date}, 
        {"Inventory record", Int64.Type}, {"Empty indicator", type text}, {"Full indicator", type text}, {"Last stock removal", type date}, 
        {"Time_1", type datetime}, {"Storage bin type", type text}, {"Sort fld stck plcm", type text}, {"Plant", Int64.Type}, 
        {"Storage Section", Int64.Type}, {"Stock Category", type text}, {"Duration", Int64.Type}, {"Last clearing", type date}, 
        {"Last movement_2", type date}
    }),

    // Add column: Storage Type Starts With 9
    #"Added custom" = Table.AddColumn(#"Changed column type", "Storage Type Starts With 9", 
        each if [Storage Type] <> null and Text.StartsWith(Text.From([Storage Type]), "9") then "Yes" else "No", type text),

    // Add column: Aisle (safe Text.Start)
    #"Added custom 1" = Table.AddColumn(#"Added custom", "Aisle", 
        each if Text.Lower(Text.From([Storage Type Starts With 9])) = "yes" then "Virtual" 
        else if [Storage Bin] <> null and Text.Length(Text.From([Storage Bin])) >= 2 
            then Text.Start(Text.From([Storage Bin]), 2) 
        else null, type text),

    // Add column: Aisle or Bin (safe Text.Range)
    #"Added custom 2" = Table.AddColumn(#"Added custom 1", "Aisle or Bin", 
        each if [Aisle] <> "Virtual" 
            then if [Storage Bin] <> null and Text.Length(Text.From([Storage Bin])) > 2 
                then Text.Range(Text.From([Storage Bin]), 2) 
            else null
        else "Virtual", type text),

    // Rename column
    #"Renamed columns" = Table.RenameColumns(#"Added custom 2", {{"Aisle or Bin", "Bin"}}),

    // Add column: Bin Level (safe Text.Start)
    #"Added custom 3" = Table.AddColumn(#"Renamed columns", "Bin Level", each 
        if [Bin] = "Virtual" then "Virtual" 
        else if [Bin] <> null then Text.Start(Text.From([Bin]), 1) 
        else null, type text),

    // Add column: BinDigitsAfterFirst (safe Text.Range)
    #"Added custom 4" = Table.AddColumn(#"Added custom 3", "BinDigitsAfterFirst", each 
        if [Bin] = "Virtual" then [Bin]
        else if [Bin] <> null then 
            let
                binValue = Text.From([Bin]),
                afterFirst = if Text.Length(binValue) > 1 then Text.Range(binValue, 1, Text.Length(binValue) - 1) else ""
            in
                afterFirst
        else null, type text)
in
    #"Added custom 4";
shared #"Fact Adams WMS 373_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Fact Adams WMS 373", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
