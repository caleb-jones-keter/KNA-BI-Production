[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared ECOM = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("ZdCxDcRACATAXi52ABzHQmx9+HIBlvtv4/2RtTgdAQuc51B38xrb+OzHd1zbX1JEuthsEq1mBTJZUnWRhCG5KyagLL4MLNDi9Cj1Nqf6ZIgs3gc22z6Y8pJEsNz/mU2WvMVZkHyXldxh/EMte9KvHw==", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [Payer = _t, ECOM = _t])
in
    Source;
shared #"Defective Allowance" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45WMjY0VdJRMtAzMDNVitUB8o3NIHwLMNfEyBDCNYZyITwjiFpLSzg3FgA=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [#"Customer Group Key" = _t, #"Defective Allowance" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Defective Allowance", type number}})
in
    #"Changed Type";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
[BindToDefaultDestination = true]
shared #"FACT YS10N All" = let
  Source = #"FACT YS10N Base",
  #"Filtered rows" = Table.SelectRows(Source, each [#"REASON FOR REJECTION _LINE_"] = null or [#"REASON FOR REJECTION _LINE_"] = "" ),
  #"Data Source" = Table.TransformColumns(
    #"Filtered rows",
    {{"Data Source", each "YS10N All", type text}}
)

in
  #"Data Source";
[BindToDefaultDestination = true]
shared #"FACT YS10N Past" = let
  Source = #"FACT YS10N All",
  #"Filtered rows" = Table.SelectRows(Source, each [Combined Date] < [Today] and [Combined Date] <> "" and [Combined Date] <> null),
  #"Data Source" = Table.TransformColumns(
    #"Filtered rows",
    {{"Data Source", each "YS10N Past", type text}}
  )
in
  #"Data Source";
[BindToDefaultDestination = true]
shared #"Dim Currency Rate" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Currency rate]", {"[Currency rate].[CurrencyID].[CurrencyID]", "[Currency rate].[DateKey].[DateKey]", "[Currency rate].[EndMonthRate].[EndMonthRate]", "[Currency rate].[FullDateDesc].[FullDateDesc]", "[Currency rate].[Rate].[Rate]"}, {"Currency rate.CurrencyID", "Currency rate.DateKey", "Currency rate.EndMonthRate", "Currency rate.FullDateDesc", "Currency rate.Rate"}}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Currency rate.CurrencyID] = "24"),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Currency rate.CurrencyID", "CurrencyID"}, {"Currency rate.DateKey", "DateKey"}, {"Currency rate.EndMonthRate", "EndMonthRate"}, {"Currency rate.FullDateDesc", "FullDateDesc"}, {"Currency rate.Rate", "Rate"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FullDateDesc", type datetime}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"Rate", "Rate EUR"}}),
    #"Removed Columns" = Table.RemoveColumns(#"Renamed Columns1",{"CurrencyID"}),
    #"Merged Queries" = Table.NestedJoin(#"Removed Columns", {"DateKey"}, #"Dim Currency Rate (2)", {"DateKey"}, "Dim Currency Rate (2)", JoinKind.LeftOuter),
    #"Expanded Dim Currency Rate (2)" = Table.ExpandTableColumn(#"Merged Queries", "Dim Currency Rate (2)", {"Rate USD"}, {"Dim Currency Rate (2).Rate USD"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Expanded Dim Currency Rate (2)",{{"Rate EUR", type number}, {"Dim Currency Rate (2).Rate USD", type number}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type1", "Conversion", each 1/[#"Dim Currency Rate (2).Rate USD"]),
  #"Changed column type" = Table.TransformColumnTypes(#"Added Custom", {{"Conversion", type number}})
in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"Dim Currency Rate (2)" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Currency rate]", {"[Currency rate].[CurrencyID].[CurrencyID]", "[Currency rate].[DateKey].[DateKey]", "[Currency rate].[EndMonthRate].[EndMonthRate]", "[Currency rate].[FullDateDesc].[FullDateDesc]", "[Currency rate].[Rate].[Rate]"}, {"Currency rate.CurrencyID", "Currency rate.DateKey", "Currency rate.EndMonthRate", "Currency rate.FullDateDesc", "Currency rate.Rate"}}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Currency rate.CurrencyID] = "1"),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Currency rate.CurrencyID", "CurrencyID"}, {"Currency rate.DateKey", "DateKey"}, {"Currency rate.EndMonthRate", "EndMonthRate"}, {"Currency rate.FullDateDesc", "FullDateDesc"}, {"Currency rate.Rate", "Rate"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FullDateDesc", type datetime}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"Rate", "Rate USD"}}),
    #"Removed Columns" = Table.RemoveColumns(#"Renamed Columns1",{"CurrencyID"})
in
    #"Removed Columns";
[BindToDefaultDestination = true]
shared #"FACT YS10N Base" = let
    Source = PowerPlatform.Dataflows([]),
    #"Navigation 1" = Source{[Id = "Workspaces"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[workspaceId = "c2419776-dec6-4cc0-8fa3-af708bd179cf"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[dataflowId = "d6b74011-0311-430f-aa6c-fdc40723f358"]}[Data],
    #"Navigation 4" = #"Navigation 3"{[entity = "Fact Service Level US", version = ""]}[Data],
    #"Filtered Rows" = Table.SelectRows(#"Navigation 4", 
        each [SalesOrgKey] = 68 
            or [SalesOrgKey] = 70
            or [SalesOrgKey] = 71
            or [SalesOrgKey] = 72
            or [SalesOrgKey] = 136
            or [SalesOrgKey] = 145
            or [SalesOrgKey] = 208
    ),
    #"Filtered Rows1" = Table.SelectRows(#"Filtered Rows", each [QTY] <> 0),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows1",{{"ActGdsMvmntDate", "FSL_ActGdsMvmntDate"}, {"ConfiramtionDate", "FSL_ConfiramtionDate"}, {"DELIVERY", "FSL_DELIVERY"}, {"DeliveryCreationDate", "FSL_DeliveryCreationDate"}, {"FIRST_DAY", "FSL_FIRST_DAY"}, {"GUARANT", "FSL_GUARANT"}, {"InvoiceBillingDate", "FSL_InvoiceBillingDate"}, {"LoadDelayReason", "FSL_LoadDelayReason"}, {"Order Number", "FSL_Order Number"}, {"OrderReason", "FSL_OrderReason"}, {"OrderReasonDesc", "FSL_OrderReasonDesc"}, {"PAYER", "FSL_PAYER"}, {"Plant DC","FSL_Plant DC"}, {"PO_Number", "FSL_PO_Number"}, {"ProductKey", "FSL_ProductKey"}, {"PSTYV", "FSL_PSTYV"}, {"REQUEST", "FSL_REQUEST"}, {"RetailGroupKey", "FSL_RetailGroupKey"}, {"SalesOrgKey", "FSL_SalesOrgKey"}, {"ShipmentNumber", "FSL_ShipmentNumber"}, {"ShippingType", "FSL_ShippingType"}, {"ShipPoint_KEY", "FSL_ShipPoint_KEY"}, {"ShipToRegion", "FSL_ShipToRegion"}, {"SO_BillingDate", "FSL_SO_BillingDate"}, {"SO_CreatedDate", "FSL_SO_CreatedDate"}, {"SOLDTO", "FSL_SOLDTO"}, {"TrailerNo", "FSL_TrailerNo"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FSL_FIRST_DAY", type date}, {"FSL_GUARANT", type date}, {"FSL_InvoiceBillingDate", type date}, {"FSL_SO_BillingDate", type date}, {"FSL_ConfiramtionDate", type date}, {"FSL_DeliveryCreationDate", type date}, {"FSL_SO_CreatedDate", type date}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"FSL_ActGdsMvmntDate", "Act. Gds Mvmnt Date"}, {"FSL_ConfiramtionDate", "Confirmation Date"}, {"FSL_DELIVERY", "Delivery"}, {"FSL_DeliveryCreationDate", "Delivery Creation Date"}, {"FSL_FIRST_DAY", "First Date"}, {"FSL_GUARANT", "Guarantee Date"}, {"FSL_InvoiceBillingDate", "Invoice Billing Date"}, {"FSL_Order Number", "Sales Order"}, {"FSL_OrderReason", "Order reason"}, {"FSL_OrderReasonDesc", "Order reason_1"}, {"FSL_PO_Number", "PO Number"}, {"FSL_PSTYV", "FSL_PSTYV"}, {"FSL_REQUEST", "Requested deliv.date"}, {"FSL_RetailGroupKey", "Payer name"}, {"FSL_Plant DC","Plant"}, {"FSL_ShipmentNumber", "Shipment Number"}, {"FSL_ShippingType", "Shipping type"}, {"FSL_ShipToRegion", "Ship-To Party Region"}, {"FSL_SO_BillingDate", "SO Billing Date"}, {"FSL_SO_CreatedDate", "SO Created Date"}, {"FSL_PAYER", "Payer"}, {"FSL_ProductKey", "Material"}, {"FSL_SalesOrgKey", "FSL_SalesOrgKey"}, {"Gross_SALES", "Net value"}, {"QTY", "Order Qty"}, {"FSL_TrailerNo", "Trailer No"}, {"LGORT", "Storage Location"}, {"VSTEL", "Shipping Point/Receiving Pt"}}),
    #"Added Custom" = Table.AddColumn(#"Renamed Columns1", "YS10N Source", each "Semantic Model"),
    #"Added Conditional Column" = Table.AddColumn(#"Added Custom", "Reason for rejection", each if [LineInFullStatus] = "SHORT" then [LineFailureReason] else null),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Conditional Column", {{"YS10N Source", type text}, {"Reason for rejection", type text}, {"Material", type text}, {"Payer", type text}, {"ship_to", type text}}),
    #"Added Custom1" = Table.AddColumn(#"Changed Type1", "SKUPayer", each [Material] & "|" & [Payer]),
    #"Added Custom2" = Table.AddColumn(#"Added Custom1", "Status", each if ([Invoice Billing Date] <> null or [Act. Gds Mvmnt Date] <> null) then
        if [Reason for rejection] = null then "Shipped" else "Shipped"
        else
        if [Reason for rejection] = null then "Open" else null),
        Custom1 = Table.AddColumn(#"Added Custom2", "Company Code", each 
        if [FSL_SalesOrgKey] = 136 then "1666" 
        else if [FSL_SalesOrgKey] = 145 then "1669" 
        else if [FSL_SalesOrgKey] = 208 then "1573" 
        else if [FSL_SalesOrgKey] = 68 then "1560" 
        else if [FSL_SalesOrgKey] = 70 then "1564" 
        else if [FSL_SalesOrgKey] = 71 then "1565" 
        else if [FSL_SalesOrgKey] = 72 then "1567" 
        else null
        ),
    #"Merged queries" = Table.NestedJoin(Custom1, {"Payer"}, ECOM, {"Payer"}, "ECOM", JoinKind.LeftOuter),
    #"Expanded ECOM" = Table.ExpandTableColumn(#"Merged queries", "ECOM", {"ECOM"}, {"ECommerce"}),
    #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded ECOM", "ECOM $", each if [ECommerce] = "ECOM" then [Net value] else null), {{"ECOM $", type number}}),
    #"Merged queries 1" = Table.NestedJoin(#"Added custom 1", {"CustomerGroupKey"}, #"Defective Allowance", {"Customer Group Key"}, "Defective Allowance", JoinKind.LeftOuter),
    #"Expanded Defective Allowance 1" = Table.ExpandTableColumn(#"Merged queries 1", "Defective Allowance", {"Defective Allowance"}, {"Defective Allowance.1"}),
    #"Changed column type" = Table.TransformColumnTypes(#"Expanded Defective Allowance 1", {{"SKUPayer", type text}, {"Company Code", type text}, {"Status", type text}, {"Act. Gds Mvmnt Date", type text}}),
    #"Replaced value" = Table.ReplaceValue(#"Changed column type", "00000000", "", Replacer.ReplaceText, {"Act. Gds Mvmnt Date"}),

    #"Duplicated Act. Gds Mvmnt Date" = Table.DuplicateColumn(#"Replaced value", "Act. Gds Mvmnt Date", "Act. Gds Mvmnt Date Converted"),

    #"Converted to Date" = Table.TransformColumns(
        #"Duplicated Act. Gds Mvmnt Date",
        {
            {
                "Act. Gds Mvmnt Date Converted",
                each 
                    let
                        val = _,
                        // Check if value is text, length is 8, and all characters are digits
                        safeDate = 
                            if val <> null 
                                and Text.Length(val) = 8 
                                and Text.Select(val, {"0".."9"}) = val
                            then 
                                try Date.FromText(
                                    Text.Middle(val, 0, 4) & "-" & 
                                    Text.Middle(val, 4, 2) & "-" & 
                                    Text.Middle(val, 6, 2)
                                ) otherwise null
                            else null
                    in
                        safeDate,
                type date
            }
        }
    ),
    #"SHIP DATE" = Table.TransformColumnTypes(Table.AddColumn(#"Converted to Date", "Ship Date", each if [Act. Gds Mvmnt Date Converted] <> null and [Act. Gds Mvmnt Date Converted] <> "" then [Act. Gds Mvmnt Date Converted]
            else if [#"Invoice Billing Date"] <> null and [#"Invoice Billing Date"] <> "" then [#"Invoice Billing Date"]
            else null), {{"Ship Date", type date}}),
    #"SHIP DATE KEY" = Table.TransformColumnTypes(Table.AddColumn(#"SHIP DATE", "ShipDateKey", each if [ActGdsMvmntDateKey] <> null and [ActGdsMvmntDateKey] <> "" then [ActGdsMvmntDateKey]
        else if [#"InvoiceBillingDateKey"] <> null and [#"InvoiceBillingDateKey"] <> "" then [#"InvoiceBillingDateKey"]
        else null), {{"ShipDateKey", type text}}),
    #"Added MRP Area" = Table.AddColumn(#"SHIP DATE KEY", "MRP Area", each let
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
    #"Added Data Source ID" = Table.AddColumn(#"Added MRP + SKU Key", "Data Source", each "YS10N Base"),
    #"Multiplied Column" = Table.TransformColumns(#"Added Data Source ID", {{"Order Qty", each _ * -1, type number}}),
    #"Duplicated column" = Table.DuplicateColumn(#"Multiplied Column", "SO Billing Date", "SOW"),
    #"Add Today" = Table.AddColumn(#"Duplicated column", "Today", each DateTime.LocalNow(), type date),
    #"Duplicated column 1" = Table.DuplicateColumn(#"Add Today", "Today", "Today SOW"),
    #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
    #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Calculated Start of Week Today", {{"Today", type date}, {"Today SOW", type date}}),
    #"Renamed columns 1" = Table.RenameColumns(#"Changed column type 1", {{"Order Qty", "Combined Qty"}}),
    #"Combined Date added here" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns 1", "Combined Date", each let
            soBillingDate = [SO Billing Date],
            shipDate = [Ship Date],
            result = 
                if (soBillingDate <> null and soBillingDate <> "" and shipDate <> null and shipDate <> "") 
                then 
                    if Date.From(soBillingDate) < Date.From(shipDate) 
                    then Date.From(soBillingDate) 
                    else Date.From(shipDate)
                else 
                    if (soBillingDate <> null and soBillingDate <> "") then Date.From(soBillingDate)
                    else if (shipDate <> null and shipDate <> "") then Date.From(shipDate)
                    else null
        in
            result), {{"Combined Date", type date}}),
    #"ShipToZip_Clean" = Table.TransformColumnTypes(Table.AddColumn(#"Combined Date added here", "ShipToZip_Clean", each let
            zip = try Record.Field(_, "ship_to_zip") otherwise null,
            noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
            hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
            result = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces
        in
            result), {{"ShipToZip_Clean", type text}}),
    #"Changed column type 2" = Table.TransformColumnTypes(ShipToZip_Clean, {{"MRPSKU Key", type text}, {"Data Source", type text}, {"MRP Area", type text}, {"SO_BillingDateKey", type text}}),
    #"Changed column type 4" = Table.TransformColumnTypes(#"Changed column type 2", {{"Combined Date", type datetime}}),
    #"Merged Queries Currency Rate" = Table.NestedJoin(#"Changed column type 4", {"Combined Date"}, #"Dim Currency Rate", {"FullDateDesc"}, "Dim Currency Rate", JoinKind.LeftOuter),
    #"Expanded Dim Currency Rate" = Table.ExpandTableColumn(#"Merged Queries Currency Rate", "Dim Currency Rate", {"Conversion"}, {"Dim Currency Rate.Conversion"}),
    #"Changed Type Currency Rate" = Table.TransformColumnTypes(#"Expanded Dim Currency Rate",{{"Dim Currency Rate.Conversion", type number}}),
    #"Added Custom Currency Rate" = Table.TransformColumnTypes(Table.AddColumn(#"Changed Type Currency Rate", "Net Value USD", each [#"Net value"]*[Dim Currency Rate.Conversion]),{{"Net Value USD", type number}}),
    #"Added custom 6" = Table.TransformColumnTypes(Table.AddColumn(#"Added Custom Currency Rate", "Gross Sales USD", each [Dim Currency Rate.Conversion] * [Gross Sale]), {{"Gross Sales USD", Currency.Type}}),
    #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 6", "New Net Value", each if [Defective Allowance.1] = null or [Defective Allowance.1] = "" then [Net Value USD] else null), {{"New Net Value", type number}}),
    #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Parcel $", each if [#"Shipping type"] = "07" then [Net Value USD] else null), {{"Parcel $", type number}}),
    #"Added custom 4" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 3", "TL $", each if [#"Shipping type"] = "01" then [Net Value USD] else null), {{"TL $", type number}}),
    #"Added custom 5" = Table.TransformColumnTypes(Table.AddColumn( #"Added custom 4", "LTL $", each if [#"Shipping type"] = "06" then [Net Value USD] else null), {{"LTL $", type number}}),
    #"Changed column type 3" = Table.TransformColumnTypes(#"Added custom 5", {{"Shipment Number", Int64.Type}, {"Combined Date", type date}}),
    #"Merged queries 2" = Table.NestedJoin(#"Changed column type 3", {"Shipment Number"}, #"DTC YRSHP", {"Shipment Number"}, "DTC YRSHP", JoinKind.LeftOuter),
    #"Expanded DTC YRSHP" = Table.ExpandTableColumn(#"Merged queries 2", "DTC YRSHP", {"Storage Location"}, {"DTC YRSHP.Storage Location"}),
    #"Added custom 7" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DTC YRSHP", "New Storage Location", each if [#"DTC YRSHP.Storage Location"] <> null and [#"DTC YRSHP.Storage Location"] <> "" and ([Payer] = "172315" and List.Contains({"367B", "367D"}, [#"Storage Location"]))
        then [#"DTC YRSHP.Storage Location"]
        else [#"Storage Location"]), {{"New Storage Location", type text}}),
    #"Added custom 8" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 7", "Material ZIP Key", each Text.From([Material]) & "|" & Text.From([ship_to])), {{"Material ZIP Key", type text}} ),
    #"Merged queries 3" = Table.NestedJoin(#"Added custom 8", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
    #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged queries 3", "DIM Product", {"Carton/Bag_Qty", "SS/PLT_Qty"}, {"DIM Product.Carton/Bag_Qty", "DIM Product.SS/PLT_Qty"}),
    #"Picks" = Table.AddColumn(
        #"Expanded DIM Product",
        "Picks",
        each
            let
                LineQty = -[Combined Qty],
                LinePlt = [#"DIM Product.SS/PLT_Qty"],
                LineCase = [#"DIM Product.Carton/Bag_Qty"],
                MovementType = [Movement Type]
            in
                if LineQty = null then null
                else if LinePlt <> null and LinePlt <> 0 and LineQty > LinePlt then Number.RoundUp(LineQty / LinePlt)
                else if LineCase <> null and LineCase <> 0 and LineQty > LineCase then Number.RoundUp(LineQty / LineCase)
                else 1,
        Int64.Type
    )
in
    #"Picks";
[BindToDefaultDestination = true]
shared #"FACT YS10N Rejected" = let
  Source = #"FACT YS10N Base",
  #"Filtered rows" = Table.SelectRows(Source, each [#"REASON FOR REJECTION _LINE_"] <> null and [#"REASON FOR REJECTION _LINE_"] <> ""),
  #"Data Source" = Table.TransformColumns(
    #"Filtered rows",
    {{"Data Source", each "YS10N Rejected", type text}}
  )
in
  #"Data Source";
[BindToDefaultDestination = true]
shared #"DTC YRSHP" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DTC YRSHP", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each [Storage Location] <> null and [Storage Location] <> ""),
  #"Changed column type" = Table.TransformColumnTypes(#"Filtered rows", {{"Shipment Number", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Changed column type", {"Delivery", "DeliveryGrossWeight", "Sold-to party", "Forwarder Name", "Act. Gds Mvmnt Date", "Material", "Description", "Payer", "Payer name", "Ship-to party", "Shipping type", "ShipTo Customer – City", "ShipTo Customer – Postal code", "RegionWE", "ShipTo Postal code _Shipment_", "ShipTo Region _Shipment_", "Delivery quantity", "Net Value", "Incoterms", "Purchase order number"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns", {"Shipment Number"})
in
  #"Removed duplicates";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Justins YS10n Test (DELETE THIS AFTER 6-15)_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Justins YS10n Test (DELETE THIS AFTER 6-15)" = let
    Source = PowerPlatform.Dataflows([]),
    #"Navigation 1" = Source{[Id = "Workspaces"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[workspaceId = "c2419776-dec6-4cc0-8fa3-af708bd179cf"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[dataflowId = "d6b74011-0311-430f-aa6c-fdc40723f358"]}[Data],
    #"Navigation 4" = #"Navigation 3"{[entity = "Fact Service Level US", version = ""]}[Data],
    #"Renamed Columns" = Table.RenameColumns(#"Navigation 4",{{"ActGdsMvmntDate", "FSL_ActGdsMvmntDate"}, {"ConfiramtionDate", "FSL_ConfiramtionDate"}, {"DELIVERY", "FSL_DELIVERY"}, {"DeliveryCreationDate", "FSL_DeliveryCreationDate"}, {"FIRST_DAY", "FSL_FIRST_DAY"}, {"GUARANT", "FSL_GUARANT"}, {"InvoiceBillingDate", "FSL_InvoiceBillingDate"}, {"LoadDelayReason", "FSL_LoadDelayReason"}, {"Order Number", "FSL_Order Number"}, {"OrderReason", "FSL_OrderReason"}, {"OrderReasonDesc", "FSL_OrderReasonDesc"}, {"PAYER", "FSL_PAYER"}, {"Plant DC","FSL_Plant DC"}, {"PO_Number", "FSL_PO_Number"}, {"ProductKey", "FSL_ProductKey"}, {"PSTYV", "FSL_PSTYV"}, {"REQUEST", "FSL_REQUEST"}, {"RetailGroupKey", "FSL_RetailGroupKey"}, {"SalesOrgKey", "FSL_SalesOrgKey"}, {"ShipmentNumber", "FSL_ShipmentNumber"}, {"ShippingType", "FSL_ShippingType"}, {"ShipPoint_KEY", "FSL_ShipPoint_KEY"}, {"ShipToRegion", "FSL_ShipToRegion"}, {"SO_BillingDate", "FSL_SO_BillingDate"}, {"SO_CreatedDate", "FSL_SO_CreatedDate"}, {"SOLDTO", "FSL_SOLDTO"}, {"TrailerNo", "FSL_TrailerNo"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FSL_FIRST_DAY", type date}, {"FSL_GUARANT", type date}, {"FSL_InvoiceBillingDate", type date}, {"FSL_SO_BillingDate", type date}, {"FSL_ConfiramtionDate", type date}, {"FSL_DeliveryCreationDate", type date}, {"FSL_SO_CreatedDate", type date}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"FSL_ActGdsMvmntDate", "Act. Gds Mvmnt Date"}, {"FSL_ConfiramtionDate", "Confirmation Date"}, {"FSL_DELIVERY", "Delivery"}, {"FSL_DeliveryCreationDate", "Delivery Creation Date"}, {"FSL_FIRST_DAY", "First Date"}, {"FSL_GUARANT", "Guarantee Date"}, {"FSL_InvoiceBillingDate", "Invoice Billing Date"}, {"FSL_Order Number", "Sales Order"}, {"FSL_OrderReason", "Order reason"}, {"FSL_OrderReasonDesc", "Order reason_1"}, {"FSL_PO_Number", "PO Number"}, {"FSL_PSTYV", "FSL_PSTYV"}, {"FSL_REQUEST", "Requested deliv.date"}, {"FSL_RetailGroupKey", "Payer name"}, {"FSL_Plant DC","Plant"}, {"FSL_ShipmentNumber", "Shipment Number"}, {"FSL_ShippingType", "Shipping type"}, {"FSL_ShipToRegion", "Ship-To Party Region"}, {"FSL_SO_BillingDate", "SO Billing Date"}, {"FSL_SO_CreatedDate", "SO Created Date"}, {"FSL_PAYER", "Payer"}, {"FSL_ProductKey", "Material"}, {"FSL_SalesOrgKey", "FSL_SalesOrgKey"}, {"Gross_SALES", "Net value"}, {"QTY", "Order Qty"}, {"FSL_TrailerNo", "Trailer No."}, {"LGORT", "Storage Location"}, {"VSTEL", "Shipping Point/Receiving Pt"}}),
    #"Added Custom" = Table.AddColumn(#"Renamed Columns1", "YS10N Source", each "Semantic Model"),
    #"Added Conditional Column" = Table.AddColumn(#"Added Custom", "Reason for rejection", each if [LineInFullStatus] = "SHORT" then [LineFailureReason] else null),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Conditional Column", {{"YS10N Source", type text}, {"Reason for rejection", type text}, {"Material", type text}, {"Payer", type text}}),
    #"Added Custom1" = Table.AddColumn(#"Changed Type1", "SKUPayer", each [Material] & "|" & [Payer]),
    #"Added Custom2" = Table.AddColumn(#"Added Custom1", "Status", each if ([Invoice Billing Date] <> null or [Act. Gds Mvmnt Date] <> null) then
        if [Reason for rejection] = null then "Shipped" else "Shipped"
        else
        if [Reason for rejection] = null then "Open" else null),
        Custom1 = Table.AddColumn(#"Added Custom2", "Company Code", each 
        if [FSL_SalesOrgKey] = 136 then "1666" 
        else if [FSL_SalesOrgKey] = 145 then "1669" 
        else if [FSL_SalesOrgKey] = 208 then "1573" 
        else if [FSL_SalesOrgKey] = 68 then "1560" 
        else if [FSL_SalesOrgKey] = 70 then "1564" 
        else if [FSL_SalesOrgKey] = 71 then "1565" 
        else if [FSL_SalesOrgKey] = 72 then "1567" 
        else null
        ),
    #"Merged queries" = Table.NestedJoin(Custom1, {"Payer"}, ECOM, {"Payer"}, "ECOM", JoinKind.LeftOuter),
    #"Expanded ECOM" = Table.ExpandTableColumn(#"Merged queries", "ECOM", {"ECOM"}, {"ECommerce"}),
    #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded ECOM", "ECOM $", each if [ECommerce] = "ECOM" then [Net value] else null), {{"ECOM $", type number}}),
    #"Merged queries 1" = Table.NestedJoin(#"Added custom 1", {"CustomerGroupKey"}, #"Defective Allowance", {"Customer Group Key"}, "Defective Allowance", JoinKind.LeftOuter),
    #"Expanded Defective Allowance 1" = Table.ExpandTableColumn(#"Merged queries 1", "Defective Allowance", {"Defective Allowance"}, {"Defective Allowance.1"}),
    #"Changed column type" = Table.TransformColumnTypes(#"Expanded Defective Allowance 1", {{"SKUPayer", type text}, {"Company Code", type text}, {"Status", type text}, {"Act. Gds Mvmnt Date", type text}}),
    #"Replaced value" = Table.ReplaceValue(#"Changed column type", "00000000", "", Replacer.ReplaceText, {"Act. Gds Mvmnt Date"}),
    #"SHIP DATE" = Table.TransformColumnTypes(Table.AddColumn(#"Replaced value", "Ship Date", each if [#"Act. Gds Mvmnt Date"] <> null and [#"Act. Gds Mvmnt Date"] <> "" then [#"Act. Gds Mvmnt Date"]
            else if [#"Invoice Billing Date"] <> null and [#"Invoice Billing Date"] <> "" then [#"Invoice Billing Date"]
            else null), {{"Ship Date", type date}}),
  #"Added MRP Area" = Table.AddColumn(#"SHIP DATE", "MRP Area", each let
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
    #"Added Data Source ID" = Table.AddColumn(#"Added MRP + SKU Key", "Data Source", each "YS10N Base"),
    #"Multiplied Column" = Table.TransformColumns(#"Added Data Source ID", {{"Order Qty", each _ * -1, type number}}),
    #"Duplicated column" = Table.DuplicateColumn(#"Multiplied Column", "SO Billing Date", "SOW"),
    #"Add Today" = Table.AddColumn(#"Duplicated column", "Today", each DateTime.LocalNow(), type date),
    #"Duplicated column 1" = Table.DuplicateColumn(#"Add Today", "Today", "Today SOW"),
    #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
    #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Calculated Start of Week Today", {{"Today", type date}, {"Today SOW", type date}}),
    #"Renamed columns 1" = Table.RenameColumns(#"Changed column type 1", {{"Order Qty", "Combined Qty"}, {"SO Billing Date", "Combined Date"}}),
    #"ShipToZip_Clean" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns 1", "ShipToZip_Clean", each let
            zip = try Record.Field(_, "ship_to_zip") otherwise null,
            noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
            hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
            result = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces
        in
            result), {{"ShipToZip_Clean", type text}}),

    #"Duplicated Act. Gds Mvmnt Date" = Table.DuplicateColumn(#"ShipToZip_Clean", "Act. Gds Mvmnt Date", "Act. Gds Mvmnt Date Converted"),

    #"Converted to Date" = Table.TransformColumns(
        #"Duplicated Act. Gds Mvmnt Date",
        {
            {
                "Act. Gds Mvmnt Date Converted",
                each 
                    let
                        val = _,
                        // Check if value is text, length is 8, and all characters are digits
                        safeDate = 
                            if val <> null 
                                and Text.Length(val) = 8 
                                and Text.Select(val, {"0".."9"}) = val
                            then 
                                try Date.FromText(
                                    Text.Middle(val, 0, 4) & "-" & 
                                    Text.Middle(val, 4, 2) & "-" & 
                                    Text.Middle(val, 6, 2)
                                ) otherwise null
                            else null
                    in
                        safeDate,
                type date
            }
        }
    ),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Converted to Date", {{"MRPSKU Key", type text}, {"Data Source", type text}, {"MRP Area", type text}, {"SO_BillingDateKey", type text}}),
    #"Merged Queries Currency Rate" = Table.NestedJoin(#"Changed column type 2", {"SO_BillingDateKey"}, #"Dim Currency Rate", {"DateKey"}, "Dim Currency Rate", JoinKind.LeftOuter),
    #"Expanded Dim Currency Rate" = Table.ExpandTableColumn(#"Merged Queries Currency Rate", "Dim Currency Rate", {"Conversion"}, {"Dim Currency Rate.Conversion"}),
    #"Changed Type Currency Rate" = Table.TransformColumnTypes(#"Expanded Dim Currency Rate",{{"Dim Currency Rate.Conversion", type number}}),
    #"Added Custom Currency Rate" = Table.TransformColumnTypes(Table.AddColumn(#"Changed Type Currency Rate", "Net Value USD", each [#"Net value"]*[Dim Currency Rate.Conversion]),{{"Net Value USD", type number}}),
  #"Added custom 6" = Table.TransformColumnTypes(Table.AddColumn(#"Added Custom Currency Rate", "Gross Sales USD", each [Dim Currency Rate.Conversion] * [Gross Sale]), {{"Gross Sales USD", Currency.Type}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 6", "New Net Value", each if [Defective Allowance.1] = null or [Defective Allowance.1] = "" then [Net Value USD] else null), {{"New Net Value", type number}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Parcel $", each if [#"Shipping type"] = "07" then [Net Value USD] else null), {{"Parcel $", type number}}),
  #"Added custom 4" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 3", "TL $", each if [#"Shipping type"] = "01" then [Net Value USD] else null), {{"TL $", type number}}),
  #"Added custom 5" = Table.TransformColumnTypes(Table.AddColumn( #"Added custom 4", "LTL $", each if [#"Shipping type"] = "06" then [Net Value USD] else null), {{"LTL $", type number}}),
  #"Changed column type 3" = Table.TransformColumnTypes(#"Added custom 5", {{"Shipment Number", Int64.Type}}),
  #"Merged queries 2" = Table.NestedJoin(#"Changed column type 3", {"Shipment Number"}, #"DTC YRSHP", {"Shipment Number"}, "DTC YRSHP", JoinKind.LeftOuter),
  #"Expanded DTC YRSHP" = Table.ExpandTableColumn(#"Merged queries 2", "DTC YRSHP", {"Storage Location"}, {"DTC YRSHP.Storage Location"}),
  #"Added custom 7" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DTC YRSHP", "New Storage Location", each if [#"DTC YRSHP.Storage Location"] <> null and [#"DTC YRSHP.Storage Location"] <> "" and ([Payer] = "172315" and List.Contains({"367B", "367D"}, [#"Storage Location"]))
        then [#"DTC YRSHP.Storage Location"]
        else [#"Storage Location"]), {{"New Storage Location", type text}}),
  #"Added custom 8" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 7", "Material ZIP Key", each Text.From([Material]) & "|" & Text.From([ship_to])), {{"Material ZIP Key", type text}})
in
    #"Added custom 8";
shared #"Justins YS10n Test (DELETE THIS AFTER 6-15)_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "c63eb910-5e90-460e-9ec2-ab13e8735c39"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "Justins YS10n Test _DELETE THIS AFTER 6-15_", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
