[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"FACT YS10N" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "FACT YS10N", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
shared #"Calc SKUPayer YS10N" = let
  Source = #"FACT YS10N",
  #"Removed other columns" = Table.SelectColumns(Source, {"SKUPayer"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"SKUPayer"})
in
  #"Removed duplicates";
[BindToDefaultDestination = true]
shared #"FACT Rejections" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Fact Rejections]", {"[Fact Rejections].[ActivityKey].[ActivityKey]", "[Fact Rejections].[CompanyCodeKey].[CompanyCodeKey]", "[Fact Rejections].[CustomerGroupKey].[CustomerGroupKey]", "[Fact Rejections].[DateKey_daily].[DateKey_daily]", "[Fact Rejections].[Gross_SALES].[Gross_SALES]", "[Fact Rejections].[OrderReasonKey].[OrderReasonKey]", "[Fact Rejections].[PlantKey_SPC].[PlantKey_SPC]", "[Fact Rejections].[ProductKey].[ProductKey]", "[Fact Rejections].[Profit_CenterID].[Profit_CenterID]", "[Fact Rejections].[Quantity1].[Quantity1]", "[Fact Rejections].[RetailerKey].[RetailerKey]", "[Fact Rejections].[SaleTypeKey].[SaleTypeKey]", "[Fact Rejections].[SBU].[SBU]", "[Fact Rejections].[SegmentID].[SegmentID]"}, {"Fact Rejections.ActivityKey", "Fact Rejections.CompanyCodeKey", "Fact Rejections.CustomerGroupKey", "Fact Rejections.DateKey_daily", "Fact Rejections.Gross_SALES", "Fact Rejections.OrderReasonKey", "Fact Rejections.PlantKey_SPC", "Fact Rejections.ProductKey", "Fact Rejections.Profit_CenterID", "Fact Rejections.Quantity1", "Fact Rejections.RetailerKey", "Fact Rejections.SaleTypeKey", "Fact Rejections.SBU", "Fact Rejections.SegmentID"}},
            {Cube.AddMeasureColumn, "SALES: Gross Sales", "[Measures].[SALES: Gross Sales]"},
            {Cube.AddMeasureColumn, "All Rejections: Gross Sales", "[Measures].[All Rejections: Gross Sales]"},
            {Cube.AddMeasureColumn, "All Rejections: Quantity", "[Measures].[All Rejections: Quantity]"},
            {Cube.AddMeasureColumn, "SALES: Quantity", "[Measures].[SALES: Quantity]"}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Fact Rejections.CompanyCodeKey] = "1567" or [Fact Rejections.CompanyCodeKey] = "1560" or [Fact Rejections.CompanyCodeKey] = "1564" or [Fact Rejections.CompanyCodeKey] = "1565" or [Fact Rejections.CompanyCodeKey] = "1666" or [Fact Rejections.CompanyCodeKey] = "1669" or [Fact Rejections.CompanyCodeKey] = "1573"),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Fact Rejections.ActivityKey", "ActivityKey"}, {"Fact Rejections.CompanyCodeKey", "CompanyCodeKey"}, {"Fact Rejections.CustomerGroupKey", "CustomerGroupKey"}, {"Fact Rejections.DateKey_daily", "DateKey_daily"}, {"Fact Rejections.Gross_SALES", "Gross_SALES"}, {"Fact Rejections.OrderReasonKey", "OrderReasonKey"}, {"Fact Rejections.PlantKey_SPC", "PlantKey_SPC"}, {"Fact Rejections.ProductKey", "ProductKey"}, {"Fact Rejections.Profit_CenterID", "Profit_CenterID"}, {"Fact Rejections.Quantity1", "Quantity1"}, {"Fact Rejections.RetailerKey", "RetailerKey"}, {"Fact Rejections.SaleTypeKey", "SaleTypeKey"}, {"Fact Rejections.SBU", "SBU"}, {"Fact Rejections.SegmentID", "SegmentID"}}),
    #"Merged Queries" = Table.NestedJoin(#"Renamed Columns", {"DateKey_daily"}, #"Dim Currency Rate", {"DateKey"}, "Dim Currency Rate", JoinKind.LeftOuter),
    #"Expanded Dim Currency Rate" = Table.ExpandTableColumn(#"Merged Queries", "Dim Currency Rate", {"Conversion"}, {"Dim Currency Rate.Conversion"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Dim Currency Rate",{{"Dim Currency Rate.Conversion", type number}, {"Gross_SALES", type number}, {"Quantity1", type number}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type", "Gross Sales USD", each [#"SALES: Gross Sales"]*[Dim Currency Rate.Conversion]),
    #"Added Custom2" = Table.AddColumn(#"Added Custom", "Rejections USD", each [#"All Rejections: Gross Sales"]*[Dim Currency Rate.Conversion]),
    #"Added Custom4" = Table.AddColumn(#"Added Custom2", "SKUPayer", each [ProductKey]&"|"&[RetailerKey]),
  #"Changed column type" = Table.TransformColumnTypes(#"Added Custom4", {{"SKUPayer", type text}, {"Gross Sales USD", Currency.Type}, {"Rejections USD", Currency.Type}})
in
    #"Changed column type";
shared #"Calc SKUPayer Rejections" = let
    Source = #"FACT Rejections",
    #"Removed Columns" = Table.RemoveColumns(Source,{"ActivityKey", "CompanyCodeKey", "CustomerGroupKey", "DateKey_daily", "Gross_SALES", "OrderReasonKey", "PlantKey_SPC", "ProductKey", "Profit_CenterID", "Quantity1", "RetailerKey", "SaleTypeKey", "SBU", "SegmentID", "SALES: Gross Sales", "All Rejections: Gross Sales", "All Rejections: Quantity", "SALES: Quantity", "Dim Currency Rate.Conversion", "Gross Sales USD", "Rejections USD"}),
    #"Removed Duplicates" = Table.Distinct(#"Removed Columns"),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed Duplicates", {{"SKUPayer", type text}})
in
    #"Changed column type";
[BindToDefaultDestination = true]
shared #"DIM SKUPayer" = let
    Source = Table.Combine({#"Calc SKUPayer YS10N",#"Calc SKUPayer Rejections"}),
  #"Removed duplicates" = Table.Distinct(Source, {"SKUPayer"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed duplicates", {{"SKUPayer", type text}})
in
    #"Changed column type";
shared #"Dim Currency Rate" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Currency rate]", {"[Currency rate].[CurrencyID].[CurrencyID]", "[Currency rate].[DateKey].[DateKey]", "[Currency rate].[EndMonthRate].[EndMonthRate]", "[Currency rate].[FullDateDesc].[FullDateDesc]", "[Currency rate].[Rate].[Rate]"}, {"Currency rate.CurrencyID", "Currency rate.DateKey", "Currency rate.EndMonthRate", "Currency rate.FullDateDesc", "Currency rate.Rate"}}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Currency rate.CurrencyID] = "24"),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Currency rate.CurrencyID", "CurrencyID"}, {"Currency rate.DateKey", "DateKey"}, {"Currency rate.EndMonthRate", "EndMonthRate"}, {"Currency rate.FullDateDesc", "FullDateDesc"}, {"Currency rate.Rate", "Rate"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FullDateDesc", type datetime}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"Rate", "Rate EUR"}}),
    #"Removed Columns" = Table.RemoveColumns(#"Renamed Columns1",{"CurrencyID"}),
    #"Merged Queries" = Table.NestedJoin(#"Removed Columns", {"DateKey"}, #"Dim Currency Rate (2)", {"DateKey"}, "Dim Currency Rate (2)", JoinKind.LeftOuter),
    #"Expanded Dim Currency Rate (2)" = Table.ExpandTableColumn(#"Merged Queries", "Dim Currency Rate (2)", {"Rate USD"}, {"Dim Currency Rate (2).Rate USD"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Expanded Dim Currency Rate (2)",{{"Rate EUR", type number}, {"Dim Currency Rate (2).Rate USD", type number}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type1", "Conversion", each [Rate EUR]/[#"Dim Currency Rate (2).Rate USD"]),
  #"Changed column type" = Table.TransformColumnTypes(#"Added Custom", {{"Conversion", type number}})
in
    #"Changed column type";
shared #"Dim Currency Rate (2)" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Currency rate]", {"[Currency rate].[CurrencyID].[CurrencyID]", "[Currency rate].[DateKey].[DateKey]", "[Currency rate].[EndMonthRate].[EndMonthRate]", "[Currency rate].[FullDateDesc].[FullDateDesc]", "[Currency rate].[Rate].[Rate]"}, {"Currency rate.CurrencyID", "Currency rate.DateKey", "Currency rate.EndMonthRate", "Currency rate.FullDateDesc", "Currency rate.Rate"}}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Currency rate.CurrencyID] = "1"),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Currency rate.CurrencyID", "CurrencyID"}, {"Currency rate.DateKey", "DateKey"}, {"Currency rate.EndMonthRate", "EndMonthRate"}, {"Currency rate.FullDateDesc", "FullDateDesc"}, {"Currency rate.Rate", "Rate"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"FullDateDesc", type datetime}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"Rate", "Rate USD"}}),
    #"Removed Columns" = Table.RemoveColumns(#"Renamed Columns1",{"CurrencyID"})
in
    #"Removed Columns";
shared ECOM = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("ZdCxDcRACATAXi52ABzHQmx9+HIBlvtv4/2RtTgdAQuc51B38xrb+OzHd1zbX1JEuthsEq1mBTJZUnWRhCG5KyagLL4MLNDi9Cj1Nqf6ZIgs3gc22z6Y8pJEsNz/mU2WvMVZkHyXldxh/EMte9KvHw==", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [Payer = _t, ECOM = _t])
in
    Source;
shared #"Defective Allowance" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45WMjY0VdJRMtAzMDNVitUB8o3NIHwLMNfEyBDCNYZyITwjiFpLSzg3FgA=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [#"Customer Group Key" = _t, #"Defective Allowance" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Defective Allowance", type number}})
in
    #"Changed Type";
