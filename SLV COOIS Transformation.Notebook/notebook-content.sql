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
-- META         },
-- META         {
-- META           "id": "be5e5c20-9808-4724-9f8d-cc5502142d75"
-- META         }
-- META       ]
-- META     }
-- META   }
-- META }

-- CELL ********************

-- Update Log
-- CJ - 08/25/2026.3: update ProductionQty to RemainingProductionQty and start no later than current date 
-- CJ - 08/25/2026.2: update MRP_Area to Plant
-- CJ - 08/25/2026.1: add DailyProductionHours
-- CJ - 08/13/2026.1: update name of table being pulled

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

-- CREATE OR REPLACE TABLE `COOIS_Plant73_PBI_DailySplit` AS -- CJ - 08/13/2026.1
CREATE OR REPLACE TABLE `fact_coois_pbi_daily_split` AS

WITH base AS (
    SELECT
        t.`Work Center` AS Work_Center,
        t.`Description` AS Description,
        t.`Mold` AS Mold,
        t.`Order` AS Order_Number,
        t.`Basic material` AS Basic_material,
        t.`Material Number` AS Material_Number,
        t.`Material description` AS Material_description,
        t.`Order quantity _GMEIN_` AS Order_quantity_GMEIN,
        t.`Confirmed quantity _GMEIN_` AS Confirmed_quantity_GMEIN,
        t.`Start date _sched_` AS Start_date_sched,
        t.`Scheduled finish date` AS Scheduled_finish_date,
        t.`Storage Location` AS Storage_Location,
        t.`System Status` AS System_Status,
        t.`Qty Per Day _BEAZE_` AS Qty_Per_Day_BEAZE,
        t.`Labour _C_ _VGE03_` AS Labour_C_VGE03,
        t.`Remaining HR time _H_` AS Remaining_HR_time_H,
        t.`Remaining weight YRW` AS Remaining_weight_YRW,
        t.`User Status` AS User_Status,
        t.`Collective order` AS Collective_order,
        t.`Leading order` AS Leading_order,
        -- CJ - 08/25/2026.2
        -- t.`MRP Area` AS MRP_Area,
        t.`MRP Area` AS Plant,

        t.`Sales Document` AS Sales_Document,
        t.`Scheduled Start DateTime` AS Scheduled_Start_DateTime,
        t.`Scheduled End DateTime` AS Scheduled_End_DateTime,

        CAST( GREATEST(t.`Scheduled Start DateTime`, current_date) AS TIMESTAMP) AS StartTS, -- CJ - 08/25/2026.3
        CAST(t.`Scheduled End DateTime` AS TIMESTAMP) AS EndTS,
        CAST(t.`Order quantity _GMEIN_` - IFNULL(`Confirmed quantity _GMEIN_`, 0) AS BIGINT) AS ProductionQty, -- CJ - 08/25/2026.3

        p.`TL Qty` as TL_Qty

    -- FROM `BRZ_NA_SC_LH`.`dbo`.`COOIS_Plant73_PBI` t -- CJ - 08/13/2026.1
    FROM `BRZ_NA_SC_LH`.`dbo`.`COOIS_PBI` t
    LEFT JOIN `DIM Product` p on t.`Material Number` = p.Material

    WHERE t.`Order` IS NOT NULL
        AND t.`Scheduled Start DateTime` IS NOT NULL
        AND t.`Scheduled End DateTime` >= CAST(current_date as TIMESTAMP)
        AND t.`Order quantity _GMEIN_` IS NOT NULL
        AND CAST(t.`Scheduled End DateTime` AS TIMESTAMP) > CAST(t.`Scheduled Start DateTime` AS TIMESTAMP)
),

expanded_days AS (
    SELECT
        b.*,
        EXPLODE(
            SEQUENCE(
                TO_DATE(b.StartTS),
                TO_DATE(b.EndTS),
                INTERVAL 1 DAY
            )
        ) AS ProductionDate
    FROM base b
),

day_windows AS (
    SELECT
        e.*,

        GREATEST(
            e.StartTS,
            CAST(e.ProductionDate AS TIMESTAMP)
        ) AS Production_DateTime_Start,

        LEAST(
            e.EndTS,
            CAST(DATE_ADD(e.ProductionDate, 1) AS TIMESTAMP)
        ) AS Production_DateTime_End

    FROM expanded_days e
),

day_seconds AS (
    SELECT
        d.*,

        UNIX_TIMESTAMP(d.Production_DateTime_End)
            - UNIX_TIMESTAMP(d.Production_DateTime_Start) AS DaySeconds

    FROM day_windows d

    WHERE d.Production_DateTime_End > d.Production_DateTime_Start
),

weighted_days AS (
    SELECT
        ds.*,

        ds.DaySeconds / 3600.0 as DailyProductionHours, -- CJ - 08/25/2026.1

        SUM(ds.DaySeconds)
            OVER (
                PARTITION BY ds.Order_Number
            ) AS TotalSeconds

    FROM day_seconds ds
),

raw_allocations AS (
    SELECT
        wd.*,

        CAST(
            wd.ProductionQty * wd.DaySeconds / wd.TotalSeconds
            AS DOUBLE
        ) AS RawDailyProductionQty

    FROM weighted_days wd
),

rounded_base AS (
    SELECT
        ra.*,

        CAST(FLOOR(ra.RawDailyProductionQty) AS BIGINT) AS BaseDailyProductionQty,

        ra.RawDailyProductionQty
            - FLOOR(ra.RawDailyProductionQty) AS DailyQtyRemainder

    FROM raw_allocations ra
),

residual_calc AS (
    SELECT
        rb.*,

        CAST(
            rb.ProductionQty
                - SUM(rb.BaseDailyProductionQty)
                    OVER (
                        PARTITION BY rb.Order_Number
                    )
            AS BIGINT
        ) AS ResidualQty

    FROM rounded_base rb
),

ranked_remainders AS (
    SELECT
        rc.*,

        ROW_NUMBER()
            OVER (
                PARTITION BY rc.Order_Number
                ORDER BY
                    rc.DailyQtyRemainder DESC,
                    rc.ProductionDate ASC
            ) AS RemainderRank

    FROM residual_calc rc
)

SELECT
    Work_Center,
    Description,
    Mold,
    Order_Number,
    Basic_material,
    Material_Number,
    Material_description,
    Order_quantity_GMEIN,
    Confirmed_quantity_GMEIN,
    ProductionQty as RemainingProductionQty, -- CJ - 08/25/2026.3
    -- Start_date_sched,
    -- Scheduled_finish_date,
    Storage_Location,
    System_Status,
    Qty_Per_Day_BEAZE,
    Labour_C_VGE03,
    Remaining_HR_time_H,
    Remaining_weight_YRW,
    User_Status,
    Collective_order,
    Leading_order,
    -- CJ - 08/25/2026.2
    -- MRP_Area,
    Plant, 

    Sales_Document,
    Scheduled_Start_DateTime,
    Scheduled_End_DateTime,

    ProductionDate,
    Production_DateTime_Start,
    Production_DateTime_End,
    DailyProductionHours, -- CJ - 08/25/2026.1
    -- DaySeconds,
    -- TotalSeconds,
    -- RawDailyProductionQty,
    -- BaseDailyProductionQty,
    -- DailyQtyRemainder,
    -- ResidualQty,
    -- RemainderRank,

    CASE
        WHEN RemainderRank <= ResidualQty
            THEN BaseDailyProductionQty + 1
        ELSE BaseDailyProductionQty
    END AS DailyProductionQty,

    TL_Qty,
    CASE
        WHEN RemainderRank <= ResidualQty
            THEN (BaseDailyProductionQty + 1) / TL_Qty
        ELSE BaseDailyProductionQty / TL_Qty
    END AS Daily_TL_Qty

FROM ranked_remainders
-- WHERE Order_Number = '104606331'
-- ORDER BY ProductionDate
;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

-- OLD VERSION

-- CREATE OR REPLACE TABLE `COOIS_Plant73_PBI_DailySplit` AS -- CJ - 08/13/2026.1
CREATE OR REPLACE TABLE `fact_coois_pbi_daily_split` AS

WITH base AS (
    SELECT
        t.`Work Center` AS Work_Center,
        t.`Description` AS Description,
        t.`Mold` AS Mold,
        t.`Order` AS Order_Number,
        t.`Basic material` AS Basic_material,
        t.`Material Number` AS Material_Number,
        t.`Material description` AS Material_description,
        t.`Order quantity _GMEIN_` AS Order_quantity_GMEIN,
        t.`Confirmed quantity _GMEIN_` AS Confirmed_quantity_GMEIN,
        t.`Start date _sched_` AS Start_date_sched,
        t.`Scheduled finish date` AS Scheduled_finish_date,
        t.`Storage Location` AS Storage_Location,
        t.`System Status` AS System_Status,
        t.`Qty Per Day _BEAZE_` AS Qty_Per_Day_BEAZE,
        t.`Labour _C_ _VGE03_` AS Labour_C_VGE03,
        t.`Remaining HR time _H_` AS Remaining_HR_time_H,
        t.`Remaining weight YRW` AS Remaining_weight_YRW,
        t.`User Status` AS User_Status,
        t.`Collective order` AS Collective_order,
        t.`Leading order` AS Leading_order,
        -- CJ - 08/25/2026.2
        -- t.`MRP Area` AS MRP_Area,
        t.`MRP Area` AS Plant,

        t.`Sales Document` AS Sales_Document,
        t.`Scheduled Start DateTime` AS Scheduled_Start_DateTime,
        t.`Scheduled End DateTime` AS Scheduled_End_DateTime,

        CAST(t.`Scheduled Start DateTime` AS TIMESTAMP) AS StartTS,
        CAST(t.`Scheduled End DateTime` AS TIMESTAMP) AS EndTS,
        CAST(t.`Order quantity _GMEIN_` AS BIGINT) AS ProductionQty,

        p.`TL Qty` as TL_Qty

    -- FROM `BRZ_NA_SC_LH`.`dbo`.`COOIS_Plant73_PBI` t -- CJ - 08/13/2026.1
    FROM `BRZ_NA_SC_LH`.`dbo`.`COOIS_PBI` t
    LEFT JOIN `DIM Product` p on t.`Material Number` = p.Material

    WHERE t.`Order` IS NOT NULL
        AND t.`Scheduled Start DateTime` IS NOT NULL
        AND t.`Scheduled End DateTime` IS NOT NULL
        AND t.`Order quantity _GMEIN_` IS NOT NULL
        AND CAST(t.`Scheduled End DateTime` AS TIMESTAMP) > CAST(t.`Scheduled Start DateTime` AS TIMESTAMP)
),

expanded_days AS (
    SELECT
        b.*,
        EXPLODE(
            SEQUENCE(
                TO_DATE(b.StartTS),
                TO_DATE(b.EndTS),
                INTERVAL 1 DAY
            )
        ) AS ProductionDate
    FROM base b
),

day_windows AS (
    SELECT
        e.*,

        GREATEST(
            e.StartTS,
            CAST(e.ProductionDate AS TIMESTAMP)
        ) AS Production_DateTime_Start,

        LEAST(
            e.EndTS,
            CAST(DATE_ADD(e.ProductionDate, 1) AS TIMESTAMP)
        ) AS Production_DateTime_End

    FROM expanded_days e
),

day_seconds AS (
    SELECT
        d.*,

        UNIX_TIMESTAMP(d.Production_DateTime_End)
            - UNIX_TIMESTAMP(d.Production_DateTime_Start) AS DaySeconds

    FROM day_windows d

    WHERE d.Production_DateTime_End > d.Production_DateTime_Start
),

weighted_days AS (
    SELECT
        ds.*,

        ds.DaySeconds / 3600.0 as DailyProductionHours, -- CJ - 08/25/2026.1

        SUM(ds.DaySeconds)
            OVER (
                PARTITION BY ds.Order_Number
            ) AS TotalSeconds

    FROM day_seconds ds
),

raw_allocations AS (
    SELECT
        wd.*,

        CAST(
            wd.ProductionQty * wd.DaySeconds / wd.TotalSeconds
            AS DOUBLE
        ) AS RawDailyProductionQty

    FROM weighted_days wd
),

rounded_base AS (
    SELECT
        ra.*,

        CAST(FLOOR(ra.RawDailyProductionQty) AS BIGINT) AS BaseDailyProductionQty,

        ra.RawDailyProductionQty
            - FLOOR(ra.RawDailyProductionQty) AS DailyQtyRemainder

    FROM raw_allocations ra
),

residual_calc AS (
    SELECT
        rb.*,

        CAST(
            rb.ProductionQty
                - SUM(rb.BaseDailyProductionQty)
                    OVER (
                        PARTITION BY rb.Order_Number
                    )
            AS BIGINT
        ) AS ResidualQty

    FROM rounded_base rb
),

ranked_remainders AS (
    SELECT
        rc.*,

        ROW_NUMBER()
            OVER (
                PARTITION BY rc.Order_Number
                ORDER BY
                    rc.DailyQtyRemainder DESC,
                    rc.ProductionDate ASC
            ) AS RemainderRank

    FROM residual_calc rc
)

SELECT
    Work_Center,
    Description,
    Mold,
    Order_Number,
    Basic_material,
    Material_Number,
    Material_description,
    Order_quantity_GMEIN,
    Confirmed_quantity_GMEIN,
    -- Start_date_sched,
    -- Scheduled_finish_date,
    Storage_Location,
    System_Status,
    Qty_Per_Day_BEAZE,
    Labour_C_VGE03,
    Remaining_HR_time_H,
    Remaining_weight_YRW,
    User_Status,
    Collective_order,
    Leading_order,
    -- CJ - 08/25/2026.2
    -- MRP_Area,
    Plant, 

    Sales_Document,
    Scheduled_Start_DateTime,
    Scheduled_End_DateTime,

    ProductionDate,
    Production_DateTime_Start,
    Production_DateTime_End,
    DailyProductionHours, -- CJ - 08/25/2026.1
    -- DaySeconds,
    -- TotalSeconds,
    -- RawDailyProductionQty,
    -- BaseDailyProductionQty,
    -- DailyQtyRemainder,
    -- ResidualQty,
    -- RemainderRank,

    CASE
        WHEN RemainderRank <= ResidualQty
            THEN BaseDailyProductionQty + 1
        ELSE BaseDailyProductionQty
    END AS DailyProductionQty,

    TL_Qty,
    CASE
        WHEN RemainderRank <= ResidualQty
            THEN (BaseDailyProductionQty + 1) / TL_Qty
        ELSE BaseDailyProductionQty / TL_Qty
    END AS Daily_TL_Qty

FROM ranked_remainders
-- WHERE ProductionDate >= CURRENT_DATE (this get filtered in FACT YM6P instead)
;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
