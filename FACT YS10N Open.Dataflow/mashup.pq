[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"FACT YS10N Open" = // New Code (updated to pull from Lake House)
let
    Source = #"YS10N Open Orders Daily Pull",
    #"Added MRP Area" = Table.AddColumn(Source, "MRP Area", each let
    CurrStLoc = [Storage Location],
    Plant = [Plant]
        in
            if Plant = "60" then "60 - USL-Stanley"
                else if Plant = "62" then "62_362B - Bramli"
                else if Plant = "65" then "65 - HDP-Anderson"
                else if Plant = "66" then "66 - MILTON"
                else if Plant = "73" then "73 - Adams"
                else
                    if CurrStLoc = null or CurrStLoc = "" then
                        if Plant = "69" then "69 - NA - Canada - Import"
                        else "67 - KNA LLC"
                    else if List.Contains({"369C","369P","369T","705","369W", "369H"}, CurrStLoc) then // 369W for weird milton transient loads for costco
                    "69_369T - OEL Overseas - 2"
                    else if List.Contains({"467C","467N","4674","467P","467O","4672","367M","4673","467Q","367J"}, CurrStLoc) then "67_4674 - DHL"
                    else if List.Contains({"367B","367A","367I","367D"}, CurrStLoc) then "67_367 - KNA- Spreetail"
                    else if List.Contains({"367G","367C"}, CurrStLoc) then "67_367G - Globe 18301 Bro"
                    else if CurrStLoc = "X67X" then "67 - KNA LLC"
                    else if CurrStLoc = "X69X" then "69 - NA - Canada - Import"
                    else "Unknown"
    ),
    #"Added MRP + SKU Key" = Table.AddColumn(#"Added MRP Area", "MRPSKU Key", each [MRP Area]&"|"&[Material]),
    #"Added Data Source ID" = Table.AddColumn(#"Added MRP + SKU Key", "Data Source", each "YS10N"),
    #"Added ""Remaining""" = Table.AddColumn(#"Added Data Source ID", "Remaining?", each "Yes"),
    #"Removed Columns" = Table.RemoveColumns(#"Added ""Remaining""",{"Material description MM"}),
    #"Today Dynamic" = Table.AddColumn(#"Removed Columns", "Today", each DateTime.LocalNow(), type date),
    #"Changed Type" = Table.TransformColumnTypes(#"Today Dynamic", {{"Sales Organization", Int64.Type}, {"Plant", Int64.Type}, {"Shipping Point/Receiving Pt", type text}, {"Storage Location", type text}, {"Payer", type text}, {"Payer name", type text}, {"Reason for rejection", Int64.Type}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, {"Sales Order", Int64.Type}, {"Delivery", type text}, {"Shipment Number", type text}, {"Shipping type", type text}, {"Material", Int64.Type}, {"Customer SKU", type text}, {"Order Qty", Int64.Type}, {"Net value", type number}, {"SO Created Date", type date}, {"Delivery Creation Date", type any}, {"First Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Ship-To Party Region", type text}, {"Planning end", type any}, {"Planned date CheckIn", type any}, {"Planned time CheckIn", type datetime}, {"Trailer No", type text}, {"Planned shipment end", type any}, {"Load Delay Reason", type text}, {"Act. Gds Mvmnt Date", type any}, {"Invoice Billing Date", type any}, {"Profit Center", Int64.Type}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Load No.", type text}, {"Ship-To Zip", type text}, {"Spare Part Indicator", type text}, {"Today", type date}}),
    #"Multiplied Column" = Table.TransformColumns(#"Changed Type", {{"Order Qty", each _ * -1, type number}}),
    #"Duplicated column" = Table.DuplicateColumn(#"Multiplied Column", "First Date", "SOW"),
    #"Duplicated column 1" = Table.DuplicateColumn(#"Duplicated column", "Today", "Today SOW"),
    #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
    #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Calculated Start of Week Today", {{"Order Qty", "Combined Qty"}, {"SO Billing Date", "Combined Date"}}),
    #"PayerMRPSKUSOW" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed Columns", "PayerMRPSKUSOW", each [Payer] & "|" & [MRPSKU Key] & "|" & Date.ToText([SOW])), {{"PayerMRPSKUSOW", type text}}),
    #"Changed column type" = Table.TransformColumnTypes(#"PayerMRPSKUSOW", {{"MRP Area", type text}, {"Remaining?", type text}, {"Data Source", type text}, {"MRPSKU Key", type text}, {"Ship-To Party", type text}, {"Sales Document Item", type text}, {"Delivery Creation Date", type date}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned shipment end", type date}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Sales Order", type text}}),
    #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "SalesOrderItem", each [Sales Order] & [Sales Document Item]), {{"SalesOrderItem", type text}}),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom 1", {{"Plant", type text}, {"Material", type text}}),
    #"Merged queries 1" = Table.NestedJoin(#"Changed column type 1", {"Payer"}, #"Payer Types", {"Payer"}, "Payer Types", JoinKind.LeftOuter),
    #"Expanded Payer Types" = Table.ExpandTableColumn(#"Merged queries 1", "Payer Types", {"Detail", "Type", "TypeKey"}, {"Payer Types.Detail", "Payer Types.Type", "Payer Types.TypeKey"}),
    #"Merged queries" = Table.NestedJoin(#"Expanded Payer Types", {"Payer"}, #"DIM IBP Customer", {"Payer Key"}, "DIM IBP Customer", JoinKind.LeftOuter),
    #"Expanded DIM IBP Customer" = Table.ExpandTableColumn(#"Merged queries", "DIM IBP Customer", {"IBP Customer Code"}, {"IBP Customer Code"}),
    #"IBP_PayerMrpSkuSow" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DIM IBP Customer", "IBP_PayerMrpSkuSow", each [IBP Customer Code] & "|" & [MRPSKU Key] & "|" & Date.ToText([SOW])), {{"IBP_PayerMrpSkuSow", type text}})
in
    #"IBP_PayerMrpSkuSow"

// Old Code

// let
//     Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/YS10N%20Open%20Orders%20Daily%20Pull.xlsx"), null, true),
//     Sheet1_Sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
//     #"Promoted Headers" = Table.PromoteHeaders(Sheet1_Sheet, [PromoteAllScalars=true]),
//     #"Filtered Rows" = Table.SelectRows(#"Promoted Headers", each ([Reason for rejection] = "")),
//     #"Added MRP Area" = Table.AddColumn(#"Filtered Rows", "MRP Area", each let
//     CurrStLoc = [Storage Location],
//     Plant = [Plant]
//         in
//             if Plant = "60" then "60 - USL-Stanley"
//             else if Plant = "62" then "62_362B - Bramli"
//             else if Plant = "65" then "65 - HDP-Anderson"
//             else if Plant = "66" then "66 - MILTON"
//             else if Plant = "73" then "73 - Adams"
//             else
//                 if CurrStLoc = null or CurrStLoc = "" then
//                     if Plant = "69" then "69 - NA - Canada - Import"
//                     else "67 - KNA LLC"
//                 else if List.Contains({"369C","369P","369T","705","369W", "369H"}, CurrStLoc) then // 369W for weird milton transient loads for costco
//                     "69_369T - OEL Overseas - 2"
//                 else if List.Contains({"467C","467N","4674","467P","467O","4672","367M","4673","467Q","367J"}, CurrStLoc) then "67_4674 - DHL"
//                 else if List.Contains({"367B","367A","367I","367D"}, CurrStLoc) then "67_367 - KNA- Spreetail"
//                 else if List.Contains({"367G","367C"}, CurrStLoc) then "67_367G - Globe 18301 Bro"
//                 else if CurrStLoc = "X67X" then "67 - KNA LLC"
//                 else if CurrStLoc = "X69X" then "69 - NA - Canada - Import"
//                 else "Unknown"
//     ),
//     #"Added MRP + SKU Key" = Table.AddColumn(#"Added MRP Area", "MRPSKU Key", each [MRP Area]&"|"&[Material]),
//     #"Added Data Source ID" = Table.AddColumn(#"Added MRP + SKU Key", "Data Source", each "YS10N"),
//     #"Added ""Remaining""" = Table.AddColumn(#"Added Data Source ID", "Remaining?", each "Yes"),
//     #"Removed Columns" = Table.RemoveColumns(#"Added ""Remaining""",{"Material description MM"}),
//     #"Today Dynamic" = Table.AddColumn(#"Removed Columns", "Today", each DateTime.LocalNow(), type date),
//     #"Changed Type" = Table.TransformColumnTypes(#"Today Dynamic", {{"Sales Organization", Int64.Type}, {"Plant", Int64.Type}, {"Shipping Point/Receiving Pt", type text}, {"Storage Location", type text}, {"Payer", type text}, {"Payer name", type text}, {"Reason for rejection", Int64.Type}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, {"Sales Order", Int64.Type}, {"Delivery", type text}, {"Shipment Number", type text}, {"Shipping type", type text}, {"Material", Int64.Type}, {"Customer SKU", type text}, {"Order Qty", Int64.Type}, {"Net value", type number}, {"SO Created Date", type date}, {"Delivery Creation Date", type any}, {"First Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Ship-To Party Region", type text}, {"Planning end", type any}, {"Planned date CheckIn", type any}, {"Planned time CheckIn", type datetime}, {"Trailer No.", type text}, {"Planned shipment end", type any}, {"Load Delay Reason", type text}, {"Act. Gds Mvmnt Date", type any}, {"Invoice Billing Date", type any}, {"Profit Center", Int64.Type}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Load No.", type text}, {"Ship-To Zip", type text}, {"Spare Part Indicator", type text}, {"Today", type date}}),
//     #"Multiplied Column" = Table.TransformColumns(#"Changed Type", {{"Order Qty", each _ * -1, type number}}),
//   #"Duplicated column" = Table.DuplicateColumn(#"Multiplied Column", "First Date", "SOW"),
//   #"Duplicated column 1" = Table.DuplicateColumn(#"Duplicated column", "Today", "Today SOW"),
//     #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
//     #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
//     #"Renamed Columns" = Table.RenameColumns(#"Calculated Start of Week Today", {{"Order Qty", "Combined Qty"}, {"SO Billing Date", "Combined Date"}}),
//   #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed Columns", "PayerMRPSKUSOW", each [Payer] & "|" & [MRPSKU Key] & "|" & Date.ToText([SOW])), {{"PayerMRPSKUSOW", type text}}),
//   #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"MRP Area", type text}, {"Remaining?", type text}, {"Data Source", type text}, {"MRPSKU Key", type text}, {"Ship-To Party", type text}, {"Sales Document Item", type text}, {"Delivery Creation Date", type date}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned shipment end", type date}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Sales Order", type text}}),
//   #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "SalesOrderItem", each [Sales Order] & [Sales Document Item]), {{"SalesOrderItem", type text}}),
//   #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom 1", {{"Plant", type text}, {"Material", type text}}),
//   #"Merged queries 1" = Table.NestedJoin(#"Changed column type 1", {"Payer"}, #"Payer Types", {"Payer"}, "Payer Types", JoinKind.LeftOuter),
//   #"Expanded Payer Types" = Table.ExpandTableColumn(#"Merged queries 1", "Payer Types", {"Detail", "Type", "TypeKey"}, {"Payer Types.Detail", "Payer Types.Type", "Payer Types.TypeKey"})
// in
//     #"Expanded Payer Types"
;
shared DefaultDestination = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"Payer Types" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "Payer Types", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"YS10N Open Orders Daily Pull" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "YS10N Open Orders Daily Pull", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"DIM IBP Customer" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM IBP Customer", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
