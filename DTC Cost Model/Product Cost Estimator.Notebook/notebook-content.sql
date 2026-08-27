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

-- Change Log
-- CJ - 07-27-2026.1: update tables with tables in NA Supply Chain LH

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

-- SKU Cost Estimator - Parcel
CREATE OR REPLACE TABLE fact_dtc_state_zone_distribution
USING DELTA
AS

WITH base AS (

    SELECT
        a.ship_to_country,
        a.ship_to_state,
        a.ship_to_zip_clean,

        b.`Distance from DHL`    AS distance_from_dhl,
        b.`Distance from Rancho` AS distance_from_rancho,

        '31326' AS dhl_zip,
        '90220' AS rancho_zip,

        SUM(a.delivery_count) AS delivery_count,

        SUM(SUM(a.delivery_count)) OVER (
            PARTITION BY
                a.ship_to_country,
                a.ship_to_state
        ) AS state_delivery_count,

        CAST(SUM(a.delivery_count) AS DOUBLE)
        /
        CAST(
            SUM(SUM(a.delivery_count)) OVER (
                PARTITION BY
                    a.ship_to_country,
                    a.ship_to_state
            )
        AS DOUBLE)
        AS state_ratio

    FROM fact_ecomm_material_zip_weight_matrix a

    LEFT JOIN `DIM USA CA Zips` b
        ON a.ship_to_zip_clean = b.`Postal Code Clean`

    WHERE a.ship_to_country = 'USA'
        AND (a.ship_to_us_region IS NOT NULL OR a.ship_to_state IN ('AK', 'HI') ) 

    GROUP BY
        a.ship_to_country,
        a.ship_to_state,
        a.ship_to_zip_clean,
        b.`Distance from DHL`,
        b.`Distance from Rancho`

),

zone_map AS (

    SELECT
        CAST(`Origin Zip` AS STRING)           AS ship_point_zip,
        CAST(`Destination Zip Code` AS STRING) AS destination_zip,
        CAST(`FedEx Ground Zone` AS INT)       AS fedex_ground_zone

    -- CJ - 07-27-2026.1
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx Zones`
    FROM `DIM FedEx Zones`

),

das_dim AS (

    SELECT
        CAST(`Destination ZIP Codes` AS STRING) AS destination_zip,
        MAX(COALESCE(CAST(`DAS Rate` AS DOUBLE),0.0)) AS das_rate

    -- CJ - 07-27-2026.1
    -- FROM `BRZ_NA_SC_LH`.`dbo`.`FedEx DAS Zip Codes`
    FROM `DIM FedEx DAS Zip Codes`

    GROUP BY
        CAST(`Destination ZIP Codes` AS STRING)

),

base_zone_map AS (

    SELECT
        a.ship_to_country,
        a.ship_to_state,
        a.ship_to_zip_clean,

        a.distance_from_dhl,
        a.distance_from_rancho,

        a.dhl_zip,
        a.rancho_zip,

        a.delivery_count,
        a.state_delivery_count,
        a.state_ratio,

        b.fedex_ground_zone AS dhl_zone,
        c.fedex_ground_zone AS rancho_zone,

        COALESCE(d.das_rate,0.0) AS das_rate

    FROM base a

    LEFT JOIN zone_map b
        ON a.ship_to_zip_clean = b.destination_zip
        AND a.dhl_zip = b.ship_point_zip

    LEFT JOIN zone_map c
        ON a.ship_to_zip_clean = c.destination_zip
        AND a.rancho_zip = c.ship_point_zip

    LEFT JOIN das_dim d
        ON a.ship_to_zip_clean = d.destination_zip

),

state_choice AS (

    SELECT
        ship_to_country,
        ship_to_state,

        SUM(distance_from_dhl * delivery_count)
            / SUM(delivery_count)
            AS dhl_weighted_avg_distance,

        SUM(distance_from_rancho * delivery_count)
            / SUM(delivery_count)
            AS rancho_weighted_avg_distance,

        CASE
            WHEN
                SUM(distance_from_dhl * delivery_count)
                    / SUM(delivery_count)
                <=
                SUM(distance_from_rancho * delivery_count)
                    / SUM(delivery_count)
            THEN 'DHL'
            ELSE 'Rancho'
        END AS chosen_ship_point

    FROM base_zone_map

    GROUP BY
        ship_to_country,
        ship_to_state

),

chosen_zip_level AS (

    SELECT
        b.ship_to_country,
        b.ship_to_state,
        b.ship_to_zip_clean,

        s.chosen_ship_point,

        CASE
            WHEN s.chosen_ship_point = 'DHL'
                THEN b.dhl_zone
            ELSE b.rancho_zone
        END AS chosen_zone,

        CASE
            WHEN s.chosen_ship_point = 'DHL'
                THEN b.distance_from_dhl
            ELSE b.distance_from_rancho
        END AS chosen_distance,

        b.das_rate,
        b.delivery_count,
        b.state_delivery_count

    FROM base_zone_map b

    INNER JOIN state_choice s
        ON b.ship_to_country = s.ship_to_country
        AND b.ship_to_state = s.ship_to_state

),

final_summary AS (

    SELECT
        ship_to_country,
        ship_to_state,
        chosen_ship_point,
        chosen_zone,

        SUM(delivery_count) AS delivery_count,

        MAX(state_delivery_count) AS state_delivery_count,

        CAST(SUM(delivery_count) AS DOUBLE)
            / CAST(MAX(state_delivery_count) AS DOUBLE)
            AS state_zone_ratio,

        SUM(chosen_distance * delivery_count)
            / SUM(delivery_count)
            AS weighted_avg_distance,

        SUM(das_rate * delivery_count)
            / SUM(delivery_count)
            AS weighted_avg_das_rate

    FROM chosen_zip_level

    GROUP BY
        ship_to_country,
        ship_to_state,
        chosen_ship_point,
        chosen_zone

)

SELECT
    ship_to_country,
    ship_to_state,
    chosen_ship_point,
    chosen_zone,

    delivery_count,
    state_delivery_count,
    state_zone_ratio,

    weighted_avg_distance,
    weighted_avg_das_rate,

    SUM(delivery_count) OVER (
        PARTITION BY ship_to_country
    ) AS country_delivery_count,

    CAST(delivery_count AS DOUBLE)
        /
        CAST(
            SUM(delivery_count) OVER (
                PARTITION BY ship_to_country
            )
        AS DOUBLE)
        AS country_ratio

FROM final_summary

ORDER BY
    ship_to_country,
    ship_to_state,
    chosen_zone;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }
