[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"Justin Test Distance" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "8e2b746d-3224-4a82-8467-a2800eef337e"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "624ea251-e87f-45d7-8358-a55b3fa46385"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "DIM USA CA Zips", ItemKind = "Table"]}[Data],
  #"DHL Distance" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "Distance from DHL", each let
            STARTLAT = 32.263, // Replace with your starting latitude
            STARTLONG = -81.235, // Replace with your starting longitude
            R = 3958.8, // Earth radius in miles
            lat1 = Number.From(STARTLAT) * Number.PI / 180,
            lon1 = Number.From(STARTLONG) * Number.PI / 180,
            lat2 = Number.From([LATITUDE]) * Number.PI / 180,
            lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
            dlat = lat2 - lat1,
            dlon = lon2 - lon1,
            a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
            c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
            distance = R * c
        in
            distance), {{"Distance from DHL", Int64.Type}}),
  #"SpreeTail Vegas Distance" = Table.TransformColumnTypes(Table.AddColumn(#"DHL Distance", "Distance from SpreeTail Vegas", each let
            STARTLAT = 36.1699, // Replace with your starting latitude
            STARTLONG = -115.1398, // Replace with your starting longitude
            R = 3958.8, // Earth radius in miles
            lat1 = Number.From(STARTLAT) * Number.PI / 180,
            lon1 = Number.From(STARTLONG) * Number.PI / 180,
            lat2 = Number.From([LATITUDE]) * Number.PI / 180,
            lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
            dlat = lat2 - lat1,
            dlon = lon2 - lon1,
            a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
            c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
            distance = R * c
        in
            distance), {{"Distance from SpreeTail Vegas", Int64.Type}}),
  #"Spreetail Nanticoke Distance" = Table.TransformColumnTypes(Table.AddColumn(#"SpreeTail Vegas Distance", "Distance from SpreeTail Nanticoke", each let
            STARTLAT = 41.2, // Replace with your starting latitude
            STARTLONG = -76, // Replace with your starting longitude
            R = 3958.8, // Earth radius in miles
            lat1 = Number.From(STARTLAT) * Number.PI / 180,
            lon1 = Number.From(STARTLONG) * Number.PI / 180,
            lat2 = Number.From([LATITUDE]) * Number.PI / 180,
            lon2 = Number.From([LONGITUDE]) * Number.PI / 180,
            dlat = lat2 - lat1,
            dlon = lon2 - lon1,
            a = Number.Power(Number.Sin(dlat / 2), 2) + Number.Cos(lat1) * Number.Cos(lat2) * Number.Power(Number.Sin(dlon / 2), 2),
            c = 2 * Number.Atan2(Number.Sqrt(a), Number.Sqrt(1 - a)),
            distance = R * c
        in
            distance), {{"Distance from SpreeTail Nanticoke", Int64.Type}})
in
  #"Spreetail Nanticoke Distance";
