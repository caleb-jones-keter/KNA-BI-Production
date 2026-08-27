[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data];
[BindToDefaultDestination = true]
shared Ym6P = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "Ym6P.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  RemoveBlankMaterials = Table.SelectRows(#"Promoted headers", each ([Material] <> "")),
  #"Changed column type" = Table.TransformColumnTypes(RemoveBlankMaterials, {{"Purchasing Document", type text}, {"Plant", Int64.Type}, {"Purchasing Group", type text}, {"Storage Location", type text}, {"Purchase Order Date", type date}, {"AASalOrd", type text}, {"Supplier", Int64.Type}, {"Item", Int64.Type}, {"Material", Int64.Type}, {"Material Description", type text}, {"Order Quantity", Int64.Type}, {"Net Order Value", type number}, {"Sales document", Int64.Type}, {"ReqDelivDate", type date}, {"Confirm. Category", type text}, {"ConfirmDelvDate", type date}, {"GR Processing Time", Int64.Type}, {"LA Date", type date}, {"CalcArravDate", type date}, {"Delivery", Int64.Type}, {"Billing Document", Int64.Type}, {"Container", type text}, {"Inb.delivery", Int64.Type}, {"Entry Port", type text}, {"VesselName", type text}, {"First GR date for item", type date}, {"Deletion Indicator", type text}, {"Ship-to party's purchase order no.", type text}, {"Ship-to party", type text}, {"Billing Date", type date}, {"BilDateSupplOrd", type date}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"YS10N Open Orders Daily Pull" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "YS10N Open Orders Daily Pull.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Filtered Rows" = Table.SelectRows(#"Promoted headers", each ([Reason for rejection] = "")),
  #"Changed column type" = Table.TransformColumnTypes(#"Filtered Rows", {{"SO Created Date", type date}, {"Delivery Creation Date", type date}, {"First Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned shipment end", type date}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Planned time CheckIn", type datetime}, {"Net value", type number}, {"Sales Organization", Int64.Type}, {"Reason for rejection", Int64.Type}, {"Profit Center", Int64.Type}, {"Plant", type text}, {"Shipping Point/Receiving Pt", type text}, {"Storage Location", type text}, {"Payer", type text}, {"Payer name", type text}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, {"Sales Order", type text}, {"Delivery", type text}, {"Shipment Number", type text}, {"Shipping type", type text}, {"Material", type text}, {"Customer SKU", type text}, {"Ship-To Party Region", type text}, {"Trailer No.", type text}, {"Load Delay Reason", type text}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Load No.", type text}, {"Ship-To Zip", type text}, {"Spare Part Indicator", type text}, {"Ship-To Party", type text}, {"Sales Document Item", type text}, {"Order Qty", type number}, {"SO Billing Date", type date}, {"Material description MM", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"Trailer No.", "Trailer No"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared #"EDB Export w MRP" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "EDB Export w MRP.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column3", type text}, {"Column4", type text}, {"Column5", type text}, {"Column7", type text}, {"Column8", type text}, {"Column9", type text}, {"Column10", type text}, {"Column15", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Renamed columns" = Table.RenameColumns(#"Promoted headers", {{"Code:Payer (c4)", "Payer Code"}, {"Customer Demand (APO)#(lf)(2024,2025,2026,2027)", "Customer Demand (APO) (2026)"}}),
  #"Removed other columns" = Table.SelectColumns(#"Renamed columns", {"Code:SKU Level (c1)", "Payer Code", "Daily Date", "MRP Area", "Customer Demand (APO) (2026)"}),
  #"Split Date by Delimiter" = Table.SplitColumn(#"Removed other columns", "Daily Date", Splitter.SplitTextByDelimiter("/", QuoteStyle.Csv), {"Daily Date.1", "Daily Date.2", "Daily Date.3"}),
  #"Merged Date Columns" = Table.CombineColumns(#"Split Date by Delimiter",{"Daily Date.2", "Daily Date.1", "Daily Date.3"},Combiner.CombineTextByDelimiter("/", QuoteStyle.None),"Initial Date"),
  #"Changed Type1" = Table.TransformColumnTypes(#"Merged Date Columns", {{"Initial Date", type date}, {"MRP Area", type text}, {"Payer Code", type text}, {"Code:SKU Level (c1)", type text}, {"Customer Demand (APO) (2026)", Int64.Type}})
in
  #"Changed Type1";
[BindToDefaultDestination = true]
shared #"Plant 67 BOMs 6-25-25" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "Plant 67 BOMs 6-25-25.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Added Custom" = Table.AddColumn(#"Promoted headers", "BOM Type", each "Component"),
  #"Removed Other Columns" = Table.SelectColumns(#"Added Custom",{"Material", "Component", "Quantity", "BOM Type"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed Other Columns", {{"Material", type text}, {"Component", type text}, {"BOM Type", type text}, {"Quantity", Int64.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Payer Types" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "Payer Types.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Detail", type text}, {"Payer", type text}, {"Type", type text}, {"TypeKey", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Y Container Daily Pull" = // New Code: 6/29/2026
let
  Site = "https://keteronline.sharepoint.com/teams/SavannahRDC/",
  TargetPath = "Shared Documents/PowerBI Projects/DL/Y Container Daily Pull.xlsx",

  // Use SharePoint.Contents (folder-level navigation) instead of scanning entire site
  Source = SharePoint.Contents(Site, [ApiVersion = 15]),

  // Drill down folder-by-folder (no full-site scan)
  SharedDocs = Source{[Name="Shared Documents"]}[Content],
  PowerBIProjects = SharedDocs{[Name="PowerBI Projects"]}[Content],
  DL = PowerBIProjects{[Name="DL"]}[Content],

  // Direct file access (single row lookup instead of filtering table)
  File = DL{[Name="Y Container Daily Pull.xlsx"]}[Content],

  // Load Excel
  ExcelFile = Excel.Workbook(File, null, true),
  Sheet = ExcelFile{[Item="Sheet1", Kind="Sheet"]}[Data],

  // Promote headers
  Promoted = Table.PromoteHeaders(Sheet, [PromoteAllScalars=true]),

  // Type conversion (do this once, after pruning)
  Typed =
    Table.TransformColumnTypes(
      Promoted,
      {
        {"Container", type text},
        {"Cont. Int. Num.", Int64.Type},
        {"Storage Loc.", type text},
        {"Transfer Pending TO", type text},
        {"Date Of Request", type date},
        {"Material", type text},
        {"Quantity", Int64.Type},
        {"Expect. Arrival Date", type date},
        {"Container With Sever", type text},
        {"PO", type text},
        {"Vessel", type text},
        {"Manifest", type text},
        {"Count", Int64.Type},
        {"Days in Country", Int64.Type},
        {"Days In Place", Int64.Type},
        {"Reception Date", type date},
        {"Inb. Del.", Int64.Type},
        {"Expected PGR", type date},
        {"User", type text},
        {"Mat. Descr.", type text},
        {"Outb.Deliv.", Int64.Type},
        {"Customer", Int64.Type},
        {"Customer_1", type text},
        {"Stock In QA Inspect.", type text},
        {"Container Full Name", type text}
      }
    ),

  // Remove unused columns as early as possible AFTER headers but BEFORE heavy ops
  Final = Table.RemoveColumns(Typed, {"Storage Loc.", "Mat. Descr."})
in
  Final

// Old Code
// let
//   Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
//   #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Alloy/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Jons Folder/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Logistics Costs/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/NA Supply Chain Historical PBIX/") and ([Name] = "Y Container Daily Pull.xlsx")),
//   Navigation = #"Filtered rows"{[Name = "Y Container Daily Pull.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
//   #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
//   #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],

//   // FilterNullAndWhitespace =
//   //   each List.Select(_, each _ <> null and (not (_ is text) or Text.Trim(_) <> "")),
 
//   // #"Removed Bottom Rows" =
//   //   Table.RemoveLastN(
//   //       #"Navigation 1",
//   //       each
//   //           try
//   //               List.IsEmpty(
//   //                   List.Skip(FilterNullAndWhitespace(Record.FieldValues(_)), 1)
//   //               )
//   //           otherwise false
//   //   ),

//   #"Promoted Headers" =
//     Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars=true]),

//   // #"Added Static MRP Area" =
//   //   Table.AddColumn(#"Promoted Headers", "MRP Area", each "67_4674 - DHL"),

//   // #"Added MRP + SKU Key" =
//   //   Table.AddColumn(
//   //       #"Added Static MRP Area",
//   //       "MRPSKU Key",
//   //       each [MRP Area] & "|" & [Material]
//   //   ),

//   #"Changed Type" =
//     Table.TransformColumnTypes(#"Promoted Headers", {{"Container", type text}, {"Cont. Int. Num.", Int64.Type}, {"Storage Loc.", type text}, {"Transfer Pending TO", type text}, {"Date Of Request", type date}, {"Material", Int64.Type}, {"Quantity", Int64.Type}, {"Expect. Arrival Date", type date}, {"Container With Sever", type text}, {"PO", Int64.Type}, {"Vessel", type text}, {"Manifest", Int64.Type}, {"Count", Int64.Type}, {"Days in Country", Int64.Type}, {"Days In Place", Int64.Type}, {"Reception Date", type date}, {"Inb. Del.", Int64.Type}, {"Expected PGR", type date}, {"User", type text}, {"Mat. Descr.", type text}, {"Outb.Deliv.", Int64.Type}, {"Customer", Int64.Type}, {"Customer_1", type text}, {"Stock In QA Inspect.", type text}, {"Container Full Name", type text}}),
//   #"Removed Columns" =
//     Table.RemoveColumns(
//       #"Changed Type",
//       {"Storage Loc.", "Mat. Descr."}
//     )
// in
//   #"Removed Columns"
;
[BindToDefaultDestination = true]
shared #"All Sold To and Ship To USA" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Alloy/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Jons Folder/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Logistics Costs/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/NA Supply Chain Historical PBIX/") and ([Name] = "All Sold To and Ship To USA.XLSX")),
  Navigation = #"Filtered rows"{[Name = "All Sold To and Ship To USA.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"PayInfoRenamed Columns" = Table.RenameColumns(#"Promoted headers",{{"Customer", "Payer Key"}}),
  #"PayInfoChanged Type" = Table.TransformColumnTypes(#"PayInfoRenamed Columns", {{"Payer Key", type text}, {"Country", type text}, {"Name 1", type text}, {"Name 2", type text}, {"City", type text}, {"Region", type text}, {"Street", type text}, {"Address", type text}, {"Name 1_1", type text}, {"Name 2_2", type text}, {"City_3", type text}, {"Title", type text}, {"Postal Code", type text}, {"Search term", type text}, {"Telephone 1", type text}, {"Fax Number", type text}, {"One-time account", type text}, {"Central order block", type text}, {"Store Number", type text}, {"EDI Location Code", type text}})
in
 #"PayInfoChanged Type";
[BindToDefaultDestination = true]
shared Specs = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/KNAItemInfo", [ApiVersion = 15]),
  // #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/")),
  #"Current Item Sheets-2026.xlsx" = Source{[Name = "Current Item Sheets-2026.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(#"Current Item Sheets-2026.xlsx", null, true),
  #"Specs" = #"Imported Excel workbook"{[Item = "Specs", Kind = "Sheet"]}[Data],

  #"Removed top rows" = Table.Skip(#"Specs", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Renamed columns" = Table.RenameColumns(#"Promoted headers", {{"Length", "Carton - Length"}, {"Width", "Carton - Width"}, {"Height", "Carton - Height"}, {"Volume", "Carton - Volume"}, {"Weight", "Carton - Weight"}, {"cf", "Carton - cf"}, {"pcf", "Carton - pcf"}, {"Length_1", "Pallet - Length"}, {"Width_2", "Pallet - Width"}, {"Height_3", "Pallet - Height"}, {"Volume_4", "Pallet - Volume"}, {"Weight_5", "Pallet - Weight"}, {"cf_6", "Pallet - cf"}, {"pcf_7", "Pallet - pcf"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Carton - Length", type number}, {"Carton - Width", type number}, {"Carton - Height", type number}, {"Carton - Volume", type number}, {"Carton - Weight", type number}, {"Carton - cf", type number}, {"Carton - pcf", type number}, {"Pallet - Length", type number}, {"Pallet - Width", type number}, {"Pallet - Height", type number}, {"Pallet - Volume", type number}, {"Pallet - Weight", type number}, {"Pallet - cf", type number}, {"Pallet - pcf", type number}, {"LP", type number}, {"Carton Class", type number}, {"SS/PLT Class", type number}, {"Carton Dim Wt", type number}, {"Oversize +130"" Max 165""", type number}, {"Linear Ft CTN", type number}, {"Current", type text}, {"Override", type text}, {"SAP", type text}, {"Item", type text}}),
  #"Replaced errors" = Table.ReplaceErrorValues(#"Changed column type", {{"SAP", ""}}),
  #"Replaced errors 1" = Table.ReplaceErrorValues(#"Replaced errors", {{"SS/PLT Class", null}}),
  #"Replaced errors 2" = Table.ReplaceErrorValues(#"Replaced errors 1", {{"Carton Class", null}}),
  #"Replaced errors 3" = Table.ReplaceErrorValues(#"Replaced errors 2", {{"Pallet - pcf", null}}),
  #"Replaced errors 4" = Table.ReplaceErrorValues(#"Replaced errors 3", {{"Carton - pcf", null}})
in
  #"Replaced errors 4";
[BindToDefaultDestination = true]
shared #"Crossdock SKUS" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  // #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/") and ([Name] = "CrossDock SKUS.xlsx")),
  Navigation = Source{[Name = "CrossDock SKUS.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Crossdock SKUS" = #"Imported Excel workbook"{[Item = "Crossdock SKUS", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Crossdock SKUS", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"SAP", type text}, {"Description", type text}}),
  // #"Removed columns" = Table.RemoveColumns(#"Changed column type", {"Description"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "Crossdock", each "Crossdock"), {{"Crossdock", type text}})

in
  #"Added custom";
[BindToDefaultDestination = true]
shared #"Current Item Sheets-2026" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/KNAItemInfo", [ApiVersion = 15]),
  // #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/")),
  #"Current Item Sheets-2026.xlsx" = Source{[Name = "Current Item Sheets-2026.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(#"Current Item Sheets-2026.xlsx", null, true),
  SAP_Sheet2026 = #"Imported Excel workbook"{[Item = "SAP", Kind = "Sheet"]}[Data],

  #"Removed Other Columns2026" = Table.SelectColumns(SAP_Sheet2026,{"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14", "Column15", "Column16", "Column17", "Column18", "Column19", "Column20", "Column21", "Column22", "Column23", "Column24", "Column25", "Column26", "Column27"}),
  #"Promoted Headers2026" = Table.PromoteHeaders(#"Removed Other Columns2026", [PromoteAllScalars=true]),
  #"Changed Type2026" = Table.TransformColumnTypes(#"Promoted Headers2026",{{"Model", Int64.Type}, {"Description", type text}, {"Customer", Int64.Type}, {"Dept", type any}, {"Customer_1", type text}, {"Vendor #", type any}, {"Carton/Bag#(lf)Qty", Int64.Type}, {"Layer Qty", Int64.Type}, {"SS/PLT#(lf)Qty", Int64.Type}, {"TL Qty", Int64.Type}, {"Brand", type text}, {"Color", type any}, {"Note", type text}, {"Supplier", Int64.Type}, {"UPC/EAN", Int64.Type}, {"Carton I2of5", Int64.Type}, {"Pallet I2of5", Int64.Type}, {"Private Label", type any}, {"Opened", type date}, {"Plant-sp.matl status", type any}, {"Disco Date", type date}, {"PC Business Unit", type text}, {"HTS Code", type any}, {"MSRP", type any}, {"SAP", type text}}),
  #"Filtered out blank SAP #s2026" = Table.SelectRows(#"Changed Type2026", each [SAP] <> null and [SAP] <> ""),
  #"Renamed Columns2026" = Table.RenameColumns(#"Filtered out blank SAP #s2026",{{"SAP", "Material"}}),
  #"2026 Current Item Sheet" = Table.AddColumn(#"Renamed Columns2026", "Document Year", each 2026),

  #"Replaced Errors" = Table.ReplaceErrorValues(#"2026 Current Item Sheet", {{"Material", null}, {"Model", null}, {"Description", null}, {"Customer", null}, {"Dept", null}, {"Customer_1", null}, {"Vendor #", null}, {"Carton/Bag#(lf)Qty", null}, {"Layer Qty", null}, {"SS/PLT#(lf)Qty", null}, {"Cont#(lf)Qty", null}, {"TL Qty", null}, {"Brand", null}, {"Color", null}, {"Note", null}, {"Supplier", null}, {"UPC/EAN", null}, {"Carton I2of5", null}, {"Pallet I2of5", null}, {"Private Label", null}, {"Opened", null}, {"Plant-sp.matl status", null}, {"Disco Date", null}, {"PC Business Unit", null}, {"HTS Code", null}, {"MSRP", null}, {"Document Year", null}}),
  #"Renamed columns" = Table.RenameColumns(#"Replaced Errors", {{"Stacked", "Stacked_Cont/TL"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"Dept", type text}, {"Vendor #", type text}, {"Cont#(lf)Qty", type text}, {"Stacked_Cont/TL", type text}, {"Color", type text}, {"Private Label", type text}, {"Plant-sp.matl status", type text}, {"HTS Code", type text}, {"MSRP", type text}, {"Document Year", type text}})
  
in
  #"Changed column type";
shared #"Current Item Sheets-Archive" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/KNAItemInfo", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/Archived Data/")),
  #"Filtered rows 1" = Table.SelectRows(#"Filtered rows", each Text.Contains([Name], "Current Item Sheets"))
  
in
  #"Filtered rows 1";
[BindToDefaultDestination = true]
shared #"Current Item Sheets-2025" = let
  Source = #"Current Item Sheets-Archive",
  #"Current Item Sheets-2025" = Source{[Name = "Current Item Sheets-2025.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/Archived Data/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(#"Current Item Sheets-2025", null, true),
  SAP_Sheet2025 = #"Imported Excel workbook"{[Item = "SAP", Kind = "Sheet"]}[Data],

  #"Removed Other Columns2025" = Table.SelectColumns(SAP_Sheet2025,{"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14", "Column15", "Column16", "Column17", "Column18", "Column19", "Column20", "Column21", "Column22", "Column23", "Column24", "Column25", "Column26", "Column27"}),
  #"Promoted Headers2025" = Table.PromoteHeaders(#"Removed Other Columns2025", [PromoteAllScalars=true]),
  #"Changed Type2025" = Table.TransformColumnTypes(#"Promoted Headers2025", {{"Model", Int64.Type}, {"Description", type text}, {"Customer", Int64.Type}, {"Dept", type text}, {"Customer_1", type text}, {"Vendor #", type text}, {"Carton/Bag#(lf)Qty", Int64.Type}, {"Layer Qty", Int64.Type}, {"SS/PLT#(lf)Qty", Int64.Type}, {"TL Qty", Int64.Type}, {"Brand", type text}, {"Color", type text}, {"Note", type text}, {"Supplier", Int64.Type}, {"UPC/EAN", Int64.Type}, {"Carton I2of5", Int64.Type}, {"Pallet I2of5", Int64.Type}, {"Private Label", type text}, {"Opened", type date}, {"Plant-sp.matl status", type text}, {"Disco Date", type date}, {"PC Business Unit", type text}, {"HTS Code", type text}, {"MSRP", type text}, {"SAP", type text}, {"Stacked#(lf)Cont/TL", type text}, {"Cont#(lf)Qty", Int64.Type}}),
  #"Filtered out blank SAP #s2025" = Table.SelectRows(#"Changed Type2025", each [SAP] <> null and [SAP] <> ""),
  #"Renamed Columns2025" = Table.RenameColumns(#"Filtered out blank SAP #s2025",{{"SAP", "Material"}, {"Stacked#(lf)Cont/TL", "Stacked_Cont/TL"}}),
  #"2025 Current Item Sheet" = Table.AddColumn(#"Renamed Columns2025", "Document Year", each 2025),

  #"Replaced Errors" = Table.ReplaceErrorValues(#"2025 Current Item Sheet", {{"Material", null}, {"Model", null}, {"Description", null}, {"Customer", null}, {"Dept", null}, {"Customer_1", null}, {"Vendor #", null}, {"Carton/Bag#(lf)Qty", null}, {"Layer Qty", null}, {"SS/PLT#(lf)Qty", null}, {"Cont#(lf)Qty", null}, {"TL Qty", null}, {"Brand", null}, {"Color", null}, {"Note", null}, {"Supplier", null}, {"UPC/EAN", null}, {"Carton I2of5", null}, {"Pallet I2of5", null}, {"Private Label", null}, {"Opened", null}, {"Plant-sp.matl status", null}, {"Disco Date", null}, {"PC Business Unit", null}, {"HTS Code", null}, {"MSRP", null}, {"Document Year", null}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Replaced Errors", {{"Document Year", type text}})

in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Current Item Sheets-2024" = let
  Source = #"Current Item Sheets-Archive",
  Navigation = Source{[Name = "Current Item Sheets-2024.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/Archived Data/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  SAP_Sheet2024 = #"Imported Excel workbook"{[Item = "SAP", Kind = "Sheet"]}[Data],

  #"Removed Other Columns2024" = Table.SelectColumns(SAP_Sheet2024,{"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14", "Column15", "Column16", "Column17", "Column18", "Column19", "Column20", "Column21", "Column22", "Column23", "Column24", "Column25", "Column26"}),
  #"Promoted Headers2024" = Table.PromoteHeaders(#"Removed Other Columns2024", [PromoteAllScalars=true]),
  #"Changed Type2024" = Table.TransformColumnTypes(#"Promoted Headers2024",{{"SAP", type text}, {"Model", Int64.Type}, {"Description", type text}, {"Customer", Int64.Type}, {"Dept", type any}, {"Customer_1", type text}, {"Vendor #", type any}, {"Carton/Bag#(lf)Qty", Int64.Type}, {"Layer Qty", Int64.Type}, {"SS/PLT#(lf)Qty", Int64.Type}, {"TL Qty", Int64.Type}, {"Stacked", type text}, {"Brand", type text}, {"Color", type any}, {"Note", type text}, {"Supplier", Int64.Type}, {"UPC/EAN", Int64.Type}, {"Carton I2of5", Int64.Type}, {"Pallet I2of5", Int64.Type}, {"Private Label", type any}, {"Opened", type date}, {"Plant-sp.matl status", type any}, {"Disco Date", type date}, {"PC Business Unit", type text}}),
  #"Filtered Rows2024" = Table.SelectRows(#"Changed Type2024", each [SAP] <> null and [SAP] <> ""),
  #"Renamed Columns2024" = Table.RenameColumns(#"Filtered Rows2024", {{"SAP", "Material"}, {"Stacked", "Stacked_Cont/TL"}}),
  #"Removed Columns2024" = Table.RemoveColumns(#"Renamed Columns2024",{"Active"}),
  #"2024 Current Item Sheet" = Table.AddColumn(#"Removed Columns2024", "Document Year", each 2024),

  #"Replaced Errors" = Table.ReplaceErrorValues(#"2024 Current Item Sheet", {{"Material", null}, {"Model", null}, {"Description", null}, {"Customer", null}, {"Dept", null}, {"Customer_1", null}, {"Vendor #", null}, {"Carton/Bag#(lf)Qty", null}, {"Layer Qty", null}, {"SS/PLT#(lf)Qty", null}, {"Cont#(lf)Qty", null}, {"TL Qty", null}, {"Stacked_Cont/TL", null}, {"Brand", null}, {"Color", null}, {"Note", null}, {"Supplier", null}, {"UPC/EAN", null}, {"Carton I2of5", null}, {"Pallet I2of5", null}, {"Private Label", null}, {"Opened", null}, {"Plant-sp.matl status", null}, {"Disco Date", null}, {"PC Business Unit", null}, {"Document Year", null}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Replaced Errors", {{"Dept", type text}, {"Vendor #", type text}, {"Cont#(lf)Qty", type text}, {"Color", type text}, {"Private Label", type text}, {"Plant-sp.matl status", type text}, {"Document Year", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Current Item Sheets-2023" = let
  Source = #"Current Item Sheets-Archive",
  Navigation = Source{[Name = "Current Item Sheets-2023.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/Archived Data/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  Items_Sheet2023 = #"Imported Excel workbook"{[Item = "Items", Kind = "Sheet"]}[Data],

  #"Removed Other Columns2023" = Table.SelectColumns(Items_Sheet2023,{"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14", "Column15", "Column16", "Column17", "Column18", "Column19", "Column20", "Column21", "Column22", "Column23", "Column24", "Column25", "Column26", "Column27"}),
  #"Promoted Headers2023" = Table.PromoteHeaders(#"Removed Other Columns2023", [PromoteAllScalars=true]),
  #"Changed Type2023" = Table.TransformColumnTypes(#"Promoted Headers2023",{{"SAP", type text}, {"Product", Int64.Type}, {"Description", type text}, {"Customer", Int64.Type}, {"Dept", type any}, {"Customer_1", type text}, {"SKU", type any}, {"Vendor #", type any}, {"Carton/Bag#(lf)Qty", Int64.Type}, {"Layer Qty", Int64.Type}, {"SS/PLT#(lf)Qty", Int64.Type}, {"TL Qty", Int64.Type}, {"Stacked", type text}, {"Brand", type text}, {"Color", type any}, {"Note", type text}, {"Active", type text}, {"Supplier", Int64.Type}, {"UPC/EAN", Int64.Type}, {"Carton I2of5", Int64.Type}, {"Pallet I2of5", Int64.Type}, {"Private Label", Int64.Type}, {"Opened", type date}, {"Plant-sp.matl status", type text}, {"Disco Date", type date}, {"PC Business Unit 2.0", type text}}),
  #"Renamed Columns2023" = Table.RenameColumns(#"Changed Type2023", {{"Product", "Model"}, {"SAP", "Material"}, {"PC Business Unit 2.0", "PC Business Unit"}, {"Stacked", "Stacked_Cont/TL"}}),
  #"Removed Columns" = Table.RemoveColumns(#"Renamed Columns2023",{"SKU", "Active"}),
  #"2023 Current Item Sheet" = Table.AddColumn(#"Removed Columns", "Document Year", each 2023),

  #"Replaced Errors" = Table.ReplaceErrorValues(#"2023 Current Item Sheet", {{"Material", null}, {"Model", null}, {"Description", null}, {"Customer", null}, {"Dept", null}, {"Customer_1", null}, {"Vendor #", null}, {"Carton/Bag#(lf)Qty", null}, {"Layer Qty", null}, {"SS/PLT#(lf)Qty", null}, {"Cont#(lf)Qty", null}, {"TL Qty", null}, {"Stacked_Cont/TL", null}, {"Brand", null}, {"Color", null}, {"Note", null}, {"Supplier", null}, {"UPC/EAN", null}, {"Carton I2of5", null}, {"Pallet I2of5", null}, {"Private Label", null}, {"Opened", null}, {"Plant-sp.matl status", null}, {"Disco Date", null}, {"PC Business Unit", null}, {"Document Year", null}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Replaced Errors", {{"Dept", type text}, {"Vendor #", type text}, {"Color", type text}, {"Document Year", type text}, {"Cont#(lf)Qty", type text}})

in
  #"Changed column type";
[BindToDefaultDestination = true]
shared PackSource = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/") ),
  Navigation = #"Filtered rows"{[Name = "Pack Type.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"SKU", type text}, {"General", type text}, {"Final", type text}})

in
  #"Changed column type";
[BindToDefaultDestination = true]
shared DCMSource = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/") ),
  Navigation = #"Filtered rows"{[Name = "DCM From EDB For PBI.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  EDBPlusExcel_sheetDCM = #"Imported Excel workbook"{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  
  FilterNullAndWhitespaceDCM = each List.Select(_, each _ <> null and (not (_ is text) or Text.Trim(_) <> "")),
  #"Removed Top RowsDCM" = Table.Skip(EDBPlusExcel_sheetDCM, each try List.IsEmpty(List.Skip(FilterNullAndWhitespaceDCM(Record.FieldValues(_)), 2)) otherwise false),
  #"Transposed TableDCM" = Table.Transpose(#"Removed Top RowsDCM"),
  #"Removed Bottom RowsDCM" = Table.RemoveLastN(#"Transposed TableDCM", each try List.IsEmpty(List.Skip(FilterNullAndWhitespaceDCM(Record.FieldValues(_)), 1)) otherwise false),
  #"Transposed Table1DCM" = Table.Transpose(#"Removed Bottom RowsDCM"),
  #"Promoted HeadersDCM" = Table.PromoteHeaders(#"Transposed Table1DCM", [PromoteAllScalars=true]),
  #"DCM (SKU Level)" = Table.TransformColumnTypes(#"Promoted HeadersDCM",{{"US DOLLAR#(lf)SKU Level", type text}, {"Code:SKU Level (c1)", type text}, {"Gross Sales#(lf)(01-09/25)", type number}, {"Quantity#(lf)(01-09/25)", Int64.Type}, {"Net  Sales#(lf)(01-09/25)", type number}, {"Direct Contribution#(lf)(01-09/25)", type number}, {"GS Price/Unit (Actual)", type number}, {"NS/GS Actual (%)", type number}, {"DCM Actual (%)", type number}, {"Gross Sales - Budget#(lf)(2025)", type number}, {"Quantity - Budget#(lf)(2025)", Int64.Type}, {"Net Sales - Budget#(lf)(2025)", type number}, {"Manufactoring Costs - Budget#(lf)(2025)", type number}, {"Total Logistics - Budget#(lf)(2025)", type number}, {"Direct Contribution - Budget#(lf)(2025)", type number}, {"GS Price/Unit (Budget)", type number}, {"NS/GS Budget (%)", type number}, {"DCM Budget (%)", type number}})

in
  #"DCM (SKU Level)";
[BindToDefaultDestination = true]
shared ZMM02 = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/")),
  Navigation = #"Filtered rows"{[Name = "ZMM02.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  // Add Cost Key column
  #"Added Plant + Material" = Table.AddColumn(#"Promoted headers", "Cost Key", each [Plnt] & ":" & [Material]),

  // Add Unit Cost calculation
  #"Added Unit Cost Calculation" = Table.AddColumn(
      #"Added Plant + Material", 
      "Cost", 
      each if [Standard price] = 0 and [per] = 0 then 0 else [Standard price] / [per]
  ),

  // Remove unnecessary columns
  #"Removed Columns" = Table.RemoveColumns(#"Added Unit Cost Calculation", {"Material Description"}),

  // Change column types
  #"Changed Column Types" = Table.TransformColumnTypes(#"Removed Columns", {{"Plnt", type text}, {"per", type number}, {"Old material no.", type text}, {"Material", type text}, {"Standard price", Currency.Type}, {"Cost Key", type text}, {"Cost", type number}, {"MS", type text}, {"MTyp", type text}, {"Material Type", type text}, {"Crcy", type text}, {"ABC", type text}, {"#### MRP", type text}, {"Profit Ctr", type text}, {"Typ", type text}, {"MRPC", type text}, {"ProcType", type text}, {"Matl Group", type text}, {"SPT", type text}, {"BUn", type text},  {"Min. Lot Sze", type text},  {"BUn_1", type text}, {"SortGrp_012_T", type text}, {"Max. Lot Size", type text}, {"SortGrp_019", type text}, {"BUn_2", type text}, {"SortGrp_019_T", type text}, {"Rounding val.", type text},  {"BUn_3", type text},  {"PrTime", type text}, {"TiHi", type text}, {"Code number", type text}, {"Orig", type text}, {"Planning time fence", type text}, {"MRP", type text}, {"Net Weight", type text}, {"WUn", type text}, {"Volume", type text}, {"VUn", type text}, {"MS_4", type text}, {"MPN", type text}, {"ValCl", type text}, {"PlanPrice 1", type text}, {"Crcy_5", type text}, {"WUn_6", type text}, {"Bulk", type text}, {"Alt.Gross Weight", type text}, {"Main Mold", type text}, {"WUn_7", type text}, {"Item classification", type text}, {"VUn_8", type text}, {"Item classification_9", type text}, {"Alt. Volume", type text}, {"Planning category", type text}, {"VUn_10", type text}, {"Planning category_11", type text}, {"Unit of Dimension", type text}, {"Pr", type text}, {"Alt.Height", type text}, {"Preference indicator in export", type text}, {"Unit of Dimension_12", type text}, {"Vdr decl.", type text}, {"Alt. Width", type text}, {"Indicator: Vendor declaration", type text}, {"Unit of Dimension_13", type text}, {"Ct", type text}, {"Alt.Length", type text}, {"Unit of Dimension_14", type text}, {"EAN/UPC", type text}, {"EAN number", type text}, {"Denom.", type text}, {"A.scrap", type text}, {"B", type text}, {"Stor", type text}, {"Customer No.", type text}, {"VUn_15", type text}, {"WUn_16", type text}, {"St", type text}, {"SPTC", type text}, {"MovAvgPrice", type text}, {"Crcy_17", type text}, {"Pr.", type text}, {"#### #""# MRP", type text}, {"Clt", type text}, {"BUn_18", type text}, {"For.", type text}, {"Size/dimensions", type text}, {"Ct_19", type text}, {"PP date 1", type text}, {"Language", type text}, {"Av", type text}, {"Prod./insp. memo", type text}, {"PGr", type text}, {"PI", type text}, {"OTol", type text}, {"Reorder Point", type text}, {"BUn_20", type text}, {"Follow-Up Material", type text}, {"Consumption mode", type text}, {"Bwd cons. per.", type text}, {"Fwd cons.period", type text}, {"SLoc", type text}, {"D", type text}, {"CoPr", type text}, {"Created", type text}, {"###.###.MR", type text}, {"Color", type text}, {"Special Procurement Type for C", type text}, {"I/C", type text}, {"Ext. Material Grp", type text}, {"Color Description", type text}, {"Pallet Type", type text}, {"Seas/NonSeasIndic", type text}, {"SparePartInd.", type text}, {"IML Code", type text}, {"PalHeight", type text}, {"PalHeightUOM", type text}, {"Packaging feature", type text}, {"MatFrtGp", type text}, {"AltUnit_NetWeight", type text}, {"WUn_21", type text}, {"MRPpr", type text}, {"SortGrp_031", type text}, {"SortGrp_031_T", type text}, {"Code Pack Desc.", type text}, {"Pallet Type Description", type text}, {"IML Description", type text}, {"BUn_22", type text}, {"Col", type text}, {"Basic material", type text}, {"Gross Weight", type text}, {"WUn_23", type text}, {"PalHeightUOM_24", type text}, {"ItCGr", type text}, {"Material Group Desc.", type text}, {"BUn_25", type text}})
in
  #"Changed Column Types";
[BindToDefaultDestination = true]
shared #"DTC YRSHP" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/")),
  Navigation = #"Filtered rows"{[Name = "DTC YRSHP.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Shipment Number", type text}, {"Delivery", type text}, {"DeliveryGrossWeight", type text}, {"Sold-to party", type text}, {"Forwarder Name", type text}, {"Act. Gds Mvmnt Date", type text}, {"Material", type text}, {"Description", type text}, {"Payer", type text}, {"Payer name", type text}, {"Ship-to party", type text}, {"Shipping type", type text}, {"ShipTo Customer – City", type text}, {"ShipTo Customer – Postal code", type text}, {"RegionWE", type text}, {"ShipTo Postal code (Shipment)", type text}, {"ShipTo Region (Shipment)", type text}, {"Delivery quantity", type text}, {"Net Value", type text}, {"Incoterms", type text}, {"Purchase order number", type text}, {"Storage Location", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"2018 to 2024 Sales" = // let
//   Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/NASpareParts", [ApiVersion = 15]),
//   #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/")),
//   Navigation = #"Filtered rows"{[Name = "2018 to 2024 EDB Sales.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/NASpareParts/Shared Documents/Justins Auto Uploads/"]}[Content],
//   #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
//   #"Navigation 1" = #"Imported Excel workbook"{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
//   #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column2", type text}, {"Column4", type text}, {"Column5", type text}, {"Column7", type text}}),
//   #"Removed top rows" = Table.Skip(#"Changed column type", 1),
//   #"Removed columns" = Table.RemoveColumns(#"Removed top rows", {"Column9"}),
//   #"Promoted headers" = Table.PromoteHeaders(#"Removed columns", [PromoteAllScalars = true]),
//   #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Code:Country (c2)", Int64.Type}, {"Code:SKU Level (c4)", Int64.Type}, {"Quantity#(lf)(2018,2019,2020,2021,2022,2023,2024)", Int64.Type}})
// in
//   #"Changed column type 1"

// 6/22/2026 - CJ: Updated Query
let
  Source = SharePoint.Contents("https://keteronline.sharepoint.com/teams/NASpareParts", [ApiVersion = 15]),
  Site = Source{[Name="Shared Documents"]}[Content],
  Folder = Site{[Name="Justins Auto Uploads"]}[Content],
  File = Folder{[Name="2018 to 2024 EDB Sales.xlsx"]}[Content],

  BufferedFile = Binary.Buffer(File),

  ExcelData = Excel.Workbook(BufferedFile, null, true),

  Sheet = ExcelData{[Item="EDBPlusExcel", Kind="Sheet"]}[Data],

  SkipHeader = Table.Skip(Sheet, 1),
  RemoveCols = Table.RemoveColumns(SkipHeader, {"Column9"}),
  Promote = Table.PromoteHeaders(RemoveCols, [PromoteAllScalars=true]),

  Types = Table.TransformColumnTypes(Promote, {
    {"Code:Country (c2)", Int64.Type},
    {"Code:SKU Level (c4)", Int64.Type},
    {"Quantity#(lf)(2018,2019,2020,2021,2022,2023,2024)", Int64.Type}
  })
in
  Types;
[BindToDefaultDestination = true]
shared #"Warranty Period" = let
    // 1. Connect to SharePoint site (ROOT ONLY)
    Source =
        SharePoint.Files(
            "https://keteronline.sharepoint.com/teams/NASpareParts",
            [ApiVersion = 15]
        ),

    // 2. Filter to the exact file
    FilteredFile =
        Table.SelectRows(
            Source,
            each
                [Name] = "FG Warranty.xlsx"
                and Text.Contains(
                    [Folder Path],
                    "Shared Documents/Justins Auto Uploads"
                )
        ),

    // 3. Get the file binary
    FileBinary =
        FilteredFile{0}[Content],

    // 4. Open the Excel file
    ExcelData =
        Excel.Workbook(
            FileBinary,
            null,
            true
        ),

    // 5. Select the desired sheet or table
    // 🔴 CHANGE "Sheet1" if needed
    WarrantySheet =
        ExcelData{
            [Item = "Sheet1", Kind = "Sheet"]
        }[Data],
  #"Promoted headers" = Table.PromoteHeaders(WarrantySheet, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"NA Finished Good", type text}, {"Warranty (Year)", Int64.Type}}),
  #"Removed duplicates" = Table.Distinct(#"Changed column type", {"NA Finished Good", "Warranty (Year)"})

in
    #"Removed duplicates";
[BindToDefaultDestination = true]
shared #"COOIS Plant 73" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Sorted rows" = Table.Sort(Source, {{"Date created", Order.Descending}}),
  Navigation = #"Sorted rows"{[Name = "COOIS_Plant73.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"User Status", type text}, {"System Status", type text}, {"Work Center", type text}, {"Mold", Int64.Type}, {"Order", Int64.Type}, {"Material Number", Int64.Type}, {"Material description", type text}, {"Order quantity (GMEIN)", Int64.Type}, {"Confirmed quantity (GMEIN)", Int64.Type}, {"Confirmed scrap (GMEIN)", Int64.Type}, {"Remaining HR time (H)", type number}, {"Remaining Work hours", type number}, {"Start date (sched)", type date}, {"Scheduled finish date", type date}, {"Mold description", type text}, {"Scheduled fin. time", type datetime}, {"Scheduled start time", type datetime}, {"Labour (C) (VGE03)", type number}, {"Last changed by", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"ABC Analysis" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "Inventory analysis ABC XYZ - APO.xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "Overview", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Removed other columns" = Table.SelectColumns(#"Promoted headers", {"Product", "Product description", "Location", "ABC", "XYZ"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed other columns", {{"XYZ", type text}, {"Product", type text}, {"Product description", type text}, {"Location", type text}, {"ABC", type text}})
in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"EDB Budget- QTY" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "EDB Budget - Quantity.xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(Navigation, {{"Column1", type text}, {"Column2", type text}, {"Column3", type text}, {"Column4", type text}, {"Column5", type text}, {"Column7", type text}, {"Column9", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Code:Payer (c5)", Int64.Type}, {"Code:SKU Level (c6)", Int64.Type}, {"Quantity - Budget#(lf)(2026,2027,01-06/28)", Int64.Type}, {"3+9 Quantity#(lf)(2026,2027,01-06/28)", Int64.Type}, {"6+6 Quantity#(lf)(2026,2027,01-06/28)", Int64.Type}, {"9+3 Quantity#(lf)(2026,2027,01-06/28)", Int64.Type}, {"Customer Demand (APO)#(lf)(2026,2027,01-06/28)", Int64.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "Months_Date", each Date.FromText("20" & Text.Range([Months], 3, 2) & "-" & Text.Start([Months], 2) & "-01")), {{"Months_Date", type date}}),
  #"Renamed columns" = Table.RenameColumns(#"Added custom", {{"Quantity - Budget#(lf)(2026,2027,01-06/28)", "Quantity - Budget"}, {"3+9 Quantity#(lf)(2026,2027,01-06/28)", "3+9 Quantity"}, {"6+6 Quantity#(lf)(2026,2027,01-06/28)", "6+6 Quantity"}, {"9+3 Quantity#(lf)(2026,2027,01-06/28)", "9+3 Quantity"}, {"Customer Demand (APO)#(lf)(2026,2027,01-06/28)", "Customer Demand (APO)"}}),
  #"Removed columns" = Table.RemoveColumns(#"Renamed columns", {"Column15"})
in
    #"Removed columns";
[BindToDefaultDestination = true]
shared #"EDB Budget- Finance" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "EDB Budget.xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Removed top rows" = Table.Skip(Navigation, 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"US DOLLAR#(lf)PC Business Unit", type text}, {"Product Line", type text}, {"MRP Area", type text}, {"Customer Groups", type text}, {"Payer", type text}, {"Code:Payer (c5)", type text}, {"SKU Level", type text}, {"Code:SKU Level (c6)", type text}, {"Months", type text}, {"Net Sales - Budget#(lf)(2026,2027,01-06/28)", Currency.Type}, {"3+9 Net Sales#(lf)(2026,2027,01-06/28)", Currency.Type}, {"6+6 Net Sales#(lf)(2026,2027,01-06/28)", Currency.Type}, {"9+3 Net Sales#(lf)(2026,2027,01-06/28)", Currency.Type}, {"Customer Demand Net sales (APO)#(lf)(2026,2027,01-06/28)", Currency.Type}, {"Committed Net Sales (APO)#(lf)(2026,2027,01-06/28)", Currency.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "Months_Date", each Date.FromText("20" & Text.Range([Months], 3, 2) & "-" & Text.Start([Months], 2) & "-01")), {{"Months_Date", type date}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom", {"Column16"})
in
    #"Removed columns";
[BindToDefaultDestination = true]
shared #"THD TEMP" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "Marshal THD SKUS (Temp for filter on THD Sample).xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "Sheet5", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(Navigation, {{"Column1", type text}, {"Column4", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"SKU Level", Int64.Type}, {"THD SKU ", Int64.Type}, {"Total Forecast ", Int64.Type}, {"Total Invoice", Int64.Type}, {"AVG Forecast", type number}})
in
    #"Changed column type 1";
[BindToDefaultDestination = true]
shared #"FCST ACCURACY" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "Forecast Accuracy All items DHL.xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "FCST ACC", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"BU", type text}, {"SKU Level", Int64.Type}, {"Description", type text}, {"Total Forecast ", Int64.Type}, {"Total Invoice", Int64.Type}, {"AVG Forecast", Percentage.Type}, {"DOS Target", type text}, {"Bias %", Percentage.Type}})

in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"Ecomm-Store" = let
    // Connect to SharePoint folder
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC", 
        [ApiVersion = 15]
    ),

    // Filter to the specific folder
    FilteredFolder = Table.SelectRows(
        Source, 
        each [Folder Path] = 
            "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ),

    // Get the specific file
    FileContent = FilteredFolder{
        [Name = "ECOMM-Store File.xlsx", 
         #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]
    }[Content],

    // Read Excel workbook
    ExcelData = Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "Export", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Payer", type text}, {"Name", type text}, {"ECOMM/ Store", type text}}),
  #"Filtered rows" = Table.SelectRows(#"Changed column type", each [Payer] <> null and [Payer] <> "")

in
    #"Filtered rows";
[BindToDefaultDestination = true]
shared Margin = let
    Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
    Navigation = Source{[
        Name = "US Negative Variable Margin.xlsx", 
        #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    ]}[Content],

    #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column2", type text}, {"Column3", type text}, {"Column5", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 1),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Code:Customer Groups (c3)", Int64.Type}, {"Code:SKU Level (c4)", type text}, {"Net  Sales#(lf)(01-05/26)", type number}, {"DC WO Fixed#(lf)(01-05/26)", type number}, {"Direct Contribution#(lf)(01-05/26)", Currency.Type}, {"DC WO Fixed/NS (%)#(lf)(01-05/26)", type number}, {"Direct Contribution/ Net Sales (%)#(lf)(01-05/26)", type number}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type 1", {{"Net  Sales#(lf)(01-05/26)", "Net  Sales"}, {"DC WO Fixed#(lf)(01-05/26)", "DC WO Fixed"}, {"Direct Contribution#(lf)(01-05/26)", "Direct Contribution"}, {"DC WO Fixed/NS (%)#(lf)(01-05/26)", "DC WO Fixed/NS (%)"}, {"Direct Contribution/ Net Sales (%)#(lf)(01-05/26)", "Direct Contribution/ Net Sales (%)"}}),
  #"Removed columns" = Table.RemoveColumns(#"Renamed columns", {"Column12"})
  
in
    #"Removed columns";
[BindToDefaultDestination = true]
shared #"THD Item number" = // let
//   Source = Excel.Workbook(
//     Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/THD%20ITEM%20Numbers.xlsx"),
//     null,
//     true
//   ),
//   #"Navigation 1" = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
//   #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars=true]),
//   #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"ITEM", type text}, {"THD item ", type text}})

// in
//   #"Changed column type"

// 6/22/2026 - CJ: Updated Query
let
  Source = SharePoint.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),

  Site = Source{[Name="Shared Documents"]}[Content],
  Folder1 = Site{[Name="PowerBI Projects"]}[Content],
  Folder2 = Folder1{[Name="DL"]}[Content],

  File = Folder2{[Name="THD ITEM Numbers.xlsx"]}[Content],

  BufferedFile = Binary.Buffer(File),

  ExcelData = Excel.Workbook(BufferedFile, null, true),

  Sheet = ExcelData{[Item="Sheet1", Kind="Sheet"]}[Data],

  Promote = Table.PromoteHeaders(Sheet, [PromoteAllScalars=true]),

  Types = Table.TransformColumnTypes(Promote, {
    {"ITEM", type text},
    {"THD item ", type text}
  })
in
  Types;
[BindToDefaultDestination = true]
shared PvillewarehousematchCOOIS = let
  // Connect to SharePoint site
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  // Filter to the specific file (robust to folder changes)
  FilteredFile = Table.SelectRows(
    Source,
    each [Name] = "PvillewarehousematchCOOIS.XLSX"
  ),

  // Get binary
  FileBinary = FilteredFile{0}[Content],

  // Read Excel
  ExcelData = Excel.Workbook(FileBinary, null, true),

  // Select the sheet (adjust if needed)
  Sheet1 = ExcelData{[Item = "Sheet1", Kind = "Sheet"]}[Data],

  // Promote headers
  PromotedHeaders = Table.PromoteHeaders(Sheet1, [PromoteAllScalars = true]),

  // Optional: type casting (safe starter — adjust later)
  TypedColumns = Table.TransformColumnTypes(
      PromotedHeaders,
      {
        {"Material Number", Int64.Type},
        {"Order", Int64.Type},
        {"Order quantity (GMEIN)", Int64.Type},
        {"Leading order", Int64.Type}
      }
  )
in
  TypedColumns;
