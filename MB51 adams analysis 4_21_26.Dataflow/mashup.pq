[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Adams MB51_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Adams MB51" = let
    Source = Excel.Workbook(
        Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Manual%20Adams%20Review/Plant%2073%20Mb51%20Manual.xlsx"),
        null,
        true
    ),

    Sheet1 = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet1, [PromoteAllScalars=true]),

    #"Changed Type" =
        Table.TransformColumnTypes(#"Promoted Headers",{
            {"Plant", type text},
            {"Material", type text},
            {"Material Description", type text},
            {"Movement Type", Int64.Type},
            {"Storage Location", type text},
            {"Document Header Text", type text},
            {"Posting Date", type date},
            {"Quantity", Int64.Type},
            {"Time of Entry", type datetime}
        }),

    #"Rename for Model Alignment" =
        Table.RenameColumns(#"Changed Type",{
            {"Posting Date","Combined Date"},
            {"Quantity","Combined Qty"}
        }),
  #"Grouped rows" = Table.Group(#"Rename for Model Alignment", {"Material", "Storage Location", "Plant"}, {{"Combined qty", each List.Sum([Combined Qty]), type nullable number}}),
  #"Merged queries" = Table.NestedJoin(#"Grouped rows", {"Material", "Storage Location"}, #"Adams Mb52 april21", {"Material", "Storage Location"}, "Adams Mb52 april21", JoinKind.LeftOuter),
  #"Expanded Adams Mb52 april21" = Table.ExpandTableColumn(#"Merged queries", "Adams Mb52 april21", {"Combined Qty"}, {"Adams Mb52 april21.Combined Qty"}),
  #"Replaced value" = Table.ReplaceValue(#"Expanded Adams Mb52 april21", null, 0, Replacer.ReplaceValue, {"Adams Mb52 april21.Combined Qty"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Replaced value", "Mb52-mb51", each [Adams Mb52 april21.Combined Qty] - [Combined qty]), {{"Mb52-mb51", type number}}),
  #"Added custom 1" = Table.AddColumn(#"Added custom", "Combined Date", each "12/31/" & Text.From(Date.Year(DateTime.LocalNow())-3)),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom 1", {{"Combined Date", type date}}),
  #"Removed columns" = Table.RemoveColumns(#"Changed column type", {"Adams Mb52 april21.Combined Qty", "Combined qty"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"Mb52-mb51", "Combined Qty"}}),
  #"Filtered rows" = Table.SelectRows(#"Renamed columns", each [Combined Qty] <> null or [Combined Qty] <> null),
  #"Add Data Source Offset" = Table.TransformColumnTypes(Table.AddColumn(#"Filtered rows", "Data Source", each "MB51 Offset"), {{"Data Source", type text}}),
    #"Combine Stuff" = Table.Combine({#"Rename for Model Alignment",#"Add Data Source Offset"}),
     #"Add MRP Area" = Table.AddColumn(#"Combine Stuff", "MRP Area", each let
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
   #"Added MRPSKU Key" = Table.AddColumn(#"Add MRP Area", "MRPSKU Key", each Text.Combine({[MRP Area], [Material]}, "|"), type text),
    Today2 =   Table.AddColumn(
        #"Added MRPSKU Key",
        "Today",
        each #date(2026, 4, 21),
        type date
    ),
    #"Added Today SOW" =   Table.AddColumn(
        Today2,
        "Today SOW",
        each Date.StartOfWeek(#date(2026, 4, 21)),
        type date
    ),
    #"Added SOW" = Table.AddColumn(#"Added Today SOW", "SOW", each Date.StartOfWeek([Combined Date])),
    #"Added Remaining" = Table.TransformColumnTypes(Table.AddColumn(#"Added SOW", "Remaining?", each "No"), {{"Remaining?", type text}}),
      
    //Fix the dates that mess up the running sum charts.
    #"Renamed Columns1" = Table.RenameColumns(#"Added Remaining",{{"Combined Date", "Combined Date 1"}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Renamed Columns1", {{"MRP Area", type text}, {"SOW", type date}})
in
    #"Changed column type 1";
shared #"Adams Mb52 april21" = let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Manual%20Adams%20Review/Plant%2073%20Mb52%20Manual.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],
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
        else if List.Contains({"369C","369P","369T","705","369W"}, CurrStLoc) then "69_369T - OEL Overseas - 2" // costco weird transient issue 369W
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
  #"Today static" = Table.AddColumn(#"Added ""Remaining""", "Today", each "4/21/2026", type date),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Today static", {{"Today", type date}}),
  #"Duplicated column" = Table.DuplicateColumn(#"Changed column type 1", "Today", "Combined Date"),
  #"Duplicated column 2" = Table.DuplicateColumn(#"Duplicated column", "Combined Date", "SOW"),
  #"Duplicated column 1" = Table.DuplicateColumn(#"Duplicated column 2", "Today", "Today SOW"),
  #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated column 1",{{"SOW", Date.StartOfWeek, type date}}),
  #"Calculated Start of Week Today" = Table.TransformColumns(#"Calculated Start of Week",{{"Today SOW", Date.StartOfWeek, type date}}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Calculated Start of Week Today", {{"MRPSKU Key", type text}, {"MRP Area", type text}, {"Data Source", type text}, {"Remaining?", type text}})
in
  #"Changed column type 2";
shared #"Adams MB51_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, PreserveOrder = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "Adams MB51", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
