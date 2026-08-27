[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared Data = let
    Source = Excel.Workbook(
        Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/Data/Copy%20of%20DTC%20US%2002.2026.xlsx"), 
        null, 
        true
    ),
    #"Navigation 1" = Source{[Item = "Data", Kind = "Sheet"]}[Data],
    #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
    #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", { /* your type list */ }),

    // Get all column names
    AllCols = Table.ColumnNames(#"Changed column type"),

    // Find all description columns
    DescriptionCols = List.Select(AllCols, each Text.StartsWith(_, "Tracking ID Charge Description")),

    // Pair each description column with the next column (amount)
    Pairs = List.Transform(
        DescriptionCols,
        (descCol) =>
            let
                idx = List.PositionOf(AllCols, descCol),
                amtCol = if idx <> -1 and idx + 1 < List.Count(AllCols) then AllCols{idx + 1} else null
            in
                [DescriptionColumn = descCol, AmountColumn = amtCol]
    ),

    // Identify columns to keep
    IdentifyingCols = List.RemoveItems(AllCols, List.Combine({DescriptionCols, List.Transform(Pairs, each _[AmountColumn])})),

    // Build combined tables
    CombinedTables = List.Transform(
        Pairs,
        (pair) =>
            let
                descCol = pair[DescriptionColumn],
                amtCol  = pair[AmountColumn],
                tempTbl = Table.SelectColumns(#"Changed column type", IdentifyingCols & {descCol, amtCol}),
                renamed = Table.RenameColumns(tempTbl, {{descCol, "Description"}, {amtCol, "Amount"}}),
                withIdx = Table.AddColumn(renamed, "PairID", each descCol)
            in
                renamed
    ),

    Combined = Table.Combine(CombinedTables),

    // Remove rows where both Description and Amount are null/empty
    Cleaned = Table.SelectRows(
        Combined,
        each not (
            ( [Description] = null or Text.Trim(Text.From([Description])) = "" )
            and
            ( [Amount] = null or Text.Trim(Text.From([Amount])) = "" )
        )
    ),
  #"Changed column type 1" = Table.TransformColumnTypes(Cleaned, {{"Transportation Charge Amount", type text}, {"Consolidated Account Number", type text}, {"Bill to Account Number", type text}, {"Invoice Date", type text}, {"Invoice Number", type text}, {"Store ID", type text}, {"Original Amount Due", type text}, {"Current Balance", type text}, {"Payor", type text}, {"Ground Tracking ID Prefix", type text}, {"Express or Ground Tracking ID", type text}, {"Net Charge Amount", type text}, {"Service Type", type text}, {"Ground Service", type text}, {"Shipment Date", type text}, {"POD Delivery Date", type text}, {"POD Delivery Time", type text}, {"POD Service Area Code", type text}, {"POD Signature Description", type text}, {"Actual Weight Amount", type text}, {"Actual Weight Units", type text}, {"Rated Weight Amount", type text}, {"Rated Weight Units", type text}, {"Number of Pieces", type text}, {"Bundle Number", type text}, {"Meter Number", type text}, {"TDMasterTrackingID", type text}, {"Service Packaging", type text}, {"Dim Length", type text}, {"Dim Width", type text}, {"Dim Height", type text}, {"Dim Divisor", type text}, {"Dim Unit", type text}, {"Recipient Name", type text}, {"Recipient Company", type text}, {"Recipient Address Line 1", type text}, {"Recipient Address Line 2", type text}, {"Recipient City", type text}, {"Recipient State", type text}, {"Recipient Zip Code", type text}, {"Recipient Country/Territory", type text}, {"Shipper Company", type text}, {"Shipper Name", type text}, {"Shipper Address Line 1", type text}, {"Shipper Address Line 2", type text}, {"Shipper City", type text}, {"Shipper State", type text}, {"Shipper Zip Code", type text}, {"Shipper Country/Territory", type text}, {"Original Customer Reference", type text}, {"Original Ref#2", type text}, {"Original Ref#3/PO Number", type text}, {"Original Department Reference Description", type text}, {"Updated Customer Reference", type text}, {"Updated Ref#2", type text}, {"Updated Ref#3/PO Number", type text}, {"Updated Department Reference Description", type text}, {"RMA#", type text}, {"Original Recipient Address Line 1", type text}, {"Original Recipient Address Line 2", type text}, {"Original Recipient City", type text}, {"Original Recipient State", type text}, {"Original Recipient Zip Code", type text}, {"Original Recipient Country/Territory", type text}, {"Zone Code", type text}, {"Cost Allocation", type text}, {"Alternate Address Line 1", type text}, {"Alternate Address Line 2", type text}, {"Alternate City", type text}, {"Alternate State Province", type text}, {"Alternate Zip Code", type text}, {"Alternate Country/Territory Code", type text}, {"CrossRefTrackingID Prefix", type text}, {"CrossRefTrackingID", type text}, {"Entry Date", type text}, {"Entry Number", type text}, {"Customs Value", type text}, {"Customs Value Currency Code", type text}, {"Declared Value", type text}, {"Declared Value Currency Code", type text}, {"Commodity Description", type text}, {"Commodity Country/Territory Code", type text}, {"Commodity Description_1", type text}, {"Commodity Country/Territory Code_2", type text}, {"Commodity Description_3", type text}, {"Commodity Country/Territory Code_4", type text}, {"Commodity Description_5", type text}, {"Commodity Country/Territory Code_6", type text}, {"Currency Conversion Date", type text}, {"Currency Conversion Rate", type text}, {"Multiweight Number", type text}, {"Multiweight Total Multiweight Units", type text}, {"Multiweight Total Multiweight Weight", type text}, {"Multiweight Total Shipment Charge Amount", type text}, {"Multiweight Total Shipment Weight", type text}, {"Ground Tracking ID Address Correction Discount Charge Amount", type text}, {"Ground Tracking ID Address Correction Gross Charge Amount", type text}, {"Rated Method", type text}, {"Sort Hub", type text}, {"Estimated Weight", type text}, {"Estimated Weight Unit", type text}, {"Postal Class", type text}, {"Process Category", type text}, {"Package Size", type text}, {"Delivery Confirmation", type text}, {"Tendered Date", type text}, {"MPS Package ID", type text}, {"Shipment Notes", type text}, {"Description", type text}, {"Amount", type text}}),
  #"Pivoted column" = Table.Pivot(Table.TransformColumnTypes(#"Changed column type 1", {{"Description", type text}}), List.Distinct(Table.TransformColumnTypes(#"Changed column type 1", {{"Description", type text}})[Description]), "Description", "Amount")
in
    #"Pivoted column";
