[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "EDBPlusExcel_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared EDBPlusExcel = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/EDB%20Lag%20Data.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "EDBPlusExcel", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column3", type text}, {"Column4", type text}, {"Column5", type text}, {"Column7", type text}}),
  #"Removed top rows" = Table.Skip(#"Changed column type", 1),
  #"Removed columns" = Table.RemoveColumns(#"Removed top rows", {"Column14"}),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed columns", [PromoteAllScalars = true]),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Promoted headers", {{"Code:SKU Level (c1)", Int64.Type}, {"Months", type text}, {"Code:Payer (c4)", Int64.Type}, {"Lag3 Quantity – (Apo)#(lf)(2025,2026,2027)", Int64.Type}, {"Lag2 Quantity – (Apo)#(lf)(2025,2026,2027)", Int64.Type}, {"Lag1 Quantity – (Apo)#(lf)(2025,2026,2027)", Int64.Type}, {"Committed Demand (APO)#(lf)(2025,2026,2027)", Int64.Type}, {"Committed Gross Sales (APO)#(lf)(2025,2026,2027)", type number}, {"Quantity#(lf)(2025,2026,2027)", Int64.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "MonthStartDate", each #date(
        2000 + Number.FromText(Text.End([Months], 2)),
        Number.FromText(Text.Start([Months], 2)),
        1
    )), {{"MonthStartDate", type date}}),
  #"Replaced value" = Table.ReplaceValue(#"Added custom", null, 0, Replacer.ReplaceValue, {"Lag3 Quantity – (Apo)#(lf)(2025,2026,2027)"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Replaced value", null, 0, Replacer.ReplaceValue, {"Lag2 Quantity – (Apo)#(lf)(2025,2026,2027)"}),
  #"Replaced value 2" = Table.ReplaceValue(#"Replaced value 1", null, 0, Replacer.ReplaceValue, {"Lag1 Quantity – (Apo)#(lf)(2025,2026,2027)"}),
  #"Replaced value 3" = Table.ReplaceValue(#"Replaced value 2", null, 0, Replacer.ReplaceValue, {"Committed Demand (APO)#(lf)(2025,2026,2027)"}),
  #"Replaced value 4" = Table.ReplaceValue(#"Replaced value 3", null, 0, Replacer.ReplaceValue, {"Committed Gross Sales (APO)#(lf)(2025,2026,2027)"}),
  #"Replaced value 5" = Table.ReplaceValue(#"Replaced value 4", null, 0, Replacer.ReplaceValue, {"Quantity#(lf)(2025,2026,2027)"})
in
  #"Replaced value 5";
shared EDBPlusExcel_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "TEST EDB LAG FCST", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
