[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"FACT MB51 Material_Movements Initial" = let
  Source = Fabric.Warehouse(null),
  Navigation = Source{[workspaceId = "c2419776-dec6-4cc0-8fa3-af708bd179cf"]}[Data],
  #"Navigation 1" = Navigation{[warehouseId = "b59fa756-dada-4729-ad99-d953b0a62c50"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Schema = "dbo", Item = "MB51_Material_Movments"]}[Data],
  // Add Data Source
  #"Add Data Source" = Table.AddColumn(#"Navigation 2", "Data Source", each "MB51", type text),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Add Data Source", {{"Posting Date in the Document", type date}, {"Quantity", Int64.Type}, {"Material Number", type text}, {"Day On Which Accounting Document Was Entered", Int64.Type}}),
  //Is this filter necessary? Probably not hurting anything.
  #"Filtered rows 1" = Table.SelectRows(#"Changed column type 1", each [Storage Location] <> null and [Storage Location] <> ""),
  //Add Container information field
  #"Added SubContainer" = Table.AddColumn(
    #"Filtered rows 1", 
    "SubContainer", 
    each if [Document Header Text] = null or Text.Length([Document Header Text]) < 11 then
      ""  
      else
        let
          // Step 1: Remove all special characters (keep only alphanumeric characters)
          CleanedText = Text.Select([Document Header Text], {"A".."Z", "a".."z", "0".."9"}),

          // Step 2: Remove alphabetic characters at the end of the string
          EndsInNumber = 
            let
              LastChar = Text.End(CleanedText, 1)
            in
              if LastChar >= "0" and LastChar <= "9" then CleanedText 
              else Text.RemoveRange(CleanedText, Text.Length(CleanedText) - 1, 1),

          // Step 3: Remove specific substrings using a list
          SubstringsToRemove = {"DHL944", "DHL214", "DHL912"},
          FinalText = List.Accumulate(SubstringsToRemove, EndsInNumber, (state, substring) => Text.Replace(state, substring, "")),

          // Step 4: Extract the first 12 characters of FinalText
          First12Chars = Text.Start(FinalText, 12),

          // Step 5: Check if the 5th character is a number
          FifthChar = Text.Middle(First12Chars, 4, 1), // Get the 5th character (index starts at 0)
          IsFifthCharNumber = FifthChar >= "0" and FifthChar <= "9",

          // Step 6: Return the first 11 characters if the 5th character is a number, otherwise return the last 11 characters
          Result = if IsFifthCharNumber then Text.Start(First12Chars, 11) else Text.End(First12Chars, 11)
        in  
          Result
  ),
  //Add Container Movement Identification field
  #"Added C_ContainerMove" = Table.AddColumn(#"Added SubContainer", "ContainerMove", each if [Movement Type] = 101 or [Movement Type] = 311 then 1 else 0),
  //This is probably not needed anymore and should be handled by the DIM Storage Location Table
  #"Added Simple Storage Location" = Table.AddColumn(
    #"Added C_ContainerMove", 
    "Simple Storage Location", 
    each 
      if [Storage Location] = "467N" then "3-DEPOT" 
      else if [Storage Location] = "476P" then "3-DEPOT" 
      else if [Storage Location] = "467Q" then "3-DEPOT" 
      else if [Storage Location] = "467C" then "2-VETERAN'S" 
      else if [Storage Location] = "467O" then "2-VETERAN'S" 
      else if [Storage Location] = "4674" then "1-DHL" 
      else if [Storage Location] = "4673" then "1-DHL" 
      else if [Storage Location] = "4672" then "4-PORT" 
      else "5-OTHER"
  ),
  //Can we move this to the end?
  #"Changed Type1" = Table.TransformColumnTypes(#"Added Simple Storage Location",{{"Simple Storage Location", type text}, {"SubContainer", type text}, {"ContainerMove", type text}, {"Data Source", type text}}),
  //Can we combine with other Rename steps?
  #"Renamed Columns" = Table.RenameColumns(#"Changed Type1", {{"Posting Date in the Document", "Combined Date"}, {"Quantity", "Combined Qty"}, {"Material Number", "Material"}, {"Reference Document Number", "Reference Document Number_"}}),

  //***MB51 OFFSET ROUTINE***

  //Group 'em up. This is pretty slow.
  #"Grouped Rows" = Table.Group(#"Renamed Columns", {"Material", "Storage Location", "Plant"}, {{"Combined Qty", each List.Sum([Combined Qty]), type nullable number}}),
  //Merge & Expand. We might want to clean up these field name. They are ugly.
  #"Merged Queries" = Table.NestedJoin(#"Grouped Rows", {"Material", "Storage Location"}, #"FACT MB52", {"Material", "Storage Location"}, "!FACT MB52 (2)", JoinKind.LeftOuter),
  #"Expanded !FACT MB52 (2)" = Table.ExpandTableColumn(#"Merged Queries", "!FACT MB52 (2)", {"Combined Qty"}, {"!FACT MB52 (2).Combined Qty"}),
  //Replace null with 0
  #"Replaced value" = Table.ReplaceValue(#"Expanded !FACT MB52 (2)", null, 0, Replacer.ReplaceValue, {"!FACT MB52 (2).Combined Qty"}),
  //Subtract MB52 - MB51 to ensure the starting value is correct.
  #"Inserted Subtraction" = Table.AddColumn(#"Replaced value", "MB52 - MB51", each [#"!FACT MB52 (2).Combined Qty"]-[Combined Qty] , type number),
  //Add a date that is 12/31 three years ago and change its type and call it Combined Date.
  #"Added Custom3" =Table.AddColumn(#"Inserted Subtraction","Combined Date",each "12/31/" & Text.From(Date.Year(DateTime.LocalNow())-3)),
  //#"Added Custom3" = Table.AddColumn(#"Inserted Subtraction", "Combined Date", each "12/31/"&Date.Year(DateTime.LocalNow()-3)),
  #"Changed Type2" = Table.TransformColumnTypes(#"Added Custom3",{{"Combined Date", type date}}),
  //Remove the MB51 Combined Qty and replace with the subtraction.
  #"Removed Columns" = Table.RemoveColumns(#"Changed Type2",{"Combined Qty", "!FACT MB52 (2).Combined Qty"}),
  #"Renamed Columns2" = Table.RenameColumns(#"Removed Columns",{{"MB52 - MB51", "Combined Qty"}}),
  //Remove nulls and blanks.
  #"Filtered Rows1" = Table.SelectRows(#"Renamed Columns2", each [Combined Qty] <> null and [Combined Qty] <> ""),
  #"Add Data Source Offset" = Table.TransformColumnTypes(Table.AddColumn(#"Filtered Rows1", "Data Source", each "MB51 Offset"), {{"Data Source", type text}}),
  #"Combine Stuff" = Table.Combine({#"Add Data Source Offset",#"Renamed Columns"}),
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
  Today2 = Table.TransformColumnTypes(Table.AddColumn(#"Added MRPSKU Key", "Today", each DateTime.LocalNow()), {{"Today", type date}}),
  #"Added Today SOW" = Table.AddColumn(Today2, "Today SOW", each Date.StartOfWeek([Today])),
  #"Added SOW" = Table.AddColumn(#"Added Today SOW", "SOW", each Date.StartOfWeek([Combined Date])),
  #"Added Remaining" = Table.AddColumn(#"Added SOW", "Remaining?", each "No"),

  //Fix the dates that mess up the running sum charts.
  #"Renamed Columns1" = Table.RenameColumns(#"Added Remaining",{{"Combined Date", "Combined Date 1"}}),
  #"Added Custom" = Table.AddColumn(#"Renamed Columns1", "Combined Date", each if [Storage Location] = "4672" and [Combined Date 1]=Date.FromText("02/07/2025") then Date.FromText("02/06/2025") else [Combined Date 1]),
  //Add Container Qtys
  // MergedProduct = Table.NestedJoin(#"Added Custom", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  // ExpandedProduct = Table.ExpandTableColumn(MergedProduct, "DIM Product", {"Cont_Qty"}, {"Cont_Qty"}),
  // #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(ExpandedProduct, "CombinedQty_per_ContQty", each Value.Divide([Combined Qty], [Cont_Qty])), {{"CombinedQty_per_ContQty", type number}}),
  MergedProduct = Table.NestedJoin(#"Added Custom", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),

  ExpandedProduct = Table.ExpandTableColumn(
    MergedProduct,
    "DIM Product",
    {"SS/PLT_Qty", "Carton/Bag_Qty", "Cont_Qty", "TL Qty"},
    {"SS/PLT_Qty", "Carton/Bag_Qty", "Cont_Qty", "TL Qty"}
  ),

  #"Added Handling Unit Calculation" = Table.AddColumn(
    ExpandedProduct,
    "Picks",
    each
      let
        LineQty = -[Combined Qty],
        LinePlt = [#"SS/PLT_Qty"],
        LineCase = [#"Carton/Bag_Qty"],
        MovementType = [Movement Type]
      in
        if LineQty = null or MovementType <> "601" then null
        else if LinePlt <> null and LinePlt <> 0 and LineQty > LinePlt then Number.RoundUp(LineQty / LinePlt)
        else if LineCase <> null and LineCase <> 0 and LineQty > LineCase then Number.RoundUp(LineQty / LineCase)
        else 1,
    Int64.Type
  ),

  #"CombinedQty_per_ContQty" = Table.TransformColumnTypes(
    Table.AddColumn(
      #"Added Handling Unit Calculation",
      "CombinedQty_per_ContQty",
      each Value.Divide([Combined Qty], [Cont_Qty])
    ),
    {{"CombinedQty_per_ContQty", type number}}
  ),

  // 8/10/2026 CJ: add TLs
  #"Calculate TLs" = Table.TransformColumnTypes(Table.AddColumn(#"CombinedQty_per_ContQty", "CombinedQty_per_TLQty", each Value.Divide([Combined Qty], [TL Qty])), {{"CombinedQty_per_TLQty", type number}}),

  #"Changed column type" = Table.TransformColumnTypes(#"Calculate TLs", {{"Combined Date", type date}, {"Remaining?", type text}, {"MRP Area", type text}, {"SOW", type date}, {"Today SOW", type date}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared #"FACT MB51 Grouped" = let
    Source = #"FACT MB51 Material_Movements Initial",
   
    #"Grouped Rows1" = Table.Group(Source, {"Storage Location", "MRP Area", "Combined Date", "Data Source", "Material", "Today", "Today SOW", "Remaining?", "MRPSKU Key", "Plant", "SOW", "Cont_Qty", "TL Qty"}, {{"Combined Qty", each List.Sum([Combined Qty]), type nullable number}, {"CombinedQty_per_ContQty", each List.Sum([CombinedQty_per_ContQty]), type nullable number}, {"CombinedQty_per_TLQty", each List.Sum([CombinedQty_per_TLQty]), type nullable number}})

    //#"Renamed Columns1" = Table.RenameColumns(#"Added custom 1",{{"Combined Date", "Combined Date 1"}}),
    //#"Added Custom" = Table.AddColumn(#"Renamed Columns1", "Combined Date", each if [Storage Location] = "4672" and [Combined Date 1]=Date.FromText("02/07/2025") then Date.FromText("02/06/2025") else [Combined Date 1])
  ,
  #"Changed column type" = Table.TransformColumnTypes(#"Grouped Rows1", {{"MRP Area", type text}, {"Combined Date", type date}, {"Today SOW", type date}, {"Remaining?", type text}, {"SOW", type date}})
in
    #"Changed column type";
shared DefaultDestination = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
shared #"FACT MB52" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT MB52", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"DIM Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
