[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
[BindToDefaultDestination = true]
shared #"FACT Armada LTL History USA" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),
  File =
    Source{
      [
        Name = "Armada_LTL_History.xlsx",
        Folder Path = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/DTC Rates/"
      ]
    }[Content],
  Workbook = Excel.Workbook(File, null, true),
  Export = Workbook{[Item="Export", Kind="Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Export, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Shipment ID", type text}, {"Ship Date", type date}, {"Delivery Date", type datetime}, {"Equipment ", type text}, {"Mode", type text}, {"Weight", type number}, {"Freight Class", type number}, {"Distance", type number}, {"On Time Pickup %", Int64.Type}, {"On Time Delivery %", Int64.Type}, {"Carrier Name", type text}, {"Shipper Name", type text}, {"Shipper Address", type text}, {"Shipper City", type text}, {"Shipper State", type text}, {"Shipper Zip Code", type text}, {"Consignee Name", type text}, {"Consignee City", type text}, {"Consignee State", type text}, {"Consignee Zip Code", type text}, {"Charge Freight", type number}, {"Charge Fuel", type number}, {"Charge Other", type number}, {"Charge Total", type number}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Changed column type", {{"Freight Class", type text}}),

  #"Removed Blank Ship Dates" =
    Table.SelectRows(
        #"Changed column type 1",
        each [Ship Date] <> null and Text.Trim(Text.From([Ship Date])) <> ""
    ),

  #"Removed Canadian Postal Codes" =
    Table.SelectRows(
      #"Removed Blank Ship Dates",
      each
        let
          FirstChar = Text.Start(Text.Trim(Text.From([Shipper Zip Code])), 1)
        in
          Value.Is(Value.FromText(FirstChar), type number)
    ),

  #"Removed Canadian Postal Codes2" =
    Table.SelectRows(
      #"Removed Canadian Postal Codes",
      each
        let
          FirstChar = Text.Start(Text.Trim(Text.From([Consignee Zip Code])), 1)
        in
          Value.Is(Value.FromText(FirstChar), type number)
    ),

  // CJ - 8/17/2026: treat as text fields rather than integer fields.
  // #"Origin Zip3" = Table.TransformColumnTypes(Table.AddColumn(#"Removed Canadian Postal Codes2", "Origin Zip3", each Number.From(Text.Start([#"Shipper Zip Code"], 3))), {{"Origin Zip3", Int64.Type}}),
  // #"Dest Zip3" = Table.TransformColumnTypes(Table.AddColumn(#"Origin Zip3", "Dest Zip3", each Number.From(Text.Start([#"Consignee Zip Code"], 3))), {{"Dest Zip3", Int64.Type}})
  #"Origin Zip3" =
    Table.TransformColumnTypes(
        Table.AddColumn(
            #"Removed Canadian Postal Codes2",
            "Origin Zip3",
            each Text.Start(Text.From([#"Shipper Zip Code"]), 3),
            type text
        ),
        {{"Origin Zip3", type text}}
    ),

  #"Dest Zip3" =
    Table.TransformColumnTypes(
        Table.AddColumn(
            #"Origin Zip3",
            "Dest Zip3",
            each Text.Start(Text.From([#"Consignee Zip Code"]), 3),
            type text
        ),
        {{"Dest Zip3", type text}}
    )

in
  #"Dest Zip3";
