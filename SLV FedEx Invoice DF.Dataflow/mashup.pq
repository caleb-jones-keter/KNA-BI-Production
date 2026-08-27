[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"FACT FedEx Invoice History" = let
  SiteUrl = "https://keteronline.sharepoint.com/teams/SavannahRDC",

  Source = SharePoint.Contents(
    SiteUrl,
    [
      ApiVersion = 15,
      Implementation = "2.0"
    ]
  ),

  #"Shared Documents" = Source{[Name = "Shared Documents"]}[Content],
  #"PowerBI Projects" = #"Shared Documents"{[Name = "PowerBI Projects"]}[Content],
  DL = #"PowerBI Projects"{[Name = "DL"]}[Content],

  FileContent = DL{[Name = "FedEx Invoice History.XLSX"]}[Content],

  #"Imported Excel workbook" = Excel.Workbook(FileContent, null, true),

  #"Navigation 1" = #"Imported Excel workbook"{[
    Item = "Data",
    Kind = "Sheet"
  ]}[Data],

  #"Promoted headers" = Table.PromoteHeaders(
    #"Navigation 1",
    [PromoteAllScalars = true]
  ),

  RefreshTime =
    DateTimeZone.RemoveZone(
      DateTimeZone.SwitchZone(
        DateTimeZone.UtcNow(),
        -4
      )
    ),

  #"Added Last Updated" =
    Table.AddColumn(
      #"Promoted headers",
      "Last Updated",
      each RefreshTime,
      type datetime
    ),

  NumberAndDateTypeMap = {
    {"Invoice Date", type date},
    {"Shipment Date", type date},
    {"POD Delivery Date", type date},
    {"POD Delivery Time", type time},
    {"Entry Date", type date},
    {"Currency Conversion Date", type date},
    {"Tendered Date", type date},
    {"Original Amount Due", type number},
    {"Current Balance", type number},
    {"Transportation Charge Amount", type number},
    {"Net Charge Amount", type number},
    {"Actual Weight Amount", type number},
    {"Rated Weight Amount", type number},
    {"Number of Pieces", type number},
    {"Dim Length", type number},
    {"Dim Width", type number},
    {"Dim Height", type number},
    {"Dim Divisor", type number},
    {"Currency Conversion Rate", type number},
    {"Multiweight Total Multiweight Units", type number},
    {"Multiweight Total Multiweight Weight", type number},
    {"Multiweight Total Shipment Charge Amount", type number},
    {"Multiweight Total Shipment Weight", type number},
    {"Estimated Weight", type number}
  },

  ExistingNumberAndDateTypeMap =
    List.Select(
      NumberAndDateTypeMap,
      each List.Contains(Table.ColumnNames(#"Added Last Updated"), _{0})
    ),

  #"Changed column type" =
    Table.TransformColumnTypes(
      #"Added Last Updated",
      ExistingNumberAndDateTypeMap
    ),

  #"Filtered rows" =
    Table.SelectRows(
      #"Changed column type",
      each [Invoice Date] <> null
        and Date.IsInPreviousNDays([Invoice Date], 90)
    ),

  BufferedRows = Table.Buffer(#"Filtered rows"),

  DescriptionColumns =
    List.Select(
      Table.ColumnNames(BufferedRows),
      each Text.StartsWith(_, "Tracking ID Charge Description")
    ),

  AmountColumns =
    List.Select(
      Table.ColumnNames(BufferedRows),
      each Text.StartsWith(_, "Tracking ID Charge Amount")
    ),

  ChargeColumnPairs =
    if List.Count(DescriptionColumns) = 0 then
      {}
    else
      List.Transform(
        {0..List.Count(DescriptionColumns)-1},
        each [
          DescriptionColumn = DescriptionColumns{_},
          AmountColumn =
            if _ < List.Count(AmountColumns)
            then AmountColumns{_}
            else null
        ]
      ),

  AmountToNumber = (amountValue as any) as nullable number =>
    let
      AmountNumber =
        try Number.From(amountValue)
        otherwise try Number.FromText(Text.Replace(Text.From(amountValue), "$", ""))
        otherwise null
    in
      AmountNumber,

  // CJ 7/6/2026: Adding logic to force certain columns to always exist to avoid schema refresh fail
  AllChargeDescriptions =
    List.Distinct(
      List.RemoveNulls(
        List.Combine(
          List.Transform(
            DescriptionColumns,
            each List.Transform(
              Table.Column(BufferedRows, _),
              each if _ = null then null else Text.Trim(Text.From(_))
            )
          )
        )
      )
    ),

  CleanChargeName = (chargeName as text) as text =>
    let
      Trimmed = Text.Trim(chargeName),
      Singularized =
        if Text.EndsWith(Trimmed, " Charges") then
          Text.BeforeDelimiter(Trimmed, " Charges") & " Charge"
        else if Text.EndsWith(Trimmed, " charges") then
          Text.BeforeDelimiter(Trimmed, " charges") & " Charge"
        else
          Trimmed
    in
      Singularized,

  // add columns here as columns break to avoid schema drift
  KnownChargeDescriptions = {
    "DAS HI Residential",
    "DAS Remote Comm"
  },

  DynamicChargeNames =
    List.Select(
      List.Distinct(
        List.Transform(
          AllChargeDescriptions,
          each CleanChargeName(_)
        )
      ),
      each _ <> ""
    ),

  KnownChargeNames =
    List.Distinct(
      List.Transform(
        KnownChargeDescriptions,
        each CleanChargeName(_)
      )
    ),

  StableChargeNames =
    List.Distinct(
      List.Combine({
        KnownChargeNames,
        DynamicChargeNames
      })
    ),

  AddChargeFlagsAndValues =
    List.Accumulate(
      StableChargeNames,
      BufferedRows,
      (state as table, chargeName as text) =>
        let
          FlagColumnName = chargeName & " Flag",
          ValueColumnName = chargeName & " Value",

          AddFlag =
            Table.AddColumn(
              state,
              FlagColumnName,
              each
                List.AnyTrue(
                  List.Transform(
                    ChargeColumnPairs,
                    (pair) =>
                        let
                          DescValue =
                            Record.FieldOrDefault(_, pair[DescriptionColumn], null),

                          DescText =
                            if DescValue = null
                            then null
                            else Text.Trim(Text.From(DescValue)),

                          DescClean =
                            if DescText = null
                            then null
                            else CleanChargeName(DescText)
                        in
                          DescClean = chargeName
                  )
                ),
              type logical
            ),

          AddValue =
            Table.AddColumn(
              AddFlag,
              ValueColumnName,
              each
                let
                  MatchingAmounts =
                    List.RemoveNulls(
                      List.Transform(
                        ChargeColumnPairs,
                        (pair) =>
                            let
                              DescValue =
                                Record.FieldOrDefault(_, pair[DescriptionColumn], null),

                              DescText =
                                if DescValue = null
                                then null
                                else Text.Trim(Text.From(DescValue)),

                              DescClean =
                                if DescText = null
                                then null
                                else CleanChargeName(DescText),

                              AmountValue =
                                if pair[AmountColumn] = null
                                then null
                                else Record.FieldOrDefault(_, pair[AmountColumn], null),

                              AmountNumber =
                                AmountToNumber(AmountValue)
                            in
                              if DescClean = chargeName
                              then AmountNumber
                              else null
                      )
                    )
                  in
                    if List.Count(MatchingAmounts) = 0
                    then null
                    else List.Sum(MatchingAmounts),
              type number
            )

        in
          AddValue
    ),

  #"Added Top Charge Record" =
    Table.AddColumn(
      AddChargeFlagsAndValues,
      "Top Charge Record",
      each
        let
          ChargeRecords =
            List.RemoveNulls(
              List.Transform(
                ChargeColumnPairs,
                (pair) =>
                  let
                    DescValue =
                      Record.FieldOrDefault(_, pair[DescriptionColumn], null),

                    DescText =
                      if DescValue = null
                      then null
                      else Text.Trim(Text.From(DescValue)),

                    AmountValue =
                      if pair[AmountColumn] = null
                      then null
                      else Record.FieldOrDefault(_, pair[AmountColumn], null),

                    AmountNumber =
                      AmountToNumber(AmountValue)
                  in
                    if DescText <> null and DescText <> "" and AmountNumber <> null
                    then [
                      Description = DescText,
                      Amount = AmountNumber
                    ]
                    else
                      null
              )
            ),

          SortedCharges =
            List.Sort(
              ChargeRecords,
              (x, y) =>
                if x[Amount] > y[Amount] then
                  -1
                else if x[Amount] < y[Amount] then
                  1
                else
                  0
            )
        in
          if List.Count(SortedCharges) = 0
          then null
          else SortedCharges{0}
    ),

  #"Added Top Tracking ID Charge" =
    Table.AddColumn(
      #"Added Top Charge Record",
      "Top Tracking ID Charge",
      each try [Top Charge Record][Description] otherwise null,
      type text
    ),

  #"Added Top Tracking ID Charge Amount" =
    Table.AddColumn(
      #"Added Top Tracking ID Charge",
      "Top Tracking ID Charge Amount",
      each try [Top Charge Record][Amount] otherwise null,
      type number
    ),

  #"Removed Top Charge Record" =
    Table.RemoveColumns(
      #"Added Top Tracking ID Charge Amount",
      {"Top Charge Record"}
    ),

  #"Added Net Surcharge Amount" =
    Table.AddColumn(
      #"Removed Top Charge Record",
      "Net Surcharge & Discount Amount",
      each
        let
          ChargeAmounts =
            List.RemoveNulls(
              List.Transform(
                ChargeColumnPairs,
                (pair) =>
                    let
                      AmountValue =
                        if pair[AmountColumn] = null
                        then null
                        else Record.FieldOrDefault(_, pair[AmountColumn], null),

                      AmountNumber =
                        AmountToNumber(AmountValue)
                    in
                      AmountNumber
              )
            )
        in
          if List.Count(ChargeAmounts) = 0
          then null
          else List.Sum(ChargeAmounts),
      type number
    ),

  OldChargeColumns =
    List.Combine({
      DescriptionColumns,
      AmountColumns
    }),

  ExistingOldChargeColumns =
    List.Intersect({
      Table.ColumnNames(#"Added Net Surcharge Amount"),
      OldChargeColumns
    }),

  #"Removed Old Charge Columns" =
    Table.RemoveColumns(
      #"Added Net Surcharge Amount",
      ExistingOldChargeColumns
    ),

  TextTypeMap = {
    {"Consolidated Account Number", type text},
    {"Bill to Account Number", type text},
    {"Invoice Number", type text},
    {"Store ID", type text},
    {"Payor", type text},
    {"Ground Tracking ID Prefix", type text},
    {"Express or Ground Tracking ID", type text},
    {"Service Type", type text},
    {"Ground Service", type text},
    {"POD Service Area Code", type text},
    {"POD Signature Description", type text},
    {"Actual Weight Units", type text},
    {"Rated Weight Units", type text},
    {"Bundle Number", type text},
    {"Meter Number", type text},
    {"TDMasterTrackingID", type text},
    {"Service Packaging", type text},
    {"Dim Unit", type text},
    {"Recipient Name", type text},
    {"Recipient Company", type text},
    {"Recipient Address Line 1", type text},
    {"Recipient Address Line 2", type text},
    {"Recipient City", type text},
    {"Recipient State", type text},
    {"Recipient Zip Code", type text},
    {"Recipient Country/Territory", type text},
    {"Shipper Company", type text},
    {"Shipper Name", type text},
    {"Shipper Address Line 1", type text},
    {"Shipper Address Line 2", type text},
    {"Shipper City", type text},
    {"Shipper State", type text},
    {"Shipper Zip Code", type text},
    {"Shipper Country/Territory", type text},
    {"Original Customer Reference", type text},
    {"Original Ref#2", type text},
    {"Original Ref#3/PO Number", type text},
    {"Original Department Reference Description", type text},
    {"Updated Customer Reference", type text},
    {"Updated Ref#2", type text},
    {"Updated Ref#3/PO Number", type text},
    {"Updated Department Reference Description", type text},
    {"RMA#", type text},
    {"Original Recipient Address Line 1", type text},
    {"Original Recipient Address Line 2", type text},
    {"Original Recipient City", type text},
    {"Original Recipient State", type text},
    {"Original Recipient Zip Code", type text},
    {"Original Recipient Country/Territory", type text},
    {"Zone Code", type text},
    {"Cost Allocation", type text},
    {"Alternate Address Line 1", type text},
    {"Alternate Address Line 2", type text},
    {"Alternate City", type text},
    {"Alternate State Province", type text},
    {"Alternate Zip Code", type text},
    {"Alternate Country/Territory Code", type text},
    {"CrossRefTrackingID Prefix", type text},
    {"CrossRefTrackingID", type text},
    {"Entry Number", type text},
    {"Customs Value", type text},
    {"Customs Value Currency Code", type text},
    {"Declared Value", type text},
    {"Declared Value Currency Code", type text},
    {"Commodity Description", type text},
    {"Commodity Country/Territory Code", type text},
    {"Commodity Description_1", type text},
    {"Commodity Country/Territory Code_2", type text},
    {"Commodity Description_3", type text},
    {"Commodity Country/Territory Code_4", type text},
    {"Commodity Description_5", type text},
    {"Commodity Country/Territory Code_6", type text},
    {"Multiweight Number", type text},
    {"Ground Tracking ID Address Correction Discount Charge Amount", type text},
    {"Ground Tracking ID Address Correction Gross Charge Amount", type text},
    {"Rated Method", type text},
    {"Sort Hub", type text},
    {"Estimated Weight Unit", type text},
    {"Postal Class", type text},
    {"Process Category", type text},
    {"Package Size", type text},
    {"Delivery Confirmation", type text},
    {"MPS Package ID", type text},
    {"Shipment Notes", type text}
  },

  ExistingTextTypeMap =
    List.Select(
      TextTypeMap,
      each List.Contains(Table.ColumnNames(#"Removed Old Charge Columns"), _{0})
    ),

  #"Changed column type 1" =
    Table.TransformColumnTypes(
      #"Removed Old Charge Columns",
      ExistingTextTypeMap
    ),

  #"Length & Girth" =
    Table.AddColumn(
      #"Changed column type 1",
      "Length & Girth",
      each
        if [#"Dim Length"] = null or [#"Dim Height"] = null or [#"Dim Width"] = null then
          null
        else
          Number.RoundUp([#"Dim Length"])
          + (2 * Number.RoundUp([#"Dim Height"]))
          + (2 * Number.RoundUp([#"Dim Width"])),
      type number
    ),

  DimWeight =
    Table.AddColumn(
      #"Length & Girth",
      "Dim Weight",
      each
        let
          Divisor = [#"Dim Divisor"],
          Length = [#"Dim Length"],
          Width = [#"Dim Width"],
          Height = [#"Dim Height"]
        in
          if Divisor = null
            or Divisor = 0
            or Length = null
            or Width = null
            or Height = null
          then
            null
          else
            Number.RoundUp((Length * Width * Height) / Divisor),
      Int64.Type
    ),

  #"Recipient Zip Clean" =
    Table.TransformColumnTypes(
      Table.AddColumn(
        DimWeight,
        "Recipient Zip Clean",
        each
          let
            zip = try Record.Field(_, "Recipient Zip Code") otherwise null,
            noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
            hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
            result = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces
          in
            result
      ),
      {{"Recipient Zip Clean", type text}}
    ),

  #"Shipper Zip Clean" =
    Table.TransformColumnTypes(
      Table.AddColumn(
        #"Recipient Zip Clean",
        "Shipper Zip Clean",
        each
          let
            zip = try Record.Field(_, "Shipper Zip Code") otherwise null,
            noSpaces = if zip <> null then Text.Replace(Text.From(zip), " ", "") else null,
            hyphenPos = if noSpaces <> null then Text.PositionOf(noSpaces, "-") else -1,
            result = if hyphenPos > -1 then Text.Start(noSpaces, hyphenPos) else noSpaces
          in
            result
      ),
      {{"Shipper Zip Clean", type text}}
    )

in
  #"Shipper Zip Clean";
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
