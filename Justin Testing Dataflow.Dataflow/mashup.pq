[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared Query1 = let
    // Connect to SharePoint
    Source = SharePoint.Files(
        "https://keteronline.sharepoint.com/teams/KeterDigitalSystemsTrainingCenter",
        [ApiVersion = 15]
    ),

    // Filter to target folder
    FilteredFolder =
        Table.SelectRows(
            Source,
            each Text.Contains([Folder Path], "Shared Documents/PIM/spare parts/RPA report")
        ),

    // Keep only Excel files
    ExcelFiles =
        Table.SelectRows(
            FilteredFolder,
            each Text.EndsWith(Text.Lower([Name]), ".xlsx")
              or Text.EndsWith(Text.Lower([Name]), ".xls")
        ),

    // Sort newest first (newest = row 0, 2nd newest = row 1)
    Sorted =
        Table.Sort(ExcelFiles, {{"Date created", Order.Descending}}),

    // Limit rows to stabilize schema evaluation
    TopFiles =
        Table.FirstN(Sorted, 2),

    // Safely pull 2nd newest file
    LatestFile =
        if Table.RowCount(TopFiles) > 1
        then TopFiles{1}
        else null,

    // Always return a TABLE (prevents ModelBuilder cancellation during schema evaluation)
    Output =
        if LatestFile = null then
            #table(
                {
                    "Product SKU","17xxxxxx","Part Customer Number","EAN Code","Product Color Code",
                    "GMD31","GMD30","GMD29","GMD5","GMD24","Spare Part SKU","Qty Spare Parts per ptoduct",
                    "Spare Part Previous Version","Spare Part Color Code","Product Name","Part Customer Name",
                    "Product Color Desc","Market Group#(lf)GMD 31 desc","Product Type#(lf)GMD 30 desc",
                    "Product Type Detailed#(lf)GMD 29 desc","STD.PROD.SITE (SOURCE)#(lf)GMD 5 desc",
                    "ACT.PROD.SITE(SOURCE2)#(lf)GMD 24 desc","Spare Part Name","Spare Part Size",
                    "set/apart","Sign","Country","Spare Part Color Desc",
                    "Data Source","Data Source Order","Last Updated"
                },
                {}
            )
        else
            let
                // Read workbook from binary content
                Workbook =
                    Excel.Workbook(LatestFile[Content], null, true),

                // Filter to "All Data" sheet safely
                AllDataSheet =
                    Table.SelectRows(Workbook, each Text.Trim([Name]) = "All Data"),

                // If sheet is missing, return empty table (still a table result)
                DataOnly =
                    try AllDataSheet{0}[Data] otherwise #table({}, {}),

                // STEP 1: Remove TRUE error values (Excel/PQ errors, not text)
                RemovedPQErrors =
                    Table.ReplaceErrorValues(
                        DataOnly,
                        List.Transform(Table.ColumnNames(DataOnly), each {_, null})
                    ),

                // STEP 2: Promote headers
                PromotedHeaders =
                    Table.PromoteHeaders(RemovedPQErrors, [PromoteAllScalars = true]),

                // STEP 3: Remove Excel error TEXT values like "#N/A" that break Lakehouse inserts
                RemovedExcelErrorText =
                    Table.ReplaceValue(
                        PromotedHeaders,
                        each _,
                        each
                            let v = try Text.Upper(Text.From(_)) otherwise ""
                            in  if v = "#N/A" or v = "#VALUE!" or v = "#DIV/0!" or v = "#REF!"
                                then null
                                else _,
                        Replacer.ReplaceValue,
                        Table.ColumnNames(PromotedHeaders)
                    ),

                // STEP 4: Force your explicit schema (locks types)
                #"Changed column type" =
                    Table.TransformColumnTypes(
                        RemovedExcelErrorText,
                        {
                            {"Product SKU", type text}, {"17xxxxxx", type text},
                            {"Part Customer Number", type text}, {"EAN Code", type text},
                            {"Product Color Code", type text}, {"GMD31", type text},
                            {"GMD30", type text}, {"GMD29", type text},
                            {"GMD5", type text}, {"GMD24", type text},
                            {"Spare Part SKU", type text},
                            {"Qty Spare Parts per ptoduct", type text},
                            {"Spare Part Previous Version", type text},
                            {"Spare Part Color Code", type text},
                            {"Product Name", type text},
                            {"Part Customer Name", type text},
                            {"Product Color Desc", type text},
                            {"Market Group#(lf)GMD 31 desc", type text},
                            {"Product Type#(lf)GMD 30 desc", type text},
                            {"Product Type Detailed#(lf)GMD 29 desc", type text},
                            {"STD.PROD.SITE (SOURCE)#(lf)GMD 5 desc", type text},
                            {"ACT.PROD.SITE(SOURCE2)#(lf)GMD 24 desc", type text},
                            {"Spare Part Name", type text},
                            {"Spare Part Size", type text},
                            {"set/apart", type text},
                            {"Sign", type text},
                            {"Country", type text},
                            {"Spare Part Color Desc", type text}
                        }
                    ),

                // Add "File Name" column
                DataSource =
                    Table.AddColumn(
                        #"Changed column type",
                        "Data Source",
                        each LatestFile[Name],
                        type text
                    ),

                // Data Source Order (2nd newest)
                DataSourceOrder =
                    Table.AddColumn(
                        DataSource,
                        "Data Source Order",
                        each "2",
                        type text
                    ),

                // Last Updated
                LastUpdated =
                    Table.AddColumn(
                        DataSourceOrder,
                        "Last Updated",
                        each DateTime.LocalNow(),
                        type datetime
                    )
            in
                LastUpdated
in
    Output;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "YS10N Past Checker (12skus)_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"YS10N Past Checker (12skus)" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT YS10N Past", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(
    #"Navigation 2",
    each List.Contains(
        {
            "261318",
            "250950",
            "259826",
            "262158",
            "255123",
            "271067",
            "273222",
            "260979",
            "255122",
            "259417",
            "259419",
            "262428"
        },
        [Material]
    )
),
  #"Filtered rows 1" = Table.SelectRows(#"Filtered rows", each [Shipping type] = "06" or [Shipping type] = "07"),
  #"Filtered rows 2" = Table.SelectRows(#"Filtered rows 1", each [Payer] = "172315"),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Filtered rows 2", "Ship Type Description", each if [#"Shipping type"] = "06" then "LTL" else if [#"Shipping type"] = "07" then "Parcel" else null), {{"Ship Type Description", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(
    Table.AddColumn(
        #"Added custom",
        "Material | shiptozipclean | Ship Type Description | Storage Location",
        each Text.From([Material]) & " | " &
             Text.From(Record.Field(_, "ShipToZip_Clean") ?? "") & " | " &
             Text.From(Record.Field(_, "Ship Type Description") ?? "") & " | " &
             Text.From(Record.Field(_, "Storage Location") ?? "")
    ),
    {{"Material | shiptozipclean | Ship Type Description | Storage Location", type text}}
),
  #"Merged queries" = Table.NestedJoin(#"Added custom 1", {"Material | shiptozipclean | Ship Type Description | Storage Location"}, fact_dummy_d2c_top12_kus_apr26, {"Material | dest_zip_clean | Ship_type | Storage Location"}, "fact_dummy_d2c_top12_kus_apr26", JoinKind.LeftOuter),
  #"Expanded fact_dummy_d2c_top12_kus_apr26" = Table.ExpandTableColumn(#"Merged queries", "fact_dummy_d2c_top12_kus_apr26", {"base_fulfillment_cost", "net_fulfillment_cost", "total_cost"}, {"fact_dummy_d2c_top12_kus_apr26.base_fulfillment_cost", "fact_dummy_d2c_top12_kus_apr26.net_fulfillment_cost", "fact_dummy_d2c_top12_kus_apr26.total_cost"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded fact_dummy_d2c_top12_kus_apr26", {{"fact_dummy_d2c_top12_kus_apr26.base_fulfillment_cost", Currency.Type}, {"fact_dummy_d2c_top12_kus_apr26.total_cost", Currency.Type}, {"fact_dummy_d2c_top12_kus_apr26.net_fulfillment_cost", Currency.Type}})

in
  #"Changed column type";
shared fact_dummy_d2c_top12_kus_apr26 = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "fact_dummy_d2c_top12_kus_apr26", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "ship_point_code", each if [ship_point] = "DHL" then "4674"
        else if [ship_point] = "Rancho" then "367G"
        else if [ship_point] = "SpreeTail Nanticoke" then "367D"
        else if [ship_point] = "SpreeTail Vegas" then "367B"
        else null), {{"ship_point_code", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "Material | dest_zip_clean | Ship_type | Storage Location", each [material] & " | " & [dest_zip_clean] & " | " & [ship_type] & " | " & [ship_point_code]), {{"Material | dest_zip_clean | Ship_type | Storage Location", type text}})
in
  #"Added custom 1";
shared #"YS10N Past Checker (12skus)_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "YS10N Past Checker _12skus_", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
