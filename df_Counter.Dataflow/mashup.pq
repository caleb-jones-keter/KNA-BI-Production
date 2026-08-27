[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "DIM Counter_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "Material", DestinationColumnName = "Material"], [SourceColumnName = "Inb. Del.", DestinationColumnName = "Inb. Del_"], [SourceColumnName = "Container", DestinationColumnName = "Container"], [SourceColumnName = "Material_InbDel_Index", DestinationColumnName = "Material_InbDel_Index"], [SourceColumnName = "MAT-INB Merge", DestinationColumnName = "MAT-INB Merge"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared df_DIM_Counter = let
    // ================================
    // SOURCE: SharePoint Excel
    // ================================
    Source =
        Excel.Workbook(
            Web.Contents(
                "https://keteronline.sharepoint.com/teams/SavannahRDC/Shared%20Documents/PowerBI%20Projects/DL/Y%20Container%20Daily%20Pull.xlsx"
            ),
            null,
            false
        ),

    Sheet1_sheet = Source{[Item="Sheet1", Kind="Sheet"]}[Data],

    FilterNullAndWhitespace =
        each
            List.Select(
                _,
                each _ <> null and (not (_ is text) or Text.Trim(_) <> "")
            ),

    #"Removed Bottom Rows" =
        Table.RemoveLastN(
            Sheet1_sheet,
            each
                try
                    List.IsEmpty(
                        List.Skip(
                            FilterNullAndWhitespace(Record.FieldValues(_)),
                            1
                        )
                    )
                otherwise false
        ),

    #"Promoted Headers" =
        Table.PromoteHeaders(
            #"Removed Bottom Rows",
            [PromoteAllScalars = true]
        ),

    #"Filtered Rows1" =
        Table.SelectRows(
            #"Promoted Headers",
            each [Container] <> null and [Container] <> ""
        ),

    #"Removed Other Columns" =
        Table.SelectColumns(
            #"Filtered Rows1",
            {"Material", "Inb. Del.", "Container"}
        ),

    // ================================
    // INDEX LOGIC (Reset by Material)
    // ================================

    // Sort by Material then Inb. Del. so index is deterministic
    Sorted =
        Table.Buffer(Table.Sort(
            #"Removed Other Columns",
            {
                {"Material", Order.Ascending},
                {"Inb. Del.", Order.Ascending},
                {"Container", Order.Ascending}
            }
        )),

    // Group ONLY by Material so the index increments across all Inb. Del. values
    Grouped =
        Table.Group(
            Sorted,
            {"Material"},
            {
                {
                    "Data",
                    (t as table) as table =>
                        Table.AddIndexColumn(
                            t,
                            "Material_InbDel_Index",
                            1,
                            1,
                            Int64.Type
                        ),
                    type table
                }
            }
        ),

    // Expand back to flat table
    Expanded =
        Table.ExpandTableColumn(
            Grouped,
            "Data",
            {"Inb. Del.", "Container", "Material_InbDel_Index"},
            {"Inb. Del.", "Container", "Material_InbDel_Index"}
        ),
    #"Changed Type" = Table.TransformColumnTypes(Expanded,{{"Inb. Del.", type text}, {"Container", type text}, {"Material_InbDel_Index", Int64.Type}}),
    #"Inserted Merged Column" = Table.AddColumn(#"Changed Type", "MAT-INB Merge", each Text.Combine({ [Material],   [#"Inb. Del."]}, "|"), type text),
    #"Sorted Rows" = Table.Sort(#"Inserted Merged Column",{{"MAT-INB Merge", Order.Ascending}})
in
    #"Sorted Rows";
shared #"DIM Dates" = let
    StartDate = #date(StartYear-1,1,1),
    EndDate = #date(EndYear,12,31),
    NumberOfDays = Duration.Days( EndDate - StartDate ),
    Dates = List.Dates(StartDate, NumberOfDays+1, #duration(1,0,0,0)),
    #"Converted to Table" = Table.FromList(Dates, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Renamed Columns" = Table.RenameColumns(#"Converted to Table",{{"Column1", "Full Date"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"Full Date", type date}}),
    #"Inserted Year" = Table.AddColumn(#"Changed Type", "Year", each Date.Year([Full Date])),
    #"Inserted Month" = Table.AddColumn(#"Inserted Year", "Month", each Date.Month([Full Date])),
    #"Inserted Month Name" = Table.AddColumn(#"Inserted Month", "Month Name", each Date.MonthName([Full Date]), type text),
    #"Inserted Quarter" = Table.AddColumn(#"Inserted Month Name", "Quarter", each Date.QuarterOfYear([Full Date]), type number),
    #"Inserted Week of Year" = Table.AddColumn(#"Inserted Quarter", "Week of Year", each Date.WeekOfYear([Full Date]), type number),
    #"Inserted Week of Month" = Table.AddColumn(#"Inserted Week of Year", "Week of Month", each Date.WeekOfMonth([Full Date]), type number),
    #"Inserted Day" = Table.AddColumn(#"Inserted Week of Month", "Day", each Date.Day([Full Date]), type number),
    #"Inserted Day of Week" = Table.AddColumn(#"Inserted Day", "Day of Week", each Date.DayOfWeek([Full Date]), type number),
    #"Inserted Day of Year" = Table.AddColumn(#"Inserted Day of Week", "Day of Year", each Date.DayOfYear([Full Date]), type number),
    #"Inserted Day Name" = Table.AddColumn(#"Inserted Day of Year", "Day Name", each Date.DayOfWeekName([Full Date]), type text),
    #"Today Dynamic" = Table.AddColumn(#"Inserted Day Name", "Today", each DateTime.LocalNow()),
    #"Changed Type3" = Table.TransformColumnTypes(#"Today Dynamic",{{"Today", type date}}),
    #"Added Custom1" = Table.AddColumn(#"Changed Type3", "Today SOW", each Date.StartOfWeek([Today])),
    #"Inserted Date Subtraction1" = Table.AddColumn(#"Added Custom1", "Subtraction1", each Duration.Days([Today SOW] - [Full Date]), Int64.Type),
    #"Added Conditional Column" = Table.AddColumn(#"Inserted Date Subtraction1", "Future?", each if [Subtraction1] < -140 then "Extended Outlook" else if [Subtraction1] < 0 then "Future" else if [Subtraction1] = 0 then "Today" else "Past"),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Conditional Column",{{"Week of Year", type text}, {"Week of Month", type text}, {"Future?", type text}}),
    #"Duplicated Column" = Table.DuplicateColumn(#"Changed Type1", "Full Date", "FullDateAlternateKey - Copy"),
    #"Calculated Start of Month" = Table.TransformColumns(#"Duplicated Column",{{"FullDateAlternateKey - Copy", Date.StartOfMonth, type date}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Calculated Start of Month",{{"FullDateAlternateKey - Copy", "FOM"}}),
    #"Calculated Start of Month1" = Table.TransformColumns(#"Renamed Columns1",{{"Today", Date.StartOfMonth, type date}}),
    #"Inserted Date Subtraction" = Table.AddColumn(#"Calculated Start of Month1", "Subtraction", each Duration.Days([Today] - [FOM])/30, Int64.Type),
    #"Rounded Up" = Table.TransformColumns(#"Inserted Date Subtraction",{{"Subtraction", Number.RoundUp, Int64.Type}}),
    #"Duplicated Column1" = Table.DuplicateColumn(#"Rounded Up", "Full Date", "FullDateAlternateKey - Copy"),
    #"Calculated Start of Week" = Table.TransformColumns(#"Duplicated Column1",{{"FullDateAlternateKey - Copy", Date.StartOfWeek, type date}}),
    #"Renamed Columns3" = Table.RenameColumns(#"Calculated Start of Week",{{"FullDateAlternateKey - Copy", "SOW"}}),
    #"Duplicated Column2" = Table.DuplicateColumn(#"Renamed Columns3", "Full Date", "Full Date - SOW"),
    #"Calculated Start of Week1" = Table.TransformColumns(#"Duplicated Column2",{{"Full Date - SOW", Date.StartOfWeek, type date}})
in
    #"Calculated Start of Week1";
shared StartYear = 2023 meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type any];
shared EndYear = 2026 meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type any];
shared #"DIM Counter_DataDestination" = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "6a85ef9d-524b-4e88-8547-f468bd89d0fc"]}[Data],
  TableNavigation = Navigation_2{[Item = "DIM Counter", Schema = "dbo"]}?[Data]?
in
  TableNavigation;
