[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "FACT Enfopak_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"FACT Enfopak" = let
    Source = AnalysisServices.Databases(
        "powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", 
        [TypedMeasureColumns=true, Implementation="2.0"]
    ),
    #"US Import" = Source{[Name="US Import"]}[Data],
    Model1 = #"US Import"{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(
        Model2,
        {
            {Cube.AddAndExpandDimensionColumn, 
                "[MrrContainers]", 
                {
                    "[MrrContainers].[awb_code].[awb_code]", 
                    "[MrrContainers].[awb_value].[awb_value]", 
                    "[MrrContainers].[awb_value_usd].[awb_value_usd]", 
                    "[MrrContainers].[bill_to].[bill_to]", 
                    "[MrrContainers].[bl_number].[bl_number]", 
                    "[MrrContainers].[booked].[booked]", 
                    "[MrrContainers].[booking_number].[booking_number]", 
                    "[MrrContainers].[broker_ab].[broker_ab]", 
                    "[MrrContainers].[carrier_name].[carrier_name]", 
                    "[MrrContainers].[cons_awb_code].[cons_awb_code]", 
                    "[MrrContainers].[consignee_name].[consignee_name]", 
                    "[MrrContainers].[container_gross_weight].[container_gross_weight]", 
                    "[MrrContainers].[container_net_weight].[container_net_weight]", 
                    "[MrrContainers].[container_number].[container_number]", 
                    "[MrrContainers].[container_type].[container_type]", 
                    "[MrrContainers].[container_volume].[container_volume]", 
                    "[MrrContainers].[currency].[currency]", 
                    "[MrrContainers].[customer_name].[customer_name]", 
                    "[MrrContainers].[customer_po_numbers].[customer_po_numbers]", 
                    "[MrrContainers].[Day].[Day]", 
                    "[MrrContainers].[delivery_country].[delivery_country]", 
                    "[MrrContainers].[dest_port_name].[dest_port_name]", 
                    "[MrrContainers].[due_date].[due_date]", 
                    "[MrrContainers].[end_customer].[end_customer]", 
                    "[MrrContainers].[eta_date].[eta_date]", 
                    "[MrrContainers].[ets_date].[ets_date]", 
                    "[MrrContainers].[Expr1].[Expr1]", 
                    "[MrrContainers].[goods_issue_date].[goods_issue_date]", 
                    "[MrrContainers].[goods_issue_ref].[goods_issue_ref]", 
                    "[MrrContainers].[inc_location].[inc_location]", 
                    "[MrrContainers].[incoterms].[incoterms]", 
                    "[MrrContainers].[Month Name].[Month Name]", 
                    "[MrrContainers].[number].[number]", 
                    "[MrrContainers].[origin_port_name].[origin_port_name]", 
                    "[MrrContainers].[part_description].[part_description]", 
                    "[MrrContainers].[part_number].[part_number]", 
                    "[MrrContainers].[pl_numbers].[pl_numbers]", 
                    "[MrrContainers].[po_numbers].[po_numbers]", 
                    "[MrrContainers].[sales_group].[sales_group]", 
                    "[MrrContainers].[service_name].[service_name]", 
                    "[MrrContainers].[ship_to].[ship_to]", 
                    "[MrrContainers].[shipper_text_code].[shipper_text_code]", 
                    "[MrrContainers].[so_lines].[so_lines]", 
                    "[MrrContainers].[so_type].[so_type]", 
                    "[MrrContainers].[sold_to].[sold_to]", 
                    "[MrrContainers].[status].[status]", 
                    "[MrrContainers].[status_date].[status_date]", 
                    "[MrrContainers].[status_time].[status_time]", 
                    "[MrrContainers].[vessel_name].[vessel_name]", 
                    "[MrrContainers].[voyage_count].[voyage_count]", 
                    "[MrrContainers].[voyage_number].[voyage_number]", 
                    "[MrrContainers].[Year].[Year]", 
                    "[MrrContainers].[eta_date Hierarchy].[Year]", 
                    "[MrrContainers].[eta_date Hierarchy].[Month Name]", 
                    "[MrrContainers].[eta_date Hierarchy].[Day]"
                }, 
                {
                    "awb_code", "awb_value", "awb_value_usd", "bill_to", "bl_number", "booked", "booking_number", 
                    "broker_ab", "carrier_name", "cons_awb_code", "consignee_name", "container_gross_weight", 
                    "container_net_weight", "container_number", "container_type", "container_volume", "currency", 
                    "customer_name", "customer_po_numbers", "Day", "delivery_country", "dest_port_name", "due_date", 
                    "end_customer", "eta_date", "ets_date", "Expr1", "goods_issue_date", "goods_issue_ref", 
                    "inc_location", "incoterms", "Month Name", "number", "origin_port_name", "part_description", 
                    "part_number", "pl_numbers", "po_numbers", "sales_group", "service_name", "ship_to", 
                    "shipper_text_code", "so_lines", "so_type", "sold_to", "status", "status_date", "status_time", 
                    "vessel_name", "voyage_count", "voyage_number", "Year", "Year.1", "Month Name.1", "Day.1"
                }
            }
        }
    ),
  #"Added custom" = 
Table.AddColumn(
    #"Added Items",
    "Today",
    each Date.From(DateTime.LocalNow()),
    type date
)
in
    #"Added custom";
shared #"FACT Enfopak_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "FACT Enfopak", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
