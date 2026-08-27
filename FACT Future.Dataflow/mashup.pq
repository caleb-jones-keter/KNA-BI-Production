[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"FACT Forecast Adjusted" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT Forecast Adjusted", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"FACT YM6P" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT YM6P", ItemKind = "Table"]}[Data],
  
   #"Sorted rows" = Table.Sort(#"Navigation 2", {{"Material", Order.Ascending},{"MRP Area", Order.Ascending},{"CalcArravDate", Order.Ascending}, {"PO Number", Order.Ascending}  }),
 
  #"Grouped rows" = Table.Group(
    #"Sorted rows",
    {"Material", "MRP Area","Storage Location Orig"},
    {
        {"Data", each 
            let
                sortedTable = Table.Sort(_, {{"CalcArravDate", Order.Ascending}, {"PO Number", Order.Ascending}}),
                indexedTable = Table.AddIndexColumn(sortedTable, "OrderIndex", 1, 1, Int64.Type)
            in
                indexedTable
        }
    }
),
  #"Expanded Data" = Table.ExpandTableColumn(#"Grouped rows", "Data", {"PO Number", "Plant", "Purchasing Group", "Storage Location Orig", "Purchase Order Date", "AASalOrd", "Supplier", "Item", "Material", "Material Description", "Order Quantity", "Net Order Value", "Sales document", "ReqDelivDate", "Confirm. Category", "ConfirmDelvDate", "GR Processing Time", "LA Date", "CalcArravDate", "Delivery", "Billing Document", "Container", "Inb.delivery", "Entry Port", "VesselName", "First GR date for item", "Deletion Indicator", "Ship-to party's purchase order no_", "Ship-to party", "Billing Date", "MRP Area", "MRPSKU Key", "Ship Date", "Today", "Days to Port", "Data Source", "Combined Date", "Combined Qty", "Remaining?", "Storage Type", "DTP Group", "Storage Location", "Today SOW", "SOW", "PO | Container", "EnfoPak _MrrContainers_.booking_number", "EnfoPak _MrrContainers_.carrier_name", "EnfoPak _MrrContainers_.eta_date", "EnfoPak _MrrContainers_.ship_to", "EnfoPak _MrrContainers_.vessel_name", "EnfoPak _MrrContainers_.voyage_number", "EnfoPak _MrrContainers_.bl_number", "_MrrContainers_.status", "OrderIndex","Billing Date Supply Order"}, {"PO Number", "Plant", "Purchasing Group", "Storage Location Orig.1", "Purchase Order Date", "AASalOrd", "Supplier", "Item", "Material.1", "Material Description", "Order Quantity", "Net Order Value", "Sales document", "ReqDelivDate", "Confirm. Category", "ConfirmDelvDate", "GR Processing Time", "LA Date", "CalcArravDate", "Delivery", "Billing Document", "Container", "Inb.delivery", "Entry Port", "VesselName", "First GR date for item", "Deletion Indicator", "Ship-to party's purchase order no_", "Ship-to party", "Billing Date", "MRP Area.1", "MRPSKU Key", "Ship Date", "Today", "Days to Port", "Data Source", "Combined Date", "Combined Qty", "Remaining?", "Storage Type", "DTP Group", "Storage Location", "Today SOW", "SOW", "PO | Container", "EnfoPak _MrrContainers_.booking_number", "EnfoPak _MrrContainers_.carrier_name", "EnfoPak _MrrContainers_.eta_date", "EnfoPak _MrrContainers_.ship_to", "EnfoPak _MrrContainers_.vessel_name", "EnfoPak _MrrContainers_.voyage_number", "EnfoPak _MrrContainers_.bl_number", "_MrrContainers_.status", "OrderIndex","Billing Date Supply Order"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded Data", "Material-MRP Area-OrderIndex (YM6p)", each [Material] & "-" & [#"MRP Area"]& "-" & [Storage Location Orig] &"-" & Number.ToText([OrderIndex])), {{"Material-MRP Area-OrderIndex (YM6p)", type text}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"PO Number", type text}, {"Plant", Int64.Type}, {"Purchasing Group", type text}, {"Storage Location Orig", type text}, {"Purchase Order Date", type date}, {"AASalOrd", type text}, {"Supplier", Int64.Type}, {"Item", Int64.Type}, {"Material", type text}, {"Material Description", type text}, {"Order Quantity", Int64.Type}, {"Net Order Value", type number}, {"Sales document", Int64.Type}, {"ReqDelivDate", type date}, {"Confirm. Category", type text}, {"ConfirmDelvDate", type date}, {"GR Processing Time", Int64.Type}, {"LA Date", type date}, {"CalcArravDate", type date}, {"Delivery", Int64.Type}, {"Billing Document", Int64.Type}, {"Container", type text}, {"Inb.delivery", Int64.Type}, {"Entry Port", type text}, {"VesselName", type text}, {"First GR date for item", type date}, {"Deletion Indicator", type text}, {"Today", type date}, {"Data Source", type text}, {"Combined Date", type date}, {"Combined Qty", Int64.Type}, {"Remaining?", type text}, {"Storage Type", type text}, {"DTP Group", type text}, {"Storage Location", type text}, {"Ship-to party", type text}, {"Ship Date", type date}, {"Days to Port", Int64.Type}, {"MRPSKU Key", type text}, {"MRP Area", type text}, {"SOW", type date}, {"Today SOW", type date}, {"Material.1", type text}, {"MRP Area.1", type text}, {"Ship-to party's purchase order no_", type text}, {"OrderIndex", type text}}),
  #"Sailed/Pending/Other" = Table.AddColumn(#"Changed column type", "Sailed/Pending/Other", each if [#"LA Date"] <> null and [#"LA Date"] <> "" then "Sailed"
            else if [Container] <> null and [Container] <> "" then "Pending Shipment"
            else if [#"Confirm. Category"] = "AB" then "Pending Keter"
            else "Open/Other"),
  #"Early/Late/On Time Costco" = Table.TransformColumnTypes(
        Table.AddColumn(#"Sailed/Pending/Other", "Early/LateDirectPO", each 
            let
                CalcArravDate = try Date.From([CalcArravDate]) otherwise null,
                RequestedDelivDate = try Date.From([#"ReqDelivDate"]) otherwise null,
                Diff = if CalcArravDate = null or RequestedDelivDate = null then null else Duration.Days(CalcArravDate - RequestedDelivDate)
            in
                if Diff = null then "N/A"
                else if Diff > 7 then "Late"
                else if Diff < -7 then "Early"
                else "On Time"
        ),
        {{"Early/LateDirectPO", type text}}
    ),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Early/Late/On Time Costco", {{"Sailed/Pending/Other", type text}, {"Storage Location Orig.1", type text}, {"Billing Date", type text}, {"PO | Container", type text}, {"EnfoPak _MrrContainers_.booking_number", type text}, {"EnfoPak _MrrContainers_.carrier_name", type text}, {"EnfoPak _MrrContainers_.eta_date", type text}, {"EnfoPak _MrrContainers_.ship_to", type text}, {"EnfoPak _MrrContainers_.vessel_name", type text}, {"EnfoPak _MrrContainers_.voyage_number", type text}, {"EnfoPak _MrrContainers_.bl_number", type text}, {"_MrrContainers_.status", type text}})

in
  #"Changed column type 1";
shared #"FACT YS10N Open" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT YS10N Open", ItemKind = "Table"]}[Data],
  #"Sorted rows" = Table.Sort(#"Navigation 3", {{"Material", Order.Ascending},{"MRP Area", Order.Ascending},{"Requested deliv.date", Order.Ascending} }),
  #"Added custom 1" = Table.AddColumn(#"Sorted rows", "Has Delivery", each if [Delivery] <> "" then "Yes" else "No"),
 
 #"Grouped rows" =
    Table.Group(
        #"Added custom 1",
        {"Material", "MRP Area", "Storage Location", "Has Delivery"},
        {
            {"Data", each
                let
                    SortedTable = Table.Sort(_, {{"Requested deliv.date", Order.Ascending}}),
                    IndexedTable = Table.AddIndexColumn(SortedTable, "OrderIndex", 1, 1, Int64.Type),
                    OffsetTable = Table.AddColumn(
                        IndexedTable,
                        "AdjustedOrderIndex",
                        each if [Planned Delivery Date] <> null then [OrderIndex] + 1 else [OrderIndex],
                        Int64.Type
                    )
                in
                    OffsetTable
            }
        }
    )
,
  #"Expanded Data" = Table.ExpandTableColumn(#"Grouped rows", "Data", {
        "Material","IBP Customer Code", "Payer", "MRP Area", "Today", "Today SOW", "Remaining?", "Combined Date", "Data Source", "Combined Qty", "MRPSKU Key", "Sales Organization", "Plant", "SOW", "Shipping Point/Receiving Pt", "Payer name", "Reason for rejection", "Reason for rejection description", "Order reason", "Order reason_1", "PO Number", "Sales Order", "Delivery", "Shipment Number", "Shipping type", "Customer SKU", "Net value", "SO Created Date", "Delivery Creation Date", "Confirmation Date", "Requested deliv.date", "Guarantee Date", "Original Delivery Date", "SO Billing Date", "Ship-To Party Region", "Planning end", "Planned date CheckIn", "Planned time CheckIn", "Trailer No", "Planned shipment end", "Load Delay Reason", "Act. Gds Mvmnt Date", "Invoice Billing Date", "Profit Center", "Carrier SCAC code", "Carrier Name", "Carrier Code", "Carrier Service", "Load No_", "Ship-To Zip", "Spare Part Indicator", "Ship-To Party", "Sales Document Item","IBP_PayerMrpSkuSow", "PayerMRPSKUSOW", "Confirm. Category", "LA Date", "CalcArravDate", "Container", "Entry Port", "VesselName", "Ship Date", "SalesOrderItem", "OrderIndex", "Payer Types.Detail", "Payer Types.Type", "Payer Types.TypeKey"
    }, 
  
    {
        "Material.1", "IBP Customer Code", "Payer", "MRP Area.1", "Today", "Today SOW", "Remaining?", "Combined Date", "Data Source", "Combined Qty", "MRPSKU Key", "Sales Organization", "Plant", "SOW", "Shipping Point/Receiving Pt", "Payer name", "Reason for rejection", "Reason for rejection description", "Order reason", "Order reason_1", "PO Number", "Sales Order", "Delivery", "Shipment Number", "Shipping type", "Customer SKU", "Net value", "SO Created Date", "Delivery Creation Date", "Confirmation Date", "Requested deliv.date", "Guarantee Date", "Original Delivery Date", "SO Billing Date", "Ship-To Party Region", "Planning end", "Planned date CheckIn", "Planned time CheckIn", "Trailer No", "Planned shipment end", "Load Delay Reason", "Act. Gds Mvmnt Date", "Invoice Billing Date", "Profit Center", "Carrier SCAC code", "Carrier Name", "Carrier Code", "Carrier Service", "Load No_", "Ship-To Zip", "Spare Part Indicator", "Ship-To Party", "Sales Document Item","IBP_PayerMrpSkuSow", "PayerMRPSKUSOW", "Confirm. Category", "LA Date", "CalcArravDate", "Container", "Entry Port", "VesselName", "Ship Date", "SalesOrderItem", "OrderIndex", "Payer Types.Detail", "Payer Types.Type", "Payer Types.TypeKey"
    }
  ),

 #"Added custom" =
    Table.TransformColumnTypes(
        Table.AddColumn(
            #"Expanded Data",
            "Material-MRP Area-OrderIndex (YS10N)",
            each if [Has Delivery] = "No"
                then Text.From([Material]) & "-" & [MRP Area] & "-" & [Storage Location] & "-" & Text.From([OrderIndex])
                else null,
            type text
        ),
        {{"Material-MRP Area-OrderIndex (YS10N)", type text}}
    )

  ,
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"Material", type text}, {"Material.1", type text}, {"Payer", type text}, {"MRP Area.1", type text}, {"Today", type date}, {"Today SOW", type date}, {"Combined Date", type date}, {"Remaining?", type text}, {"Data Source", type text}, {"Combined Qty", Int64.Type}, {"MRPSKU Key", type text}, {"Sales Organization", type text}, {"Plant", type text}, {"Storage Location", type text}, {"SOW", type date}, {"Shipping Point/Receiving Pt", type text}, {"Payer name", type text}, {"Reason for rejection", type text}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, {"Sales Order", type text}, {"Delivery", type text}, {"Shipment Number", type text}, {"Shipping type", type text}, {"Customer SKU", type text}, {"Net value", Currency.Type}, {"SO Created Date", type date}, {"Delivery Creation Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Ship-To Party Region", type text}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned time CheckIn", type datetime}, {"Trailer No", type text}, {"Planned shipment end", type date}, {"Load Delay Reason", type text}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Profit Center", type text}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Load No_", type text}, {"Ship-To Zip", type text}, {"Spare Part Indicator", type text}, {"Ship-To Party", type text}, {"Sales Document Item", type text}, {"PayerMRPSKUSOW", type text}, {"Confirm. Category", type text}, {"LA Date", type date}, {"CalcArravDate", type date}, {"Container", type text}, {"Entry Port", type text}, {"VesselName", type text}, {"SalesOrderItem", type text}, {"OrderIndex", type text}, {"Ship Date", type date}, {"Payer Types.Type", type text}, {"Payer Types.Detail", type text}, {"Payer Types.TypeKey", Int64.Type}, {"IBP Customer Code", type text}, {"IBP_PayerMrpSkuSow", type text}}),
  #"Merged queries" = Table.NestedJoin(#"Changed column type", {"Material-MRP Area-OrderIndex (YS10N)"}, #"FACT YM6P", {"Material-MRP Area-OrderIndex (YM6p)"}, "FACT YM6P", JoinKind.LeftOuter),
  #"Expanded FACT YM6P" = Table.ExpandTableColumn(#"Merged queries", "FACT YM6P", {"Storage Location", "PO Number", "CalcArravDate", "Container","Material-MRP Area-OrderIndex (YM6p)","Sailed/Pending/Other","Early/LateDirectPO", "ConfirmDelvDate"}, {"FACT YM6P.Storage Location", "FACT YM6P.PO Number", "FACT YM6P.CalcArravDate", "Fact YM6P.Container", "Fact Ym6P.Material-MRP Area-OrderIndex (YM6p)","Sailed/Pending/Other","Early/LateDirectPO", "Fact Ym6P.ConfirmDelvDate"}),
  
  #"Changed column type final" = Table.TransformColumnTypes(#"Expanded FACT YM6P", {{"Sales Organization", Int64.Type}, {"Plant", type text}, {"Shipping Point/Receiving Pt", type text}, {"Storage Location", type text}, {"Payer", type text}, {"Payer name", type text}, {"Reason for rejection", Int64.Type}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Order reason_1", type text}, {"PO Number", type text}, {"Sales Order", type text}, {"Delivery", type text}, {"Shipment Number", type text}, {"Shipping type", type text}, {"Material", Int64.Type}, {"Customer SKU", type text}, {"Combined Qty", type number}, {"Net value", type number}, {"SO Created Date", type date}, {"Delivery Creation Date", type date}, {"Combined Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Ship-To Party Region", type text}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned time CheckIn", type datetime}, {"Planned shipment end", type date}, {"Load Delay Reason", type text}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Profit Center", Int64.Type}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Ship-To Zip", type text}, {"Spare Part Indicator", type text}, {"Today", type date}, {"Today SOW", type date}, {"SOW", type date}, {"MRP Area", type text}, {"Remaining?", type text}, {"Data Source", type text}, {"MRPSKU Key", type text}, {"Ship-To Party", type text}, {"Sales Document Item", type text}, {"PayerMRPSKUSOW", type text}, {"Confirm. Category", type text}, {"LA Date", type date}, {"CalcArravDate", type date}, {"Container", type text}, {"Entry Port", type text}, {"VesselName", type text}, {"Ship Date", type date}, {"SalesOrderItem", type text}, {"Has Delivery", type text}}),
    #"Added custom 2" = Table.AddColumn(#"Changed column type final", "Factory PO", each if [Has Delivery] = "Yes" then "Arrived" else [FACT YM6P.PO Number]),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Earliest Arrival Date", each if [Factory PO] = "Arrived" then [Today] else [FACT YM6P.CalcArravDate]), {{"Earliest Arrival Date", type date}}),
  #"Added custom 4" = Table.AddColumn(#"Added custom 3", "Order Status MTO", each if [Factory PO] = "Arrived" then "Arrived" else [#"Sailed/Pending/Other"]),
  #"Added custom 5" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 4", "On Time Status", each let
            earlyLate = [#"Early/LateDirectPO"],
            earliestArrival = try Date.From([#"Earliest Arrival Date"]) otherwise null,
            requestedDelivery = try Date.From([#"Requested deliv.date"]) otherwise null,
            dayDiff = if earliestArrival <> null and requestedDelivery <> null then Duration.Days(earliestArrival - requestedDelivery) else null
        in
            if Text.Trim(earlyLate) <> "" then
                earlyLate
            else if dayDiff = null then
                null
            else if Number.Abs(dayDiff) <= 7 then
                "On Time"
            else if dayDiff < -7 then
                "Early"
            else if dayDiff > 7 then
                "Late"
            else
                null), {{"On Time Status", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Added custom 5", {{"PayerMRPSKUSOW", "PayerMrpSkuSow"}})

in

#"Renamed columns";
[BindToDefaultDestination = true]
shared #"FACT Future" = let//Combined all tables
  Source3 = Table.Combine({ #"FACT Forecast Adjusted", #"FACT YM6P", #"FACT YS10N Open",#"FACT MB52"}),
  #"Filter rows" = Table.SelectRows(
    Source3,
    each if ([Data Source] = "YM6P" or [Data Source] = "YS10N") 
         then true 
         else [SOW] >= [Today SOW]
    ),
  #"Renamed columns" = Table.RenameColumns(#"Filter rows", {{"Combined Date", "Combined Date 1"}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns", "Combined Date", each if [Today] > [Combined Date 1] then [Today] else [Combined Date 1]), {{"Combined Date", type date}}),
  #"Sorted Rows3" = Table.Sort(#"Added custom",{{"MRPSKU Key", Order.Ascending}, {"Storage Location", Order.Ascending},{"Combined Date", Order.Ascending}}),

  // 3. Group by MRPSKU Key (no global sort)
  // CJ 8/26/2026: removes hard-coded column list and allows new columns such as IBP Customer Code to flow through
  Grouped =
    Table.Group(
        #"Sorted Rows3",
        {"MRPSKU Key"},
        {
            {"Details", each _, type table}
        }
    ),
  // Grouped = 
  //   Table.Group(
  //     #"Sorted Rows3", {"MRPSKU Key"}, {
  //       {"Details", each _, type table [
  //         Payer=nullable text, Sales Organization=nullable text, MRPSKU Key=nullable text, Combined Date=nullable date, Today=nullable date, Storage Location=nullable text, Data Source=nullable text, BOM Type=nullable text, PayerMrpSkuSow=nullable text, Material=nullable text, MRP Area=nullable text, Combined Qty=number, PO=nullable number, Purchase Order Date=nullable date, Order Quantity=nullable number, Net Order Value=nullable number, Sales document=nullable number, Container=nullable text, Inb.delivery=nullable number, Entry Port=nullable text, VesselName=nullable text, Days to Port=any, #"Remaining?"=nullable text, Storage Type=nullable text, DTP Group=nullable text, #"Shipping Point/Receiving Pt"=nullable text, PO Number=nullable text, Sales Order=nullable number, Delivery=nullable text, Shipment Number=nullable text, Customer SKU=nullable text, Net value=nullable number, DIM Dates.SOW=nullable date, Blocked_Qty=nullable text, Stock_Value=nullable text, SOW=nullable date, Quantity=nullable number, Days in Country=nullable number, Days In Place=nullable number, Reception Date=nullable date, Expected PGR=nullable date, Customer=nullable number, MrpSkuDate Key=nullable text, #"DIM Dates.Future?"=nullable text
  //       ]}
  //     }
  //   ),
  
  // 4. Apply running total, lost sales, running max, and inventory inside each group
  #"Adj Combined Qty Start" = Table.TransformColumns(
    Grouped,
      {
        "Details",
          each
            let
              // Sort inside each group
              Sorted = Table.Sort(_, {{"Combined Date", Order.Ascending}, {"Combined Qty", Order.Descending}}),

              // Buffer values for faster iteration
              QtyList = List.Buffer(Table.Column(Sorted, "Combined Qty")),

              // Running total using List.Accumulate
              RTList = List.Accumulate(QtyList, {}, (state, current) => state & { (List.Last(state, 0) ?? 0) + current }),

              // Previous running total list
              PrevRTList = {0} & List.RemoveLastN(RTList, 1),

              // Add index for mapping
              WithRTIndex = Table.AddIndexColumn(Sorted, "RT_Index", 0, 1, Int64.Type),

              // Add Running Total column
              WithRTCol = Table.AddColumn(WithRTIndex, "Running Total", each RTList{[RT_Index]}),

              // Lost Sales (cumulative)
              WithLostSales = Table.AddColumn(WithRTCol, "Lost Sales", each if [Running Total] < 0 then -[Running Total] else 0),

              // Running Max on Lost Sales
              LostList = List.Buffer(Table.Column(WithLostSales, "Lost Sales")),
              RMList = List.Accumulate(LostList, {}, (state, current) => state & { List.Max({ List.Last(state, 0) ?? current, current }) }),

              WithRMCol = Table.AddColumn(WithLostSales, "Running Max", each RMList{[RT_Index]}),

              // Inventory
              WithInv = Table.AddColumn(WithRMCol, "Inv", each [Running Total] + [Running Max]),

              //Test
              PrevRMList = {0} & List.RemoveLastN(RMList, 1),
              WithPrevInv = Table.AddColumn(WithInv, "PrevInv", each PrevRTList{[RT_Index]} + PrevRMList{[RT_Index]}),

              // Qty not counted toward inventory 
              WithQtyNotInInv = Table.AddColumn(
                WithPrevInv,
                "Qty Not In Inv",
                each 
                  if [PrevInv] + [Combined Qty] < 0 then -[PrevInv] + -[Combined Qty] 
                  else 0
              ),

                // Remove helper index and duplicate MRPSKU Key
                WithoutKey = Table.RemoveColumns(WithQtyNotInInv, {"RT_Index", "MRPSKU Key"})
            in
                WithoutKey
        }
  ),

  // 5. Expand all columns once (no duplicate MRPSKU Key error now)
  ExpandedAll = Table.ExpandTableColumn(
      #"Adj Combined Qty Start",
      "Details",
      Table.ColumnNames(#"Adj Combined Qty Start"{0}[Details])
  ),
  #"Changed column type 2" = Table.TransformColumnTypes(ExpandedAll, {{"Material", type text}}),

  // 6. Join to DIM Product
  MergedProduct = Table.NestedJoin(#"Changed column type 2", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(MergedProduct, "DIM Product", {"Cont_Qty", "TL Qty"}, {"Cont_Qty", "TL Qty"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Expanded DIM Product", {{"Combined Qty", "Combined Qty 2"}}),
  #"Changed column type 5" = Table.TransformColumnTypes(#"Renamed columns 1", {{"Payer Types.Detail", type text}, {"Payer Types.Type", type text}, {"Payer Types.TypeKey", type text}}),
  #"Adjusted Combined Qty" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 5", "Combined Qty", 
    each 
      if [Data Source] = "YS10N" and ([Payer Types.TypeKey] = "1" or [Payer Types.TypeKey] = "2") then [Combined Qty 2] //if you're special, you can go negative
      else [Combined Qty 2] + [Qty Not In Inv]), {{"Combined Qty", Int64.Type}}
  ),
  #"Changed column type" = Table.TransformColumnTypes(#"Adjusted Combined Qty", {{"Combined Date", type date}, {"Today", type date}}),
  #"Removed Columns" = Table.RemoveColumns(#"Changed column type",{"Combined Date 1", "Combined Qty 2", "Custom"}),
  #"Replaced Value" = Table.ReplaceValue(#"Removed Columns","Unknown","67_4674 - DHL",Replacer.ReplaceText,{"MRPSKU Key"}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Replaced Value", {{"Material", type text}, {"MRPSKU Key", type text}, {"Payer", type text}, {"MRP Area", type text}, {"Component", type text}, {"Remaining?", type text}, {"Data Source", type text}, {"BOM Type", type text}, {"PayerMrpSkuSow", type text}, {"Plant", type text}, {"Storage Location", type text}, {"PO Number", type text}, {"Purchasing Group", type text}, {"Storage Location Orig", type text}, {"AASalOrd", type text}, {"SOW", type date}, {"Max Sales Date", type date}, {"Check Date", type date}, {"Today SOW", type date}, {"Purchase Order Date", type date}, {"LA Date", type date}, {"ConfirmDelvDate", type date}, {"ReqDelivDate", type date}, {"CalcArravDate", type date}, {"First GR date for item", type date}, {"Ship Date", type date}, {"SO Created Date", type date}, {"Delivery Creation Date", type date}, {"Confirmation Date", type date}, {"Requested deliv.date", type date}, {"Guarantee Date", type date}, {"Original Delivery Date", type date}, {"SO Billing Date", type date}, {"Planning end", type date}, {"Planned date CheckIn", type date}, {"Planned time CheckIn", type date}, {"Planned shipment end", type date}, {"Act. Gds Mvmnt Date", type date}, {"Invoice Billing Date", type date}, {"Year", type text}, {"Qty Not In Inv", Int64.Type}, {"PrevInv", Int64.Type}, {"Inv", Int64.Type}, {"Running Max", Int64.Type}, {"Lost Sales", Int64.Type}, {"Running Total", Int64.Type}, {"Supplier", type text}, {"Item", type text}, {"Material Description", type text}, {"Order Quantity", Int64.Type}, {"Net Order Value", type number}, {"Sales document", type text}, {"Confirm. Category", type text}, {"GR Processing Time", type text}, {"Billing Document", type text}, {"Inb.delivery", Int64.Type}, {"Container", type text}, {"VesselName", type text}, {"Deletion Indicator", type text}, {"Ship-to party's purchase order no_", type text}, {"Ship-to party", type text}, {"Entry Port", type text}, {"Days to Port", Int64.Type}, {"Reason for rejection", type text}, {"DTP Group", type text}, {"Storage Type", type text}, {"Shipping Point/Receiving Pt", type text}, {"Shipping type", type text}, {"Ship-To Zip", type text}, {"Ship-To Party", type text}, {"Shipment Number", type text}, {"Order reason_1", type text}, {"Sales Document Item", type text}, {"Load No_", type text}, {"Profit Center", type text}, {"Load Delay Reason", type text}, {"Customer SKU", type text}, {"Sales Order", type text}, {"Sales Organization", type text}, {"Delivery", type text}, {"IBP Customer Code", type text}, {"IBP_PayerMrpSkuSow", type text}}),
  #"Calculate Container" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "CombinedQty_per_ContQty", each Value.Divide([Combined Qty], [Cont_Qty])), {{"CombinedQty_per_ContQty", type number}}),
  // 8/10/2026 CJ: add TLs
  #"Calculate TLs" = Table.TransformColumnTypes(Table.AddColumn(#"Calculate Container", "CombinedQty_per_TLQty", each Value.Divide([Combined Qty], [TL Qty])), {{"CombinedQty_per_TLQty", type number}}),

  #"Planned Delivery Date" = Table.TransformColumnTypes(
    Table.AddColumn(#"Calculate TLs", "Planned Delivery Date", each let
      date1 = try Date.From([#"FACT YM6P.CalcArravDate"]) otherwise null,
      date2 = try Date.From([#"Requested deliv.date"]) otherwise null
      in
        if date1 = null and date2 = null then null
        else if date1 = null then date2
        else if date2 = null then date1
        else if date1 > date2 then date1 else date2), {{"Planned Delivery Date", type date}}
  ),

  #"Changed column type 3" = Table.TransformColumnTypes(#"Planned Delivery Date", {{"Net value", Currency.Type}}),
  #"Replaced value 1" = Table.ReplaceValue(#"Changed column type 3", null, 0, Replacer.ReplaceValue, {"Blocked_Qty"}),
  #"Inserted subtraction" = Table.AddColumn(#"Replaced value 1", "_Available", each [Inv] - [Blocked_Qty], Int64.Type),
  #"Changed column type 4" = Table.TransformColumnTypes(#"Inserted subtraction", {{"FACT YM6P.Storage Location", type text}, {"FACT YM6P.PO Number", type text}, {"FACT YM6P.CalcArravDate", type text}, {"Fact YM6P.Container", type text}, {"Sales Qty", Int64.Type}, {"Quantity", Int64.Type}, {"Material.1", type text}, {"MRP Area.1", type text}, {"Material-MRP Area-OrderIndex (YM6p)", type text}, {"Payer name", type text}, {"Reason for rejection description", type text}, {"Order reason", type text}, {"Ship-To Party Region", type text}, {"Trailer No", type text}, {"Carrier SCAC code", type text}, {"Carrier Name", type text}, {"Carrier Code", type text}, {"Carrier Service", type text}, {"Spare Part Indicator", type text}, {"PayerMrpSkuSow", type text}, {"SalesOrderItem", type text}, {"Material-MRP Area-OrderIndex (YS10N)", type text}, {"Fact Ym6P.Material-MRP Area-OrderIndex (YM6p)", type text}, {"_DOS MB52", type number}, {"ADS NUMERATOR", Int64.Type}, {"BOM Forecast", Int64.Type}, {"OrderIndex", type text}, {"Has Delivery", type text}, {"Blocked_Qty", Int64.Type}, {"Base Unit of Measure", type text}, {"Unrestricted", type text}, {"Transit and Transfer", type text}, {"In Quality Insp.", type text}, {"Restricted-Use Stock", type text}, {"Returns", type text}, {"Descr. of Storage Loc.", type text}, {"Storage Location Initial", type text}, {"Stock_Value", Currency.Type}, {"Payer Types.TypeKey", type text}, {"Payer Types.Type", type text}, {"Payer Types.Detail", type text}, {"Sailed/Pending/Other", type text}, {"Early/LateDirectPO", type text}, {"Fact Ym6P.ConfirmDelvDate", type text}, {"Factory PO", type text}, {"On Time Status", type text}, {"Order Status MTO", type text}, {"Earliest Arrival Date", type date}, {"EnfoPak _MrrContainers_.vessel_name", type text}, {"EnfoPak _MrrContainers_.booking_number", type text}, {"EnfoPak _MrrContainers_.carrier_name", type text}, {"EnfoPak _MrrContainers_.eta_date", type text}, {"EnfoPak _MrrContainers_.ship_to", type text}, {"EnfoPak _MrrContainers_.voyage_number", type text}, {"EnfoPak _MrrContainers_.bl_number", type text}, {"PO | Container", type text}, {"Billing Date", type text}, {"Storage Location Orig.1", type text}, {"Week %", type text}, {"Custom _2_", type text}, {"Adj %", type text}, {"_MrrContainers_.status", type text}, {"Billing Date Supply Order", type date}, {"CombinedQty_per_ContQty_fcst", type number}, {"CombinedQty_per_TLQty_fcst", type number}})
in
  #"Changed column type 4";
shared #"FACT MB52" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT MB52", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared fxRunningMax = ( RT_Name as text, MyTable as table, RT_ColumnName as text) => 
let
    Source = MyTable,
    BufferedValues = List.Buffer( Table.Column(MyTable, RT_ColumnName) ),
    RunningTotal = List.Generate( () => [ RT = BufferedValues{0}, Counter = 0],
        each [Counter] < List.Count( BufferedValues),
        each [RT = List.Max( { [RT] , BufferedValues{[Counter]  +1} } ),
            Counter = [Counter] + 1 ],
        each [RT] ),
    CombinedTable = Table.FromColumns(
        Table.ToColumns(Source) & {Value.ReplaceType(RunningTotal, type {Int64.Type})},
        Table.ColumnNames(Source) & {RT_Name})
in
    CombinedTable;
shared fxRunningTotal = ( RT_Name as text, MyTable as table, RT_ColumnName as text) => 
let
    Source = MyTable,
    BufferedValues = List.Buffer( Table.Column(MyTable, RT_ColumnName) ),
    RunningTotal = List.Generate( () => [ RT = BufferedValues{0}, Counter = 0],
        each [Counter] < List.Count( BufferedValues),
        each [RT = List.Sum( { [RT] , BufferedValues{[Counter]  +1} } ),
            Counter = [Counter] + 1 ],
        each [RT] ),
    CombinedTable = Table.FromColumns(
        Table.ToColumns(Source) & {Value.ReplaceType(RunningTotal, type {Int64.Type})},
        Table.ColumnNames(Source) & {RT_Name})
in
    CombinedTable;
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
