[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
[BindToDefaultDestination = true]
shared #"FACT YM6P" = let
    // Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Ym6P.XLSX"), null, true),
    // Sheet1_Sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    // #"Promoted Headers" = Table.PromoteHeaders(Sheet1_Sheet, [PromoteAllScalars=true]),
    // #"Filtered Rows" = Table.SelectRows(#"Promoted Headers", each ([Material] <> "")),
    
    // 6/30/2026: updated source
    Source = Ym6P,
    // #"Added MRP Area" = Table.AddColumn(Source, "MRP Area", each let
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
    // ),
    // 8/3/2026 CJ: MRP Area Cleaned up 
    #"Added MRP Area" =
    Table.AddColumn(
        Source,
        "MRP Area",
        each
            let
                Plant =
                    try Text.From(Number.From([Plant]))
                    otherwise Text.From([Plant]),
                StLoc = [Storage Location],

                PlantMap =
                    [
                        #"60" = "60 - USL-Stanley",
                        #"62" = "62_362B - Bramli",
                        #"65" = "65 - HDP-Anderson",
                        #"66" = "66 - MILTON",
                        #"73" = "73 - Adams"
                    ]
            in
                if Record.HasFields(PlantMap, Plant) then
                    Record.Field(PlantMap, Plant)

                else if StLoc = null or StLoc = "" then
                    if Plant = "69"
                    then "69 - NA - Canada - Import"
                    else "67 - KNA LLC"

                else if List.Contains(
                    {"369C","369P","369T","705","369W","369H"},
                    StLoc
                ) then
                    "69_369T - OEL Overseas - 2"

                else if List.Contains(
                    {"467C","467N","4674","467P","467O","4672","367M","4673","467Q","367J"},
                    StLoc
                ) then
                    "67_4674 - DHL"

                else if List.Contains(
                    {"367B","367A","367I","367D"},
                    StLoc
                ) then
                    "67_367 - KNA- Spreetail"

                else if List.Contains(
                    {"367G","367C"},
                    StLoc
                ) then
                    "67_367G - Globe 18301 Bro"

                else if StLoc = "X67X" then
                    "67 - KNA LLC"

                else if StLoc = "X69X" then
                    "69 - NA - Canada - Import"

                else
                    "Unknown"
    ),
    // #"Added MRP + SKU Key" = Table.AddColumn(#"Added MRP Area", "MRPSKU Key", each [MRP Area]&"|"&[Material]),
    #"Added MRP + SKU Key" = Table.AddColumn(
        #"Added MRP Area",
        "MRPSKU Key",
        each [MRP Area] & "|" & Text.From([Material])
    ),
    #"Added Ship Date" =
        Table.AddColumn(
            #"Added MRP + SKU Key",
            "Ship Date",
            each
                if [LA Date] <> null then
                    [LA Date]
                else if [CalcArravDate] <> null then
                    Date.AddDays(
                        [CalcArravDate],
                        - (if [GR Processing Time] = null then 0 else [GR Processing Time])
                    )
                else
                    null,
            type date
        ),
    // #"Added Today" = Table.AddColumn(#"Added Ship Date", "Today", each DateTime.LocalNow()),
    // #"Changed Type1" = Table.TransformColumnTypes(#"Added Today",{{"Today", type date}, {"Purchasing Document", type text}}),
    // 8/3/2026 CJ: updated logic
    // #"Added Today" =
    //     Table.AddColumn(#"Added Ship Date", "Today", each DateTime.LocalNow()),

    // #"Changed Type1" =
    //     Table.TransformColumnTypes(#"Added Today",
    //         {{"Today", type date}}),

    // #"Added Days to Port" = Table.AddColumn(#"Changed Type1", "Days to Port", each Duration.Days([CalcArravDate] - [Today])),
    #"Added Today" =
        Table.AddColumn(
            #"Added Ship Date",
            "Today",
            each Date.From(DateTime.LocalNow()),
            type date
        ),

    #"Added Days to Port" =
        Table.AddColumn(
            #"Added Today",
            "Days to Port",
            each Duration.Days([CalcArravDate] - [Today]),
            Int64.Type
        ),

    #"Changed Type" = Table.TransformColumnTypes(#"Added Days to Port",{{"Purchasing Document", type text}, {"Plant", Int64.Type}, {"Purchasing Group", type text}, {"Storage Location", type text}, {"Purchase Order Date", type date}, {"AASalOrd", type text}, {"Supplier", Int64.Type}, {"Item", Int64.Type}, {"Material", Int64.Type}, {"Material Description", type text}, {"Order Quantity", Int64.Type}, {"Net Order Value", type number}, {"Sales document", Int64.Type}, {"ReqDelivDate", type date}, {"Confirm. Category", type text}, {"ConfirmDelvDate", type date}, {"GR Processing Time", Int64.Type}, {"LA Date", type date}, {"CalcArravDate", type date}, {"Delivery", Int64.Type}, {"Billing Document", Int64.Type}, {"Container", type text}, {"Inb.delivery", Int64.Type}, {"Entry Port", type text}, {"VesselName", type text}, {"First GR date for item", type any}, {"Deletion Indicator", type text}}),
    // For Append into FACT Combined
    #"Duplicated Column" = Table.DuplicateColumn(#"Changed Type", "CalcArravDate", "Combined Date"),
    // For Append into FACT Combined
    #"Duplicated Column1" = Table.DuplicateColumn(#"Duplicated Column", "Order Quantity", "Combined Qty"),
    #"Added Custom8" = Table.AddColumn(#"Duplicated Column1", "Remaining?", each "Yes"),
    #"Replaced value" = Table.ReplaceValue(#"Added Custom8", "", null, Replacer.ReplaceValue, {"Container"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Replaced value",{{"Purchasing Document", "PO"}}),
    #"Added Storage Type" = Table.AddColumn(#"Renamed Columns1", "Storage Type", 
    each if [Container] <> null and [LA Date] = null then "Haifa Storage" 
    else if [Container] = null and [LA Date] = null then "Future Production"
    else "Shipment", type text
),
    #"Added DTP Grouping" = Table.AddColumn(#"Added Storage Type", "DTP Group", each if [Days to Port] >= 50 then 50 else if [Days to Port] >= 43 then 49 else if [Days to Port] >= 36 then 42 else if [Days to Port] >= 29 then 35 else if [Days to Port] >= 22 then 28 else if [Days to Port] >= 15 then 21 else if [Days to Port] >= 8 then 14 else if [Days to Port] > 0 then 7 else if [Days to Port] = 0 then 0 else 0),
    #"Renamed Columns2" = Table.RenameColumns(#"Added DTP Grouping",{{"Storage Location", "Storage Location Orig"}, {"PO", "PO Number"}}),
    #"Added Custom Storage LOC" = Table.AddColumn(#"Renamed Columns2", "Storage Location", 
        each if [Storage Type] = "Shipment" then
            if [DTP Group] < 28 then 
                "Transit " & Number.ToText([DTP Group]) &" "& Number.ToText([Plant])
            else
                "Transit " & Number.ToText([DTP Group])
            else
                [Storage Type]),

    // #"Duplicated column 1" = Table.DuplicateColumn(#"Added Custom Storage LOC", "Today", "Today SOW"),
    // #"Transform columns" = Table.TransformColumns(#"Duplicated column 1", {{"Today SOW", each Date.StartOfWeek(Date.From(_)), type date}}),
    // // #"Duplicated column 2" = Table.DuplicateColumn(#"Transform columns", "Combined Date", "SOW"),
    // // #"Transform columns 1" = Table.TransformColumns(#"Duplicated column 2", {{"SOW", each Date.ToText(Date.StartOfWeek(Date.From(_), Day.Monday), "yyyy-MM-dd"), type text}}),
    // // #"Changed column type" = Table.TransformColumnTypes(#"Transform columns 1", {{"SOW", type date}}),
    // // 8/3/2026 CJ: Updated Logic
    // #"Added SOW" =
    //     Table.AddColumn(
    //         #"Transform columns",
    //         "SOW",
    //         each Date.StartOfWeek([Combined Date], Day.Monday),
    //         type date
    //     ),
    
    // 8/3/2026 CJ: updated logic
    #"Duplicated column 1" =
        Table.DuplicateColumn(
            #"Added Custom Storage LOC",
            "Today",
            "Today SOW"
        ),

    #"Transform columns" =
        Table.TransformColumns(
            #"Duplicated column 1",
            {
                {
                    "Today SOW",
                    each Date.StartOfWeek(Date.From(_), Day.Monday),
                    type date
                }
            }
        ),

    #"Added SOW" =
        Table.AddColumn(
            #"Transform columns",
            "SOW",
            each Date.StartOfWeek(Date.From([Combined Date]), Day.Monday),
            type date
        ),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Added SOW", {{"Material", type text}, {"MRP Area", type text}, {"Remaining?", type text}, {"MRPSKU Key", type text}, {"Storage Location", type text}, {"Ship-to party's purchase order no.", type text}, {"Ship-to party", type text}, {"DTP Group", type text}, {"First GR date for item", type date}, {"Ship Date", type date}, {"Days to Port", Int64.Type}, {"Billing Date", type date}}),
    #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "PO | Container", each (if [PO Number] = null then "0" else [PO Number]) 
        & " | " & 
        (if [Container] = null then "0" else [Container])), {{"PO | Container", type text}}),
    #"Merged queries" = Table.NestedJoin(#"Added custom", {"PO Number"}, #"EnfoPak _MrrContainers_", {"po_numbers"}, "EnfoPak _MrrContainers_", JoinKind.LeftOuter),
    #"Expanded EnfoPak _MrrContainers_" = Table.ExpandTableColumn(#"Merged queries", "EnfoPak _MrrContainers_", {"booking_number", "carrier_name", "eta_date", "ship_to", "vessel_name", "voyage_number", "bl_numberL", "status"}, {"EnfoPak _MrrContainers_.booking_number", "EnfoPak _MrrContainers_.carrier_name", "EnfoPak _MrrContainers_.eta_date", "EnfoPak _MrrContainers_.ship_to", "EnfoPak _MrrContainers_.vessel_name", "EnfoPak _MrrContainers_.voyage_number", "EnfoPak _MrrContainers_.bl_number","_MrrContainers_.status"}),
    #"Changed column type 2" = Table.TransformColumnTypes(#"Expanded EnfoPak _MrrContainers_", {{"EnfoPak _MrrContainers_.bl_number", type text}, {"BilDateSupplOrd", type date}}),
    #"Renamed columns" = Table.RenameColumns(#"Changed column type 2", {{"BilDateSupplOrd", "Billing Date Supply Order"}}),
    #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns", "StartOfWeek_CalcArravDate_Plus7", each Date.AddDays(Date.StartOfWeek(Date.From([CalcArravDate])), 7)), {{"StartOfWeek_CalcArravDate_Plus7", type date}})
in
    #"Added custom 1";
[BindToDefaultDestination = true]
shared #"Fact Vessel Table" = let
  Source = #"FACT YM6P",
  #"Removed other columns" = Table.SelectColumns(Source, {"SOW", "Storage Type", "VesselName", "CalcArravDate"}),
  #"Sorted rows" = Table.Sort(#"Removed other columns", {{"CalcArravDate", Order.Descending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"VesselName"}),
  #"Filtered rows" = Table.SelectRows(#"Removed duplicates", each ([VesselName] <> "" and [VesselName] <> "Finish goods" and [VesselName] <> "STOCK TO ORDER"))
in
  #"Filtered rows";
[BindToDefaultDestination = true]
shared #"EnfoPak _MrrContainers_" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "EnfoPak _MrrContainers_", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared Ym6P = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Ym6P", ItemKind = "Table"]}[Data],
  #"Data Source" = Table.AddColumn(#"Navigation 2", "Data Source", each "YM6P", type text),
  #"Appended query" = Table.Combine({#"Data Source", fact_coois_pbi_daily_split}),
  #"Removed columns" = Table.RemoveColumns(#"Appended query", {"Work_Center", "Description", "Mold", "Basic_material", "Order_quantity_GMEIN", "Confirmed_quantity_GMEIN", "System_Status", "Qty_Per_Day_BEAZE", "Labour_C_VGE03", "Remaining_HR_time_H", "Remaining_weight_YRW", "User_Status", "Collective_order", "Leading_order", "Scheduled_Start_DateTime", "Scheduled_End_DateTime", "Production_DateTime_Start", "Production_DateTime_End", "TL_Qty", "Daily_TL_Qty"})
in
  #"Removed columns";
shared fact_coois_pbi_daily_split = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  // #"Navigation 2" = #"Navigation 1"{[Id = "coois_plant73_pbi_dailysplit", ItemKind = "Table"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "fact_coois_pbi_daily_split", ItemKind = "Table"]}[Data], // CJ 8/13/2026: update name being pulled
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"Storage_Location", "Storage Location"}, {"ProductionDate", "CalcArravDate"}, {"Material_Number", "Material"}, {"Material_description", "Material Description"}, {"DailyProductionQty", "Order Quantity"}, {"Sales_Document", "Sales document"}, {"Order_Number", "Purchasing Document"}}),
  #"Data Source" = Table.AddColumn(#"Renamed columns", "Data Source", each "YM6P", type text),

  #"Filtered ProductionDate" = Table.SelectRows(
    #"Data Source",
    each Date.From([CalcArravDate]) >= Date.From(DateTime.LocalNow())
  )
in
  #"Filtered ProductionDate";
