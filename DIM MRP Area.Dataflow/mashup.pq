[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
[BindToDefaultDestination = true]
shared #"DIM MRP Area" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("XZBda8IwFIb/Sui1gX6ZrJe1blUWbSHuSoqcrcEF2kTaIvjvd4KB1d4l7/PkPYeczwELCSVfUlA5genUI1hhFDQrJPElYfEG8WaAvtOOxE+yxnC3rWluWjWM1ji0fiKG6LAXp+roQubDS8qYdE3wIMJe9Tjpn3EmcGSfx5wIUbiU+xQX8IQSeRuUmkB3S6FEo+zstyLRWxJGuK1dKsLXS7iDMfBL6kIsHekHlcoOVw2ktsP04qSMp+hsd2IZF/4pttIojGc4Q4JzKSnAQAt42Pc3X5x5BYdnruHjoF//Zi6cUKjeBanu+OEKRrzG/w5P8J630Lt3PAma5g8=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [#"MRP Area (Edb)" = _t, Plant = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"MRP Area (Edb)", type text}, {"Plant", Int64.Type}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"MRP Area (Edb)", "MRP Area"}}),
    #"Added Imports Conditional" = Table.AddColumn(#"Renamed Columns", "Imports", each if [MRP Area] = "67_367G - Globe 18301 Bro" then "Yes" 
else if [MRP Area] = "67 - KNA LLC" then "Yes" 
else if [MRP Area] = "67_4674 - DHL" then "Yes" 
else if [MRP Area] = "69 - NA - Canada - Import" then "Yes"
else if [MRP Area] = "67_467C - KNA-PCL-102" then "Yes" 
else if [MRP Area] = "69_369C - FMi Logistics" then "Yes" 
else if [MRP Area] = "69_369T - OEL Overseas - 2" then "Yes" 
else if [MRP Area] = "67_367 - KNA- Spreetail" then "Yes"
else "No"),
    #"Sorted Rows" = Table.Sort(#"Added Imports Conditional",{{"Plant", Order.Ascending}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Sorted Rows", {{"Imports", type text}, {"Plant", type text}})
in
    #"Changed column type";
