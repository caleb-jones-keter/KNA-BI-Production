[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"DAT US Regions" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/") and ([Name] = "State_Regions.xlsx")),
  Navigation = #"Filtered rows"{[Name = "State_Regions.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Region", type text}, {"StateCode", type text}, {"Rate", type number}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"Spreetail Rates" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/")),
  Navigation = #"Filtered rows"{[Name = "Spreetail Rates.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"YR Code", type text}, {"YR Description", type text}, {"Material", type text}, {"Material Description", type text}, {"Amount", type number}, {"UOM", type text}}),
  #"Filtered rows 1" = Table.SelectRows(#"Changed column type", each ([YR Code] = "YR60") and ([Amount] <> null and [Amount] <> ""))
in
  #"Filtered rows 1";
[BindToDefaultDestination = true]
shared #"Spreetail High Cost Service Area Zips" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/")),
  Navigation = #"Filtered rows"{[Name = "Spreetail High Cost Service Area Zips.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"ZipCode", type text}, {"Area", type text}, {"Surcharge", Int64.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"USA CAN Zips" = // let
//   Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
//   #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Alloy/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Jons Folder/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Logistics Costs/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/NA Supply Chain Historical PBIX/" or [Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/Spare parts/") and ([Name] = "usa+canada zip codes.xlsx")),
//   Navigation = #"Filtered rows"{[Name = "usa+canada zip codes.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
//   #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
//   #"Navigation 1" = #"Imported Excel workbook"{[Item = "usa+canada zip codes", Kind = "Sheet"]}[Data],
//   #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
//   #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"POSTAL_CODE", type text}, {"CITY", type text}, {"PROVINCE_ABBR", type text}, {"LATITUDE", type number}, {"LONGITUDE", type number}}),
//   #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"PROVINCE_ABBR", "REGION"}})
// in
//   #"Renamed columns"

let
  Source = SharePoint.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC"),
  SharedDocs = Source{[Name="Documents"]}[Content],
  PowerBI = SharedDocs{[Name="PowerBI Projects"]}[Content],
  DL = PowerBI{[Name="DL"]}[Content],
  File = DL{[Name="usa+canada zip codes.xlsx"]}[Content],

  ExcelFile = Excel.Workbook(File, null, true),
  Sheet = ExcelFile{[Item="usa+canada zip codes", Kind="Sheet"]}[Data],
  Promoted = Table.PromoteHeaders(Sheet, [PromoteAllScalars = true]),

  Typed = Table.TransformColumnTypes(Promoted,{
    {"POSTAL_CODE", type text},
    {"CITY", type text},
    {"PROVINCE_ABBR", type text},
    {"LATITUDE", type number},
    {"LONGITUDE", type number}
  }),

  Final = Table.RenameColumns(Typed, {{"PROVINCE_ABBR", "REGION"}})
in
  Final;
[BindToDefaultDestination = true]
shared #"Amazon Warehouses" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "Amazon Warehouses.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"State", type text}, {"Amazon Warehouse", type text}, {"IATA Code", type text}, {"Airport Zip Code", type text}})
in
  #"Changed column type";
