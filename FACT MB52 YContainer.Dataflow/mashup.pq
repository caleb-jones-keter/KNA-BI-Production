[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"FACT YContainer" = let
    Source = Excel.Workbook(
        Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Y%20Container%20Daily%20Pull.xlsx"),
        null,
        false
    ),
 
    Sheet1_sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
 
    FilterNullAndWhitespace =
        each List.Select(_, each _ <> null and (not (_ is text) or Text.Trim(_) <> "")),
 
    #"Removed Bottom Rows" =
        Table.RemoveLastN(
            Sheet1_sheet,
            each
                try
                    List.IsEmpty(
                        List.Skip(FilterNullAndWhitespace(Record.FieldValues(_)), 1)
                    )
                otherwise false
        ),
 
    #"Promoted Headers" =
        Table.PromoteHeaders(#"Removed Bottom Rows", [PromoteAllScalars=true]),
 
    #"Added Static MRP Area" =
        Table.AddColumn(#"Promoted Headers", "MRP Area", each "67_4674 - DHL"),
 
    #"Added MRP + SKU Key" =
        Table.AddColumn(
            #"Added Static MRP Area",
            "MRPSKU Key",
            each [MRP Area] & "|" & [Material]
        ),
    #"Today Dynamic" = Table.AddColumn(#"Added MRP + SKU Key",  "Today", each DateTime.LocalNow()),
    #"Duplicated Column" = Table.DuplicateColumn(#"Today Dynamic", "Today", "SOW"),
    #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated Column",{{"SOW", Date.StartOfWeek, type date}}),
 
    #"Changed Type" =
        Table.TransformColumnTypes(#"Calculated Start of Week", {{"Container", type text}, {"Cont. Int. Num.", Int64.Type}, {"Storage Loc.", type text}, {"Transfer Pending TO", Int64.Type}, {"Date Of Request", type date}, {"Material", Int64.Type}, {"Quantity", Int64.Type}, {"Expect. Arrival Date", type date}, {"Container With Sever", type text}, {"PO", Int64.Type}, {"Vessel", type text}, {"Manifest", Int64.Type}, {"Count", Int64.Type}, {"Days in Country", Int64.Type}, {"Days In Place", Int64.Type}, {"Reception Date", type date}, {"Inb. Del.", Int64.Type}, {"Expected PGR", type date}, {"User", type text}, {"Mat. Descr.", type text}, {"Outb.Deliv.", Int64.Type}, {"Customer", Int64.Type}, {"Customer_1", type text}, {"Stock In QA Inspect.", type text}, {"Container Full Name", type text}, {"Today", type date}, {"SOW", type date}}),
 
    #"Added Custom Storage LOC" =
        Table.AddColumn(
            #"Changed Type",
            "Storage Location",
            each if [PO] = null then [#"Storage Loc."] else null,
            type text
        ),
 
    #"XXXAdded Storage Location Name" =
        Table.AddColumn(
            #"Added Custom Storage LOC",
            "Storage Location Name",
            each
                if [Storage Location] = "4672" then "Savannah Port"
                else if [Storage Location] = "467N" then "C&C"
                else if [Storage Location] = "467P" then "OPTIX"
                else if [Storage Location] = "4673" then "DHL YARD"
                else null,
            type text
        ),
 
    #"Removed Columns" =
        Table.RemoveColumns(
            #"XXXAdded Storage Location Name",
            {"Storage Loc.", "Mat. Descr."}
        ),
 
    //COUNTER ROUTINE
    #"Filtered Rows" =
        Table.SelectRows(
            #"Removed Columns",
            each [Storage Location] <> null
        ),
    #"Filtered Rows1" = Table.SelectRows(#"Filtered Rows", each [Container] <> null and [Container] <> ""),
    #"Grouped Rows" = Table.Group(#"Filtered Rows1", {"MRPSKU Key"}, {{"Counter", each Table.RowCount(_), Int64.Type}}),
    #"Sorted RowsCOUNTER" = Table.Sort(#"Grouped Rows",{{"Counter", Order.Descending}}),
    //END COUNTER
 
//START
    #"XXXFiltered Rows" =
        Table.SelectRows(
            #"Removed Columns",
            each [Storage Location] <> null
        ),
 
    /* =======================
       DAYS BUCKET (Days in Country)
       ======================= */
    #"Added Days Bucket" =
        Table.AddColumn(
            #"XXXFiltered Rows",
            "Days Bucket",
            each
                if [Days in Country] <= 30 then "0-30"
                else if [Days in Country] <= 60 then "31-60"
                else if [Days in Country] <= 90 then "61-90"
                else "91+",
                
            type text
        ),

    /* =======================
       STORAGE PRICE (UPDATED – includes Yard)
       ======================= */
    #"Added Storage Price" =
        Table.AddColumn(
            #"Added Days Bucket",
            "Storage Price",
            each
                if [Storage Location] = "4672" then
                    if [Days in Country] <= 30 then 0 else 422

                else if List.Contains({"467N", "467P"}, [Storage Location]) then
                    if [Days in Country] <= 60 then 7.5
                    else if [Days in Country] <= 90 then 15.5
                    else 37.5

                else if [Storage Location] = "4673" then
                    if [Days in Country] <= 60 then 0
                    else if [Days in Country] <= 90 then 8
                    else 30

                else
                    null,
            Currency.Type
        ),

    #"XXXDuplicated Column" =
        Table.DuplicateColumn(#"Added Storage Price", "SOW", "Combined Date"),

    #"XXXDuplicated Column1" =
        Table.DuplicateColumn(#"XXXDuplicated Column", "Quantity", "Combined Qty"),

    #"Added ""Remaining""" =
        Table.AddColumn(#"XXXDuplicated Column1", "Remaining?", each "Yes"),

    #"Added Data Source ID" =
        Table.AddColumn(#"Added ""Remaining""", "Data Source", each "YContainer"),

    #"Renamed Columns2" =
        Table.RenameColumns(#"Added Data Source ID", {{"Inb. Del.", "Inb.delivery"}}),

    #"XXXRemoved Columns1" =
        Table.RemoveColumns(
            #"Renamed Columns2",
            {
                "Cont. Int. Num.", "Transfer Pending TO", "Date Of Request",
                "Expect. Arrival Date", "Container With Sever", "PO",
                "Vessel", "Manifest", "Count", "User", "Outb.Deliv.",
                "Customer_1", "Stock In QA Inspect.", "Container Full Name"
            }
        ),

    #"Sorted Rows" =
        Table.Sort(#"XXXRemoved Columns1", {{"Inb.delivery", Order.Ascending}}),

    #"Reordered Columns" =
        Table.ReorderColumns(
            #"Sorted Rows",
            {
                "MRPSKU Key", "Container", "Material", "Quantity",
                "Days in Country", "Days In Place", "Days Bucket",
                "Storage Location", "Storage Location Name",
                "Storage Price",
                "Reception Date", "Inb.delivery", "Expected PGR",
                "Customer", "MRP Area", "Today",
                "SOW", "Combined Date", "Combined Qty",
                "Remaining?", "Data Source"
            }
        ),

    #"Changed Type1" =
        Table.TransformColumnTypes(#"Reordered Columns",{{"MRPSKU Key", type text}, {"Material", type text}, {"Inb.delivery", type text}}),
    XXXCustom1 = Table.AddColumn(#"Changed Type1", "SLO Combined", each Text.Combine({[Storage Location], [Storage Location Name]}, ": "), type text),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(XXXCustom1, "Target DOS", each #"Target DOS"), {{"Target DOS", Int64.Type}}),
    #"Merged Queries1" = Table.NestedJoin(#"Added custom", {"Material"}, #"DIM YCONT - MB52 MAT", {"Material"}, "DIM YCONT - MB52 MAT", JoinKind.LeftOuter),
  #"Expanded DIM YCONT - MB52 MAT" = Table.ExpandTableColumn(#"Merged Queries1", "DIM YCONT - MB52 MAT", {"DHL + YARD Qty", "ADS NUMERATOR MAX", "DHL + YARD DOS"}, {"DHL + YARD Qty", "ADS NUMERATOR MAX", "DHL + YARD DOS"}),
    #"Merged Queries2" = Table.NestedJoin(#"Expanded DIM YCONT - MB52 MAT", {"MRPSKU Key"}, #"DIM YCONT - YS10N", {"MRPSKU Key"}, "DIM YCONT - YS10N", JoinKind.LeftOuter),
  #"Expanded DIM YCONT - YS10N" = Table.ExpandTableColumn(
    #"Merged Queries2",
    "DIM YCONT - YS10N",
    {"_YS10N DHL 7 PQ", "Open Order DOS","ADS NUMERATOR"},
    {"_YS10N DHL 7 PQ", "Open Order DOS","ADS NUMERATOR"}
),
  #"Merged queries 1" = Table.NestedJoin(#"Expanded DIM YCONT - YS10N", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged queries 1", "DIM Product", {"Cont_Qty", "ECOM Flag"}, {"DIM Product.Cont_Qty", "DIM Product.ECOM Flag"}),
  #"half continer qty" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Expanded DIM Product",
        "ECOM Half Qty",
        each if [#"DIM Product.ECOM Flag"] = true
             then [#"DIM Product.Cont_Qty"] / 2
             else null
    ),
    {{"ECOM Half Qty", type number}}
),
  #"add to open orders" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"half continer qty",
        "ADD TO OPEN ORDERS",
        each
            let
                EcomQty = try Number.From([ECOM Half Qty]) otherwise null,
                ADS = try Number.From([ADS NUMERATOR]) otherwise null,

                Calc =
                    if EcomQty = null or ADS = null or ADS = 0
                    then null
                    else EcomQty / (ADS / 140)
            in
                if Calc = null then 0 else Calc
    ),
    {{"ADD TO OPEN ORDERS", type number}}
),
  #"add open orders" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"add to open orders",
        "Open orders 2",
        each
            if [Open Order DOS] = null
                or [ADD TO OPEN ORDERS] = null
            then 2
            else [Open Order DOS] + [ADD TO OPEN ORDERS]
    ),
    {{"Open orders 2", type number}}
),
  #"Added custom 1" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"add open orders",
        "new_YS10nDHL 7 PQ",
        each
            (if [#"_YS10N DHL 7 PQ"] = null then 0 else [#"_YS10N DHL 7 PQ"])
            +
            (if [ECOM Half Qty] = null then 0 else [ECOM Half Qty])
    ),
    {{"new_YS10nDHL 7 PQ", type number}}
),
  #"Renamed columns" = Table.RenameColumns(#"Added custom 1", {{"_YS10N DHL 7 PQ", "_YS10N DHL 7 PQog"}, {"new_YS10nDHL 7 PQ", "_YS10N DHL 7 PQ"}}),
  #"Remove Open ORders" = Table.RemoveColumns(#"Renamed columns", {"Open Order DOS"}),
  #"Get open orders again" = Table.RenameColumns(#"Remove Open ORders", {{"Open orders 2", "Open Order DOS"}}),
  #"Merged queries" = Table.NestedJoin(#"Get open orders again", {"Inb.delivery", "Material"}, #"DIM Counter PQ", {"Inb. Del.", "Material"}, "DIM Counter PQ", JoinKind.LeftOuter),
  #"Replaced value 5" = Table.ReplaceValue(#"Merged queries", null, 0, Replacer.ReplaceValue, {"Open Order DOS"}),
  #"Move DOS Container" = Table.AddColumn(#"Replaced value 5", "Move DOS", each [Quantity]/([ADS NUMERATOR MAX]/140),type number
),
  #"Expanded DIM Counter PQ" = Table.ExpandTableColumn(#"Move DOS Container", "DIM Counter PQ", {"Material_InbDel_Index"}, {"_Counter"}),
    #"Replaced Value" = Table.ReplaceValue(#"Expanded DIM Counter PQ",null,0,Replacer.ReplaceValue,{"_YS10N DHL 7 PQ"}),
    #"Replaced Value1" = Table.ReplaceValue(#"Replaced Value",null,0,Replacer.ReplaceValue,{"DHL + YARD Qty"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Replaced Value1", null, 0, Replacer.ReplaceValue, {"DHL + YARD DOS"}),
  #"Replaced value 2" = Table.ReplaceValue(#"Replaced value 1", null, 0, Replacer.ReplaceValue, {"Move DOS"}),
  #"Replaced value 4" = Table.ReplaceValue(#"Replaced value 2", null, 999, Replacer.ReplaceValue, {"_Counter"}),
      #"DOS 15 Days PQ" = Table.AddColumn(#"Replaced value 4", "Target DOS 15", each 15, Int64.Type),
    #"Init Sales Pull Date" = Table.AddColumn(#"DOS 15 Days PQ", "Init Sales Pull Date", 
each if [_YS10N DHL 7 PQ] > [#"DHL + YARD Qty"] and [Storage Location] = "4672" then [Today]
else if [Expected PGR] > [Today] then [Expected PGR]
else [Today]),
    #"Sales Pull Date" = Table.AddColumn(#"Init Sales Pull Date", "Sales Pull Date", 
each if [#"DHL + YARD Qty"] + [Combined Qty] < [_YS10N DHL 7 PQ] then [Init Sales Pull Date]
else null),
    #"Init DOS Pull Date" = Table.AddColumn(
    #"Sales Pull Date",
    "Init DOS Pull Date",
    each if [Storage Location] <> "4673" 
         then List.Max({Date.AddDays([Today], List.Max({[#"DHL + YARD DOS"] - 15, 0})),[Expected PGR]})
         else null
)



,
    #"DOS Pull Date" = Table.AddColumn(
    #"Init DOS Pull Date",
    "DOS Pull Date",
    each 
        let
            moveDays = try Number.RoundUp(Number.From([Move DOS]), 0) otherwise 0
        in
            if [Init DOS Pull Date] = null then [Expected PGR]
            else if [Expected PGR] > Date.AddDays([Init DOS Pull Date], moveDays) 
                 then [Expected PGR]
            else Date.AddDays([Init DOS Pull Date], moveDays)
)

,
    #"P1 Containers" = Table.AddColumn(#"DOS Pull Date", "_P1 Container PQ", 
        each if [#"DHL + YARD Qty"] + (([_Counter]-1)*[Combined Qty]) > ([_YS10N DHL 7 PQ]+[Combined Qty]) then 0 
            else ([_YS10N DHL 7 PQ] - [#"DHL + YARD Qty"])/ [Combined Qty]),
    #"P1 Marker (Sales Pull Date)" = Table.AddColumn(#"P1 Containers", "_P1 Marker PQ", each if [_Counter] <= Number.RoundUp([_P1 Container PQ]) then
        [Today]
        else if [_Counter] = 1 and [#"DHL + YARD DOS"] < 1 then
            [Today]
        else
            null),
    // #"P2 Marker (Port Age Date)" = Table.AddColumn(#"P1 Marker (Sales Pull Date)", "_P2 Marker PQ", 
    //     each if [Storage Location] <> "4672" then null 
    //     // 6/30/2026: update from 28 to 19 days (2 day buffer)
    //     // 7/1/2026: change back to 28 days until July 14
    //     else if Date.AddDays([Today],-[Days In Place]+28) <= [Today] and [Storage Location] = "4672"  then [Today]
    //     else if [Storage Location] = "4672" then Date.AddDays([Today],-[Days In Place]+28)
    //     // changed from on 2.7.26 at 5:40 PM, meeting with Justin - stated that only 4672 can be a P2 in Next Move Date: [Storage Location] = "467N" then  Date.AddDays([Expected PGR],28)
    //     else if [Storage Location] = "467N" then Date.AddDays([Expected PGR],[Days in Country])
    //     else if [Storage Location] <> "4672" and [Today]>[Expected PGR] then Date.AddDays([Today],28) 
    //     else if [Storage Location] <> "4672" and [Today]<=[Expected PGR] then Date.AddDays([Expected PGR],28) 
    
    // 7/14/2026 CJ: make port free days dynamic
    #"P2 Marker (Port Age Date)" =
    Table.AddColumn(
        #"P1 Marker (Sales Pull Date)",
        "_P2 Marker PQ",
        each
            let
                PortFreeDays =
                    if [Reception Date] < #date(2026, 7, 1)
                    then 28
                    else 19
            in
                if [Storage Location] <> "4672" then null

                else if Date.AddDays([Today], -[Days In Place] + PortFreeDays) <= [Today]
                    and [Storage Location] = "4672"
                    then [Today]

                else if [Storage Location] = "4672"
                    then Date.AddDays([Today], -[Days In Place] + PortFreeDays)

                // changed from on 2.7.26 at 5:40 PM, meeting with Justin - stated that only 4672 can be a P2 in Next Move Date
                // [Storage Location] = "467N" then Date.AddDays([Expected PGR], PortFreeDays)

                else if [Storage Location] = "467N"
                    then Date.AddDays([Expected PGR], [Days in Country])

                else if [Storage Location] <> "4672"
                    and [Today] > [Expected PGR]
                    then Date.AddDays([Today], PortFreeDays)

                else if [Storage Location] <> "4672"
                    and [Today] <= [Expected PGR]
                    then Date.AddDays([Expected PGR], PortFreeDays)

                else Date.AddDays([Today], PortFreeDays)
    ),

    //     else Date.AddDays([Today], 28)),
    // #"P2 Marker (Port Age Date)" =
    //     Table.AddColumn(
    //         #"P1 Marker (Sales Pull Date)",
    //         "_P2 Marker PQ",
    //         each
    //             let
    //                 // 6/30/2026: update from 28 to 19 days (2 day buffer)
    //                 // 7/1/2026: change back to 28 days until July 14
    //                 PortFreeDays = 28
    //             in
    //                 if [Storage Location] <> "4672" then null

    //                 else if Date.AddDays([Today], -[Days In Place] + PortFreeDays) <= [Today]
    //                     and [Storage Location] = "4672"
    //                     then [Today]

    //                 else if [Storage Location] = "4672"
    //                     then Date.AddDays([Today], -[Days In Place] + PortFreeDays)

    //                 // changed from on 2.7.26 at 5:40 PM, meeting with Justin - stated that only 4672 can be a P2 in Next Move Date
    //                 // [Storage Location] = "467N" then Date.AddDays([Expected PGR], PortFreeDays)

    //                 else if [Storage Location] = "467N"
    //                     then Date.AddDays([Expected PGR], [Days in Country])

    //                 else if [Storage Location] <> "4672"
    //                     and [Today] > [Expected PGR]
    //                     then Date.AddDays([Today], PortFreeDays)

    //                 else if [Storage Location] <> "4672"
    //                     and [Today] <= [Expected PGR]
    //                     then Date.AddDays([Expected PGR], PortFreeDays)

    //                 else Date.AddDays([Today], PortFreeDays)
    //     ),
    
/*#"P3 Marker (DOS Pull Date)" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"P2 Marker (Port Age Date)",
        "_P3 Marker PQ",
        each 
            let
                safeDHL = try Number.From([#"DHL + YARD DOS"]) otherwise null,
                safeOpen = try Number.From([Open Order DOS]) otherwise null,
                safeCounter = try Number.From([_Counter]) otherwise null,
                safeMove = try Number.From([Move DOS]) otherwise null,

                baseCalc = 
                    if safeDHL <> null and safeOpen <> null and safeCounter <> null and safeMove <> null then
                        Number.RoundDown(
                            (safeDHL - safeOpen) + (safeCounter * safeMove),
                            0
                        )
                    else 
                        null,

                offset = if baseCalc <> null then baseCalc - 15 else null,

                safeDate =
                    if offset = null 
                        or offset > 36500     // ~100 years forward
                        or offset < -36500    // ~100 years backward
                    then null
                    else Date.AddDays([Today], offset)

            in
                if safeCounter = 1 and baseCalc <> null and baseCalc < 15 then
                    [Today]
                else if baseCalc <> null and baseCalc < 15 then
                    [Today]
                else
                    safeDate
    ),
    {{"_P3 Marker PQ", type date}}
)

,*/


#"P3 Marker (DOS Pull Date)" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"P2 Marker (Port Age Date)",
        "_P3 Marker PQ",
        each
            let
                safeDHL = try Number.From([#"DHL + YARD DOS"]) otherwise null,
                safeOpen = try Number.From([Open Order DOS]) otherwise null,
                safeCounter = try Number.From([_Counter]) otherwise null,
                safeMove = try Number.From([Move DOS]) otherwise null,
 
                baseCalc =
                    if safeDHL <> null and safeOpen <> null and safeCounter <> null and safeMove <> null then
                        Number.RoundDown(
                            (safeDHL - safeOpen) + ((safeCounter-1) * safeMove),
                            0
                        )
                    else
                        null,
 
                offset = if baseCalc <> null then baseCalc - 15 else null,
 
                safeDate =
                    if offset = null
                        or offset > 36500     // ~100 years forward
                        or offset < -36500    // ~100 years backward
                    then null
                    else Date.AddDays([Today], offset)
 
            in
                if safeCounter = 1 and baseCalc <> null and baseCalc < 15 then
                    [Today]
                else if baseCalc <> null and baseCalc < 15 then
                    [Today]
                else
                    safeDate
    ),
    {{"_P3 Marker PQ", type date}}
)
 
,
   
    #"P4 Marker (Depot Age Date)" = Table.AddColumn(
    #"P3 Marker (DOS Pull Date)",
    "_P4 Marker PQ",
    each
        let
            daysInPlace = [Days In Place],
            reception   = [Reception Date],
            today       = [Today],
            sloc        = [Storage Location],

            result =
                if daysInPlace = 0 then
                    if reception = null then null else Date.AddDays(reception, 86)
                else if sloc = "467N" or sloc = "467P" then
                    let
                        candidate = Date.AddDays(today, Number.From(59 - daysInPlace))
                    in
                        if candidate < today then today else candidate
                else if sloc = "4672" then
                    let
                        candidate = Date.AddDays(today, Number.From(86 - daysInPlace))   // 27+59 = 86
                    in
                        if candidate < today then today else candidate
                else
                    null
        in
            result
),
    #"Depot Age Date" = Table.AddColumn(#"P4 Marker (Depot Age Date)", "Depot Age Date", 
each if [Storage Location] = "4672" or [Storage Location] is null then Date.AddDays([_P2 Marker PQ], 60) 
else if [Storage Location] = "467N" or [Storage Location] = "467P" then Date.AddDays([Today], 60 - [Days In Place]) else null),
    #"Next Move Date" = Table.AddColumn(#"Depot Age Date","_Next Move Date PQ",
        each let dates = List.RemoveNulls({[_P1 Marker PQ],[_P2 Marker PQ],[_P3 Marker PQ],[_P4 Marker PQ]})
        in if List.IsEmpty(dates) then null 
        else List.Min(dates),type date),
    _Priority = Table.AddColumn(#"Next Move Date", "_Priority PQ", each if [_Next Move Date PQ] = null then null else if [_Next Move Date PQ] = [_P1 Marker PQ] then "Priority 1 - Sales" else if [_Next Move Date PQ] = [_P2 Marker PQ] then "Priority 2 - Port Aging" else if [_Next Move Date PQ] = [_P3 Marker PQ] then "Priority 3 - Low Inventory" else if [_Next Move Date PQ] = [_P4 Marker PQ] then "Priority 4 - Depot Aging" else null),
    #"Init Next Move Date" = Table.AddColumn(
    _Priority,
    "Init Next Move Date",
    each
        let
            initSales = [Init Sales Pull Date],
            portAge   = [_P2 Marker PQ],
            depotAge  = [Depot Age Date],
            dosPull   = [_P3 Marker PQ],

            // Helper: minimum of non-null dates
            minDate =
                (lst as list) as nullable date =>
                    let
                        cleaned = List.RemoveNulls(lst)
                    in
                        if List.Count(cleaned) = 0 then null else List.Min(cleaned)
        in
            if initSales <> null then
                initSales
            else if portAge = null then
                if depotAge = null then dosPull else minDate({depotAge, dosPull})
            else
                minDate({dosPull, depotAge, portAge}),
    type date
),
    #"Changed Type2" = Table.TransformColumnTypes(#"Init Next Move Date", {{"_P1 Marker PQ", type date}, {"_P2 Marker PQ", type date}, {"_P3 Marker PQ", type date}, {"_P4 Marker PQ", type date}, {"_Priority PQ", type text}, {"Depot Age Date", type date}, {"DOS Pull Date", type date}, {"Init DOS Pull Date", type date}, {"Sales Pull Date", type date}, {"Init Sales Pull Date", type date}}),
    #"Inserted Date Subtraction" = Table.AddColumn(#"Changed Type2", "Subtraction", each Duration.Days([_P3 Marker PQ] - [_P2 Marker PQ]), Int64.Type),
  #"Replaced value 3" = Table.ReplaceValue(#"Inserted Date Subtraction", null, 0, Replacer.ReplaceValue, {"Subtraction"}),
    #"Move Type" = Table.AddColumn(#"Replaced value 3", "Move Type", 
each if [Storage Location] = "467N" then "Move to DHL"
else if [_Priority PQ]= "Priority 1 - Sales" then "Move to DHL"
else if [Subtraction] <=3  then "Move to DHL"
else if [Subtraction] > 3  then "Move to Depot"
else if [_P2 Marker PQ] = null then "Move to DHL"
else if
Duration.Days([Init Next Move Date] - [_P2 Marker PQ]) >= -2 and [DOS Pull Date] <> [_Next Move Date PQ] then "Move to Depot" else "Move to DHL", type text),
  #"Inserted merged column" = Table.AddColumn(#"Move Type", "_Priority & Move Type", each Text.Combine({[_Priority PQ], [Move Type]}, ": "), type text),
  #"Changed column type" = Table.TransformColumnTypes(#"Inserted merged column", {{"MRPSKU Key", type text}, {"MRP Area", type text}, {"Remaining?", type text}, {"Data Source", type text}, {"_P1 Container PQ", type date}})
in
    #"Changed column type";
shared #"DIM YCONT - MB52 MAT" = let
  #"Merged Queries" = Table.NestedJoin(#"FACT MB52", {"MRPSKU Key"}, #"FACT ADS NUMERATOR", {"MRPSKU Key"}, "FACT ADS NUMERATOR", JoinKind.LeftOuter),
  #"Filtered Rows1" = Table.SelectRows(#"Merged Queries", each ([Storage Location] = "4673" or [Storage Location] = "4674")),
  /*#"Filtered Rows1" = Table.SelectRows(#"Filtered rows", each (Cube.AttributeMemberId([Storage Location]) = "[MB52 Stock_Value].[Storage Location].&[4673]" meta [DisplayName = "4673"] or Cube.AttributeMemberId([Storage Location]) = "[MB52 Stock_Value].[Storage Location].&[4674]" meta [DisplayName = "4674"])),*/
  #"Grouped Rows" = Table.Group(#"Filtered Rows1", {"Material"}, {{"DHL + YARD Qty", each List.Sum([Combined Qty]), type nullable number}, {"ADS NUMERATOR MAX", each List.Max([ADS NUMERATOR]), type nullable number}}),
  #"Inserted Division" = Table.AddColumn(#"Grouped Rows", "DHL + YARD DOS", each [#"DHL + YARD Qty"] / ([ADS NUMERATOR MAX]/140), type number),
#"Changed column type" = Table.TransformColumnTypes(#"Inserted Division", {{"DHL + YARD DOS", Int64.Type}})
in
    #"Changed column type";
shared #"DIM YCONT - YS10N" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT YS10N Open", ItemKind = "Table"]}[Data],
    #"Filtered Rows1" = Table.SelectRows(#"Navigation 2", each [MRP Area] = "67_4674 - DHL"),
    #"WHERE YOU ADD 7 DAYS" = Table.AddColumn(#"Filtered Rows1", "Today + 7", each Date.AddDays([Today],5)),
    #"Changed Type2" = Table.TransformColumnTypes(#"WHERE YOU ADD 7 DAYS",{{"Today + 7", type date}}),
    #"Added Conditional Column" = Table.AddColumn(#"Changed Type2", "Within Today + 7?", each if [Combined Date] <= [#"Today + 7"] then "Yes" else "No", type text),
    #"Filtered Rows2" = Table.SelectRows(#"Added Conditional Column", each ([#"Within Today + 7?"] = "Yes")),
    #"Grouped Rows" = Table.Group(#"Filtered Rows2", {"MRPSKU Key"}, {{"_YS10N DHL 7 PQ", each List.Sum([Combined Qty])*-1, type number}}),
  #"Merged queries" = Table.NestedJoin(#"Grouped Rows", {"MRPSKU Key"}, #"FACT ADS NUMERATOR", {"MRPSKU Key"}, "FACT ADS NUMERATOR", JoinKind.LeftOuter),
  #"Expanded FACT ADS NUMERATOR" = Table.ExpandTableColumn(#"Merged queries", "FACT ADS NUMERATOR", {"ADS NUMERATOR"}, {"ADS NUMERATOR"}),
  #"Find Material" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded FACT ADS NUMERATOR", "material", each Text.Middle(
        [MRPSKU Key],
        Text.PositionOf([MRPSKU Key], "|") + 1,
        6
    )), {{"material", type text}}),
  #"Open Order DOS Calculation (last)" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Find Material",
        "Open Order DOS",
        each
            let
                Result = try [#"_YS10N DHL 7 PQ"] / ([#"ADS NUMERATOR"] / 140) otherwise null
            in
                if Result = null then 10 else Result
    ),
    {{"Open Order DOS", type number}}
)
,
  #"MOVE DOS" = Table.AddColumn(#"Open Order DOS Calculation (last)", "Move DOS", each Number.IntegerDivide([_YS10N DHL 7 PQ], 7), Int64.Type)
in
    #"MOVE DOS";
shared #"DIM Counter PQ" = let
    // ================================
    // SOURCE: SharePoint Excel
    // ================================
    Source =
        Excel.Workbook(
            Web.Contents(
                "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Y%20Container%20Daily%20Pull.xlsx"
            ),
            null,
            false
        ),

    Sheet1_sheet = Source{[Item="Sheet1", Kind="Sheet"]}[Data],

    FilterNullAndWhitespace =
        each
            List.Select(
                _,
                each _ <> null and (not (_ is text) or Text.Trim(_) <> "")
            ),

    #"Removed Bottom Rows" =
        Table.RemoveLastN(
            Sheet1_sheet,
            each
                try
                    List.IsEmpty(
                        List.Skip(
                            FilterNullAndWhitespace(Record.FieldValues(_)),
                            1
                        )
                    )
                otherwise false
        ),

    #"Promoted Headers" =
        Table.PromoteHeaders(
            #"Removed Bottom Rows",
            [PromoteAllScalars = true]
        ),

    #"Filtered Rows1" =
        Table.SelectRows(#"Promoted Headers", each ([Container] <> null and [Container] <> "") and ([#"Storage Loc."] <> "4673")),

    #"Removed Other Columns" =
        Table.SelectColumns(
            #"Filtered Rows1",
            {"Material", "Inb. Del.", "Container", "Storage Loc.", "PO"}
        ),

    // ================================
    // INDEX LOGIC (Reset by Material)
    // ================================

    // Sort by Material then Inb. Del. so index is deterministic
    Sorted =
        Table.Buffer(Table.Sort(
            #"Removed Other Columns",
            {
                {"Material", Order.Ascending},{"PO", Order.Ascending},
                {"Inb. Del.", Order.Ascending}, 
                {"Container", Order.Ascending}
            }
        )),

    // Group ONLY by Material so the index increments across all Inb. Del. values
    Grouped =
        Table.Group(
            Sorted,
            {"Material"},
            {
                {
                    "Data",
                    (t as table) as table =>
                        Table.AddIndexColumn(
                            t,
                            "Material_InbDel_Index",
                            1,
                            1,
                            Int64.Type
                        ),
                    type table
                }
            }
        ),

    // Expand back to flat table
    Expanded =
        Table.ExpandTableColumn(
            Grouped,
            "Data",
            {"Inb. Del.", "Container", "Material_InbDel_Index"},
            {"Inb. Del.", "Container", "Material_InbDel_Index"}
        ),
    #"Changed Type" = Table.TransformColumnTypes(Expanded,{{"Inb. Del.", type text}, {"Container", type text}, {"Material_InbDel_Index", Int64.Type}}),
    #"Inserted Merged Column" = Table.AddColumn(#"Changed Type", "MAT-INB Merge", each Text.Combine({ [Material],   [#"Inb. Del."]}, "|"), type text),
    #"Sorted Rows" = Table.Sort(#"Inserted Merged Column",{{"MAT-INB Merge", Order.Ascending}})
in
    #"Sorted Rows";
shared #"Target DOS" = 15 meta [IsParameterQuery=true, Type="Any", IsParameterQueryRequired=true];
shared #"Component Forecast Initial" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT Component Forecast Initial", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
[BindToDefaultDestination = true]
shared #"FACT ADS NUMERATOR" = let
    // 1. Combine source tables
    //FACT EDB APO Forecast
    Source = #"Component Forecast Initial",
    #"Today + 140" = Table.AddColumn(Source, "Today + 140", each Date.AddDays([Today],140), type date),
  #"Today7WK + 140" = Table.AddColumn(#"Today + 140", "Today7WK + 140", each Date.AddDays([Today], 189), type date),
  #"Today20WK + 140" = Table.AddColumn(#"Today7WK + 140", "Today20WK + 140", each  Date.AddDays([Today], 280), type date),
    #"ADS Numerator Splits" = Table.AddColumn(#"Today20WK + 140", "Date Range Check", 
each if [Combined Date] >= Date.AddDays([Today], 49) and [Combined Date] <= [#"Today + 140"] then "7WK ADS_NUM 1"
else if [Combined Date] >= [Today] and [Combined Date] <= [#"Today + 140"] then "Base ADS_N" 
else if [Combined Date] >= Date.AddDays([Today], 49) and [Combined Date] <= [#"Today7WK + 140"] then "7WK ADS_NUM 2"
else if [Combined Date] >= [#"Today + 140"] and [Combined Date] <= [#"Today20WK + 140"] then "20WK ADS_NUM"
else null, type text),
  #"BASE ADS NUM" = Table.AddColumn(#"ADS Numerator Splits", "Base ADS NUM", 
each if [Combined Date] >= [Today] and [Combined Date] <= [#"Today + 140"] then [Combined Qty]
else 0),
  #"7WK ADS NUM" = Table.AddColumn(#"BASE ADS NUM", "7WK ADS NUM", 
each if [Date Range Check] = "7WK ADS_NUM 2" then [Combined Qty] 
else if [Date Range Check] = "7WK ADS_NUM 1" then [Combined Qty] 
else 0, Int64.Type),
  #"20WK ADS NUM" = Table.AddColumn(#"7WK ADS NUM", "20WK ADS NUM", 
each if [Date Range Check] = "7WK ADS_NUM 2" then [Combined Qty] 
else if [Date Range Check] = "20WK ADS NUM" then [Combined Qty] 
else 0, Int64.Type),
  #"Grouped rows" = Table.Group(#"20WK ADS NUM", {"MRPSKU Key"}, {{"ADS NUMERATOR", each -1* List.Sum([Base ADS NUM]), type nullable number}, {"7WK ADS NUMERATOR", each -1*List.Sum([7WK ADS NUM]), type nullable number}, {"20WK ADS NUMERATOR", each -1* List.Sum([20WK ADS NUM]), type nullable number}}),
    #"Changed Type3" = Table.TransformColumnTypes(#"Grouped rows",{{"MRPSKU Key", type text}}),
  #"Replaced value" = Table.ReplaceValue(#"Changed Type3", 0, null, Replacer.ReplaceValue, {"ADS NUMERATOR"})
in
    #"Replaced value";
[BindToDefaultDestination = true]
shared #"FACT MB52" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "FACT MB52 All", ItemKind = "Table"]}[Data],
  #"Merged Queries" = Table.NestedJoin(#"Navigation 3", {"MRPSKU Key"}, #"FACT ADS NUMERATOR", {"MRPSKU Key"}, "FACT ADS NUMERATOR", JoinKind.LeftOuter),
  #"Expanded FACT ADS NUMERATOR" = Table.ExpandTableColumn(#"Merged Queries", "FACT ADS NUMERATOR", {"ADS NUMERATOR"}, {"ADS NUMERATOR"}),
  #"Added Custom" = Table.AddColumn(#"Expanded FACT ADS NUMERATOR", "_DOS MB52", each [Combined Qty]/([ADS NUMERATOR]/140), type number),
  AddYearColumn = Table.AddColumn(#"Added Custom", "Year", each Date.Year([Combined Date]), Int64.Type),
  #"Renamed columns" = Table.RenameColumns(AddYearColumn, {{"Blocked", "Blocked_Qty"}})
in
  #"Renamed columns";
shared DefaultDestination = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
