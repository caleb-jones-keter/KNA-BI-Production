[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"Invoice to Net Products" = let
  Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
  #"Invoice to Net" = Source{[Name="Invoice to Net"]}[Data],
  Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
  Model2 = Model1{[Id="Model"]}[Data],
  #"Added Items" = Cube.Transform(Model2,
      {
          {Cube.AddAndExpandDimensionColumn, "[Dim Products]", {"[Dim Products].[ACT PROD SITE].[ACT PROD SITE]", "[Dim Products].[ACT PROD SITE Region].[ACT PROD SITE Region]", "[Dim Products].[Brand desc].[Brand desc]", "[Dim Products].[COUNTRY OF PRODUCT(24)].[COUNTRY OF PRODUCT(24)]", "[Dim Products].[COUNTRY OF PRODUCT(24) (groups)].[COUNTRY OF PRODUCT(24) (groups)]", "[Dim Products].[COUNTRY OF PRODUCTION(5)].[COUNTRY OF PRODUCTION(5)]", "[Dim Products].[EAN].[EAN]", "[Dim Products].[Image].[Image]", "[Dim Products].[ITEM GROUP].[ITEM GROUP]", "[Dim Products].[ITEM GROUP (prod cat)].[ITEM GROUP (prod cat)]", "[Dim Products].[MARKET GROUP].[MARKET GROUP]", "[Dim Products].[OUTDOOR / INDOOR (groups)].[OUTDOOR / INDOOR (groups)]", "[Dim Products].[OUTDOOR/INDOOR].[OUTDOOR/INDOOR]", "[Dim Products].[PRODUCT CATEGORY].[PRODUCT CATEGORY]", "[Dim Products].[PRODUCT CATEGORY (groups)].[PRODUCT CATEGORY (groups)]", "[Dim Products].[PRODUCT LINE DESC].[PRODUCT LINE DESC]", "[Dim Products].[PRODUCT MANAGEMENT/Category].[PRODUCT MANAGEMENT/Category]", "[Dim Products].[PRODUCT TYPE].[PRODUCT TYPE]", "[Dim Products].[ProductOrg].[ProductOrg]", "[Dim Products].[Region].[Region]", "[Dim Products].[SAP_MATERIALTYPE].[SAP_MATERIALTYPE]", "[Dim Products].[SKU Group].[SKU Group]", "[Dim Products].[SKU Group #].[SKU Group #]", "[Dim Products].[SKU Group # & Desc].[SKU Group # & Desc]", "[Dim Products].[SKU Level].[SKU Level]", "[Dim Products].[SKU Level #].[SKU Level #]", "[Dim Products].[SKU Level # & Desc].[SKU Level # & Desc]", "[Dim Products].[SubContinent Production].[SubContinent Production]"}, {"Dim Products.ACT PROD SITE", "Dim Products.ACT PROD SITE Region", "Dim Products.Brand desc", "Dim Products.COUNTRY OF PRODUCT(24)", "Dim Products.COUNTRY OF PRODUCT(24) (groups)", "Dim Products.COUNTRY OF PRODUCTION(5)", "Dim Products.EAN", "Dim Products.Image", "Dim Products.ITEM GROUP", "Dim Products.ITEM GROUP (prod cat)", "Dim Products.MARKET GROUP", "Dim Products.OUTDOOR / INDOOR (groups)", "Dim Products.OUTDOOR/INDOOR", "Dim Products.PRODUCT CATEGORY", "Dim Products.PRODUCT CATEGORY (groups)", "Dim Products.PRODUCT LINE DESC", "Dim Products.PRODUCT MANAGEMENT/Category", "Dim Products.PRODUCT TYPE", "Dim Products.ProductOrg", "Dim Products.Region", "Dim Products.SAP_MATERIALTYPE", "Dim Products.SKU Group", "Dim Products.SKU Group #", "Dim Products.SKU Group # & Desc", "Dim Products.SKU Level", "Dim Products.SKU Level #", "Dim Products.SKU Level # & Desc", "Dim Products.SubContinent Production"}}
      })
in
  #"Added Items";
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared #"EnfoPak (MrrContainers)" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    #"Invoice to Net" = Source{[Name="US Import"]}[Data],
    Model1 = #"Invoice to Net"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],

    #"Added Items" =
        Cube.Transform(
            Model2,
            {
                {Cube.AddAndExpandDimensionColumn, "[MrrContainers]",
                    {
                        "[MrrContainers].[bill_to].[bill_to]",
                        "[MrrContainers].[booking_number].[booking_number]",
                        "[MrrContainers].[broker_ab].[broker_ab]",
                        "[MrrContainers].[carrier_name].[carrier_name]",
                        "[MrrContainers].[consignee_name].[consignee_name]",
                        "[MrrContainers].[container_number].[container_number]",
                        "[MrrContainers].[container_type].[container_type]",
                        "[MrrContainers].[currency].[currency]",
                        "[MrrContainers].[customer_name].[customer_name]",
                        "[MrrContainers].[customer_po_numbers].[customer_po_numbers]",
                        "[MrrContainers].[delivery_country].[delivery_country]",
                        "[MrrContainers].[dest_port_name].[dest_port_name]",
                        "[MrrContainers].[due_date].[due_date]",
                        "[MrrContainers].[end_customer].[end_customer]",
                        "[MrrContainers].[eta_date].[eta_date]",
                        "[MrrContainers].[goods_issue_ref].[goods_issue_ref]",
                        "[MrrContainers].[inc_location].[inc_location]",
                        "[MrrContainers].[incoterms].[incoterms]",
                        "[MrrContainers].[number].[number]",
                        "[MrrContainers].[origin_port_name].[origin_port_name]",
                        "[MrrContainers].[part_description].[part_description]",
                        "[MrrContainers].[part_number].[part_number]",
                        "[MrrContainers].[po_numbers].[po_numbers]",
                        "[MrrContainers].[sales_group].[sales_group]",
                        "[MrrContainers].[service_name].[service_name]",
                        "[MrrContainers].[pl_numbers].[pl_numbers]",
                        "[MrrContainers].[ship_to].[ship_to]",
                        "[MrrContainers].[shipper_text_code].[shipper_text_code]",
                        "[MrrContainers].[so_lines].[so_lines]",
                        "[MrrContainers].[so_type].[so_type]",
                        "[MrrContainers].[sold_to].[sold_to]",
                        "[MrrContainers].[status].[status]",
                        "[MrrContainers].[vessel_name].[vessel_name]",
                        "[MrrContainers].[voyage_number].[voyage_number]",
                        "[MrrContainers].[bl_number].[bl_number]"
                    },
                    {
                        "bill_to","booking_number","broker_ab","carrier_name","consignee_name",
                        "container_number","container_type","currency","customer_name","customer_po_numbers",
                        "delivery_country","dest_port_name","due_date","end_customer","eta_date",
                        "goods_issue_ref","inc_location","incoterms","number","origin_port_name",
                        "part_description","part_number","po_numbers","sales_group","service_name",
                        "pl_numbers","ship_to","shipper_text_code","so_lines","so_type",
                        "sold_to","status","vessel_name","voyage_number","bl_number"
                    }
                }
            }
        ),
    #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Added Items", "PO | Container", each [po_numbers] & " | " & [container_number]), {{"PO | Container", type text}})
in
    #"Added custom";
