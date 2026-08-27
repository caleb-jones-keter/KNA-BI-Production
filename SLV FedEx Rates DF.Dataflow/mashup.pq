[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
shared #"FedEx Rates" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/")),
  Navigation = #"Filtered rows"{[Name = "FedEx US Rates.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true)
in
  #"Imported Excel workbook";
[BindToDefaultDestination = true]
shared #"DIM FedEx Zones" = let
  Source = #"FedEx Rates",
  Navigation = Source{[Item = "FedEx Zones", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Destination Zip", type text}, {"Destination Zip Start", type text}, {"Destination Zip End", type text}, {"FedEx Ground Zone", type text}, {"Destination Zip Start Int", Int64.Type}, {"Destination Zip End Int", Int64.Type}, {"Origin Zip", type text}}),
  AddList = Table.AddColumn(#"Changed column type", "ZipList", each List.Numbers([Destination Zip Start Int], [Destination Zip End Int] - [Destination Zip Start Int] + 1)),
  Expanded = Table.ExpandListColumn(AddList, "ZipList"),
  AddPaddedZip = Table.AddColumn(Expanded, "Destination Zip Code", each Text.PadStart(Text.From([ZipList]), 5, "0")),
  #"Changed column type 1" = Table.TransformColumnTypes(AddPaddedZip, {{"Destination Zip Code", type text}, {"FedEx Ground Zone", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Changed column type 1", {"Destination Zip Start", "Destination Zip End", "Destination Zip Start Int", "Destination Zip End Int", "ZipList"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"Destination Zip", "Dest Zip Zone"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared #"DIM FedEx DAS Zip Codes" = let
  Source = #"FedEx Rates",
  Navigation = Source{[Item = "DAS Zip Codes", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Destination ZIP Codes", type text}, {"DAS Type", type text}, {"DAS Charge", Currency.Type}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"DAS Charge", "DAS Rate"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared #"DIM FedEx Ground Rates Domestic" = let
  Source = #"FedEx Rates",
  Navigation = Source{[Item = "Domestic Ground Rates", Kind = "Sheet"]}[Data],
  #"Removed top rows" = Table.Skip(Navigation, 3),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Renamed columns" = Table.RenameColumns(#"Promoted headers", {{"Column1", "Weight (lbs)"}}),
  #"Unpivoted columns" = Table.UnpivotOtherColumns(#"Renamed columns", {"Weight (lbs)"}, "Zone", "Base Rate"),
  #"Changed column type" = Table.TransformColumnTypes(#"Unpivoted columns", {{"Base Rate", Currency.Type}, {"Weight (lbs)", Int64.Type}, {"Zone", Int64.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"DIM FedEx Ground Surcharges Domestic" = let
  Source = #"FedEx Rates",
  Navigation = Source{[Item = "Domestic Ground Surcharges", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Zone", Int64.Type}, {"AHS_Dim", Currency.Type}, {"AHS_Dim_Disc", Currency.Type}, {"AHS_Weight", Currency.Type}, {"AHS_Weight_Disc", Currency.Type}, {"AHS_Packaging", Currency.Type}, {"AHS_Packaging_Disc", Currency.Type}, {"Oversize", Currency.Type}, {"Oversize_Disc", Currency.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"DIM FedEx Canada Zones 2026" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/")),
  Navigation = #"Filtered rows"{[Name = "FedEx_International_Ground_Canada_Zones_2026.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "FedEx Canada Zones 2026", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Province", type text}, {"Service Type", type text}, {"Postal Range", type text}, {"Start FSA", type text}, {"End FSA", type text}, {"Zone", Int64.Type}})
in
  #"Changed column type";
