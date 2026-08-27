[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Manual Fact CSYS upload_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Manual Fact CSYS upload" = let
    // Connect to the SharePoint site
    Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/KNADemandPlanning", [ApiVersion = 15]),
    
    // Filter to the specific file
    Filtered = Table.SelectRows(Source, each [Folder Path] = "https://keteronline.sharepoint.com/teams/KNADemandPlanning/Shared Documents/OTIF/" 
        and [Name] = "New OTIF Data Upload-- Feb 2026 - Present.xlsx"),
    
    // Get the binary content
    FileBinary = Filtered{0}[Content],
    
    // Read the Excel file
    ExcelData = Excel.Workbook(FileBinary, null, true),
    
    // Select the first sheet (adjust as needed)
    FirstSheet = ExcelData{0}[Data],
    
    // Promote first row to headers
    PromotedHeaders = Table.PromoteHeaders(FirstSheet, [PromoteAllScalars = true]),
    
    // Change column types
    #"Changed column type" = Table.TransformColumnTypes(
        PromotedHeaders, 
        {
            {"Sales Organization", type text}, {"Plant", type text}, {"Shipping Point/Receiving Pt", type text}, 
            {"Storage Location", type text}, {"Payer", type text}, {"Payer name", type text}, 
            {"Reason for rejection", type text}, {"Reason for rejection description", type text}, 
            {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, 
            {"Sales Order", type text}, {"Delivery", type text}, {"Shipment Number", type text}, 
            {"Shipping type", type text}, {"Material", type text}, {"Customer SKU", type text}, 
            {"Material description MM", type text}, {"Order Qty", type text}, {"Net value", type text}, 
            {"SO Created Date", type date}, {"Delivery Creation Date", type date}, {"First Date", type date}, 
            {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, 
            {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Ship-To Party Region", type text}, 
            {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned time CheckIn", type datetime}, 
            {"Trailer No.", type text}, {"Planned shipment end", type text}, {"Load Delay Reason", type text}, 
            {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Profit Center", type text}, 
            {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, 
            {"Carrier Service", type text}, {"Load No.", type text}, {"Ship-To Zip", type text}, 
            {"Spare Part Indicator", type text}, {"Del. Qty", type text}, {"Original First Date", type date}, 
            {"Ship-To Party", type text}, {"Carrier", type text}, {"Manifest/PRO No.", type text}, 
            {"Door No.", type text}, {"SO Remarks", type text}, {"Delv Remarks", type text}, 
            {"Overall Pick Status", type text}, {"Load Notes", type text}, {"Service Description", type text}
        }
    ),

    // Add US ZIP Code column
    #"Added custom" = Table.AddColumn(
        #"Changed column type",
        "US ZIP Code (5 digit)",
        each 
            let
                zipText = Text.From([#"Ship-To Zip"]),
                digitsOnly = Text.Select(zipText, {"0".."9"}),
                firstFive = Text.Start(digitsOnly, 5),
                padded = Text.PadStart(firstFive, 5, "0")
            in
                padded,
        type text
    ),

    // Add Material & DESC column
    #"Added custom 1" = Table.AddColumn(#"Added custom", "Material & DESC", each [Material] & " - " & [Material description MM]),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom 1", {{"Material & DESC", type text}}),

    // Add MRP Area column based on logic
    #"Added MRP Area" = Table.AddColumn(#"Changed column type 1", "MRP Area", each 
        let
            CurrStLoc = [Storage Location],
            Plant = [Plant]
        in
            if Plant = "60" then "60 - USL-Stanley"
            else if Plant = "62" then "62_362B - Bramli"
            else if Plant = "65" then "65 - HDP-Anderson"
            else if Plant = "66" then "66 - MILTON"
            else if Plant = "73" then "73 - Adams"
            else if CurrStLoc = null or CurrStLoc = "" then
                if Plant = "69" then "69 - NA - Canada - Import"
                else "67 - KNA LLC"
            else if List.Contains({"369C","369P","369T","705","369W"}, CurrStLoc) then
                "69_369T - OEL Overseas - 2"
            else if List.Contains({"467C","467N","4674","467P","467O","4672","367M","4673","467Q","367J"}, CurrStLoc) then
                "67_4674 - DHL"
            else if List.Contains({"367B","367A","367I","367D"}, CurrStLoc) then
                "67_367 - KNA- Spreetail"
            else if List.Contains({"367G","367C"}, CurrStLoc) then
                "67_367G - Globe 18301 Bro"
            else if CurrStLoc = "X67X" then
                "67 - KNA LLC"
            else if CurrStLoc = "X69X" then
                "69 - NA - Canada - Import"
            else
                "Unknown"
    ),

    // Add MRPSKU Key column
    #"Added MRP + SKU Key" = Table.AddColumn(#"Added MRP Area", "MRPSKU Key", each [MRP Area] & "|" & [Material]),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added MRP + SKU Key", "Country Location (MAP)", each if List.Contains({"67", "65", "73"}, [Plant]) then "United States" else if List.Contains({"66", "69"}, [Plant]) then "Canada" else null), {{"Country Location (MAP)", type text}}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Added custom 2", {{"MRP Area", type text}, {"MRPSKU Key", type text}}),
  #"Merged queries" = Table.NestedJoin(#"Changed column type 2", {"US ZIP Code (5 digit)"}, #"uszips csv", {"zip"}, "uszips csv", JoinKind.Inner),
  #"Expanded uszips csv" = Table.ExpandTableColumn(#"Merged queries", "uszips csv", {"zip", "lat", "lng", "city", "state_id", "state_name", "imprecise"}, {"uszips csv.zip", "uszips csv.lat", "uszips csv.lng", "uszips csv.city", "uszips csv.state_id", "uszips csv.state_name", "uszips csv.imprecise"})

in
    #"Expanded uszips csv";
shared #"Manual Fact CSYS upload_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Manual Fact CSYS upload", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"uszips csv" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 4" = #"Navigation 3"{[Name = "uszips.csv"]}[Content],
  #"Imported CSV" = Csv.Document(#"Navigation 4", [Delimiter = ",", Columns = 18, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true])
in
  #"Promoted headers";
