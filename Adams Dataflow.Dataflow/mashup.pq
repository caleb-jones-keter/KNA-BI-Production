[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "AdamsLogisticsMb51_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared AdamsLogisticsMb51 = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  Navigation = Source{[Name = "AdamsMb51Logistics.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Material", Int64.Type}}),
  #"Filtered rows" = Table.SelectRows(#"Changed column type 1", each [Material] < 400000),
  #"Changed column type" = Table.TransformColumnTypes(#"Filtered rows", {{"Plant", type text}, {"Storage Location", type text}, {"Material", type text}, {"Material Description", type text}, {"Material Document", type text}, {"Reference", type text}, {"Order", type text}, {"Quantity", Int64.Type}, {"Movement Type", Int64.Type}, {"Qty in Un. of Entry", Int64.Type}, {"Amount in LC", type number}, {"Purchase Order", type text}, {"Document Header Text", type text}, {"Posting Date", type date}, {"Local Entry Date", type date}, {"Local Entry Time", type datetime}, {"User name", type text}, {"Receiving Stor. Loc.", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "SKU & DESC", each [Material] & " " & [Material Description]), {{"SKU & DESC", type text}})
in
  #"Added custom";
shared AdamsLogisticsMb51_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "AdamsLogisticsMb51", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "AdamsLogisticsME2L_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared AdamsLogisticsME2L = let
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC",
        [ApiVersion = 15]
    ),

    // temp
    Filter = Table.SelectRows(
        Source,
        each Text.Contains([Name], "ME2L")
    ),
    Navigation = Filter{[Name = "AdamME2LLogistics.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
    // Navigation =
    //     Source{
    //         [
    //             Name = "AdamME2LLogistics.XLSX",
    //             #"Folder Path" =
    //                 "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"
    //         ]
    //     }[Content],

    #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
    #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
    #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),

    #"Renamed columns" =
        Table.RenameColumns(
            #"Promoted headers",
            {{"Short Text", "Description"}}
        ),

    #"Filtered rows" =
        Table.SelectRows(
            #"Renamed columns",
            each [Plant] <> null and [Plant] <> ""
        ),

    #"Converted Document Date" =
        Table.TransformColumns(
            #"Filtered rows",
            {
                {
                    "Document Date",
                    each
                        try Date.From(_)
                        otherwise
                        try Date.AddDays(
                            #date(1899,12,30),
                            Number.From(Text.From(_))
                        )
                        otherwise null,
                    type nullable date
                }
            }
        ),

    #"Changed column type" =
        Table.TransformColumnTypes(
            #"Converted Document Date",
            {
                {"Plant", type text},
                {"Vendor/supplying plant", type text},
                {"Purchasing Group", type text},
                {"Purchasing Document", type text},
                {"Item", type text},
                {"Material", type text},
                {"Item Category", type text},
                {"Description", type text},
                {"Net price", type text},
                {"Order Quantity", type text},
                {"Net Order Value", type text},
                {"Still to be delivered (qty)", type text},
                {"Currency", type text},
                {"Still to be invoiced (qty)", type text},
                {"Still to be invoiced (val.)", type text},
                {"Still to be delivered (value)", type text},
                {"Deletion Indicator", type text},
                {"Acct Assignment Cat.", type text},
                {"Stockkeeping unit", type text},
                {"Order Unit", type text},
                {"Release Strategy", type text},
                {"Release status", type text},
                {"Our Reference", type text},
                {"Storage Location", type text},
                {"PO history/release documentation", type text}
            }
        ),

    #"Added custom" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Changed column type",
                "Sku & Desc",
                each [Material] & " " & [Description]
            ),
            {{"Sku & Desc", type text}}
        )

in
    #"Added custom";
shared AdamsLogisticsME2L_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "AdamsLogisticsME2L", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "AdamsMaster_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared AdamsMaster = let
    Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/NAGardenFurniture", [ApiVersion = 15]),
    
    #"Filtered File" = Table.SelectRows(Source, each 
        [Name] = "adams master.xlsx" and 
        Text.Contains([Folder Path], "Shared Documents/09 Warehouse/")
    ),

    Navigation = #"Filtered File"{0}[Content],

    #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),

    #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],

    #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"SAP", type text}, {"Model", type text}, {"Description", type text}, {"Customer", type text}, {"Dept", type text}, {"Customer_1", type text}, {"Vendor #", type text}, {"Carton/Bag#(lf)Qty", type text}, {"Layer Qty", type text}, {"SS/PLT#(lf)Qty", type text}, {"Cont#(lf)Qty", type text}, {"TL Qty", type text}, {"Updated", type text}}),
  
#"Replaced Errors" =
    Table.ReplaceErrorValues(
        #"Changed column type",
        List.Transform(
            Table.ColumnNames(#"Changed column type"),
            each {_, null}
        )
    )



in
    #"Replaced Errors";
shared AdamsMaster_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "AdamsMaster", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
