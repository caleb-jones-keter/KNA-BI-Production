[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Product_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM Product" = let
  #"Appended Query" = Table.Combine({#"Current Item Sheets-2026", #"Current Item Sheets-2025", #"Current Item Sheets-2024", #"Current Item Sheets-2023"}),
  #"Sorted Rows (Table.Buffer)" = Table.Buffer(Table.Sort(#"Appended Query",{{"Document Year", Order.Descending}})),
  #"Removed Duplicates (Priority)" = Table.Distinct(#"Sorted Rows (Table.Buffer)", {"Material"}),
  #"Replaced Errors" = Table.ReplaceErrorValues(#"Removed Duplicates (Priority)", {{"Material", null}, {"Model", null}, {"Description", null}, {"Customer", null}, {"Dept", null}, {"Customer_1", null}, {"Vendor #", null}, {"Carton/Bag_Qty", null}, {"Layer Qty", null}, {"SS/PLT_Qty", null}, {"Cont_Qty", null}, {"TL Qty", null}, {"Stacked_Cont/TL", null}, {"Brand", null}, {"Color", null}, {"Note", null}, {"Supplier", null}, {"UPC/EAN", null}, {"Carton I2of5", null}, {"Pallet I2of5", null}, {"Private Label", null}, {"Opened", null}, {"Plant-sp.matl status", null}, {"Disco Date", null}, {"PC Business Unit", null}, {"HTS Code", null}, {"MSRP", null}, {"Document Year", null}}),
  #"Merged PackSource" = Table.NestedJoin(#"Replaced Errors", {"Material"}, PackSource, {"SKU"}, "PackSource", JoinKind.LeftOuter),
  #"Expanded Pack Type" = Table.ExpandTableColumn(#"Merged PackSource", "PackSource", {"Final", "General"}, {"Pack Type.Final", "Pack Type.General"}),
  #"Merged DCMSource" = Table.NestedJoin(#"Expanded Pack Type", {"Material"}, DCMSource, {"Code:SKU Level _c1_"}, "DCMSource", JoinKind.LeftOuter),

  #"Expanded DCM (SKU Level)" = Table.ExpandTableColumn(#"Merged DCMSource", "DCMSource", {"DCM Budget (%)"}, {"DCM (SKU Level).DCM Budget (%)"}),

  // CJ 8/28/2026: Protect against non-numeric values
  // #"Replaced Value" = Table.ReplaceValue(#"Expanded DCM (SKU Level)","NA",null,Replacer.ReplaceValue,{"Cont_Qty"}),
  // #"Changed Type1" = Table.TransformColumnTypes(#"Invalid Cont_Qty",{{"Cont_Qty", type number}, {"Material", type text}}),
  #"Clean Cont_Qty" =
    Table.TransformColumns(
      #"Expanded DCM (SKU Level)",
      {
        {
          "Cont_Qty",
          each try Number.From(_) otherwise null,
          type nullable number
        }
      }
    ),
  #"Changed Type1" =
    Table.TransformColumnTypes(
      #"Clean Cont_Qty",
      {{"Material", type text}}
    ),

  #"Inserted Addition" = Table.AddColumn(#"Changed Type1", "Port Free Days", each [#"Cont_Qty"] + 400, type number),
  DIMBOMCombined = #"DIM BOM Combined",
  #"Removed Duplicates" = Table.Distinct(DIMBOMCombined, {"Component"}),
  #"Merged DIMBOMCombined" = Table.NestedJoin(#"Inserted Addition", {"Material"}, #"Removed Duplicates", {"Component"}, "DIM BOM Combined", JoinKind.LeftOuter),
  #"Expanded DIM BOM Combined" = Table.ExpandTableColumn(#"Merged DIMBOMCombined", "DIM BOM Combined", {"BOM Type"}, {"DIM BOM Combined.BOM Type"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded DIM BOM Combined", {{"Dept", type text}, {"Vendor #", type text}, {"Stacked_Cont/TL", type text}, {"Color", type text}, {"Private Label", type text}, {"Plant-sp.matl status", type text}, {"HTS Code", type text}, {"MSRP", type text}, {"Document Year", type text},  {"Pack Type.Final", type text}, {"Pack Type.General", type text}}),
  #"Merged Specs" = Table.NestedJoin(#"Changed column type", {"Material"}, Specs, {"Item"}, "Specs", JoinKind.LeftOuter),
  #"Expanded Specs" = Table.ExpandTableColumn(#"Merged Specs", "Specs", {"Carton - Length", "Carton - Width", "Carton - Height", "Carton - Volume", "Carton - Weight", "Carton - cf", "Carton - pcf", "Pallet - Length", "Pallet - Width", "Pallet - Height", "Pallet - Volume", "Pallet - Weight", "Pallet - cf", "Pallet - pcf", "LP", "Carton Class", "SS/PLT Class", "Carton Dim Wt", "Oversize +130"" Max 165""", "SAP", "Override", "Linear Ft CTN", "Current"}, {"Specs.Carton - Length", "Specs.Carton - Width", "Specs.Carton - Height", "Specs.Carton - Volume", "Specs.Carton - Weight", "Specs.Carton - cf", "Specs.Carton - pcf", "Specs.Pallet - Length", "Specs.Pallet - Width", "Specs.Pallet - Height", "Specs.Pallet - Volume", "Specs.Pallet - Weight", "Specs.Pallet - cf", "Specs.Pallet - pcf", "Specs.LP", "Specs.Carton Class", "Specs.SS/PLT Class", "Specs.Carton Dim Wt", "Specs.Oversize +130"" Max 165""", "Specs.SAP", "Specs.Override", "Specs.Linear Ft CTN", "Specs.Current"}),

  //CJ 4/24/2026: Normalize dims (length is always longest)
  AddNormalizedDims =
  Table.AddColumn(
    #"Expanded Specs",
    "_Dims",
    each
      let
        L = [#"Specs.Carton - Length"],
        W = [#"Specs.Carton - Width"],
        H = [#"Specs.Carton - Height"],

        // Replace nulls with -1 only for comparison
        Lc = if L = null then -1 else L,
        Wc = if W = null then -1 else W,
        Hc = if H = null then -1 else H

      in

        if Lc >= Wc and Lc >= Hc then
          [Length = L, Width = W, Height = H]
        else if Wc >= Lc and Wc >= Hc then
          [Length = W, Width = L, Height = H]
        else
          [Length = H, Width = L, Height = W]

  ),

  RemoveOriginals =
    Table.RemoveColumns(
      AddNormalizedDims,
      {
        "Specs.Carton - Length",
        "Specs.Carton - Width",
        "Specs.Carton - Height"
      }
    ),

  ExpandDims =
    Table.ExpandRecordColumn(
      RemoveOriginals,
      "_Dims",
      {"Length", "Width", "Height"},
      {
        "Specs.Carton - Length",
        "Specs.Carton - Width",
        "Specs.Carton - Height"
      }
    ),

  #"Merged Invoice to Net Products" = Table.NestedJoin(ExpandDims, {"Material"}, #"Invoice to Net Products", {"Dim Products.SKU Level #"}, "Invoice to Net Products", JoinKind.LeftOuter),
  #"Expanded Invoice to Net Products" = Table.ExpandTableColumn(#"Merged Invoice to Net Products", "Invoice to Net Products", {"Dim Products.ACT PROD SITE", "Dim Products.ACT PROD SITE Region", "Dim Products.Brand desc", "Dim Products.COUNTRY OF PRODUCT(24)", "Dim Products.COUNTRY OF PRODUCT(24) (groups)", "Dim Products.COUNTRY OF PRODUCTION(5)", "Dim Products.EAN", "Dim Products.Image", "Dim Products.ITEM GROUP", "Dim Products.ITEM GROUP (prod cat)", "Dim Products.MARKET GROUP", "Dim Products.OUTDOOR / INDOOR (groups)", "Dim Products.OUTDOOR/INDOOR", "Dim Products.PRODUCT CATEGORY", "Dim Products.PRODUCT CATEGORY (groups)", "Dim Products.PRODUCT LINE DESC", "Dim Products.PRODUCT MANAGEMENT/Category", "Dim Products.PRODUCT TYPE", "Dim Products.ProductOrg", "Dim Products.Region", "Dim Products.SAP_MATERIALTYPE", "Dim Products.SKU Group", "Dim Products.SKU Group #", "Dim Products.SKU Group # & Desc", "Dim Products.SKU Level", "Dim Products.SKU Level # & Desc", "Dim Products.SubContinent Production"}, {"Dim Products.ACT PROD SITE", "Dim Products.ACT PROD SITE Region", "Dim Products.Brand desc", "Dim Products.COUNTRY OF PRODUCT(24)", "Dim Products.COUNTRY OF PRODUCT(24) (groups)", "Dim Products.COUNTRY OF PRODUCTION(5)", "Dim Products.EAN", "Dim Products.Image", "Dim Products.ITEM GROUP", "Dim Products.ITEM GROUP (prod cat)", "Dim Products.MARKET GROUP", "Dim Products.OUTDOOR / INDOOR (groups)", "Dim Products.OUTDOOR/INDOOR", "Dim Products.PRODUCT CATEGORY", "Dim Products.PRODUCT CATEGORY (groups)", "Dim Products.PRODUCT LINE DESC", "Dim Products.PRODUCT MANAGEMENT/Category", "Dim Products.PRODUCT TYPE", "Dim Products.ProductOrg", "Dim Products.Region", "Dim Products.SAP_MATERIALTYPE", "Dim Products.SKU Group", "Dim Products.SKU Group #", "Dim Products.SKU Group # & Desc", "Dim Products.SKU Level", "Dim Products.SKU Level # & Desc", "Dim Products.SubContinent Production"}),
  #"Merged Crossdock SKUS" = Table.NestedJoin(#"Expanded Invoice to Net Products", {"Material"}, #"Crossdock SKUS", {"SAP"}, "Crossdock SKUS", JoinKind.LeftOuter),
  #"Expanded Crossdock SKUS" = Table.ExpandTableColumn(#"Merged Crossdock SKUS", "Crossdock SKUS", {"Crossdock"}, {"Crossdock"}),
  
#"Remove Specific Materials(needs 2nd to last)" =
    Table.SelectRows(
        #"Expanded Crossdock SKUS",
        each not List.Contains(
            {
                "218576",
                "227631",
                "233206"
            },
            [Material]
        )
    ),

  #"Add Missing Items list. Make sure this is Last" = Table.Combine({#"Remove Specific Materials(needs 2nd to last)", #"Missing Items"}),
  #"Added SKU + Description" = Table.TransformColumnTypes(Table.AddColumn(#"Add Missing Items list. Make sure this is Last", "SKU & Desc", each [Material] & " " & [Description]), {{"SKU & Desc", type text}}),

  //CJ 4/3/2026: FedEx US DTC Dimensions 
  // #"Duplicated column" = Table.DuplicateColumn(#"Expanded Crossdock SKUS", "Specs.Carton - Volume", "Specs.Carton - Volume - Copy"),
  // #"Renamed columns" = Table.RenameColumns(#"Duplicated column", {{"Specs.Carton - Volume - Copy", "Specs.Carton - Volume - in."}}),
  // #"Multiplied column" = Table.TransformColumns(#"Renamed columns", {{"Specs.Carton - Volume - in.", each _ * 1728, type number}}),
  //CJ 4/24/2026: Redo Carton Volume in. logic to round up first
  
  #"Specs.Carton - Volume - in." = Table.AddColumn(
      #"Added SKU + Description",
      "Specs.Carton - Volume - in.",
      each
          Number.RoundUp([#"Specs.Carton - Length"])
          * Number.RoundUp([#"Specs.Carton - Width"])
          * Number.RoundUp([#"Specs.Carton - Height"]),
      Int64.Type
  ),

  // CJ 7/28/2026: add logic for Canada
    #"FedEx Ground US Dim Divisor" =
    Table.AddColumn(
      #"Specs.Carton - Volume - in.",
      "FedEx Ground US Dim Divisor",
      each 194,
      Int64.Type
    ),

  #"FedEx Ground CAN Dim Divisor" =
    Table.AddColumn(
      #"FedEx Ground US Dim Divisor",
      "FedEx Ground CAN Dim Divisor",
      each 166,
      Int64.Type
    ),

  FedEx_US_DimWeight =
    Table.AddColumn(
      #"FedEx Ground CAN Dim Divisor",
      "FedEx US Dim Weight",
      each try Number.RoundUp([#"Specs.Carton - Volume - in."] / [#"FedEx Ground US Dim Divisor"]) otherwise null,
      Int64.Type
    ),

  FedEx_CAN_DimWeight =
    Table.AddColumn(
      FedEx_US_DimWeight,
      "FedEx CAN Dim Weight",
      each try Number.RoundUp([#"Specs.Carton - Volume - in."] / [#"FedEx Ground CAN Dim Divisor"]) otherwise null,
      Int64.Type
    ),

  #"Length & Girth" =
    Table.AddColumn(
      FedEx_CAN_DimWeight,
      "Length & Girth",
      each
        Number.RoundUp([#"Specs.Carton - Length"])
        + (2 * Number.RoundUp([#"Specs.Carton - Height"]))
        + (2 * Number.RoundUp([#"Specs.Carton - Width"])),
      type number
    ),

  #"FedEx AHS Dim Flag" =
    Table.AddColumn(
      #"Length & Girth",
      "FedEx AHS Dim Flag",
      each
        let
          length = [#"Specs.Carton - Length"],
          width = [#"Specs.Carton - Width"],
          height = [#"Specs.Carton - Height"],
          lengthGirth = [#"Length & Girth"],
          volume = [#"Specs.Carton - Volume - in."],

          dims = {length, width, height},
          maxDim = List.Max(dims),
          secondLargest = List.Sort(dims, Order.Descending){1}
        in
          (maxDim > 48)
          or (secondLargest > 30)
          or (lengthGirth > 105)
          or (volume > 10368),
      type logical
    ),

  #"FedEx AHS Dim US Billable Weight" =
    Table.AddColumn(
      #"FedEx AHS Dim Flag",
      "FedEx AHS Dim US Billable Weight",
      each
        if [#"FedEx AHS Dim Flag"] = null then null
        else if [#"FedEx AHS Dim Flag"] then
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 40})
        else
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx AHS Dim CAN Billable Weight" =
    Table.AddColumn(
      #"FedEx AHS Dim US Billable Weight",
      "FedEx AHS Dim CAN Billable Weight",
      each
        if [#"FedEx AHS Dim Flag"] = null then null
        else if [#"FedEx AHS Dim Flag"] then
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 40})
        else
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx AHS Weight Flag" =
    Table.AddColumn(
      #"FedEx AHS Dim CAN Billable Weight",
      "FedEx AHS Weight Flag",
      each
        if [#"Specs.Carton - Weight"] = null then null
        else if [#"Specs.Carton - Weight"] > 50 then true
        else false,
      type logical
    ),

  #"FedEx Oversize Flag" =
    Table.AddColumn(
      #"FedEx AHS Weight Flag",
      "FedEx Oversize Flag",
      each
        let
          length = [#"Specs.Carton - Length"],
          width = [#"Specs.Carton - Width"],
          height = [#"Specs.Carton - Height"],
          lengthGirth = [#"Length & Girth"],
          volume = [#"Specs.Carton - Volume - in."],
          actualWeight = [#"Specs.Carton - Weight"],

          dims = {length, width, height},
          maxDim = List.Max(dims)
        in
          (maxDim > 96)
          or (lengthGirth > 130)
          or (volume > 17280)
          or (actualWeight > 110),
      type logical
    ),

  #"FedEx Oversize US Billable Weight" =
    Table.AddColumn(
      #"FedEx Oversize Flag",
      "FedEx Oversize US Billable Weight",
      each
        if [#"FedEx Oversize Flag"] = null then null
        else if [#"FedEx Oversize Flag"] then
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
        else
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx Oversize CAN Billable Weight" =
    Table.AddColumn(
      #"FedEx Oversize US Billable Weight",
      "FedEx Oversize CAN Billable Weight",
      each
        if [#"FedEx Oversize Flag"] = null then null
        else if [#"FedEx Oversize Flag"] then
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
        else
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx Unauthorized Flag" =
    Table.AddColumn(
      #"FedEx Oversize CAN Billable Weight",
      "FedEx Unauthorized Flag",
      each
        let
          length = [#"Specs.Carton - Length"],
          lengthGirth = [#"Length & Girth"],
          actualWeight = [#"Specs.Carton - Weight"],
          dimWeight = [#"FedEx US Dim Weight"],

          dims = {actualWeight, dimWeight},
          ratedWeight = List.Max(dims)
        in
          (length > 108)
          or (lengthGirth > 165)
          or (ratedWeight > 150),
      type logical
    ),

  #"FedEx Unauthorized US Billable Weight" =
    Table.AddColumn(
      #"FedEx Unauthorized Flag",
      "FedEx Unauthorized US Billable Weight",
      each
        if [#"FedEx Unauthorized Flag"] = null then null
        else if [#"FedEx Unauthorized Flag"] then
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
        else
          List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx Unauthorized CAN Flag" =
    Table.AddColumn(
      #"FedEx Unauthorized US Billable Weight",
      "FedEx Unauthorized CAN Flag",
      each
        let
          length = [#"Specs.Carton - Length"],
          lengthGirth = [#"Length & Girth"],
          actualWeight = [#"Specs.Carton - Weight"],
          dimWeight = [#"FedEx CAN Dim Weight"],

          dims = {actualWeight, dimWeight},
          ratedWeight = List.Max(dims)
        in
          (length > 108)
          or (lengthGirth > 165)
          or (ratedWeight > 150),
      type logical
    ),

  #"FedEx Unauthorized CAN Billable Weight" =
    Table.AddColumn(
      #"FedEx Unauthorized CAN Flag",
      "FedEx Unauthorized CAN Billable Weight",
      each
        if [#"FedEx Unauthorized CAN Flag"] = null then null
        else if [#"FedEx Unauthorized CAN Flag"] then
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
        else
          List.Max({[#"FedEx CAN Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"])}),
      type number
    ),

  #"FedEx Applied AHS Category" =
    Table.AddColumn(
      #"FedEx Unauthorized CAN Billable Weight",
      "FedEx Applied AHS Category",
      each
        try
          if [#"FedEx Unauthorized Flag"] then "Unauthorized"
          else if [#"FedEx Oversize Flag"] then "Oversize"
          else if [#"FedEx AHS Weight Flag"] then "AHS Weight"
          else if [#"FedEx AHS Dim Flag"] then "AHS Dim"
          else null
        otherwise null,
      type text
    ),

  #"FedEx Applied AHS CAN Category" =
    Table.AddColumn(
      #"FedEx Applied AHS Category",
      "FedEx Applied AHS CAN Category",
      each
        try
          if [#"FedEx Unauthorized CAN Flag"] then "Unauthorized"
          else if [#"FedEx Oversize Flag"] then "Oversize"
          else if [#"FedEx AHS Weight Flag"] then "AHS Weight"
          else if [#"FedEx AHS Dim Flag"] then "AHS Dim"
          else null
        otherwise null,
      type text
    ),

  #"FedEx US Final Billable Weight" =
    Table.AddColumn(
      #"FedEx Applied AHS CAN Category",
      "FedEx US Final Billable Weight",
      each
        List.Max({
          [#"FedEx Unauthorized US Billable Weight"],
          [#"FedEx Oversize US Billable Weight"],
          [#"FedEx AHS Dim US Billable Weight"],
          [#"FedEx US Dim Weight"],
          Number.RoundUp([#"Specs.Carton - Weight"])
        }),
      type number
    ),

  #"FedEx CAN Final Billable Weight" =
    Table.AddColumn(
      #"FedEx US Final Billable Weight",
      "FedEx CAN Final Billable Weight",
      each
        List.Max({
          [#"FedEx Unauthorized CAN Billable Weight"],
          [#"FedEx Oversize CAN Billable Weight"],
          [#"FedEx AHS Dim CAN Billable Weight"],
          [#"FedEx CAN Dim Weight"],
          Number.RoundUp([#"Specs.Carton - Weight"])
        }),
      type number
    ),

  //   #"FedEx Ground US Dim Divisor" = Table.AddColumn(#"Specs.Carton - Volume - in.", "FedEx Ground US Dim Divisor", each 194, Int64.Type),

  //   FedEx_US_DimWeight = Table.AddColumn(
  //     #"FedEx Ground US Dim Divisor",
  //     "FedEx US Dim Weight",
  //     each Number.RoundUp(
  //         [#"Specs.Carton - Volume - in."] / [#"FedEx Ground US Dim Divisor"]
  //     ),
  //     Int64.Type
  //   ),

  //   #"Length & Girth" = Table.AddColumn(
  //     FedEx_US_DimWeight, "Length & Girth", 
  //     each Number.RoundUp([#"Specs.Carton - Length"]) + (2*Number.RoundUp([#"Specs.Carton - Height"]) ) + (2*Number.RoundUp([#"Specs.Carton - Width"]) ), 
  //     type number   
  //   ),

  //   #"FedEx AHS Dim Flag" = Table.AddColumn(
  //     #"Length & Girth",
  //     "FedEx AHS Dim Flag",
  //     each 
  //       let
  //         length = [#"Specs.Carton - Length"],   // Length
  //         width  = [#"Specs.Carton - Width"],   // Width
  //         height = [#"Specs.Carton - Height"],   // Height
  //         lengthGirth = [#"Length & Girth"], // Length & Girth
  //         volume = [#"Specs.Carton - Volume - in."],      // Volume

  //         dims = {length, width, height},
  //         maxDim = List.Max(dims),
  //         secondLargest = List.Sort(dims, Order.Descending){1}
  //       in
  //         (maxDim > 48) 
  //         or (secondLargest > 30) 
  //         or (lengthGirth > 105) 
  //         or (volume > 10368),
  //     type logical
  //   ),

  //   #"FedEx AHS Dim US Billable Weight" = Table.AddColumn(
  //     #"FedEx AHS Dim Flag",
  //     "FedEx AHS Dim US Billable Weight",
  //     each 
  //       if [#"FedEx AHS Dim Flag"] = null then null
  //       else if [#"FedEx AHS Dim Flag"] then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 40})
  //       else if [#"FedEx AHS Dim Flag"] = false then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]) })
  //       else null,
  //     type number
  //   ),

  //   #"FedEx AHS Weight Flag" = Table.AddColumn(
  //     #"FedEx AHS Dim US Billable Weight",
  //     "FedEx AHS Weight Flag",
  //     each 
  //       if [#"Specs.Carton - Weight"] = null then null  
  //       else if [#"Specs.Carton - Weight"] > 50 then true 
  //       else false,
  //     type logical
  //   ),

  //   #"FedEx Oversize Flag" = Table.AddColumn(
  //     #"FedEx AHS Weight Flag",
  //     "FedEx Oversize Flag",
  //     each 
  //       let
  //         length = [#"Specs.Carton - Length"],   // Length
  //         width  = [#"Specs.Carton - Width"],   // Width
  //         height = [#"Specs.Carton - Height"],   // Height
  //         lengthGirth = [#"Length & Girth"], // Length & Girth
  //         volume = [#"Specs.Carton - Volume - in."],      // Volume
  //         actualWeight = [#"Specs.Carton - Weight"], //Actual Weight

  //         dims = {length, width, height},
  //         maxDim = List.Max(dims)

  //       in
  //         (maxDim > 96) 
  //         or (lengthGirth > 130) 
  //         or (volume > 17280)
  //         or (actualWeight > 110),
  //     type logical
  //   ),

  //   #"FedEx Oversize US Billable Weight" = Table.AddColumn(
  //     #"FedEx Oversize Flag",
  //     "FedEx Oversize US Billable Weight",
  //     each 
  //       if [#"FedEx Oversize Flag"] = null then null
  //       else if [#"FedEx Oversize Flag"] then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
  //       else if [#"FedEx Oversize Flag"] = false then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]) })
  //       else null,
  //     type number
  //   ),

  //   #"FedEx Unauthorized Flag" = Table.AddColumn(
  //     #"FedEx Oversize US Billable Weight",
  //     "FedEx Unauthorized Flag",
  //     each 
  //       let
  //         length = [#"Specs.Carton - Length"],   // Length
  //         lengthGirth = [#"Length & Girth"], // Length & Girth
  //         actualWeight = [#"Specs.Carton - Weight"], //Actual Weight
  //         dimWeight = [#"FedEx US Dim Weight"], //Dim Weight

  //         dims = {actualWeight, dimWeight},
  //         ratedWeight = List.Max(dims)

  //       in
  //         (length > 108) 
  //         or (lengthGirth > 165) 
  //         or (ratedWeight > 150),
  //     type logical
  //   ),

  //   #"FedEx Unauthorized US Billable Weight" = Table.AddColumn(
  //     #"FedEx Unauthorized Flag",
  //     "FedEx Unauthorized US Billable Weight",
  //     each 
  //       if [#"FedEx Unauthorized Flag"] = null then null
  //       else if [#"FedEx Unauthorized Flag"] then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]), 90})
  //       else if [#"FedEx Unauthorized Flag"] = false then
  //         List.Max({[#"FedEx US Dim Weight"], Number.RoundUp([#"Specs.Carton - Weight"]) })
  //       else null,
  //     type number
  //   ),

  //   #"FedEx Applied AHS Category" = Table.AddColumn(
  //     #"FedEx Unauthorized US Billable Weight",
  //     "FedEx Applied AHS Category",
  //     each 
  //       try 
  //         if [#"FedEx Unauthorized Flag"] then "Unauthorized"
  //         else if [#"FedEx Oversize Flag"] then "Oversize"
  //         else if [#"FedEx AHS Weight Flag"] then "AHS Weight"
  //         else if [#"FedEx AHS Dim Flag"] then "AHS Dim"
  //         else null // "N/A" // change from N/A to null
  //       otherwise null,
  //     type text
  //   ),

  //   #"FedEx US Final Billable Weight" = Table.AddColumn(
  //     #"FedEx Applied AHS Category",
  //     "FedEx US Final Billable Weight",
  //     each List.Max({
  //         [#"FedEx Unauthorized US Billable Weight"],
  //         [#"FedEx Oversize US Billable Weight"],
  //         [#"FedEx AHS Dim US Billable Weight"],
  //         [#"FedEx US Dim Weight"],
  //         Number.RoundUp([#"Specs.Carton - Weight"])
  //     }),
  //     type number
  // ),

  // #"Merged queries" = Table.NestedJoin(#"FedEx US Final Billable Weight", {"Material"}, #"Last sale date", {"Material"}, "Last sale date", JoinKind.LeftOuter),
  #"Merged queries" = Table.NestedJoin(#"FedEx CAN Final Billable Weight", {"Material"}, #"Last sale date", {"Material"}, "Last sale date", JoinKind.LeftOuter),

  #"Expanded Last sale date" = 
    Table.ExpandTableColumn(#"Merged queries", "Last sale date", {"Last Sale Date"}, {"Last Sale Date.1"})

     
,
  #"Merged queries 1" = Table.NestedJoin(#"Expanded Last sale date", {"Material"}, #"Warranty Period", {"NA Finished Good"}, "Warranty Period", JoinKind.LeftOuter),
  #"Expanded Warranty Period" = Table.TransformColumns(
    Table.ExpandTableColumn(
        #"Merged queries 1",
        "Warranty Period",
        {"Warranty _Year_"},
        {"Warranty _Year_"}
    ),
    {
        {
            "Warranty _Year_",
            each if _ = null then 0 else _,
            Int64.Type
        }
    }
),
  #"Added custom" = Table.AddColumn(#"Expanded Warranty Period", "Last Warranty Date", each Date.AddYears([Last Sale Date.1], [Warranty _Year_])),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"Last Warranty Date", type date}, {"Specs.Carton - Length", type number}, {"Specs.Carton - Width", type number}, {"Specs.Carton - Height", type number}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "Concat Length X Width", each if [#"Specs.Pallet - Length"] = null or [#"Specs.Pallet - Width"] = null
    then null
    else
        Number.ToText([#"Specs.Pallet - Length"], "0") &
        " X " &
        Number.ToText([#"Specs.Pallet - Width"], "0")), {{"Concat Length X Width", type text}}),
  
  //CJ 4/27/2026: Add Parcel / LTL Flag
  #"LTL_Parcel" = Table.AddColumn(
    #"Added custom 1",
    "LTL_Parcel",
    each if [#"Specs.Carton - Weight"] <= 150 and [#"Length & Girth"] <= 165 and [#"Specs.Carton - Weight"] <> null and [#"Length & Girth"] <> null
      then "Parcel" 
      else "LTL",
    type text
),
  #"Merged queries 2" = Table.NestedJoin(LTL_Parcel, {"Material"}, #"ABC Analysis", {"Product"}, "ABC Analysis", JoinKind.LeftOuter),
  #"Expanded ABC Analysis" = Table.ExpandTableColumn(#"Merged queries 2", "ABC Analysis", {"ABC", "XYZ"}, {"ABC", "XYZ"}),
  #"Merged queries 3" = Table.NestedJoin(#"Expanded ABC Analysis", {"Material"}, #"FCST ACCURACY", {"SKU Level"}, "FCST ACCURACY", JoinKind.LeftOuter),
  #"Expanded FCST ACCURACY" = Table.ExpandTableColumn(#"Merged queries 3", "FCST ACCURACY", {"AVG Forecast", "DOS Target","Bias %"}, {"AVG Forecast", "DOS Target","Bias %"}),
  #"Filtered rows" = Table.SelectRows(#"Expanded FCST ACCURACY", each [Material] <> null and [Material] <> ""),
  #"Merged queries 4" = Table.NestedJoin(#"Filtered rows", {"Material"}, #"THD Item number", {"ITEM"}, "THD Item number", JoinKind.LeftOuter),
  #"Expanded THD Item number" = Table.ExpandTableColumn(#"Merged queries 4", "THD Item number", {"THD item_"}, {"THD item_"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded THD Item number", {{"THD item_", "THD Item Number"}}),
  #"Merged queries 5" = Table.NestedJoin(#"Renamed columns", {"Material"}, #"Ecomm Assortment 2026", {"SAP"}, "Ecomm Assortment 2026", JoinKind.LeftOuter),
  #"Expanded Ecomm Assortment 2026" = Table.ExpandTableColumn(#"Merged queries 5", "Ecomm Assortment 2026", {"SAP"}, {"ECOM SKU"}),

  #"ECOMM Flag" = Table.AddColumn(
  #"Expanded Ecomm Assortment 2026",
  "ECOM Flag",
  each [ECOM SKU] <> null and Text.Trim(Text.From([ECOM SKU])) <> "",
  type logical
),
  #"Removed columns" = Table.RemoveColumns(#"ECOMM Flag", {"ECOM SKU"})


in
  #"Removed columns";
shared #"DIM BOM Combined" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1"= Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "DIM BOM Combined", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"Component Forecast Initial" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT Component Forecast Initial", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"DIM MRPSKU" = /*OLD CODE -- RETIRED 3/26/2026
let
  Source = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/MRPSKU%20Key.xlsx"), null, true),
  #"MRPSKU Key_Sheet" = Source{[Item="MRPSKU Key",Kind="Sheet"]}[Data],
  #"Promoted Headers" = Table.PromoteHeaders(#"MRPSKU Key_Sheet", [PromoteAllScalars=true]),
  #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Material", type text}, {"MRP Area", type text}, {"MRPSKU Key", type text}}),
  #"Removed other columns" = Table.SelectColumns(#"Component Forecast Initial", {"MRPSKU Key", "Material", "MRP Area"}),
  Combined_Stuff = Table.Combine({#"Changed Type",#"Removed other columns"}),
  #"Removed duplicates" = Table.Distinct(Combined_Stuff, {"MRPSKU Key"}),
  #"Merged queries" = Table.NestedJoin(#"Removed duplicates", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged queries", "DIM Product", {"PC Business Unit", "SKU & Desc"}, {"PC Business Unit", "SKU & Desc"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded DIM Product", "MRP Area Left 2", each Text.Start([MRP Area], 2)), {{"MRP Area Left 2", type text}}),
  #"Merged queries 1" = Table.NestedJoin(#"Added custom", {"MRP Area Left 2", "Material"}, #"DIM ZMM02 COGS", {"Plnt", "Material"}, "DIM ZMM02 COGS", JoinKind.LeftOuter),
  #"Expanded DIM ZMM02 COGS" = Table.ExpandTableColumn(#"Merged queries 1", "DIM ZMM02 COGS", {"Standard price", "per", "Cost"}, {"Standard price", "per", "Cost"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded DIM ZMM02 COGS", {{"Standard price", Currency.Type}, {"per", Int64.Type}, {"Cost", Currency.Type}})
in
  #"Changed column type"
*/

// CJ: 3/26/2026 - updated MRPSKU Key logic (brings in all combinations of SKU MRP Area)
let
  //Relevant Tables
  CF_MaterialOnly = Table.SelectColumns(#"Component Forecast Initial", {"Material"}),
  DP_MaterialOnly = Table.SelectColumns(#"DIM Product", {"Material"}),
  MI_MaterialOnly=Table.SelectColumns(#"Missing Items", {"Material"}),
  DIM_MRP_Area = #"DIM MRP Area",

  //Append the two tables
  Appended = Table.Combine({CF_MaterialOnly, DP_MaterialOnly,MI_MaterialOnly}),

  //Remove duplicates based on Material
  DistinctMaterials = Table.Distinct(Appended, {"Material"}),

  //Cross Join Tables
  MaterialsWithKey = Table.AddColumn(DistinctMaterials, "__Key", each 1),
  MRPWithKey = Table.AddColumn(DIM_MRP_Area, "__Key", each 1),
  CrossJoined = Table.Join(MaterialsWithKey, "__Key", MRPWithKey, "__Key", JoinKind.Inner),

  //Remove the helper key column
  RemoveColumns = Table.RemoveColumns(CrossJoined, {"__Key"}),

  //Add MRPSKU Key
  #"MRPSKU Key" = Table.AddColumn(
      RemoveColumns,
      "MRPSKU Key",
      each Text.Combine({[MRP Area], [Material]}, "|"),
      type text
  ),

  //Add DIM Product
  #"Merged DIM Product" = Table.NestedJoin(#"MRPSKU Key", {"Material"}, #"DIM Product", {"Material"}, "DIM Product", JoinKind.LeftOuter),
  #"Expanded DIM Product" = Table.ExpandTableColumn(#"Merged DIM Product", "DIM Product", {"PC Business Unit", "SKU & Desc"}, {"PC Business Unit", "SKU & Desc"}),

  //Add ZMM02 COGS
  #"Merged DIM ZMM02 COGS" = Table.NestedJoin(#"Expanded DIM Product", {"Plant", "Material"}, #"DIM ZMM02 COGS", {"Plnt", "Material"}, "DIM ZMM02 COGS", JoinKind.LeftOuter),
  #"Expanded DIM ZMM02 COGS" = Table.ExpandTableColumn(#"Merged DIM ZMM02 COGS", "DIM ZMM02 COGS", {"Standard price", "per", "Cost"}, {"Standard price", "per", "Cost"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded DIM ZMM02 COGS", {{"Standard price", Currency.Type}, {"per", Int64.Type}, {"Cost", Currency.Type}}),
  #"Removed duplicates" = Table.Distinct(#"Changed column type", {"MRPSKU Key"})

in
  #"Removed duplicates";
shared DefaultDestination = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
shared #"DIM BOM Combined FG" = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1"= Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "DIM BOM Combined", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 3", each ([BOM Type] = "Finished Goods")),
  #"Removed duplicates" = Table.Distinct(#"Filtered rows", {"Component"})
in
  #"Removed duplicates";
shared Specs = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Specs", ItemKind = "Table"]}[Data],

  // Group + prioritize non-null Carton - Volume
  #"Grouped" =
    Table.Group(
      #"Navigation 2",
      {"Item"},
      {
        {
          "BestRow",
          (t as table) =>
            Table.First(
              Table.Sort(
                t,
                {{"Carton - Volume", Order.Descending}}
              )
            ),
          type record
        }
      }
    ),

  // Expand EXCLUDING the grouping column
  ColumnsToExpand =
    List.RemoveItems(
      Table.ColumnNames(#"Navigation 2"),
      {"Item"}
    ),

  #"Expanded BestRow" =
    Table.ExpandRecordColumn(
      #"Grouped",
      "BestRow",
      ColumnsToExpand
    ),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded BestRow", {{"SAP", type text}, {"Override", type text}, {"Current", type text}, {"Carton - Length", type number}, {"Carton - Width", type number}, {"Carton - Height", type number}, {"Carton - Volume", type number}, {"Carton - Weight", type number}, {"Carton - cf", type number}, {"Carton - pcf", type number}, {"Pallet - Length", type number}, {"Pallet - Width", type number}, {"Pallet - Height", type number}, {"Pallet - Volume", type number}, {"Pallet - Weight", type number}, {"Pallet - cf", type number}, {"Pallet - pcf", type number}, {"LP", type number}, {"Carton Class", type number}, {"SS/PLT Class", type number}, {"Carton Dim Wt", type number}, {"Oversize +130"" Max 165""", type number}, {"Linear Ft CTN", type number}})
in
  #"Changed column type";
shared #"Invoice to Net Products" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Invoice to Net Products", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Crossdock SKUS" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Crossdock SKUS", ItemKind = "Table"]}[Data],
  #"Removed columns" = Table.RemoveColumns(#"Navigation 2", {"Description"})
in
  #"Removed columns";
shared #"DIM Product_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM Product", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DIM ZMM02 COGS" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "ZMM02", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"DIM MRP Area" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "DIM MRP Area", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"Current Item Sheets-2023" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Current Item Sheets-2023", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"Current Item Sheets-2024" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Current Item Sheets-2024", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Current Item Sheets-2025" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Current Item Sheets-2025", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Current Item Sheets-2026" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Current Item Sheets-2026", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared DCMSource = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DCMSource", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared PackSource = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "PackSource", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Last sale date" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Last sale date", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Warranty Period" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Warranty Period", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"ABC Analysis" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "ABC Analysis", ItemKind = "Table"]}[Data],
  #"Sorted rows" = Table.Sort(#"Navigation 2", {{"ABC", Order.Ascending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"Product"})
in
  #"Removed duplicates";
shared NavigationQuery = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true])
in
  Source;
[BindToDefaultDestination = true]
shared #"FCST ACCURACY" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FCST ACCURACY", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"SKU Level", type text}, {"AVG Forecast", Percentage.Type}}),
  #"Sorted rows" = Table.Sort(#"Changed column type", {{"SKU Level", Order.Ascending}, {"AVG Forecast", Order.Descending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"SKU Level"})
in
  #"Removed duplicates";
[BindToDefaultDestination = true]
shared #"Missing Items" = let
    Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
    Navigation = Source{[Name = "Missing Items To Add.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
    #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "Export", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Material", type text}, {"Description", type text}, {"PC Business Unit", type text}, {"Dim Products.PRODUCT LINE DESC", type text}, {"Dim Products.PRODUCT TYPE", type text}, {"Not In Current Items Sheet", type text}}),
  #"Filtered rows" = Table.SelectRows(#"Changed column type", each not Text.Contains([Material], "272789"))
in
    #"Filtered rows";
shared #"THD Item number" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "THD Item number", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Ecomm Assortment 2026" = let
  Source = SharePoint.Files(
    "https://keteronline.sharepoint.com/teams/KNAItemInfo",
    [ApiVersion = 15]
  ),

  File =
    Source{
      [
        Name = "Ecomm Assortment 2026.xlsx",
        #"Folder Path" =
          "https://keteronline.sharepoint.com/teams/KNAItemInfo/Shared Documents/Item Info/"
      ]
    }[Content],

  Workbook = Excel.Workbook(File, null, true),
  Navigation = Workbook{[Item = "Items", Kind = "Sheet"]}[Data],

  
  #"Removed Top 4 Rows" = Table.Skip(Navigation, 4),

  #"Promoted Headers" =
    Table.PromoteHeaders(
      #"Removed Top 4 Rows",
      [PromoteAllScalars = true]
    ),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted Headers", {{"SAP", type text}}),
  #"Removed duplicates" = Table.Distinct(#"Changed column type", {"SAP"})


in
  #"Removed duplicates";
