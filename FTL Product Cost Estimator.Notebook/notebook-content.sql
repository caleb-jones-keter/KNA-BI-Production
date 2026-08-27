-- Fabric notebook source

-- METADATA ********************

-- META {
-- META   "kernel_info": {
-- META     "name": "synapse_pyspark"
-- META   },
-- META   "dependencies": {
-- META     "lakehouse": {
-- META       "default_lakehouse": "624ea251-e87f-45d7-8358-a55b3fa46385",
-- META       "default_lakehouse_name": "NA_Supply_Chain",
-- META       "default_lakehouse_workspace_id": "8e2b746d-3224-4a82-8467-a2800eef337e",
-- META       "known_lakehouses": [
-- META         {
-- META           "id": "624ea251-e87f-45d7-8358-a55b3fa46385"
-- META         }
-- META       ]
-- META     }
-- META   }
-- META }

-- CELL ********************

CREATE OR REPLACE TABLE fact_ftl_material_shipments_model AS

WITH
YS10N AS (
    SELECT
        CAST(A.ship_to as string) as ship_to,
        A.Plant,
        -- `Storage Location`,
        -- `Shipping Point/Receiving Pt`,
        A.`New Storage Location` New_Storage_Location,
        A.Payer,
        A.`MRP Area` MRP_Area,
        A.`ShipToZip_Clean`,
        -- `First Date`,
        -- `Guarantee Date`,
        -- `SO Created Date`,
        -- `Delivery Creation Date`,
        -- `Confirmation Date`,
        -- `SO Billing Date`,
        -- `Invoice Billing Date`,
        -- A.`Act. Gds Mvmnt Date Converted` Act_Gds_Mvmnt_Date,
        A.ActGdsMvmntDateKey,
        -- A.`Ship Date` Ship_Date,
        A.ShipDateKey,
        -- A.`Combined Date` Combined_Date,
        GREATEST(C.`DHL TL Cost`, 500) as DHL_TL_Cost,
        GREATEST(C.`Rancho TL Cost`, 500) as Rancho_TL_Cost,
        GREATEST(C.`Anderson TL Cost`, 500) as Anderson_TL_Cost,
        SUM(-A.`Combined Qty`) as Combined_Qty,
        COUNT(DISTINCT A.Delivery) as Delivery_Count,
        COUNT(DISTINCT A.`PO Number`) as PO_Number_Count,
        COUNT(DISTINCT A.`Shipment Number`) as Shipment_Number_Count
        -- COUNT(DISTINCT A.`Trailer No.`) as Trailer_Count
    FROM `FACT YS10N Past` A
    -- INNER JOIN `DIM MRPSKU` B ON A.`MRPSKU Key` = B.`MRPSKU Key`
    --     AND B.Imports = 'No'
    INNER JOIN `DIM USA CA Zips` C ON A.ShipToZip_Clean = C.`Postal Code Clean`
    WHERE `Shipping type` = '01'
    GROUP BY
        A.ship_to,
        A.Plant,
        A.`New Storage Location`,
        A.Payer,
        A.`MRP Area`,
        A.`ShipToZip_Clean`,
        A.ActGdsMvmntDateKey,
        A.ShipDateKey,
        GREATEST(C.`DHL TL Cost`, 500),
        GREATEST(C.`Rancho TL Cost`, 500),
        GREATEST(C.`Anderson TL Cost`, 500)
)

,MATERIAL AS (
    SELECT DISTINCT 
        Material,
        `TL Qty` as TL_Qty
    FROM `FACT YS10N Past` A
    INNER JOIN `DIM Product` B USING (Material)
    WHERE A.`Shipping type` = '01'
        AND B.`TL Qty` IS NOT NULL
)
SELECT
    -- COUNT(*) OVER (),
    B.Material,
    
    A.ship_to,
    A.Plant,
    A.New_Storage_Location,
    A.Payer, 
    A.MRP_Area,
    A.ShipToZip_Clean,
    A.ActGdsMvmntDateKey,
    A.ShipDateKey,
    A.Combined_Qty,
    B.TL_Qty,
    (A.Combined_Qty/B.TL_Qty) as Combined_TL_Qty,

    A.DHL_TL_Cost,
    A.Rancho_TL_Cost,
    A.Anderson_TL_Cost,

    (A.DHL_TL_Cost/B.TL_Qty) as DHL_Cost_per_Unit,
    (A.Combined_Qty/B.TL_Qty) * A.DHL_TL_Cost as DHL_Total_Cost,

    (A.Rancho_TL_Cost/B.TL_Qty) as Rancho_Cost_per_Unit,
    (A.Combined_Qty/B.TL_Qty) * A.Rancho_TL_Cost as Rancho_Total_Cost,

    (A.Anderson_TL_Cost/B.TL_Qty) as Anderson_Cost_per_Unit,
    (A.Combined_Qty/B.TL_Qty) * A.Anderson_TL_Cost as Anderson_Total_Cost,

    A.Delivery_Count,
    A.PO_Number_Count,
    A.Shipment_Number_Count
FROM YS10N A
CROSS JOIN MATERIAL B

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }
