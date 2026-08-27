[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
shared #"CollectLTLRoutingGuide-2026K" = let
  Source = SharePoint.Contents(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  SharedDocuments = Source{[Name="Shared Documents"]}[Content],
  PowerBIProjects = SharedDocuments{[Name="PowerBI Projects"]}[Content],
  DL = PowerBIProjects{[Name="DL"]}[Content],

  FileContent = DL{[Name="CollectLTLRoutingGuide-2026K.xlsx"]}[Content],

  Workbook = Excel.Workbook(FileContent, null, true)
in
  Workbook;
[BindToDefaultDestination = true]
shared #"DIM LTL Vendor Origin-Point to State" = let
    Source = #"CollectLTLRoutingGuide-2026K",
    Navigation = Source{[Item = "Vendor Origin-Point to State", Kind = "Sheet"]}[Data],
    #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
    #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Supplier IB                                  to     DC/Store Carrier", type text}, {"Residential Delivery Carrier (Hd.com)", type text}, {"Origin Location ID", type text}, {"Origin Facility Name", type text}, {"Origin State", type text}, {"Origin Zip", type text}, {"Origin Country", type text}, {"Destination State", type text}, {"Destination Country", type text}, {"Effective Date", type date}, {"Expiration Date", type date}, {"First Mile Avg Transit Time", Int64.Type}, {"Residential  Delivery   Avg      Transit Time", Int64.Type}}),
    #"Grouped rows" = Table.Group(
    #"Changed column type",
    {"Origin State", "Origin Zip", "Origin Country", "Destination State", "Destination Country"},
        {
            {
                "Avg Transit Time",
                each Number.RoundUp(
                    List.Average([Residential  Delivery   Avg      Transit Time])
                ),
                Int64.Type
            }
        }
    ),
  #"Removed duplicates" = Table.Distinct(#"Grouped rows", {"Origin Zip", "Destination State"})
in
  #"Removed duplicates";
[BindToDefaultDestination = true]
shared #"DIM LTL State to State" = let
    Source = #"CollectLTLRoutingGuide-2026K",
    Navigation = Source{[Item = "State to State", Kind = "Sheet"]}[Data],
    #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
    #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Supplier IB to             DC/Store Carrier", type text}, {"Residential Delivery Carrier (Hd.com)", type text}, {"Origin State", type text}, {"Origin Country", type text}, {"Destination State", type text}, {"Destination Country", type text}, {"Effective Date", type date}, {"Expiration Date", type date}, {"First Mile Avg Transit Time", Int64.Type}, {"Residential  Delivery   Avg      Transit Time", Int64.Type}}),
    #"Grouped rows" = Table.Group(
        #"Changed column type",
        {"Origin State", "Origin Country", "Destination State", "Destination Country"},
        {
            {
                "Avg Delivery Time",
                each Number.RoundUp(
                    List.Average([Residential  Delivery   Avg      Transit Time])
                ),
                Int64.Type
            }
        }
    ),
  #"Removed duplicates" = Table.Distinct(#"Grouped rows", {"Origin State", "Destination State"})
in
  #"Removed duplicates";
