[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"_TEST RPA Report TW" = let
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/KeterDigitalSystemsTrainingCenter",
        [ApiVersion = 15]
    ),

    FilteredFolder =
        Table.SelectRows(
            Source,
            each Text.Contains(
                [Folder Path],
                "Shared Documents/PIM/spare parts/RPA report"
            )
        ),

    ExcelFiles =
        Table.SelectRows(
            FilteredFolder,
            each Text.EndsWith(Text.Lower([Name]), ".xlsx")
              or Text.EndsWith(Text.Lower([Name]), ".xls")
        ),

    Sorted =
        Table.Sort(
            ExcelFiles,
            {{"Date created", Order.Descending}}
        ),

    TopFiles = Table.FirstN(Sorted, 3),

    LatestFile =
        if Table.RowCount(TopFiles) = 0 then
            null
        else
            TopFiles{0},

    Workbook =
        if LatestFile = null then
            null
        else
            Excel.Workbook(LatestFile[Content], null, true),

    AllDataSheet =
        if Workbook = null then
            #table({}, {})
        else
            Table.SelectRows(
                Workbook,
                each Text.Trim([Name]) = "All Data"
            ),

    DataOnly =
        if Table.RowCount(AllDataSheet) = 0 then
            #table({}, {})
        else
            AllDataSheet{0}[Data],

    CleanErrors =
        Table.ReplaceErrorValues(
            DataOnly,
            List.Transform(Table.ColumnNames(DataOnly), each {_, null})
        ),

    AllText =
        Table.TransformColumnTypes(
            CleanErrors,
            List.Transform(Table.ColumnNames(CleanErrors), each {_, type text})
        ),

    ReplaceInvalidValuesBeforeHeaders =
        Table.ReplaceValue(
            AllText,
            "#N/A",
            null,
            Replacer.ReplaceValue,
            Table.ColumnNames(AllText)
        ),

    PromotedHeaders =
        if Table.IsEmpty(ReplaceInvalidValuesBeforeHeaders) then
            ReplaceInvalidValuesBeforeHeaders
        else
            Table.PromoteHeaders(
                ReplaceInvalidValuesBeforeHeaders,
                [PromoteAllScalars = true]
            ),

    ReplaceInvalidValuesAfterHeaders =
        Table.ReplaceValue(
            PromotedHeaders,
            "#N/A",
            null,
            Replacer.ReplaceValue,
            Table.ColumnNames(PromotedHeaders)
        ),

    DataSource =
        if LatestFile = null then
            ReplaceInvalidValuesAfterHeaders
        else
            Table.AddColumn(
                ReplaceInvalidValuesAfterHeaders,
                "Data Source",
                each LatestFile[Name],
                type text
            ),

    DataSourceOrder =
        Table.AddColumn(
            DataSource,
            "Data Source Order",
            each "1",
            type text
        ),

    #"Changed column type" =
        Table.TransformColumnTypes(
            DataSourceOrder,
            {
                {"Product Name", type text},
                {"Product SKU", type text},
                {"17xxxxxx", type text},
                {"Part Customer Name", type text},
                {"Part Customer Number", type text},
                {"EAN Code", type text},
                {"Product Color Code", type text},
                {"Product Color Desc", type text},
                {"Market Group#(lf)GMD 31 desc", type text},
                {"GMD31", type text},
                {"Product Type#(lf)GMD 30 desc", type text},
                {"GMD30", type text},
                {"Product Type Detailed#(lf)GMD 29 desc", type text},
                {"GMD29", type text},
                {"STD.PROD.SITE (SOURCE)#(lf)GMD 5 desc", type text},
                {"GMD5", type text},
                {"ACT.PROD.SITE(SOURCE2)#(lf)GMD 24 desc", type text},
                {"GMD24", type text},
                {"Spare Part SKU", type text},
                {"Spare Part Name", type text},
                {"Spare Part Size", type text},
                {"set/apart", type text},
                {"Sign", type text},
                {"Qty Spare Parts per ptoduct", type text},
                {"Spare Part Previous Version", type text},
                {"Country", type text},
                {"Spare Part Color Code", type text},
                {"Spare Part Color Desc", type text},
                {"Data Source", type text},
                {"Data Source Order", type text}
            }
        )
in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"_TEST RPA Report LW" = let
    // Connect to SharePoint
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/KeterDigitalSystemsTrainingCenter",
        [ApiVersion = 15]
    ),
    // Filter to target folder
    FilteredFolder = Table.SelectRows(
        Source,
        each Text.Contains([Folder Path], "Shared Documents/PIM/spare parts/RPA report")
    ),
    // Keep only Excel files
    ExcelFiles = Table.SelectRows(
        FilteredFolder,
        each Text.EndsWith(Text.Lower([Name]), ".xlsx") or Text.EndsWith(Text.Lower([Name]), ".xls")
    ),
    // Sort newest first
    Sorted = Table.Sort(ExcelFiles, {{"Date created", Order.Descending}}),
    // Get 2nd latest file
    LatestFile = Sorted{1},
    // LatestFile = Sorted{21}, //CJ - CALEB TESTING CHANGE BACK
    // Read workbook from binary content
    Workbook = Excel.Workbook(LatestFile[Content], null, true),
    // Filter to "All Data" sheet
    AllDataSheet = Table.SelectRows(Workbook, each Text.Trim([Name]) = "All Data"),
    // Get the sheet's table
    DataOnly = AllDataSheet{0}[Data],
    // Step 1: Replace Excel error values with null
    CleanErrors = Table.ReplaceErrorValues(
        DataOnly,
        List.Transform(Table.ColumnNames(DataOnly), each {_, null})
    ),
    // Step 2: Force all columns to Text type
    AllText = Table.TransformColumnTypes(
        CleanErrors,
        List.Transform(Table.ColumnNames(CleanErrors), each {_, type text})
    ),
    #"Promoted headers" = Table.PromoteHeaders(AllText, [PromoteAllScalars = true]),
    #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Product SKU", type text}, {"17xxxxxx", type text}, {"Part Customer Number", type text}, {"EAN Code", type text}, {"Product Color Code", type text}, {"GMD31", type text}, {"GMD30", type text}, {"GMD29", type text}, {"GMD5", type text}, {"GMD24", type text}, {"Spare Part SKU", type text}, {"Qty Spare Parts per ptoduct", type text}, {"Spare Part Previous Version", type text}, {"Spare Part Color Code", type text}, {"Product Name", type text}, {"Part Customer Name", type text}, {"Product Color Desc", type text}, {"Market Group#(lf)GMD 31 desc", type text}, {"Product Type#(lf)GMD 30 desc", type text}, {"Product Type Detailed#(lf)GMD 29 desc", type text}, {"STD.PROD.SITE (SOURCE)#(lf)GMD 5 desc", type text}, {"ACT.PROD.SITE(SOURCE2)#(lf)GMD 24 desc", type text}, {"Spare Part Name", type text}, {"Spare Part Size", type text}, {"set/apart", type text}, {"Sign", type text}, {"Country", type text}, {"Spare Part Color Desc", type text}}),
    // Add "File Name" column
    DataSource = Table.AddColumn(
        #"Changed column type",
        "Data Source",
        each LatestFile[Name],
        type text
    ),
    // Data Source Order
    DataSourceOrder = Table.AddColumn(
        DataSource,
        "Data Source Order",
        each "2",
        type text
    ),
    // Add "Last Updated" column with current date/time
    LastUpdated = Table.AddColumn(
        DataSourceOrder,
        "Last Updated",
        each DateTime.LocalNow(),
        type datetime
    )
in
    LastUpdated;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"_TEST Additional zmm02 SP info" = let
    // SharePoint site root (IMPORTANT: site only, not full file path)
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/SavannahRDC",
        [ApiVersion = 15]
    ),

    // Filter to your specific file
    FilteredFile =
        Table.SelectRows(
            Source,
            each [Name] = "ZMM02 SP.XLSX"
        ),

    // Get file content
    FileContent =
        FilteredFile{0}[Content],

    // Read Excel workbook
    ExcelData =
        Excel.Workbook(FileContent, null, true),
  Navigation = ExcelData{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(Navigation, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Plnt", type text}, {"Old material no.", type text}, {"Material", type text}, {"Material Description", type text}, {"MS", type text}, {"MTyp", type text}, {"Material Type", type text}, {"Standard price", type text}, {"Crcy", type text}, {"per", type text}, {"ABC", type text}, {"#### MRP", type text}, {"Profit Ctr", type text}, {"Typ", type text}, {"MRPC", type text}, {"ProcType", type text}, {"Matl Group", type text}, {"SPT", type text}, {"BUn", type text}, {"Min. Lot Sze", type text},  {"BUn_1", type text}, {"SortGrp_012_T", type text}, {"Max. Lot Size", type text}, {"SortGrp_019", type text}, {"BUn_2", type text}, {"SortGrp_019_T", type text}, {"Rounding val.", type text},  {"BUn_3", type text}, {"PrTime", type text}, {"TiHi", type text}, {"Code number", type text}, {"Orig", type text}, {"Planning time fence", type text}, {"MRP", type text}, {"Net Weight", type text}, {"WUn", type text}, {"Volume", type text}, {"VUn", type text}, {"MS_4", type text}, {"MPN", type text}, {"ValCl", type text}, {"PlanPrice 1", type text}, {"Crcy_5", type text}, {"WUn_6", type text}, {"Bulk", type text}, {"Alt.Gross Weight", type text}, {"Main Mold", type text}, {"WUn_7", type text}, {"Item classification", type text}, {"VUn_8", type text}, {"Item classification_9", type text}, {"Alt. Volume", type text}, {"Planning category", type text}, {"VUn_10", type text}, {"Planning category_11", type text}, {"Unit of Dimension", type text}, {"Pr", type text}, {"Alt.Height", type text}, {"Preference indicator in export", type text}, {"Unit of Dimension_12", type text}, {"Vdr decl.", type text}, {"Alt. Width", type text}, {"Indicator: Vendor declaration", type text}, {"Unit of Dimension_13", type text}, {"Ct", type text}, {"Alt.Length", type text}, {"Unit of Dimension_14", type text}, {"EAN/UPC", type text}, {"EAN number", type text}, {"Denom.", type text}, {"A.scrap", type text}, {"B", type text}, {"Stor", type text}, {"Customer No.", type text}, {"VUn_15", type text}, {"WUn_16", type text}, {"St", type text}, {"SPTC", type text}, {"MovAvgPrice", type text}, {"Crcy_17", type text}, {"Pr.", type text}, {"#### #""# MRP", type text}, {"Clt", type text}, {"BUn_18", type text}, {"For.", type text}, {"Size/dimensions", type text}, {"Ct_19", type text}, {"PP date 1", type text}, {"Language", type text}, {"Av", type text}, {"Prod./insp. memo", type text}, {"PGr", type text}, {"PI", type text}, {"OTol", type text}, {"Reorder Point", type text}, {"BUn_20", type text}, {"Follow-Up Material", type text}, {"Consumption mode", type text}, {"Bwd cons. per.", type text}, {"Fwd cons.period", type text}, {"SLoc", type text}, {"D", type text}, {"CoPr", type text}, {"Created", type text}, {"###.###.MR", type text}, {"Color", type text}, {"Special Procurement Type for C", type text}, {"I/C", type text}, {"Ext. Material Grp", type text}, {"Color Description", type text}, {"Pallet Type", type text}, {"Seas/NonSeasIndic", type text}, {"SparePartInd.", type text}, {"IML Code", type text}, {"PalHeight", type text}, {"PalHeightUOM", type text}, {"Packaging feature", type text}, {"MatFrtGp", type text}, {"AltUnit_NetWeight", type text}, {"WUn_21", type text}, {"MRPpr", type text}, {"SortGrp_031", type text}, {"SortGrp_031_T", type text}, {"Code Pack Desc.", type text}, {"Pallet Type Description", type text}, {"IML Description", type text}, {"BUn_22", type text}, {"Col", type text}, {"Basic material", type text}, {"Gross Weight", type text}, {"WUn_23", type text}, {"PalHeightUOM_24", type text}, {"ItCGr", type text}, {"Material Group Desc.", type text}, {"BUn_25", type text}})

in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"_TEST SP BOM" = let
  Source = SharePoint.Files("https://keteronline.sharepoint.com/teams/SavannahRDC", [ApiVersion = 15]),
  #"Sorted rows" = Table.Sort(Source, {{"Date created", Order.Descending}}),
  Navigation = #"Sorted rows"{[Name = "Spare Parts BOM.xlsx", #"Folder Path" = "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared Documents/PowerBI Projects/DL/"]}[Content],
  #"Imported Excel workbook" = Excel.Workbook(Navigation, null, true),
  #"Navigation 1" = #"Imported Excel workbook"{[Item = "SP BOM", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"SP Parent SKU", Int64.Type}, {"SP Description", type text}, {"Replacement Item", type text}, {"SP Child SKU", Int64.Type}, {"Conversion", Int64.Type}})
in
  #"Changed column type";
