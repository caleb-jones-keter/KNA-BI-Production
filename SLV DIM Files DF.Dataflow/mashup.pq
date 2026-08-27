[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM USA CA Zips_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM USA CA Zips" = let
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Id = "USA CAN Zips", ItemKind = "Table"]}[Data],

    // #"Postal Code Clean" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "Postal Code Clean", each let
    //         zip = try Record.Field(_, "POSTAL_CODE") otherwise null,
    //         noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
    //         hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
    //         result = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces
    //     in
    //         result), {{"Postal Code Clean", type text}}),

    // updates to pad US zip codes with 0 up to 5 characters 
    #"Postal Code Clean" = Table.TransformColumnTypes(
        Table.AddColumn(
            #"Navigation 2",
            "Postal Code Clean",
            each
                let
                    zip = try Record.Field(_, "POSTAL_CODE") otherwise null,
                    noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
                    hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
                    cleanedZip = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces,

                    // If numeric, assume US ZIP and pad to 5 digits
                    result =
                        if cleanedZip <> null
                            and Text.Select(cleanedZip, {"0".."9"}) = cleanedZip
                        then
                            Text.PadStart(cleanedZip, 5, "0")
                        else
                            cleanedZip
                in
                    result
        ),
        {{"Postal Code Clean", type text}}
    ),

    Grouped = Table.Group(
        #"Postal Code Clean",
        {"POSTAL_CODE", "Postal Code Clean", "REGION", "LATITUDE", "LONGITUDE"},
        {
            {"City List", each Text.Combine([CITY], ", "), type text}
        }
    ),
    #"Removed duplicates" = Table.Distinct(Grouped, {"Postal Code Clean"}),

    #"Postal Code Country" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Removed duplicates",
                "Postal Code Country",
                each
                    if [Postal Code Clean] <> null
                        and Text.Select([Postal Code Clean], {"0".."9"}) = [Postal Code Clean]
                    then "USA"
                    else "CAN"
            ),
            {{"Postal Code Country", type text}}
        ),

    #"Padded POSTAL_CODE" =
        Table.AddColumn(
            #"Postal Code Country",
            "POSTAL_CODE_NEW",
            each
                let
                    txt = Text.From([POSTAL_CODE]),
                    beforeDash =
                        if Text.Contains(txt, "-")
                        then Text.BeforeDelimiter(txt, "-")
                        else txt,

                    afterDash =
                        if Text.Contains(txt, "-")
                        then "-" & Text.AfterDelimiter(txt, "-")
                        else "",

                    paddedBeforeDash =
                        if [Postal Code Country] = "USA"
                            and Text.Length(beforeDash) <= 5
                        then Text.PadStart(beforeDash, 5, "0")
                        else beforeDash
                in
                    paddedBeforeDash & afterDash,
            type text
        ),

    #"Removed Original POSTAL_CODE" =
        Table.RemoveColumns(
            #"Padded POSTAL_CODE",
            {"POSTAL_CODE"}
        ),

    #"Renamed POSTAL_CODE" =
        Table.RenameColumns(
            #"Removed Original POSTAL_CODE",
            {{"POSTAL_CODE_NEW", "POSTAL_CODE"}}
        ),

    #"DHL Distance" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed POSTAL_CODE", "Distance from DHL", each let
        STARTLAT = 32.263, // Replace with your starting latitude
        STARTLONG = -81.235, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c
    in
        distance), {{"Distance from DHL", Int64.Type}}),
    #"SpreeTail Vegas Distance" = Table.TransformColumnTypes(Table.AddColumn(#"DHL Distance", "Distance from SpreeTail Vegas", each let
        STARTLAT = 36.1699, // Replace with your starting latitude
        STARTLONG = -115.1398, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c
    in
        distance), {{"Distance from SpreeTail Vegas", Int64.Type}}),

    #"Spreetail Nanticoke Distance" = Table.TransformColumnTypes(Table.AddColumn(#"SpreeTail Vegas Distance", "Distance from SpreeTail Nanticoke", each let
        STARTLAT = 41.2, // Replace with your starting latitude
        STARTLONG = -76, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c

    in
        distance), {{"Distance from SpreeTail Nanticoke", Int64.Type}}),

    // 6/17/2026 - CJ: add other SpreeTail locations

    #"SpreeTail Tacoma Distance" = Table.TransformColumnTypes(Table.AddColumn(#"Spreetail Nanticoke Distance", "Distance from SpreeTail Tacoma", each let
        STARTLAT = 47.2529, // Replace with your starting latitude
        STARTLONG = -122.4443, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c

    in
        distance), {{"Distance from SpreeTail Tacoma", Int64.Type}}),

    #"SpreeTail Greenwood Distance" = Table.TransformColumnTypes(Table.AddColumn(#"SpreeTail Tacoma Distance", "Distance from SpreeTail Greenwood", each let
        STARTLAT = 39.64, // Replace with your starting latitude
        STARTLONG = -86.13, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c

    in
        distance), {{"Distance from SpreeTail Greenwood", Int64.Type}}),

    #"SpreeTail Ellabell Distance" = Table.TransformColumnTypes(Table.AddColumn(#"SpreeTail Greenwood Distance", "Distance from SpreeTail Ellabell", each let
        STARTLAT = 32.12, // Replace with your starting latitude
        STARTLONG = -81.49, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c

    in
        distance), {{"Distance from SpreeTail Ellabell", Int64.Type}}),

    #"Ranchero Distance" = Table.TransformColumnTypes(Table.AddColumn(#"SpreeTail Ellabell Distance", "Distance from Rancho", each let
        STARTLAT = 33.874, // Replace with your starting latitude
        STARTLONG = -118.2117, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c
    in
        distance), {{"Distance from Rancho", Int64.Type}}),

    // CJ 8/17/2026: add Anderson distance
    #"Anderson Distance" = Table.TransformColumnTypes(Table.AddColumn(#"Ranchero Distance", "Distance from Anderson", each let
        STARTLAT = 40.95, // Replace with your starting latitude
        STARTLONG = -85.28, // Replace with your starting longitude
        R = 3958.8, // Earth radius in miles
        lat1 = Number.From(STARTLAT) * Number.PI / 180,
        lon1 = Number.From(STARTLONG) * Number.PI / 180,
        lat2 = Number.From([LATITUDE]) * Number.PI / 180,
        lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
        dlat = lat2 - lat1,
        dlon = lon2 - lon1,
        a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
        c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
        distance = R * c

    in
        distance), {{"Distance from Anderson", Int64.Type}}),

    #"Min. Distance" = Table.AddColumn(#"Anderson Distance", "Min. Distance", each List.Min({[Distance from DHL], [Distance from SpreeTail Vegas], [Distance from SpreeTail Nanticoke], [Distance from Rancho], [Distance from SpreeTail Tacoma], [Distance from SpreeTail Greenwood], [Distance from SpreeTail Ellabell] }), type number),
    #"Min Distance Source" = Table.TransformColumnTypes(
        Table.AddColumn(
            #"Min. Distance",
            "Min Distance Source",
            each
                let
                    minDist = [#"Min. Distance"],
                    cols = {
                        "Distance from DHL",
                        "Distance from SpreeTail Vegas",
                        "Distance from SpreeTail Nanticoke",
                        "Distance from SpreeTail Tacoma",
                        "Distance from SpreeTail Greenwood",
                        "Distance from SpreeTail Ellabell",
                        "Distance from Rancho"
                    },
                    match = List.Select(cols, (c) => Record.Field(_, c) = minDist)
                in
                    if List.Count(match) > 0
                    then Text.AfterDelimiter(match{0}, "Distance from ")
                    else null
        ),
        {{"Min Distance Source", type text}}
    ),
    // CJ 7/20/2026: moved logic up to flow better
    // #"Postal Code Country" = Table.TransformColumnTypes(Table.AddColumn(#"Min Distance Source", "Postal Code Country", each if Text.Length([#"Postal Code Clean"]) = 5 then "USA" else if Text.Length([#"Postal Code Clean"]) = 6 then "CAN" else null), {{"Postal Code Country", type text}}),
    
    DHLRate    = try #"DHL DAT Rate"{0}[Rate] otherwise null,
    RanchoRate = try #"Rancho DAT Rate"{0}[Rate] otherwise null,
    AndersonRate = try #"Anderson DAT Rate"{0}[Rate] otherwise null,
    WithRates = Table.AddColumn(#"Min Distance Source", "DHL DAT Rate", each DHLRate, type number),
    WithRates2 = Table.AddColumn(WithRates, "Rancho DAT Rate", each RanchoRate, type number),
    WithRates3 = Table.AddColumn(WithRates2, "Anderson DAT Rate", each AndersonRate, type number),
    WithCosts = Table.AddColumn(WithRates3, "DHL TL Cost", each [Distance from DHL] * [DHL DAT Rate], type number),
    WithCosts2 = Table.AddColumn(WithCosts, "Rancho TL Cost", each [Distance from Rancho] * [Rancho DAT Rate], type number),
    WithCosts3 = Table.AddColumn(WithCosts2, "Anderson TL Cost", each [Distance from Anderson] * [Anderson DAT Rate], type number),

    #"Merged queries" = Table.NestedJoin(WithCosts3, {"REGION"}, #"DAT US Regions", {"StateCode"}, "DAT US Regions", JoinKind.LeftOuter),
    #"Expanded DAT US Regions" = Table.ExpandTableColumn(#"Merged queries", "DAT US Regions", {"Region"}, {"DAT US Region"}),

    // CJ 7/8/2026: alt region
    #"Added Zip Code Prefix" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DAT US Regions", "Zip Code Prefix", each Text.Start([Postal Code Clean], 3)), {{"Zip Code Prefix", type text}}),
    #"Merged California Region Legend" = Table.NestedJoin(#"Added Zip Code Prefix", {"Zip Code Prefix", "REGION"}, #"California Region Legend", {"Zip Code Prefix", "State "}, "California Region Legend", JoinKind.LeftOuter),
    #"Expanded California Region Legend" = Table.ExpandTableColumn(#"Merged California Region Legend", "California Region Legend", {"Region"}, {"CA Region"}),
    #"Added Alt Region" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded California Region Legend", "Alt Region", each if [CA Region] <> null and [CA Region] <> "" then [CA Region] else [REGION]), {{"Alt Region", type text}}),
    #"Removed CA Region" = Table.RemoveColumns(#"Added Alt Region", {"CA Region"}),

    // add general region
    #"Added General Region" =
        Table.AddColumn(
            #"Removed CA Region",
            "General Region",
            each
                if [DAT US Region] <> null and [DAT US Region] <> "" then [DAT US Region]
                else if List.Contains({"AK", "HI"}, [REGION]) then "Alaska/Hawaii"
                else if List.Contains({"PR", "VI"}, [REGION]) then "Caribbean"
                else if List.Contains({"AS", "FM", "GU", "MH", "MP", "PW"}, [REGION]) then "Territories"
                else if [Postal Code Country] = "CAN" then "Canada"
                else null,
            type text
        )

in
    #"Added General Region";
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
    else "No"
  ),
  #"Sorted Rows" = Table.Sort(#"Added Imports Conditional",{{"Plant", Order.Ascending}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Sorted Rows", {{"Imports", type text}, {"Plant", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"DIM Date" = let
  StartDate =  #date(Date.Year(DateTime.LocalNow())-3,1,1),
  EndDate = Date.AddYears(Date.From(DateTime.LocalNow()), 2),
  NumberOfDays = Duration.Days( EndDate - StartDate ),
  Dates = List.Dates(StartDate, NumberOfDays+1, #duration(1,0,0,0)),
  #"Converted to Table" = Table.FromList(Dates, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
  #"Renamed Columns" = Table.RenameColumns(#"Converted to Table",{{"Column1", "Full Date"}}),
  #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"Full Date", type date}}),
  #"Inserted Year" = Table.AddColumn(#"Changed Type", "Year", each Date.Year([Full Date])),
  #"Inserted Month" = Table.AddColumn(#"Inserted Year", "Month", each Date.Month([Full Date])),
  #"Inserted Month Name" = Table.AddColumn(#"Inserted Month", "Month Name", each Date.MonthName([Full Date]), type text),
  #"Inserted Quarter" = Table.AddColumn(#"Inserted Month Name", "Quarter", each Date.QuarterOfYear([Full Date]), type number),
  #"Inserted Week of Year" = Table.AddColumn(#"Inserted Quarter", "Week of Year", each Date.WeekOfYear([Full Date]), type number),
  #"Inserted Week of Month" = Table.AddColumn(#"Inserted Week of Year", "Week of Month", each Date.WeekOfMonth([Full Date]), type number),
  #"Inserted Day" = Table.AddColumn(#"Inserted Week of Month", "Day", each Date.Day([Full Date]), type number),
  #"Inserted Day of Week" = Table.AddColumn(#"Inserted Day", "Day of Week", each Date.DayOfWeek([Full Date]), type number),
  #"Inserted Day of Year" = Table.AddColumn(#"Inserted Day of Week", "Day of Year", each Date.DayOfYear([Full Date]), type number),
  #"Inserted Day Name" = Table.AddColumn(#"Inserted Day of Year", "Day Name", each Date.DayOfWeekName([Full Date]), type text),
  #"Today Dynamic" = Table.AddColumn(#"Inserted Day Name", "Today", each DateTime.LocalNow()),
  #"Changed Type3" = Table.TransformColumnTypes(#"Today Dynamic",{{"Today", type date}}),
  #"Added Custom1" = Table.AddColumn(#"Changed Type3", "Today SOW", each Date.StartOfWeek([Today])),
  #"Added TodayFOM" = Table.AddColumn(#"Added Custom1", "Today FOM", each Date.StartOfMonth([Today]), type date),
  #"Inserted Date Subtraction1" = Table.AddColumn(#"Added TodayFOM", "Subtraction1", each Duration.Days([Today SOW] - [Full Date]), Int64.Type),
  #"Added Conditional Column" = Table.AddColumn(#"Inserted Date Subtraction1", "Future?", each if [Subtraction1] < -140 then "Extended Outlook" else if [Subtraction1] < -6 then "Future" else if [Subtraction1] <= 0 then "This Week" else "Past"),
  #"Changed Type1" = Table.TransformColumnTypes(#"Added Conditional Column",{{"Week of Year", type text}, {"Week of Month", type text}, {"Future?", type text}}),
  #"Duplicated Column" = Table.DuplicateColumn(#"Changed Type1", "Full Date", "FullDateAlternateKey - Copy"),
  #"Calculated Start of Month" = Table.TransformColumns(#"Duplicated Column",{{"FullDateAlternateKey - Copy", Date.StartOfMonth, type date}}),
  #"Renamed Columns1" = Table.RenameColumns(#"Calculated Start of Month",{{"FullDateAlternateKey - Copy", "FOM"}}),
  #"Inserted Date Subtraction" = Table.AddColumn(#"Renamed Columns1", "Subtraction", each Duration.Days([Today] - [FOM])/30, Int64.Type),
  #"Rounded Up" = Table.TransformColumns(#"Inserted Date Subtraction",{{"Subtraction", Number.RoundUp, Int64.Type}}),
  #"Duplicated Column1" = Table.DuplicateColumn(#"Rounded Up", "Full Date", "FullDateAlternateKey - Copy"),
  #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated Column1",{{"FullDateAlternateKey - Copy", Date.StartOfWeek, type date}}),
  #"Renamed Columns3" = Table.RenameColumns(#"Calculated Start of Week",{{"FullDateAlternateKey - Copy", "SOW"}}),
  #"Duplicated Column2" = Table.DuplicateColumn(#"Renamed Columns3", "Full Date", "Full Date - SOW"),
  #"Calculated Start of Week1" = Table.TransformColumns(#"Duplicated Column2",{{"Full Date - SOW", Date.StartOfWeek, type date}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Calculated Start of Week1", {{"Year", Int64.Type}, {"Month", type text}, {"Today SOW", type date}}),
  #"Inserted conditional column" = Table.AddColumn(#"Changed column type", "SOW>=TODAY", each if [Full Date] >= [Today] then [SOW] else null, type date),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Inserted conditional column", "6 week filter", each let
  fullDateSOW = Date.From([#"Full Date - SOW"]),
  todaySOW = Date.From([#"Today SOW"]),
  diffDays = Duration.Days(fullDateSOW - todaySOW)
      in if Number.Abs(diffDays) <= 42 then "Yes" else "No"), {{"6 week filter", type text}}),
  AddFormattedDate = Table.AddColumn(
      #"Added custom",
      "Full Date Formatted",
      each Date.ToText([Full Date], "yyyyMMdd"),
      type text
  ),
#"Reordered columns" = Table.ReorderColumns(AddFormattedDate, {"Full Date", "Full Date Formatted", "Year", "Month", "Month Name", "Quarter", "Week of Year", "Week of Month", "Day", "Day of Week", "Day of Year", "Day Name", "Today", "Today SOW", "Subtraction1", "Future?", "FOM", "Subtraction", "SOW", "Full Date - SOW", "SOW>=TODAY", "6 week filter"}),
#"Added custom 1" = 
  Table.AddColumn(
      #"Reordered columns",
      "DateKey",
      each Text.From(
          Duration.Days( [#"Full Date"] - #date(2022, 1, 1) ) + 9498
      ),
      type text
  ),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "InRange", each let
            fullDate = Date.From([#"Full Date"]),
            today = Date.From([Today]),
            minDate = Date.AddDays(today, -180),
            maxDate = Date.AddDays(today, 42)
        in
            if fullDate >= minDate and fullDate <= maxDate then "Yes" else "No"), {{"InRange", type text}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "Full Date Next Year Adjusted", each Date.AddDays(Date.From([Full Date]), 364)), {{"Full Date Next Year Adjusted", type date}}),

  // CJ 8/11/2026: add Next Year Adjusted derived fields
  #"Added NYA Attributes" =
    Table.AddColumn(
      #"Added custom 3",
      "NYA",
      each [
        SOW = Date.StartOfWeek([Full Date Next Year Adjusted]),
        Year = Date.Year([Full Date Next Year Adjusted]),
        WeekOfYear = Date.WeekOfYear([Full Date Next Year Adjusted])
      ]
    ),

  #"Expanded NYA Attributes" =
    Table.ExpandRecordColumn(
      #"Added NYA Attributes",
      "NYA",
      {"SOW","Year","WeekOfYear"},
      {"NYA SOW","NYA Year","NYA Week Of Year"}
    ),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Expanded NYA Attributes", {{"NYA SOW", type date}, {"NYA Year", Int64.Type}, {"NYA Week Of Year", Int64.Type}})

in
  #"Changed column type 1";
[BindToDefaultDestination = true]
shared #"DIM Date (2)" = let
  Source = #"DIM Date"
in
  Source;
[BindToDefaultDestination = true]
shared #"FACT MB52 All" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),  
  // CJ 6/22/2026: Case-insensitive filter instead of brittle record navigation
  // Navigation = Source{[Name = "MB52.XLSX", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  Filtered =
  Table.SelectRows(
    Source,
    each 
      Text.Upper([Name]) = "MB52.XLSX" and
      Text.Upper([Folder Path]) = Text.Upper("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/")
  ),

  Navigation = Filtered{0}[Content],

  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Filtered rows" = Table.SelectRows(#"Promoted headers", each [Material] <> null and [Material] <> ""),
  #"Changed column type" = Table.TransformColumnTypes(#"Filtered rows", {{"Material", type text}, {"Material Description", type text}, {"Base Unit of Measure", type text}, {"Plant", type text}, {"Unrestricted", type number}, {"Transit and Transfer", Int64.Type}, {"In Quality Insp.", Int64.Type}, {"Restricted-Use Stock", Int64.Type}, {"Blocked", Int64.Type}, {"Returns", Int64.Type}, {"Descr. of Storage Loc.", type text}, {"Storage Location", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"Storage Location", "Storage Location Initial"}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns", "Storage Location",
    each 
      if [Storage Location Initial] ="" then "473-Transit" 
      else if [Storage Location Initial] = "473" and [#"In Quality Insp."]>0 then "473-QA"
      else if [Storage Location Initial] = "473" and [Blocked]>0 then "473-Blocked"
      else [Storage Location Initial]), 
    {{"Storage Location", type text}}
  ),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "Combined Qty", each [Unrestricted] + [Blocked]), {{"Combined Qty", Int64.Type}}),
  #"Added MRP Area" = Table.AddColumn(#"Added custom", "MRP Area", 
    each let
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
        else if List.Contains({"369C","369P","369T","705","369W","369H"}, CurrStLoc) then "69_369T - OEL Overseas - 2" // costco weird transient issue 369W
        else if List.Contains({"467C","467N","4674","467P","4672","367M","4673","467Q","367J"}, CurrStLoc) then "67_4674 - DHL"
        else if List.Contains({"367B","367A","367I","367D"}, CurrStLoc) then "67_367 - KNA- Spreetail"
        else if List.Contains({"367G","367C"}, CurrStLoc) then "67_367G - Globe 18301 Bro"
        else if CurrStLoc = "X67X" then "67 - KNA LLC"
        else if CurrStLoc = "X69X" then "69 - NA - Canada - Import"
        else "Unknown"
  ),
  #"Added MRP + SKU Key" = Table.AddColumn(#"Added MRP Area", "MRPSKU Key", each [MRP Area]&"|"&[Material]),
  #"Added Data Source ID" = Table.AddColumn(#"Added MRP + SKU Key", "Data Source", each "MB52"),
  #"Added ""Remaining""" = Table.AddColumn(#"Added Data Source ID", "Remaining?", each "Yes"),
  #"Today Dynamic" = Table.AddColumn(#"Added ""Remaining""", "Today", each DateTime.LocalNow(), type date),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Today Dynamic", {{"Today", type date}}),
  #"Duplicated column" = Table.DuplicateColumn(#"Changed column type 1", "Today", "Combined Date"),
  #"Duplicated column 2" = Table.DuplicateColumn(#"Duplicated column", "Combined Date", "SOW"),
  #"Duplicated column 1" = Table.DuplicateColumn(#"Duplicated column 2", "Today", "Today SOW"),
  #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
  #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Calculated Start of Week Today", {{"MRPSKU Key", type text}, {"MRP Area", type text}, {"Data Source", type text}, {"Remaining?", type text}, {"Value Unrestricted", Currency.Type}, {"Value Rets Blocked", Currency.Type}}),
  #"Reordered columns" = Table.ReorderColumns(#"Changed column type 2", {"Material", "Material Description", "Base Unit of Measure", "Plant", "Unrestricted", "Transit and Transfer", "In Quality Insp.", "Restricted-Use Stock", "Blocked", "Returns", "Descr. of Storage Loc.", "Storage Location Initial", "Storage Location", "Combined Qty", "MRP Area", "MRPSKU Key", "Data Source", "Remaining?", "Today", "Combined Date", "SOW", "Today SOW", "Value Unrestricted", "Value Rets Blocked"}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Reordered columns", "Stock_Value", each [Value Unrestricted] + [Value Rets Blocked]), {{"Stock_Value", type number}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom 2", {"Value Unrestricted", "Value Rets Blocked"})
in
  #"Removed columns";
[BindToDefaultDestination = true]
shared #"DIM DTC Ship Point Key" = let
  Source =
    #table(
      type table [
        Port = text,
        shipping_point = text,
        shipping_point_desc = text,
        shipping_point_type = text,
        shipping_point_type_desc = text,
        shipping_point_zip = text,
        origin_state = text,
        YR50 = nullable number,
        YR73 = nullable number,
        YR51 = nullable number,
        YR52 = nullable number,
        YR53 = nullable number
        // DTC_Flag = logical
      ],
      {
        {"Tacoma"    , "367A"    , "SpreeTail Tacoma"   , "06", "LTL"   , "98446", "WA" , 350 , 270 , 5882, 775 , 0   },
        {"New York"  , "367O"    , "SpreeTail Greenwood", "06", "LTL"   , "46143", "IN" , 350 , 270 , 2508, 1877, 0   },
        {"Savannah"  , "367I"    ,  "SpreeTail Ellabell", "06", "LTL"   , "31308", "GA" , 350 , 270 , 2671, 0   , 600 },
        {"Long Beach", "367B"    , "SpreeTail Vegas"    , "06", "LTL"   , "89115", "NV" , 350 , 270 , 4474, 0   , 2185},
        {"New York"  , "367D"    , "SpreeTail Nanticoke", "06", "LTL"   , "18634", "PA" , 350 , 270 , 2671, 0   , 1800},
        {"Savannah"  , "4674"    , "DHL"                , "07", "Parcel", "31326", "GA" , 350 , 270 , 2671, 0   , 220 },
        {"Long Beach", "367G"    , "Rancho"             , "07", "Parcel", "90220", "SCA", 350 , 270 , 4474, 0   , 493 },
        {"Savannah"  , "4674"    , "DHL"                , "06", "LTL"   , "31326", "GA" , 350 , 270 , 2671, 0   , 220 },
        {"Long Beach", "367G"    , "Rancho"             , "06", "LTL"   , "90220", "SCA", 350 , 270 , 4474, 0   , 493 },
        {"Savannah"  , "699"     , "CastleGate"         , "07", "Parcel", "31326", null , 350 , 270 , 2671, 0   , 220 },
        {null        , "699-AMZN", "Amazon"             , "07", "Parcel", null   , null , null, null, null, null, null},
        {null        , "699-AMZN", "Amazon"             , "06", "LTL"   , null   , null , null, null, null, null, null},
        {null        , "699-WMT" , "Walmart"            , "07", "Parcel", null   , null , null, null, null, null, null},
        {null        , "699-WMT" , "Walmart"            , "06", "LTL"   , null   , null , null, null, null, null, null}

        // {"Savannah"  , ""    , "Olive Branch US"    ,         2508, 1398,    0, false}
      }
    ),
  // 8/10/2026 CJ: remove "LTL" from SpreeTail
  #"shipping_point_key_desc" =
    Table.TransformColumnTypes(
      Table.AddColumn(
        Source,
        "shipping_point_key_desc",
        each
          (if Text.StartsWith([shipping_point_desc], "SpreeTail")
            then [shipping_point_desc]
            else [shipping_point_desc] & " - " & [shipping_point_type_desc]),
        type text
      ),
      {{"shipping_point_key_desc", type text}}
    ),
  // #"shipping_point_key_desc" = Table.TransformColumnTypes(Table.AddColumn(Source, "shipping_point_key_desc", each [shipping_point_desc] & " - " & [shipping_point_type_desc]), {{"shipping_point_key_desc", type text}}),

  #"shipping_point_key" = Table.TransformColumnTypes(Table.AddColumn(shipping_point_key_desc, "shipping_point_key", each [shipping_point] & " - " & [shipping_point_type]), {{"shipping_point_key", type text}})
in
  shipping_point_key;
[BindToDefaultDestination = true]
shared #"DIM Amazon Warehouses" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Amazon Warehouses", ItemKind = "Table"]}[Data],
  #"Merged queries" = Table.NestedJoin(#"Navigation 2", {"Airport Zip Code"}, #"DIM USA CA Zips", {"Postal Code Clean"}, "DIM USA CA Zips", JoinKind.LeftOuter),
  #"Expanded DIM USA CA Zips" = Table.ExpandTableColumn(#"Merged queries", "DIM USA CA Zips", {"DHL DAT Rate", "Rancho DAT Rate", "DHL TL Cost", "Rancho TL Cost", "DAT US Region"}, {"DHL DAT Rate", "Rancho DAT Rate", "DHL TL Cost", "Rancho TL Cost", "DAT US Region"})
in
  #"Expanded DIM USA CA Zips";
shared #"DAT US Regions" = // DAT US Regions
let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DAT US Regions", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"DIM USA CA Zips_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "DIM USA CA Zips", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DHL DAT Rate" = let
  Source = #"DAT US Regions",
  #"Filtered rows" = Table.SelectRows(Source, each ([StateCode] = "GA"))
in
  #"Filtered rows";
shared #"Rancho DAT Rate" = let
  Source = #"DAT US Regions",
  #"Filtered rows" = Table.SelectRows(Source, each ([StateCode] = "CA"))
in
  #"Filtered rows";
shared #"California Region Legend" = let
  Source = SharePoint.Contents(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  SharedDocuments = Source{[Name="Shared Documents"]}[Content],
  PowerBIProjects = SharedDocuments{[Name="PowerBI Projects"]}[Content],
  DL = PowerBIProjects{[Name="DL"]}[Content],

  FileContent = DL{[Name="CollectLTLRoutingGuide-2026K.xlsx"]}[Content],

  Workbook = Excel.Workbook(FileContent, null, true),
  Navigation = Workbook{[Item = "California Region Legend", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Zip Code Prefix", type text}, {"City, State", type text}, {"State ", type text}, {"Region", type text}})
in
  #"Changed column type";
shared #"Anderson DAT Rate" = let
  Source = #"DAT US Regions",
  #"Filtered rows" = Table.SelectRows(Source, each ([StateCode] = "IN"))
in
  #"Filtered rows";
