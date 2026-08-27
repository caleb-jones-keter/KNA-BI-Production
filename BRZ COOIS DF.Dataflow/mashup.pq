[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "be5e5c20-9808-4724-9f8d-cc5502142d75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
[BindToDefaultDestination = true]
shared COOIS_PBI = let
  Source = SharePoint.Contents(
    "https://keteronline.sharepoint.com/teams/SavannahRDC",
    [ApiVersion = 15]
  ),

  File =
    Source{[Name = "Shared Documents"]}[Content]
      {[Name = "PowerBI Projects"]}[Content]
      {[Name = "DL"]}[Content]
      // {[Name = "COOIS_Plant73_PBI.XLSX"]}[Content],
      {[Name = "COOIS_PBI.XLSX"]}[Content], // CJ 8/13/2026: update excel file name

  ExcelFile = Excel.Workbook(File, null, true),
  Sheet1 = ExcelFile{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  PromotedHeaders = Table.PromoteHeaders(Sheet1, [PromoteAllScalars = true]),

  #"Changed column type" =
    Table.TransformColumnTypes(
      PromotedHeaders,
      {
        {"Work Center", type text},
        {"Description", type text},
        {"Mold", type text},
        {"Order", type text},
        {"Basic material", type text},
        {"Material Number", type text},
        {"Material description", type text},
        {"Order quantity (GMEIN)", Int64.Type},
        {"Confirmed quantity (GMEIN)", Int64.Type},
        {"Start date (sched)", type date},
        {"Scheduled start time", type time},
        {"Scheduled finish date", type date},
        {"Scheduled fin. time", type time},
        {"Storage Location", type text},
        {"System Status", type text},
        {"Qty Per Day (BEAZE)", Int64.Type},
        {"Labour (C) (VGE03)", type number},
        {"Remaining HR time (H)", type number},
        {"Remaining weight YRW", type number},
        {"User Status", type text},
        {"Collective order", type text},
        {"Leading order", Int64.Type},
        {"MRP Area", Int64.Type},
        {"Sales Document", type text}
      }
    ),

  #"Added Scheduled Start DateTime" =
    Table.AddColumn(
      #"Changed column type",
      "Scheduled Start DateTime",
      each
        if [#"Start date (sched)"] = null
          or [#"Scheduled start time"] = null
        then
          null
        else
          DateTime.From([#"Start date (sched)"]) +
          #duration(
              0,
              Time.Hour([#"Scheduled start time"]),
              Time.Minute([#"Scheduled start time"]),
              Time.Second([#"Scheduled start time"])
            ),
      type nullable datetime
    ),

  #"Added Scheduled End DateTime" =
    Table.AddColumn(
      #"Added Scheduled Start DateTime",
      "Scheduled End DateTime",
      each
        if [Scheduled finish date] = null
          or [Scheduled fin. time] = null
        then
          null
        else
          DateTime.From([Scheduled finish date]) +
          #duration(
            0,
            Time.Hour([Scheduled fin. time]),
            Time.Minute([Scheduled fin. time]),
            Time.Second([Scheduled fin. time])
          ),
      type nullable datetime
    ),
  RemoveBlanks = Table.SelectRows(
    #"Added Scheduled End DateTime",
    each [Order] <> null and Text.Trim(Text.From([Order])) <> ""
  )
in
  RemoveBlanks;
