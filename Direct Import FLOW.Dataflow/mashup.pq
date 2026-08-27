[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DI YM6P FACT HELP_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"DI YM6P FACT HELP" = let
    // Connect to Lakehouse
    Source = Lakehouse.Contents(null),

    // Navigate to workspace
    #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],

    // Navigate to specific Lakehouse
    #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],

    // Navigate to FACT YM6P table
    #"Navigation 3" = #"Navigation 2"{[Id = "FACT YM6P", ItemKind = "Table"]}[Data],

    // Change column type
    #"Changed column type" = Table.TransformColumnTypes(#"Navigation 3", {{"Item", type text}}),

    // Get FACT YS10N Open from Lakehouse too
    #"Navigation YS10N" = #"Navigation 2"{[Id = "FACT YS10N Open", ItemKind = "Table"]}[Data],

    // Merge queries
    #"Merged queries" = Table.NestedJoin(
        #"Changed column type",
        {"Ship-to party's purchase order no.", "Item"},
        #"Navigation YS10N",
        {"PO Number", "Sales Document Item"},
        "FACT YS10N Open",
        JoinKind.LeftOuter
    ),

    // Expand merged table
    #"Expanded FACT YS10N Open" = Table.ExpandTableColumn(
        #"Merged queries",
        "FACT YS10N Open",
        {"Payer", "PO Number", "Customer SKU", "Requested deliv.date", "Planned date CheckIn", "Planned shipment end", "Ship-To Party", "Payer name", "Guarantee Date"},
        {"Payer", "PO Number.1", "Customer SKU", "Requested deliv.date", "Planned date CheckIn", "Planned shipment end", "Ship-To Party.1", "Payer name", "Guarantee Date"}
    ),

    // Add custom date column
    #"Added custom" = Table.TransformColumnTypes(
        Table.AddColumn(#"Expanded FACT YS10N Open", "Max CalcArravDate or RequestedDelivDate", each 
            let
                calcArravDate = try Date.From([CalcArravDate]) otherwise null,
                requestedDelivDate = try Date.From([Requested deliv.date]) otherwise null
            in
                if calcArravDate = null and requestedDelivDate = null then null
                else if calcArravDate = null then requestedDelivDate
                else if requestedDelivDate = null then calcArravDate
                else if calcArravDate > requestedDelivDate then calcArravDate else requestedDelivDate
        ),
        {{"Max CalcArravDate or RequestedDelivDate", type date}}
    ),

    // Rename column
    #"Renamed columns" = Table.RenameColumns(#"Added custom", {{"Max CalcArravDate or RequestedDelivDate", "Planned Delivery Date"}}),

    // Add Order Status
    #"Sailed/Pending/Other" = Table.TransformColumnTypes(
        Table.AddColumn(#"Renamed columns", "Order Status", each 
            if [#"LA Date"] <> null and [#"LA Date"] <> "" then "Sailed"
            else if [Container] <> null and [Container] <> "" then "Pending Shipment"
            else if [#"Confirm. Category"] = "AB" then "Pending Keter"
            else "Open/Other"
        ),
        {{"Order Status", type text}}
    ),

    // Add Early/Late/On Time
    #"Early Late On time" = Table.TransformColumnTypes(
        Table.AddColumn(#"Sailed/Pending/Other", "Early/LateDirectPO", each 
            let
                CalcArravDate = try Date.From([CalcArravDate]) otherwise null,
                RequestedDelivDate = try Date.From([#"Requested deliv.date"]) otherwise null,
                Diff = if CalcArravDate = null or RequestedDelivDate = null then null else Duration.Days(CalcArravDate - RequestedDelivDate)
            in
                if Diff = null then "N/A"
                else if Diff > 7 then "Late"
                else if Diff < -7 then "Early"
                else "On Time"
        ),
        {{"Early/LateDirectPO", type text}}
    ),

    // Combine Payer and Description
    #"Combine Payer and Desc" = Table.AddColumn(#"Early Late On time", "Custom", each [Payer] & " - " & [Payer name]),
    #"Changed column type 1" = Table.TransformColumnTypes(#"Combine Payer and Desc", {{"Custom", type text}})
in
    #"Changed column type 1";
shared DefaultDestination = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data]
in
  #"Navigation 2";
shared #"DI YM6P FACT HELP_DataDestination" = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  TableNavigation = Navigation_2{[Id = "DI YM6P FACT HELP", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
