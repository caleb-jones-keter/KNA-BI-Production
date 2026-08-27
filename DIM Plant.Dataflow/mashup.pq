[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared #"DIM Plant" = let
    Source = AnalysisServices.Databases("powerbi://api.powerbi.com/v1.0/myorg/Keter%20Analytics", [TypedMeasureColumns=true, Implementation="2.0"]),
    OTIF = Source{[Name="OTIF"]}[Data],
    Model1 = OTIF{[Id="Model"]}[Data],
    Model2 = Model1{[Id="Model"]}[Data],
    #"Added Items" = Cube.Transform(Model2,
        {
            {Cube.AddAndExpandDimensionColumn, "[Dim Plant DC]", {"[Dim Plant DC].[CountryDesc].[CountryDesc]", "[Dim Plant DC].[Plant DC].[Plant DC]", "[Dim Plant DC].[Plant DC (key & desc)].[Plant DC (key & desc)]", "[Dim Plant DC].[Plant DC Region].[Plant DC Region]", "[Dim Plant DC].[PlantDesc].[PlantDesc]", "[Dim Plant DC].[PlantKey].[PlantKey]", "[Dim Plant DC].[Region].[Region]"}, {"Dim Plant DC.CountryDesc", "Dim Plant DC.Plant DC", "Dim Plant DC.Plant DC (key & desc)", "Dim Plant DC.Plant DC Region", "Dim Plant DC.PlantDesc", "Dim Plant DC.PlantKey", "Dim Plant DC.Region"}}
        }),
    #"Filtered Rows" = Table.SelectRows(#"Added Items", each [Dim Plant DC.PlantKey] <> null and [Dim Plant DC.PlantKey] <> ""),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows",{{"Dim Plant DC.CountryDesc", "Country Desc"}, {"Dim Plant DC.Plant DC", "Plant Code"}, {"Dim Plant DC.Plant DC (key & desc)", "Plant"}, {"Dim Plant DC.Plant DC Region", "Plant Region"}, {"Dim Plant DC.PlantDesc", "Plant Description"}, {"Dim Plant DC.Region", "Region Code"}, {"Dim Plant DC.PlantKey", "Plant Key"}})
in
    #"Renamed Columns";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data]{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data];
