[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
[BindToDefaultDestination = true]
shared #"DIM IBP Customer" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  FilteredFile =
    Table.SelectRows(
      Source,
      each [Name] = "DIM IBP Customer.xlsx"
    ),

  File = FilteredFile{0}[Content],

  Workbook = Excel.Workbook(File, null, true),

  Data = Workbook{[Item = "Sheet1", Kind = "Sheet"]}[Data],

  #"Promoted Headers" = Table.PromoteHeaders(Data, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted Headers", {{"IBP Customer Code", type text}, {"Payer Key", type text}, {"Payer Name", type text}, {"IBP Customer", type text}}),
  #"Removed duplicates" = Table.Distinct(#"Changed column type", {"Payer Key"})
in
  #"Removed duplicates";
[BindToDefaultDestination = true]
shared #"DIM IBP Payer Type" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  FilteredFile =
    Table.SelectRows(
      Source,
      each [Name] = "DIM IBP Customer.xlsx"
    ),

  File = FilteredFile{0}[Content],

  Workbook = Excel.Workbook(File, null, true),

  Data = Workbook{[Item = "Sheet2", Kind = "Sheet"]}[Data],

  #"Promoted Headers" = Table.PromoteHeaders(Data, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted Headers", {{"IBP Customer Code", type text}, {"IBP Customer", type text}, {"Payer Key", type text}, {"Payer Name", type text}, {"Payer Type", type text}, {"Payer Type Key", type text}, {"Detail", type text}})
in
  #"Changed column type";
