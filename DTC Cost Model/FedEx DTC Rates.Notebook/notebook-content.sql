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

-- MAGIC %%sql
-- MAGIC -- Change Log
-- MAGIC -- CJ - 08-04-2026.3: REMOVE CANADA LOGIC UNTIL WE ARE READY. Massive performance issues.
-- MAGIC -- CJ - 08-04-2026.2: update canadian zip logic to only use FSAs due to performance issues
-- MAGIC -- CJ - 08-04-2026.1: update join logic due to performance issues
-- MAGIC -- CJ - 07-28-2026.3: northern canada surcharge
-- MAGIC -- CJ - 07-28-2026.2: add billable weight for Canada and applied AHS rate for Canada
-- MAGIC -- CJ - 07-28-2026.1: add Canada Ground Zone
-- MAGIC -- CJ - 07-27-2026.2: add city, region, and country
-- MAGIC -- CJ - 07-27-2026.1: update tables with tables in NA Supply Chain LH
-- MAGIC -- CJ - 07-08-2026.2: add estimated delivery time
-- MAGIC -- CJ - 07-08-2026.1: update N/As to NULL
-- MAGIC -- CJ - 07-07-2026.1: add distance
-- MAGIC -- CJ - 06-25-2026.1: pull in unauthorized SKUs
-- MAGIC -- CJ - 06-15-2026.2: per Jon, we are currently not strapping in Rancho
-- MAGIC -- CJ - 06-15-2026.1: add storage rates for Rancho
-- MAGIC -- CJ - 05-14-2026.1: added YR60 (DHL Warehouse costs)
-- MAGIC -- CJ - 05-11-2026.1: updated how we're pulling origins
-- MAGIC -- CJ - 05-01-2026.1: add Rancho costs
-- MAGIC -- CJ - 04-27-2026.1: Add LTL / Parcel logic, include carton weight
-- MAGIC -- CJ - 04-24-2026.1: add COGS to FedEx Parcel Rates

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

-- NO CANADA
CREATE OR REPLACE TABLE fact_fedex_dtc_rates
USING DELTA
AS

WITH
params AS (
    SELECT
        9.99  AS min_net_base,
        6.45/2.0  AS residential_charge,
        0.25 AS fuel_rate,

        -- CJ - 05-01-2026.1:adding Rancho DTC Rates
        450.0 AS container_receipt,
        2.50  AS order_processing,
        6.75  AS shed_picking,
        0.75  AS parcel_picking,
        -- CJ - 06-15-2026.2
        -- 6.50  AS strapping
        0.0  AS strapping
),

origins AS (
    -- CJ - 05-11-2026.1
    SELECT *
    FROM `DIM DTC Ship Point Key`
    WHERE shipping_point_key in ('4674 - 07', '367G - 07')
),

-- CJ - 08-04-2026.2
-- zips AS (
--     SELECT
--         -- CJ - 07-28-2026.1
--         CASE
--             WHEN A.`Postal Code Country` = 'CAN' THEN LEFT (upper(trim(A.`Postal Code Clean`) ), 3) 
--             ELSE NULL
--         END AS FSA,
--         b.`Start FSA` as start_fsa,
--         b.`End FSA`   as end_fsa,

--         A.`Postal Code Clean` AS dest_zip_clean,
--         POSTAL_CODE AS destination_zip,
--         -- CJ - 07-27-2026.2
--         A.`City List` as dest_city,
--         A.`REGION` as dest_region,
--         A.`Postal Code Country` as dest_country,

--         -- CJ - 07-07-2026.1
--         A.`Distance from DHL`    AS dist_dhl,
--         A.`Distance from Rancho` AS dist_rancho,
--         -- CJ - 07-08-2026.2
--         A.`Alt Region`           AS alt_region,

--         -- CJ - 07-28-2026.1
--         `Zone` as Canada_Ground_Zone

--     FROM `DIM USA CA Zips` A
--     LEFT JOIN `DIM FedEx Canada Zones 2026` B  
--         ON LEFT (upper(trim(A.`Postal Code Clean`) ), 3) BETWEEN B.`Start FSA` AND B.`End FSA`
--     AND A.`Postal Code Country` = 'CAN'
-- ),

us_zips AS (
    SELECT
        NULL as start_fsa,
        NULL as end_fsa,

        A.`Postal Code Clean` AS dest_zip_clean,
        POSTAL_CODE AS destination_zip,
        -- CJ - 07-27-2026.2
        A.`City List` as dest_city,
        A.`REGION` as dest_region,
        A.`Postal Code Country` as dest_country,

        -- CJ - 07-07-2026.1
        A.`Distance from DHL`    AS dist_dhl,
        A.`Distance from Rancho` AS dist_rancho,
        -- CJ - 07-08-2026.2
        A.`Alt Region`           AS alt_region,

        NULL as Canada_Ground_Zone
 
    FROM `DIM USA CA Zips` A
    WHERE A.`Postal Code Country` = 'USA'
),
-- CJ - 08-04-2026.3
-- canadian_zips AS (
--     SELECT
--         MAX(b.`Start FSA`) as start_fsa,
--         MAX(b.`End FSA`) as end_fsa,

--         LEFT(UPPER(TRIM(A.`Postal Code Clean`)),3) AS dest_zip_clean,
--         LEFT(UPPER(TRIM(A.POSTAL_CODE)),3) AS destination_zip,

--         NULL as dest_city, -- when concatenating like below, it generates some extremely long strings
--         -- concat_ws(', ', collect_set(A.`City List`)) as dest_city,

--         concat_ws(', ', collect_set(A.`REGION`)) as dest_region,
--         A.`Postal Code Country` as dest_country,
--         AVG(A.`Distance from DHL`) AS dist_dhl,
--         AVG(A.`Distance from Rancho`) AS dist_rancho,
--         concat_ws(', ', collect_set(A.`Alt Region`)) as alt_region,
--         MAX(`Zone`) as Canada_Ground_Zone

--     FROM `DIM USA CA Zips` A
--     LEFT JOIN `DIM FedEx Canada Zones 2026` B ON LEFT (upper(trim(A.`Postal Code Clean`) ), 3) BETWEEN B.`Start FSA` AND B.`End FSA`
--     WHERE `Postal Code Country` = 'CAN'
--     GROUP BY
--         LEFT(UPPER(TRIM(A.`Postal Code Clean`)),3),
--         LEFT(UPPER(TRIM(A.POSTAL_CODE)),3),
--         A.`Postal Code Country`
-- ),
zips AS (
    -- CJ - 08-04-2026.3
    -- SELECT * FROM canadian_zips
    -- UNION ALL
    
    SELECT * FROM us_zips
),

sku AS (
    SELECT
        CAST(P.Material AS STRING) AS material,
        -- CJ - 07-28-2026.2
        -- CAST(P.`FedEx US Final Billable Weight` AS INT) AS fedex_billable_weight,
        ceil(`FedEx US Final Billable Weight`) AS fedex_us_billable_weight,
        ceil(`FedEx CAN Final Billable Weight`) AS fedex_can_billable_weight,
        -- CJ - 07-28-2026.2
        -- COALESCE(CAST(P.`FedEx Applied AHS Category` AS STRING), NULL) AS fedex_ahs_category, -- CJ - 07-08-2026.1
        COALESCE(CAST(P.`FedEx Applied AHS Category` AS STRING), NULL) AS fedex_us_ahs_category,
        COALESCE(CAST(P.`FedEx Applied AHS CAN Category` AS STRING), NULL) AS fedex_can_ahs_category,

        P.Cont_Qty as cont_qty,
        P.`TL Qty` as tl_qty,
        P.LTL_Parcel AS ltl_parcel, -- CJ - 04-27-2026.1
        coalesce(Z.COGS, 0) as COGS, -- CJ - 04-24-2026.1

        -- CJ - 05-14-2026.1
        P.`SS/PLT_Qty` as ss_plt_qty,
        P.`PC Business Unit` AS pc_business_unit

    FROM `DIM Product` P

    -- CJ - 04-24-2026.1
    LEFT JOIN (
        WITH cte AS (
            SELECT *,
            row_number() OVER (PARTITION BY Material ORDER BY Plnt) AS rn
            FROM `DIM ZMM02 COGS`
            WHERE Plnt in ('67', '73')
        )
        SELECT
            Material
            , `Standard price`/per as COGS
        FROM cte
        WHERE rn = 1
    ) Z on P.Material = Z.Material

),

rates_dim AS (
    SELECT
        CAST(`Weight _lbs_` AS INT)  AS bill_wt,
        CAST(Zone AS INT)            AS zone,
        CAST(`Base Rate` AS DOUBLE)  AS base_rate
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx Ground Rates Domestic`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Ground Rates Domestic`
),

surch_dim AS (
    SELECT
        CAST(Zone AS INT) AS zone,
        CAST(Oversize_Disc   AS DOUBLE) AS Oversize_Disc,
        CAST (AHS_Packaging_Disc AS DOUBLE) AS AHS_Packaging_Disc,
        CAST(AHS_Weight_Disc AS DOUBLE) AS AHS_Weight_Disc,
        CAST(AHS_Dim_Disc    AS DOUBLE) AS AHS_Dim_Disc
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx Ground Surcharges Domestic`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Ground Surcharges Domestic`
),

das_dim AS (
    SELECT
        CAST(`Destination ZIP Codes` AS STRING) AS destination_zip,
        COALESCE(CAST(`DAS Type` AS STRING), NULL) AS das_type, -- CJ - 07-08-2026.1
        COALESCE(CAST(`DAS Rate` AS DOUBLE), 0.0)   AS das_rate
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx DAS Zip Codes`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx DAS Zip Codes`
),

us_zone_map AS (
    SELECT
        CAST(`Origin Zip` AS STRING)           AS ship_point_zip,
        CAST(`Destination Zip Code` AS STRING) AS destination_zip,
        CAST(`FedEx Ground Zone` AS INT)       AS fedex_ground_zone
    -- CJ - 07-27-2026.1
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Zones`
    FROM `DIM FedEx Zones`
),

zip_origin_zone AS (
    SELECT
        o.*,
        z.dest_zip_clean,
        z.destination_zip,
        -- CJ - 07-28-2026.3
        case when z.dest_country in ('CAN') and 
            (z.dest_zip_clean in ('A0K', 'A2V') or (z.dest_zip_clean between 'A0P' and 'A0R') or (z.dest_zip_clean between 'X0A' and 'Y9Z') ) then TRUE else FALSE end as is_northern_canada,

        -- CJ - 07-27-2026.2
        z.dest_city,
        z.dest_region,
        z.dest_country,
        -- CJ - 07-08-2026.2
        z.alt_region,
        -- CJ - 07-07-2026.1
        CASE
            WHEN o.shipping_point = '4674' THEN z.dist_dhl
            WHEN o.shipping_point = '367G' THEN z.dist_rancho
        END AS distance,
        -- CJ - 07-28-2026.1
        CASE
            WHEN z.dest_country = 'CAN' THEN z.Canada_Ground_Zone
            ELSE zm.fedex_ground_zone
        END AS fedex_ground_zone
    FROM origins o
    CROSS JOIN zips z
    LEFT JOIN us_zone_map zm
        ON o.shipping_point_zip = zm.ship_point_zip
        AND z.dest_zip_clean = zm.destination_zip
    WHERE COALESCE(zm.fedex_ground_zone, z.Canada_Ground_Zone) IS NOT NULL -- CJ - 07-28-2026.1
),

-- CJ - 07-08-2026.2
delivery_time as (
    select a.*
        ,b.`Avg Delivery Time` as avg_ltl_delv_time
    from zip_origin_zone a
    left join `DIM LTL State to State` b on a.origin_state = b.`Origin State`
        and a.alt_region = b.`Destination State`
),

/* Join once, then calculate once */
joined AS (
    SELECT
        s.material,
        s.cont_qty,
        s.tl_qty,
        -- CJ - 05-14-2026.1
        s.ss_plt_qty,
        s.pc_business_unit,

        -- CJ - 04-24-2026.1
        s.COGS,
        s.ltl_parcel, -- CJ - 04-27-2026.1

        zoz.*,
        -- CJ - 07-08-2026.2
        least(
            zoz.avg_ltl_delv_time,
            case
                when zoz.distance <= 100 then 1
                when zoz.distance <= 300 then 2
                when zoz.distance <= 700 then 3
                when zoz.distance <= 1200 then 4
                when zoz.distance <= 1800 then 5
                else 6
            end
        ) as est_delv_time,

        -- CJ - 07-28-2026.2
        case
            when zoz.dest_country = 'CAN' then s.fedex_can_billable_weight
            when zoz.dest_country = 'USA' then s.fedex_us_billable_weight
        end as fedex_billable_weight,
        -- s.fedex_billable_weight,

        -- CJ - 07-28-2026.2
        case
            when zoz.dest_country = 'CAN' then s.fedex_can_ahs_category
            when zoz.dest_country = 'USA' then s.fedex_us_ahs_category
        end as fedex_ahs_category,
        -- s.fedex_ahs_category,

        r.base_rate,

        sd.Oversize_Disc,
        sd.AHS_Weight_Disc,
        sd.AHS_Dim_Disc,

        -- CJ - 07-28-2026.3
        case
            when zoz.is_northern_canada then 'Northern Canada Surcharge'
            when zoz.dest_country = 'USA' then dd.das_type
            else NULL
        end as das_type,
        -- dd.das_type,
        case
            when zoz.is_northern_canada
            then
                case
                    when s.fedex_can_billable_weight <= 70 then 110
                    else 175
                end
            else COALESCE(dd.das_rate,0.0)
        end as das_rate

    FROM delivery_time zoz
    CROSS JOIN sku s

    JOIN rates_dim r
    ON r.zone = zoz.fedex_ground_zone
        -- CJ - 07-28-2026.2
        -- AND (
        --     (
        --         zoz.dest_country = 'USA'
        --         AND r.bill_wt = least(150, s.fedex_us_billable_weight)
        --     )
        --     OR
        --     (
        --         zoz.dest_country = 'CAN'
        --         AND r.bill_wt = least(150, s.fedex_can_billable_weight)
        --     )
        -- )

        -- CJ - 08-04-2026.1
        AND r.bill_wt = LEAST(
            150,
            CASE
                WHEN zoz.dest_country = 'CAN'
                THEN s.fedex_can_billable_weight
                WHEN zoz.dest_country = 'USA'
                THEN s.fedex_us_billable_weight
            END
        )
        
    LEFT JOIN surch_dim sd ON sd.zone = zoz.fedex_ground_zone
    LEFT JOIN das_dim dd ON dd.destination_zip = zoz.destination_zip
),

/* Compute all reusable rates & subtotals once */
calc AS (
    SELECT
        j.*,

        /* Performance pricing rate (computed once) */
        CASE
            WHEN j.fedex_ground_zone BETWEEN 2 AND 8 THEN
                CASE
                    WHEN j.fedex_billable_weight BETWEEN 1 AND 6  THEN -0.36
                    WHEN j.fedex_billable_weight BETWEEN 7 AND 10 THEN -0.40
                    WHEN j.fedex_billable_weight >= 11            THEN -0.45
                    ELSE 0.0
                END
            WHEN j.fedex_ground_zone IN (9,14,17,22,23,25,92,96) THEN -0.09
            WHEN j.fedex_ground_zone IN (51, 54) THEN -0.27
            ELSE 0.0
        END AS perf_pricing_rate,

        /* Earned discount rate (computed once) */
        CASE
            WHEN j.fedex_ground_zone BETWEEN 2 AND 8 THEN -0.15
            ELSE 0.0
        END AS earned_discount_rate,

        /* AHS applied (computed once) */
        CASE
            WHEN j.fedex_ahs_category = 'Unauthorized' THEN CAST(1875 AS DOUBLE)
            WHEN j.fedex_ahs_category = 'Oversize'     THEN COALESCE(j.Oversize_Disc, 0.0)
            WHEN j.fedex_ahs_category = 'AHS Weight'   THEN COALESCE(j.AHS_Weight_Disc, 0.0)
            WHEN j.fedex_ahs_category = 'AHS Dim'      THEN COALESCE(j.AHS_Dim_Disc, 0.0)
            WHEN j.fedex_ahs_category IS NULL          THEN 0.0 -- CJ - 07-08-2026.1
            ELSE 0.0
        END AS applied_ahs_rate,

        /* Constants as columns for easy reuse */
        p.*

    FROM joined j
    CROSS JOIN params p
),

-- CJ - 06-15-2026.1
material_fc AS (
    SELECT
        a.Material,
        SUM(-a.`Combined Qty`) / 2.0 AS fc_sales_units -- splits volume between DHL and Rancho
    FROM `FACT Component Forecast Initial` a
    JOIN (
        select distinct Material 
        from `DIM Account` a
        join `DIM Customer` b on a.Payer = b. `Payer Key`
        where b.ECOM IS NOT NULL
    ) b on a.Material = b.Material
    WHERE a.`SOW` BETWEEN a.`Today SOW` AND (a.`Today SOW` + 139)
    GROUP BY a.Material
),

avg_fc AS (
    SELECT 
    AVG(fc_sales_units) AS avg_fc_sales_units
    FROM material_fc
),

storage_base AS (
    SELECT
        P.Material,
        P.`Cont_Qty` / 2.0        AS half_container_units,
        P.`Specs.Carton - Volume` AS carton_volume_ft3,
        COALESCE(
            a.fc_sales_units,
            b.avg_fc_sales_units
        ) AS fc_sales_units
    FROM `DIM Product` P
    LEFT JOIN material_fc a ON P.Material = a.Material
    CROSS JOIN avg_fc b
),

storage_drivers AS (
    SELECT
        Material,
        half_container_units,
        carton_volume_ft3,

        140.0 AS fc_sales_days,

        fc_sales_units,
        fc_sales_units / 140.0 AS fc_ADS, 

        half_container_units / NULLIF(fc_sales_units / 140.0, 0) AS half_container_DOS,

        (0.35 / 30.4167) * carton_volume_ft3 AS daily_storage_rate
    FROM storage_base
),

storage_costs AS (
    SELECT
        *,
        0.5 * half_container_DOS * half_container_units * daily_storage_rate AS total_storage_cost
    FROM storage_drivers
),

final_storage_costs AS (
    SELECT
        Material,
        half_container_units,
        carton_volume_ft3,
        fc_sales_days,

        daily_storage_rate,

        fc_sales_units,
        fc_ADS,
        half_container_DOS,

        total_storage_cost,

        total_storage_cost / NULLIF(half_container_units, 0) AS total_storage_cost_per_unit
    FROM storage_costs
)
-- end CJ - 06-15-2026.1

SELECT
    a.material,
    cont_qty,
    tl_qty,

    ss_plt_qty,
    pc_business_unit,
    COGS,

    ltl_parcel, -- CJ - 04-27-2026.1

    Port,
    shipping_point,
    shipping_point_desc,
    shipping_point_type,
    shipping_point_type_desc,
    shipping_point_zip,
    shipping_point_key_desc,
    shipping_point_key,

    -- CJ - 07-07-2026.1
    a.distance,
    -- CJ - 07-08-2026.2
    a.est_delv_time,

    YR50,
    YR73,
    YR51,
    YR53,

    CASE
        WHEN shipping_point_key in ('367G - 07') THEN
            (container_receipt) +
            (order_processing) +
            CASE
                WHEN ltl_parcel = 'LTL' THEN (shed_picking)
                ELSE (parcel_picking)
            END
        WHEN shipping_point_key in ('4674 - 07') THEN
            CASE
                WHEN pc_business_unit = 'GF NA' THEN 181.21
                WHEN pc_business_unit = 'Tools' THEN 108.21
                WHEN pc_business_unit = 'F & P EU' THEN 75.99
                WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62
                WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97
                WHEN pc_business_unit = 'Deck Boxes' THEN 87.41
                WHEN pc_business_unit = 'Packout' THEN 117.22
                WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
                ELSE NULL
            END  
        ELSE NULL
    END AS YR60,

    CASE
        WHEN shipping_point_key in ('367G - 07') THEN
            (container_receipt)/nullif(cont_qty, 0) +
            (order_processing) +
            CASE
                WHEN ltl_parcel = 'LTL' THEN (shed_picking)
                ELSE (parcel_picking)
            END
        WHEN shipping_point_key in ('4674 - 07') THEN
            CASE
                WHEN pc_business_unit = 'GF NA' THEN 181.21/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Tools' THEN 108.21/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'F & P EU' THEN 75.99/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Deck Boxes' THEN 87.41/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Packout' THEN 117.22/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89/nullif(ss_plt_qty, 0)
                ELSE NULL
            END
        ELSE NULL
    END AS YR60_ea_cost,

    dest_zip_clean,
    destination_zip,
    -- CJ - 07-27-2026.2
    a.dest_city,
    a.dest_region,
    a.dest_country,

    fedex_ground_zone,
    fedex_billable_weight,

    base_rate,
    perf_pricing_rate,
    (base_rate * perf_pricing_rate) AS perf_discount,

    earned_discount_rate,
    (base_rate * earned_discount_rate) AS earned_discount,

    /* Net base after discounts (min charge enforced once) */
    GREATEST(
        base_rate
        + (base_rate * perf_pricing_rate)
        + (base_rate * earned_discount_rate),
        (min_net_base)
    ) AS net_base_discounted,

    fedex_ahs_category,
    applied_ahs_rate,
    das_type,
    das_rate,
    residential_charge,

    /* Prefuel subtotal */
    (
        GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
        )
        + COALESCE(applied_ahs_rate, 0.0)
        + COALESCE(das_rate, 0.0)
        + residential_charge
    ) AS prefuel_base_rate,

    fuel_rate,

    /* Fuel charge */
    fuel_rate * (
        GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
        )
        + COALESCE(applied_ahs_rate, 0.0)
        + COALESCE(das_rate, 0.0)
        + residential_charge
    ) AS fuel_surcharge,

    /* Net charge */
    (
        (
            GREATEST(
                base_rate
                + (base_rate * perf_pricing_rate)
                + (base_rate * earned_discount_rate),
                (min_net_base)
            )
            + COALESCE(applied_ahs_rate, 0.0)
            + COALESCE(das_rate, 0.0)
            + residential_charge
        )
        + fuel_rate * (
            GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
            )
            + COALESCE(applied_ahs_rate, 0.0)
            + COALESCE(das_rate, 0.0)
            + residential_charge
        )
    ) AS net_cost,

    -- CJ - 06-15-2026.1
    b.half_container_units,
    b.fc_sales_days,
    b.daily_storage_rate,
    b.fc_sales_units,
    b.fc_ADS,
    b.half_container_DOS,
    b.total_storage_cost,
    b.total_storage_cost_per_unit

FROM calc a 
left join final_storage_costs b on a.material = b.Material and shipping_point_key in ('367G - 07')   
WHERE true
    -- and a.material in ('255122')
    -- and destination_zip in ('30305')
    -- and dest_country in ('CAN')
    -- and das_type is not null
; 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- WITH CANADA (TO STRENUOUS TO RUN)
CREATE OR REPLACE TABLE fact_fedex_dtc_rates
USING DELTA
AS

WITH
params AS (
    SELECT
        9.99  AS min_net_base,
        6.45/2.0  AS residential_charge,
        0.25 AS fuel_rate,

        -- CJ - 05-01-2026.1:adding Rancho DTC Rates
        450.0 AS container_receipt,
        2.50  AS order_processing,
        6.75  AS shed_picking,
        0.75  AS parcel_picking,
        -- CJ - 06-15-2026.2
        -- 6.50  AS strapping
        0.0  AS strapping
),

origins AS (
    -- CJ - 05-11-2026.1
    SELECT *
    FROM `DIM DTC Ship Point Key`
    WHERE shipping_point_key in ('4674 - 07', '367G - 07')
),

-- CJ - 08-04-2026.2
-- zips AS (
--     SELECT
--         -- CJ - 07-28-2026.1
--         CASE
--             WHEN A.`Postal Code Country` = 'CAN' THEN LEFT (upper(trim(A.`Postal Code Clean`) ), 3) 
--             ELSE NULL
--         END AS FSA,
--         b.`Start FSA` as start_fsa,
--         b.`End FSA`   as end_fsa,

--         A.`Postal Code Clean` AS dest_zip_clean,
--         POSTAL_CODE AS destination_zip,
--         -- CJ - 07-27-2026.2
--         A.`City List` as dest_city,
--         A.`REGION` as dest_region,
--         A.`Postal Code Country` as dest_country,

--         -- CJ - 07-07-2026.1
--         A.`Distance from DHL`    AS dist_dhl,
--         A.`Distance from Rancho` AS dist_rancho,
--         -- CJ - 07-08-2026.2
--         A.`Alt Region`           AS alt_region,

--         -- CJ - 07-28-2026.1
--         `Zone` as Canada_Ground_Zone

--     FROM `DIM USA CA Zips` A
--     LEFT JOIN `DIM FedEx Canada Zones 2026` B  
--         ON LEFT (upper(trim(A.`Postal Code Clean`) ), 3) BETWEEN B.`Start FSA` AND B.`End FSA`
--     AND A.`Postal Code Country` = 'CAN'
-- ),
us_zips AS (
    SELECT
        NULL as start_fsa,
        NULL as end_fsa,

        A.`Postal Code Clean` AS dest_zip_clean,
        POSTAL_CODE AS destination_zip,
        -- CJ - 07-27-2026.2
        A.`City List` as dest_city,
        A.`REGION` as dest_region,
        A.`Postal Code Country` as dest_country,

        -- CJ - 07-07-2026.1
        A.`Distance from DHL`    AS dist_dhl,
        A.`Distance from Rancho` AS dist_rancho,
        -- CJ - 07-08-2026.2
        A.`Alt Region`           AS alt_region,

        NULL as Canada_Ground_Zone
 
    FROM `DIM USA CA Zips` A
    WHERE A.`Postal Code Country` = 'USA'
),
canadian_zips AS (
    SELECT
        MAX(b.`Start FSA`) as start_fsa,
        MAX(b.`End FSA`) as end_fsa,

        LEFT(UPPER(TRIM(A.`Postal Code Clean`)),3) AS dest_zip_clean,
        LEFT(UPPER(TRIM(A.POSTAL_CODE)),3) AS destination_zip,

        NULL as dest_city, -- when concatenating like below, it generates some extremely long strings
        -- concat_ws(', ', collect_set(A.`City List`)) as dest_city,

        concat_ws(', ', collect_set(A.`REGION`)) as dest_region,
        A.`Postal Code Country` as dest_country,
        AVG(A.`Distance from DHL`) AS dist_dhl,
        AVG(A.`Distance from Rancho`) AS dist_rancho,
        concat_ws(', ', collect_set(A.`Alt Region`)) as alt_region,
        MAX(`Zone`) as Canada_Ground_Zone

    FROM `DIM USA CA Zips` A
    LEFT JOIN `DIM FedEx Canada Zones 2026` B ON LEFT (upper(trim(A.`Postal Code Clean`) ), 3) BETWEEN B.`Start FSA` AND B.`End FSA`
    WHERE `Postal Code Country` = 'CAN'
    GROUP BY
        LEFT(UPPER(TRIM(A.`Postal Code Clean`)),3),
        LEFT(UPPER(TRIM(A.POSTAL_CODE)),3),
        A.`Postal Code Country`
),
zips AS (
    SELECT * FROM canadian_zips
    UNION ALL
    SELECT * FROM us_zips
),

sku AS (
    SELECT
        CAST(P.Material AS STRING) AS material,
        -- CJ - 07-28-2026.2
        -- CAST(P.`FedEx US Final Billable Weight` AS INT) AS fedex_billable_weight,
        ceil(`FedEx US Final Billable Weight`) AS fedex_us_billable_weight,
        ceil(`FedEx CAN Final Billable Weight`) AS fedex_can_billable_weight,
        -- CJ - 07-28-2026.2
        -- COALESCE(CAST(P.`FedEx Applied AHS Category` AS STRING), NULL) AS fedex_ahs_category, -- CJ - 07-08-2026.1
        COALESCE(CAST(P.`FedEx Applied AHS Category` AS STRING), NULL) AS fedex_us_ahs_category,
        COALESCE(CAST(P.`FedEx Applied AHS CAN Category` AS STRING), NULL) AS fedex_can_ahs_category,

        P.Cont_Qty as cont_qty,
        P.`TL Qty` as tl_qty,
        P.LTL_Parcel AS ltl_parcel, -- CJ - 04-27-2026.1
        coalesce(Z.COGS, 0) as COGS, -- CJ - 04-24-2026.1

        -- CJ - 05-14-2026.1
        P.`SS/PLT_Qty` as ss_plt_qty,
        P.`PC Business Unit` AS pc_business_unit

    FROM `DIM Product` P

    -- CJ - 04-24-2026.1
    LEFT JOIN (
        WITH cte AS (
            SELECT *,
            row_number() OVER (PARTITION BY Material ORDER BY Plnt) AS rn
            FROM `DIM ZMM02 COGS`
            WHERE Plnt in ('67', '73')
        )
        SELECT
            Material
            , `Standard price`/per as COGS
        FROM cte
        WHERE rn = 1
    ) Z on P.Material = Z.Material

),

rates_dim AS (
    SELECT
        CAST(`Weight _lbs_` AS INT)  AS bill_wt,
        CAST(Zone AS INT)            AS zone,
        CAST(`Base Rate` AS DOUBLE)  AS base_rate
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx Ground Rates Domestic`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Ground Rates Domestic`
),

surch_dim AS (
    SELECT
        CAST(Zone AS INT) AS zone,
        CAST(Oversize_Disc   AS DOUBLE) AS Oversize_Disc,
        CAST (AHS_Packaging_Disc AS DOUBLE) AS AHS_Packaging_Disc,
        CAST(AHS_Weight_Disc AS DOUBLE) AS AHS_Weight_Disc,
        CAST(AHS_Dim_Disc    AS DOUBLE) AS AHS_Dim_Disc
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx Ground Surcharges Domestic`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Ground Surcharges Domestic`
),

das_dim AS (
    SELECT
        CAST(`Destination ZIP Codes` AS STRING) AS destination_zip,
        COALESCE(CAST(`DAS Type` AS STRING), NULL) AS das_type, -- CJ - 07-08-2026.1
        COALESCE(CAST(`DAS Rate` AS DOUBLE), 0.0)   AS das_rate
    -- CJ - 07-27-2026.1
    FROM `DIM FedEx DAS Zip Codes`
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx DAS Zip Codes`
),

us_zone_map AS (
    SELECT
        CAST(`Origin Zip` AS STRING)           AS ship_point_zip,
        CAST(`Destination Zip Code` AS STRING) AS destination_zip,
        CAST(`FedEx Ground Zone` AS INT)       AS fedex_ground_zone
    -- CJ - 07-27-2026.1
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Zones`
    FROM `DIM FedEx Zones`
),

zip_origin_zone AS (
    SELECT
        o.*,
        z.dest_zip_clean,
        z.destination_zip,
        -- CJ - 07-28-2026.3
        case when z.dest_country in ('CAN') and 
            (z.dest_zip_clean in ('A0K', 'A2V') or (z.dest_zip_clean between 'A0P' and 'A0R') or (z.dest_zip_clean between 'X0A' and 'Y9Z') ) then TRUE else FALSE end as is_northern_canada,

        -- CJ - 07-27-2026.2
        z.dest_city,
        z.dest_region,
        z.dest_country,
        -- CJ - 07-08-2026.2
        z.alt_region,
        -- CJ - 07-07-2026.1
        CASE
            WHEN o.shipping_point = '4674' THEN z.dist_dhl
            WHEN o.shipping_point = '367G' THEN z.dist_rancho
        END AS distance,
        -- CJ - 07-28-2026.1
        CASE
            WHEN z.dest_country = 'CAN' THEN z.Canada_Ground_Zone
            ELSE zm.fedex_ground_zone
        END AS fedex_ground_zone
    FROM origins o
    CROSS JOIN zips z
    LEFT JOIN us_zone_map zm
        ON o.shipping_point_zip = zm.ship_point_zip
        AND z.dest_zip_clean = zm.destination_zip
    WHERE COALESCE(zm.fedex_ground_zone, z.Canada_Ground_Zone) IS NOT NULL -- CJ - 07-28-2026.1
),

-- CJ - 07-08-2026.2
delivery_time as (
    select a.*
        ,b.`Avg Delivery Time` as avg_ltl_delv_time
    from zip_origin_zone a
    left join `DIM LTL State to State` b on a.origin_state = b.`Origin State`
        and a.alt_region = b.`Destination State`
),

/* Join once, then calculate once */
joined AS (
    SELECT
        s.material,
        s.cont_qty,
        s.tl_qty,
        -- CJ - 05-14-2026.1
        s.ss_plt_qty,
        s.pc_business_unit,

        -- CJ - 04-24-2026.1
        s.COGS,
        s.ltl_parcel, -- CJ - 04-27-2026.1

        zoz.*,
        -- CJ - 07-08-2026.2
        least(
            zoz.avg_ltl_delv_time,
            case
                when zoz.distance <= 100 then 1
                when zoz.distance <= 300 then 2
                when zoz.distance <= 700 then 3
                when zoz.distance <= 1200 then 4
                when zoz.distance <= 1800 then 5
                else 6
            end
        ) as est_delv_time,

        -- CJ - 07-28-2026.2
        case
            when zoz.dest_country = 'CAN' then s.fedex_can_billable_weight
            when zoz.dest_country = 'USA' then s.fedex_us_billable_weight
        end as fedex_billable_weight,
        -- s.fedex_billable_weight,

        -- CJ - 07-28-2026.2
        case
            when zoz.dest_country = 'CAN' then s.fedex_can_ahs_category
            when zoz.dest_country = 'USA' then s.fedex_us_ahs_category
        end as fedex_ahs_category,
        -- s.fedex_ahs_category,

        r.base_rate,

        sd.Oversize_Disc,
        sd.AHS_Weight_Disc,
        sd.AHS_Dim_Disc,

        -- CJ - 07-28-2026.3
        case
            when zoz.is_northern_canada then 'Northern Canada Surcharge'
            when zoz.dest_country = 'USA' then dd.das_type
            else NULL
        end as das_type,
        -- dd.das_type,
        case
            when zoz.is_northern_canada
            then
                case
                    when s.fedex_can_billable_weight <= 70 then 110
                    else 175
                end
            else COALESCE(dd.das_rate,0.0)
        end as das_rate

    FROM delivery_time zoz
    CROSS JOIN sku s

    JOIN rates_dim r
    ON r.zone = zoz.fedex_ground_zone
        -- -- CJ - 07-28-2026.2
        -- AND (
        --     (
        --         zoz.dest_country = 'USA'
        --         AND r.bill_wt = least(150, s.fedex_us_billable_weight)
        --     )
        --     OR
        --     (
        --         zoz.dest_country = 'CAN'
        --         AND r.bill_wt = least(150, s.fedex_can_billable_weight)
        --     )
        -- )

        -- CJ - 08-04-2026.1
        AND r.bill_wt = LEAST(
            150,
            CASE
                WHEN zoz.dest_country = 'CAN'
                THEN s.fedex_can_billable_weight
                WHEN zoz.dest_country = 'USA'
                THEN s.fedex_us_billable_weight
            END
        )
        
    LEFT JOIN surch_dim sd ON sd.zone = zoz.fedex_ground_zone
    LEFT JOIN das_dim dd ON dd.destination_zip = zoz.destination_zip
),

/* Compute all reusable rates & subtotals once */
calc AS (
    SELECT
        j.*,

        /* Performance pricing rate (computed once) */
        CASE
            WHEN j.fedex_ground_zone BETWEEN 2 AND 8 THEN
                CASE
                    WHEN j.fedex_billable_weight BETWEEN 1 AND 6  THEN -0.36
                    WHEN j.fedex_billable_weight BETWEEN 7 AND 10 THEN -0.40
                    WHEN j.fedex_billable_weight >= 11            THEN -0.45
                    ELSE 0.0
                END
            WHEN j.fedex_ground_zone IN (9,14,17,22,23,25,92,96) THEN -0.09
            WHEN j.fedex_ground_zone IN (51, 54) THEN -0.27
            ELSE 0.0
        END AS perf_pricing_rate,

        /* Earned discount rate (computed once) */
        CASE
            WHEN j.fedex_ground_zone BETWEEN 2 AND 8 THEN -0.15
            ELSE 0.0
        END AS earned_discount_rate,

        /* AHS applied (computed once) */
        CASE
            WHEN j.fedex_ahs_category = 'Unauthorized' THEN CAST(1875 AS DOUBLE)
            WHEN j.fedex_ahs_category = 'Oversize'     THEN COALESCE(j.Oversize_Disc, 0.0)
            WHEN j.fedex_ahs_category = 'AHS Weight'   THEN COALESCE(j.AHS_Weight_Disc, 0.0)
            WHEN j.fedex_ahs_category = 'AHS Dim'      THEN COALESCE(j.AHS_Dim_Disc, 0.0)
            WHEN j.fedex_ahs_category IS NULL          THEN 0.0 -- CJ - 07-08-2026.1
            ELSE 0.0
        END AS applied_ahs_rate,

        /* Constants as columns for easy reuse */
        p.*

    FROM joined j
    CROSS JOIN params p
),

-- CJ - 06-15-2026.1
material_fc AS (
    SELECT
        a.Material,
        SUM(-a.`Combined Qty`) / 2.0 AS fc_sales_units -- splits volume between DHL and Rancho
    FROM `FACT Component Forecast Initial` a
    JOIN (
        select distinct Material 
        from `DIM Account` a
        join `DIM Customer` b on a.Payer = b. `Payer Key`
        where b.ECOM IS NOT NULL
    ) b on a.Material = b.Material
    WHERE a.`SOW` BETWEEN a.`Today SOW` AND (a.`Today SOW` + 139)
    GROUP BY a.Material
),

avg_fc AS (
    SELECT 
    AVG(fc_sales_units) AS avg_fc_sales_units
    FROM material_fc
),

storage_base AS (
    SELECT
        P.Material,
        P.`Cont_Qty` / 2.0        AS half_container_units,
        P.`Specs.Carton - Volume` AS carton_volume_ft3,
        COALESCE(
            a.fc_sales_units,
            b.avg_fc_sales_units
        ) AS fc_sales_units
    FROM `DIM Product` P
    LEFT JOIN material_fc a ON P.Material = a.Material
    CROSS JOIN avg_fc b
),

storage_drivers AS (
    SELECT
        Material,
        half_container_units,
        carton_volume_ft3,

        140.0 AS fc_sales_days,

        fc_sales_units,
        fc_sales_units / 140.0 AS fc_ADS, 

        half_container_units / NULLIF(fc_sales_units / 140.0, 0) AS half_container_DOS,

        (0.35 / 30.4167) * carton_volume_ft3 AS daily_storage_rate
    FROM storage_base
),

storage_costs AS (
    SELECT
        *,
        0.5 * half_container_DOS * half_container_units * daily_storage_rate AS total_storage_cost
    FROM storage_drivers
),

final_storage_costs AS (
    SELECT
        Material,
        half_container_units,
        carton_volume_ft3,
        fc_sales_days,

        daily_storage_rate,

        fc_sales_units,
        fc_ADS,
        half_container_DOS,

        total_storage_cost,

        total_storage_cost / NULLIF(half_container_units, 0) AS total_storage_cost_per_unit
    FROM storage_costs
)
-- end CJ - 06-15-2026.1

SELECT
    a.material,
    cont_qty,
    tl_qty,

    ss_plt_qty,
    pc_business_unit,
    COGS,

    ltl_parcel, -- CJ - 04-27-2026.1

    Port,
    shipping_point,
    shipping_point_desc,
    shipping_point_type,
    shipping_point_type_desc,
    shipping_point_zip,
    shipping_point_key_desc,
    shipping_point_key,

    -- CJ - 07-07-2026.1
    a.distance,
    -- CJ - 07-08-2026.2
    a.est_delv_time,

    YR50,
    YR73,
    YR51,
    YR53,

    CASE
        WHEN shipping_point_key in ('367G - 07') THEN
            (container_receipt) +
            (order_processing) +
            CASE
                WHEN ltl_parcel = 'LTL' THEN (shed_picking)
                ELSE (parcel_picking)
            END
        WHEN shipping_point_key in ('4674 - 07') THEN
            CASE
                WHEN pc_business_unit = 'GF NA' THEN 181.21
                WHEN pc_business_unit = 'Tools' THEN 108.21
                WHEN pc_business_unit = 'F & P EU' THEN 75.99
                WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62
                WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97
                WHEN pc_business_unit = 'Deck Boxes' THEN 87.41
                WHEN pc_business_unit = 'Packout' THEN 117.22
                WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
                ELSE NULL
            END  
        ELSE NULL
    END AS YR60,

    CASE
        WHEN shipping_point_key in ('367G - 07') THEN
            (container_receipt)/nullif(cont_qty, 0) +
            (order_processing) +
            CASE
                WHEN ltl_parcel = 'LTL' THEN (shed_picking)
                ELSE (parcel_picking)
            END
        WHEN shipping_point_key in ('4674 - 07') THEN
            CASE
                WHEN pc_business_unit = 'GF NA' THEN 181.21/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Tools' THEN 108.21/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'F & P EU' THEN 75.99/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Deck Boxes' THEN 87.41/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit = 'Packout' THEN 117.22/nullif(ss_plt_qty, 0)
                WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89/nullif(ss_plt_qty, 0)
                ELSE NULL
            END
        ELSE NULL
    END AS YR60_ea_cost,

    dest_zip_clean,
    destination_zip,
    -- CJ - 07-27-2026.2
    a.dest_city,
    a.dest_region,
    a.dest_country,

    fedex_ground_zone,
    fedex_billable_weight,

    base_rate,
    perf_pricing_rate,
    (base_rate * perf_pricing_rate) AS perf_discount,

    earned_discount_rate,
    (base_rate * earned_discount_rate) AS earned_discount,

    /* Net base after discounts (min charge enforced once) */
    GREATEST(
        base_rate
        + (base_rate * perf_pricing_rate)
        + (base_rate * earned_discount_rate),
        (min_net_base)
    ) AS net_base_discounted,

    fedex_ahs_category,
    applied_ahs_rate,
    das_type,
    das_rate,
    residential_charge,

    /* Prefuel subtotal */
    (
        GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
        )
        + COALESCE(applied_ahs_rate, 0.0)
        + COALESCE(das_rate, 0.0)
        + residential_charge
    ) AS prefuel_base_rate,

    fuel_rate,

    /* Fuel charge */
    fuel_rate * (
        GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
        )
        + COALESCE(applied_ahs_rate, 0.0)
        + COALESCE(das_rate, 0.0)
        + residential_charge
    ) AS fuel_surcharge,

    /* Net charge */
    (
        (
            GREATEST(
                base_rate
                + (base_rate * perf_pricing_rate)
                + (base_rate * earned_discount_rate),
                (min_net_base)
            )
            + COALESCE(applied_ahs_rate, 0.0)
            + COALESCE(das_rate, 0.0)
            + residential_charge
        )
        + fuel_rate * (
            GREATEST(
            base_rate
            + (base_rate * perf_pricing_rate)
            + (base_rate * earned_discount_rate),
            (min_net_base)
            )
            + COALESCE(applied_ahs_rate, 0.0)
            + COALESCE(das_rate, 0.0)
            + residential_charge
        )
    ) AS net_cost,

    -- CJ - 06-15-2026.1
    b.half_container_units,
    b.fc_sales_days,
    b.daily_storage_rate,
    b.fc_sales_units,
    b.fc_ADS,
    b.half_container_DOS,
    b.total_storage_cost,
    b.total_storage_cost_per_unit

FROM calc a 
left join final_storage_costs b on a.material = b.Material and shipping_point_key in ('367G - 07')   
WHERE true
    -- and a.material in ('255122')
    -- and destination_zip in ('30305')
    -- and dest_country in ('CAN')
    -- and das_type is not null
; 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
