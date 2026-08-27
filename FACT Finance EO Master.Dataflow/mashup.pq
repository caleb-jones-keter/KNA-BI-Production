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
shared #"FACT Finance EO Master" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  File = Source{
      [
        Name = "Finance EO Provision MASTER.xlsm",
        Folder Path = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/Additional Files/"
      ]
  }[Content],

  Workbook = Excel.Workbook(File, null, true),
  Navigation = Workbook{[Item = "09_ZMD07", Kind = "Sheet"]}[Data],
  #"Removed top rows" = Table.Skip(Navigation, 2),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Plnt", Int64.Type}, {"Basic material", type text}, {"Material", Int64.Type}, {"Material Number", type text}, {"End date", type date}, {"Total Stock", type number}, {"Total Free Stock", type number}, {"Planned Price", type number}, {"Price", Int64.Type}, {"Created", type date}, {"MS", type text}, {"Plant_Name", type text}, {"Status", type text}, {"Mat_Code", Int64.Type}, {"BU", type text}, {"Profit Center", Int64.Type}, {"PL GL", Int64.Type}, {"BS GL", Int64.Type}, {"cost-conter", type text}, {"Inventory Type", type text}, {"FCTS", type number}, {"Monthly Coverage=(L12M Sales/12)", type number}, {"positive Open order", type number}, {"TYPE", type text}, {"Months of existence", Int64.Type}, {"SAP Item Status", type text}, {"COOIS - 3LM_Prod&Purch", type number}, {"Stock At Sea $", Int64.Type}, {"Healthy", type number}, {"Excessive", type number}, {"Obsolete", Int64.Type}, {"Healthy  $", type number}, {"Excessive $", type number}, {"Obs $", type number}, {"Provision Excessive Stock", type number}, {"Provision Obsolete stock", type number}, {"Provision With Var Cap Adjustment", type number}, {"$ This Month Less $ Last Month", type number}})

in
  #"Changed column type";
