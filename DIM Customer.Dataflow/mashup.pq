[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Customer_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM Customer" = let
    PayInfoSource = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/All%20Sold%20To%20and%20Ship%20To%20USA.XLSX"), null, true),
    PayInfoSheet1_Sheet = PayInfoSource{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"PayInfoPromoted Headers" = Table.PromoteHeaders(PayInfoSheet1_Sheet, [PromoteAllScalars=true]),
    #"PayInfoRenamed Columns" = Table.RenameColumns(#"PayInfoPromoted Headers",{{"Customer", "Payer Key"}}),
    #"PayInfoChanged Type" = Table.TransformColumnTypes(#"PayInfoRenamed Columns",{{"Payer Key", type text}}),

    PayTypeSource = Excel.Workbook(Web.Contents("https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Payer%20Types.xlsx"), null, true),
    PayTypeSheet1_Sheet = PayTypeSource{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"PayTypePromoted Headers" = Table.PromoteHeaders(PayTypeSheet1_Sheet, [PromoteAllScalars=true]),
    #"PayTypeChanged Type" = Table.TransformColumnTypes(#"PayTypePromoted Headers",{{"Payer", type text}, {"Detail", type text}, {"Type", type text}}),


    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Sorted Rows" = Table.Sort(Source,{{"Name", Order.Ascending}}),
    OTIF = #"Sorted Rows"{[Name="OTIF"]}[Data],
    Model1 = OTIF{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Dim Customer - Payer]", {"[Dim Customer - Payer].[Customer Groups].[Customer Groups]", "[Dim Customer - Payer].[KNA Drop Ship].[KNA Drop Ship]", "[Dim Customer - Payer].[Market Org].[Market Org]", "[Dim Customer - Payer].[Payer].[Payer]", "[Dim Customer - Payer].[Payer #&D].[Payer #&D]", "[Dim Customer - Payer].[RetailerKey].[RetailerKey]"}, {"Dim Customer - Payer.Customer Groups", "Dim Customer - Payer.KNA Drop Ship", "Dim Customer - Payer.Market Org", "Dim Customer - Payer.Payer", "Dim Customer - Payer.Payer #&D", "Dim Customer - Payer.RetailerKey"}}
        }),
    #"Renamed Columns" = Table.RenameColumns(#"Added Items",{{"Dim Customer - Payer.Customer Groups", "Customer Groups"}, {"Dim Customer - Payer.KNA Drop Ship", "KNA Drop Ship"}, {"Dim Customer - Payer.Market Org", "Market Org"}, {"Dim Customer - Payer.Payer", "Payer Desc"}, {"Dim Customer - Payer.Payer #&D", "Payer & Desc"}, {"Dim Customer - Payer.RetailerKey", "Payer Key"}}),
    #"Merged Queries" = Table.NestedJoin(#"Renamed Columns", {"Payer Key"}, #"PayInfoChanged Type", {"Payer Key"}, "Sheet1", JoinKind.LeftOuter),
    #"Expanded DIM Customer (Excel)" = Table.ExpandTableColumn(#"Merged Queries", "Sheet1", {"Payer Key", "Country", "Name 1", "Name 2", "City", "Postal Code", "Region", "Search term", "Street", "Telephone 1", "Fax Number", "One-time account", "Address", "Name 1_1", "Name 2_2", "City_3", "Title", "Central order block", "Store Number", "EDI Location Code", "Industry", "Data line", "Created on", "Created by", "Central billing block", "Account group", "Customer classific.", "Vendor", "Central delivery block", "Central deletion flag", "Name 3", "Name 4", "Nielsen indicator", "District", "PO Box", "P.O. Box Postal Code", "Regional Market", "Central posting block", "Language Key", "Tax Number 1", "Telephone 2", "Telex number", "Transportation zone", "Trading Partner", "VAT Registration No.", "Legal status", "Industry Code 1", "Industry code 2", "Tax Jurisdiction", "P.O. Box city", "Status of Data Transfer to Next Release", "Tax Number 4", "Central sales block", "Central del.block"}, {"Sheet1.Payer Key", "Sheet1.Country", "Sheet1.Name 1", "Sheet1.Name 2", "Sheet1.City", "Sheet1.Postal Code", "Sheet1.Region", "Sheet1.Search term", "Sheet1.Street", "Sheet1.Telephone 1", "Sheet1.Fax Number", "Sheet1.One-time account", "Sheet1.Address", "Sheet1.Name 1_1", "Sheet1.Name 2_2", "Sheet1.City_3", "Sheet1.Title", "Sheet1.Central order block", "Sheet1.Store Number", "Sheet1.EDI Location Code", "Sheet1.Industry", "Sheet1.Data line", "Sheet1.Created on", "Sheet1.Created by", "Sheet1.Central billing block", "Sheet1.Account group", "Sheet1.Customer classific.", "Sheet1.Vendor", "Sheet1.Central delivery block", "Sheet1.Central deletion flag", "Sheet1.Name 3", "Sheet1.Name 4", "Sheet1.Nielsen indicator", "Sheet1.District", "Sheet1.PO Box", "Sheet1.P.O. Box Postal Code", "Sheet1.Regional Market", "Sheet1.Central posting block", "Sheet1.Language Key", "Sheet1.Tax Number 1", "Sheet1.Telephone 2", "Sheet1.Telex number", "Sheet1.Transportation zone", "Sheet1.Trading Partner", "Sheet1.VAT Registration No.", "Sheet1.Legal status", "Sheet1.Industry Code 1", "Sheet1.Industry code 2", "Sheet1.Tax Jurisdiction", "Sheet1.P.O. Box city", "Sheet1.Status of Data Transfer to Next Release", "Sheet1.Tax Number 4", "Sheet1.Central sales block", "Sheet1.Central del.block"}),
    #"Filtered Rows" = Table.SelectRows(#"Expanded DIM Customer (Excel)", each [Payer Key] <> null and [Payer Key] <> ""),
    #"Removed Duplicates" = Table.Distinct(#"Filtered Rows", {"Payer Key"}),
    #"Merged Queries1" = Table.NestedJoin(#"Removed Duplicates", {"Payer Key"}, #"PayTypeChanged Type", {"Payer"}, "Payer Types", JoinKind.LeftOuter),
    #"Expanded Payer Types" = Table.ExpandTableColumn(#"Merged Queries1", "Payer Types", {"Detail", "Type"}, {"Payer Types.Detail", "Payer Types.Type"}),
    #"Removed Columns" = Table.RemoveColumns(#"Expanded Payer Types",{"Payer Desc"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed Columns", {{"Sheet1.Country", type text}, {"Sheet1.Name 1", type text}, {"Sheet1.Name 2", type text}, {"Sheet1.City", type text}, {"Sheet1.Postal Code", type text}, {"Sheet1.Region", type text}, {"Sheet1.Search term", type text}, {"Sheet1.Street", type text}, {"Sheet1.Telephone 1", type text}, {"Sheet1.Fax Number", type text}, {"Sheet1.One-time account", type text}, {"Sheet1.Address", type text}, {"Sheet1.Name 1_1", type text}, {"Sheet1.Name 2_2", type text}, {"Sheet1.City_3", type text}, {"Sheet1.Title", type text}, {"Sheet1.Central order block", type text}, {"Sheet1.Store Number", type text}, {"Sheet1.EDI Location Code", type text}, {"Payer Key", type text}, {"Sheet1.Payer Key", Int64.Type}}),
  #"Merged queries 1" = Table.NestedJoin(#"Changed column type", {"Payer Key"}, ECOM, {"Payer"}, "ECOM", JoinKind.LeftOuter),
  #"Expanded ECOM" = Table.ExpandTableColumn(#"Merged queries 1", "ECOM", {"ECOM"}, {"ECOM"}),
  #"Merged queries 2" = Table.NestedJoin(#"Expanded ECOM", {"Payer & Desc"}, #"RTV Payer Info", {"Payer & Desc"}, "RTV Payer Info", JoinKind.LeftOuter),
  #"Expanded RTV Payer Info" = Table.ExpandTableColumn(#"Merged queries 2", "RTV Payer Info", {"New Group", "RTV Type"}, {"New Group", "RTV Type"})
in
    #"Expanded RTV Payer Info";
shared ECOM = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("ZdC7DYRADATQXjYm8P8TowtPFIDov43jEqQx6ZPX453zXGwm1mtbn/34rmv7SxHRFNEhMWY8sgqlmB0kJAtfhWYyirkkSnJjejTb2NNzcxI53pOi455UeklloNz96BCntxhKFv5Lmu4w7JBbRjqp+egwaMwYmzxy/QA=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [Payer = _t, ECOM = _t])
in
    Source;
shared #"Defective Allowance" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45WMjY0VdJRMtAzMDNVitUB8o3NIHwLMNfEyBDCNYZyITwjiFpLSzg3FgA=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [#"Customer Group Key" = _t, #"Defective Allowance" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Defective Allowance", type number}})
in
    #"Changed Type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Customer Group_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM Customer Group" = let
  Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
  #"Navigation 1" = Source{[Name = "Fact Service Level US"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Model"]}[Data],
  Model = #"Navigation 2"{[Id = "Model"]}[Data],
  #"Added items" = Cube.Transform(Model, {{Cube.AddAndExpandDimensionColumn, "[Dim CustomerGroup]", {"[Dim CustomerGroup].[CustomerGroupDesc].[CustomerGroupDesc]", "[Dim CustomerGroup].[CustomerGroupKey].[CustomerGroupKey]"}, {"CustomerGroupDesc", "CustomerGroupKey"}}}),
  #"Merged queries" = Table.NestedJoin(#"Added items", {"CustomerGroupKey"}, #"Defective Allowance", {"Customer Group Key"}, "Defective Allowance", JoinKind.LeftOuter),
  #"Expanded Defective Allowance" = Table.ExpandTableColumn(#"Merged queries", "Defective Allowance", {"Defective Allowance"}, {"Defective Allowance"})
in
  #"Expanded Defective Allowance";
shared #"DIM Customer Group_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM Customer Group", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"DIM Customer_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM Customer", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Ship To_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DIM Ship To" = let
  Source = #"DIM Customer"
in
  Source;
shared #"DIM Ship To_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "DIM Ship To", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared #"RTV Payer Info" = let
  Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("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", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [#"Payer & Desc" = _t, #"New Group" = _t, #"RTV Type" = _t])
in
  Source;
