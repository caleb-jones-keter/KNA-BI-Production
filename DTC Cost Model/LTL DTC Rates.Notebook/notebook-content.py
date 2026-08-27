# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "624ea251-e87f-45d7-8358-a55b3fa46385",
# META       "default_lakehouse_name": "NA_Supply_Chain",
# META       "default_lakehouse_workspace_id": "8e2b746d-3224-4a82-8467-a2800eef337e",
# META       "known_lakehouses": [
# META         {
# META           "id": "624ea251-e87f-45d7-8358-a55b3fa46385"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC -- Change Log
# MAGIC -- CJ - 07-17-2026.1: Tom's wild nonsense factor (account for % of loads that are bundled)
# MAGIC -- CJ - 07-08-2026.1: add estimated delivery time
# MAGIC -- CJ - 06-11-2026.1: add storage costs
# MAGIC -- CJ - 05-26-2026.1: limit to just USA zips for now
# MAGIC -- CJ - 05-14-2026.1: added YR60 (DHL Warehouse costs)
# MAGIC -- CJ - 05-11-2026.1: updated how we're pulling origins

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC CREATE OR REPLACE TABLE fact_ltl_dtc_rates
# MAGIC USING DELTA
# MAGIC AS
# MAGIC 
# MAGIC WITH origins AS (
# MAGIC     -- CJ - 05-11-2026.1
# MAGIC     SELECT *
# MAGIC     FROM `DIM DTC Ship Point Key`
# MAGIC     WHERE shipping_point_key in ('4674 - 06', '367G - 06')
# MAGIC ),
# MAGIC 
# MAGIC zip_distances AS (
# MAGIC     SELECT
# MAGIC         CAST(`Postal Code Clean` AS STRING) AS dest_zip_clean,
# MAGIC         CAST(POSTAL_CODE AS STRING)         AS destination_zip,
# MAGIC         REGION,
# MAGIC         `City List` AS city_list,
# MAGIC         'DHL' AS ship_point,
# MAGIC         `Distance from DHL` AS distance,
# MAGIC         `Alt Region` AS alt_region -- CJ - 07-08-2026.1
# MAGIC 
# MAGIC     FROM `DIM USA CA Zips`
# MAGIC     -- CJ - 05-26-2026.1
# MAGIC     WHERE `Postal Code Country` = 'USA'
# MAGIC 
# MAGIC     UNION ALL
# MAGIC 
# MAGIC     SELECT
# MAGIC         CAST(`Postal Code Clean` AS STRING),
# MAGIC         CAST(POSTAL_CODE AS STRING),
# MAGIC         REGION,
# MAGIC         `City List`,
# MAGIC         'Rancho',
# MAGIC         `Distance from Rancho`,
# MAGIC         `Alt Region` -- CJ - 07-08-2026.1
# MAGIC     FROM `DIM USA CA Zips`
# MAGIC     -- CJ - 05-26-2026.1
# MAGIC     WHERE `Postal Code Country` = 'USA'
# MAGIC ),
# MAGIC 
# MAGIC sku AS (
# MAGIC     SELECT
# MAGIC         CAST(P.Material AS STRING)                        AS material,
# MAGIC         P.`Specs.Carton - Volume`                         AS carton_volume_ft3,  
# MAGIC         P.`Specs.Carton - Length`                         AS carton_len,  
# MAGIC         P.`Specs.Carton - Width`                          AS carton_width,  
# MAGIC         P.`Specs.Carton - Height`                         AS carton_height,
# MAGIC         P.`Specs.Carton - Weight`                         AS carton_weight,
# MAGIC         GREATEST(
# MAGIC             CEIL(P.`Specs.Carton - Weight`), 
# MAGIC             CEIL( (P.`Specs.Carton - Length`  * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139.0 )
# MAGIC         )                                                 AS billable_weight,
# MAGIC         P.`Cont_Qty`                                      AS cont_qty,
# MAGIC         P.`TL Qty`                                        AS tl_qty,
# MAGIC         P.LTL_Parcel                                      AS ltl_parcel,
# MAGIC         Z.COGS,
# MAGIC         P.`Model`                                         AS model,
# MAGIC         P.`SS/PLT_Qty`                                    AS ss_plt_qty,
# MAGIC         P.`Stacked_Cont/TL`                               AS stacked_cont_tl,
# MAGIC         IF(upper(`Stacked_Cont/TL`) like ('%P%'), 1, 0)   AS pallet_present,
# MAGIC         -- CJ - 05-14-2026.1
# MAGIC         P.`PC Business Unit`                              AS pc_business_unit
# MAGIC 
# MAGIC     FROM `DIM Product` P
# MAGIC     LEFT JOIN (
# MAGIC         WITH cte AS (
# MAGIC             SELECT *,
# MAGIC                 row_number() OVER (PARTITION BY Material ORDER BY Plnt) AS rn
# MAGIC             FROM `dbo`.`DIM ZMM02 COGS`
# MAGIC             WHERE Plnt in ('67', '73')
# MAGIC         )
# MAGIC         SELECT
# MAGIC             Material
# MAGIC             , `Standard price`/per as COGS
# MAGIC         FROM cte
# MAGIC         WHERE rn = 1
# MAGIC     ) Z on P.Material = Z.Material
# MAGIC     WHERE P.`Specs.Carton - Weight` IS NOT NULL
# MAGIC ),
# MAGIC 
# MAGIC -- CJ - 06-11-2026.1
# MAGIC 
# MAGIC material_fc AS (
# MAGIC     SELECT
# MAGIC         a.Material,
# MAGIC         SUM(-a.`Combined Qty`) / 2.0 AS fc_sales_units -- 2 nodes for DHL and Rancho
# MAGIC     FROM `FACT Component Forecast Initial` a
# MAGIC     JOIN (
# MAGIC         select distinct Material 
# MAGIC         from `DIM Account` a
# MAGIC         join `DIM Customer` b on a.Payer = b. `Payer Key`
# MAGIC         where b.ECOM IS NOT NULL
# MAGIC     ) b on a.Material = b.Material
# MAGIC     WHERE a.`SOW` BETWEEN a.`Today SOW` AND (a.`Today SOW` + 139)
# MAGIC     --   AND a.payer = '172315'
# MAGIC     GROUP BY a.Material
# MAGIC ),
# MAGIC 
# MAGIC avg_fc AS (
# MAGIC     SELECT 
# MAGIC         AVG(fc_sales_units) AS avg_fc_sales_units
# MAGIC     FROM material_fc
# MAGIC ),
# MAGIC 
# MAGIC storage_base AS (
# MAGIC     SELECT
# MAGIC         P.Material,
# MAGIC         P.`Cont_Qty` / 2.0             AS half_container_units,
# MAGIC         P.`Specs.Carton - Volume`      AS carton_volume_ft3,
# MAGIC         COALESCE(
# MAGIC             a.fc_sales_units,
# MAGIC             b.avg_fc_sales_units
# MAGIC         ) AS fc_sales_units
# MAGIC     FROM `DIM Product` P
# MAGIC     LEFT JOIN material_fc a ON P.Material = a.Material
# MAGIC     CROSS JOIN avg_fc b
# MAGIC ),
# MAGIC 
# MAGIC storage_drivers AS (
# MAGIC     SELECT
# MAGIC         Material,
# MAGIC         half_container_units,
# MAGIC         carton_volume_ft3,
# MAGIC 
# MAGIC         140.0 AS fc_sales_days,
# MAGIC 
# MAGIC         fc_sales_units,
# MAGIC         fc_sales_units / 140.0 AS fc_ADS, 
# MAGIC 
# MAGIC         half_container_units / NULLIF(fc_sales_units / 140.0, 0) AS half_container_DOS,
# MAGIC 
# MAGIC         (0.35 / 30.4167) * carton_volume_ft3 AS daily_storage_rate
# MAGIC     FROM storage_base
# MAGIC ),
# MAGIC 
# MAGIC storage_costs AS (
# MAGIC     SELECT
# MAGIC         *,
# MAGIC         0.5 * half_container_DOS * half_container_units * daily_storage_rate AS total_storage_cost
# MAGIC     FROM storage_drivers
# MAGIC ),
# MAGIC 
# MAGIC final_storage_costs AS (
# MAGIC     SELECT
# MAGIC         Material,
# MAGIC         half_container_units,
# MAGIC         carton_volume_ft3,
# MAGIC         fc_sales_days,
# MAGIC 
# MAGIC         daily_storage_rate,
# MAGIC 
# MAGIC         fc_sales_units,
# MAGIC         fc_ADS,
# MAGIC         half_container_DOS,
# MAGIC 
# MAGIC         total_storage_cost,
# MAGIC 
# MAGIC         total_storage_cost / NULLIF(half_container_units, 0) AS total_storage_cost_per_unit
# MAGIC     FROM storage_costs
# MAGIC ),
# MAGIC 
# MAGIC -- CJ - 06-11-2026.1 end
# MAGIC 
# MAGIC final AS (
# MAGIC     SELECT
# MAGIC         o.*,
# MAGIC         -- CJ - 05-14-2026.1
# MAGIC         CASE
# MAGIC             WHEN shipping_point_key = '4674 - 06' THEN 
# MAGIC                 CASE
# MAGIC                     WHEN s.pc_business_unit = 'GF NA' THEN 181.21
# MAGIC                     WHEN s.pc_business_unit = 'Tools' THEN 108.21
# MAGIC                     WHEN s.pc_business_unit = 'F & P EU' THEN 75.99
# MAGIC                     WHEN s.pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62
# MAGIC                     WHEN s.pc_business_unit = 'Sheds & Buildings' THEN 68.97
# MAGIC                     WHEN s.pc_business_unit = 'Deck Boxes' THEN 87.41
# MAGIC                     WHEN s.pc_business_unit = 'Packout' THEN 117.22
# MAGIC                     WHEN s.pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
# MAGIC                     ELSE NULL
# MAGIC                 END
# MAGIC             WHEN shipping_point_key = '367G - 06' THEN
# MAGIC                 450.0 + --ContainerReceipt
# MAGIC                 2.50 + --Order Processing
# MAGIC                 CASE
# MAGIC                     WHEN s.ltl_parcel = 'LTL' THEN 
# MAGIC                         6.75 + --handling/picking of sheds
# MAGIC                         6.50 -- strapping
# MAGIC                     ELSE
# MAGIC                         0.75 --handling/picking for parcel
# MAGIC                 END
# MAGIC             ELSE NULL
# MAGIC         END AS YR60,
# MAGIC 
# MAGIC         CASE
# MAGIC             WHEN shipping_point_key = '4674 - 06' THEN 
# MAGIC                 CASE
# MAGIC                     WHEN s.pc_business_unit = 'GF NA' THEN 181.21/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'Tools' THEN 108.21/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'F & P EU' THEN 75.99/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'Sheds & Buildings' THEN 68.97/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'Deck Boxes' THEN 87.41/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit = 'Packout' THEN 117.22/nullif(s.ss_plt_qty, 0)
# MAGIC                     WHEN s.pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89/nullif(s.ss_plt_qty, 0)
# MAGIC                     ELSE NULL
# MAGIC                 END
# MAGIC             WHEN shipping_point_key = '367G - 06' THEN
# MAGIC                 450.0/ NULLIF(s.cont_qty, 0) + --ContainerReceipt
# MAGIC                 2.50 + --Order Processing
# MAGIC                 CASE
# MAGIC                     WHEN s.ltl_parcel = 'LTL' THEN 
# MAGIC                         6.75 + --handling/picking of sheds
# MAGIC                         6.50 -- strapping
# MAGIC                     ELSE
# MAGIC                         0.75 --handling/picking for parcel
# MAGIC                 END
# MAGIC             ELSE NULL
# MAGIC         END AS YR60_ea_cost,
# MAGIC 
# MAGIC         s.model,
# MAGIC         s.material,
# MAGIC         s.pc_business_unit, -- CJ - 05-14-2026.1
# MAGIC         s.carton_len,
# MAGIC         s.carton_width,
# MAGIC         s.carton_height,
# MAGIC         s.carton_weight,
# MAGIC         s.carton_volume_ft3,
# MAGIC         s.ltl_parcel,
# MAGIC         s.cont_qty,
# MAGIC         s.tl_qty,
# MAGIC         s.stacked_cont_tl,
# MAGIC         s.ss_plt_qty,
# MAGIC 
# MAGIC         z.dest_zip_clean,
# MAGIC         z.destination_zip,
# MAGIC         z.region,
# MAGIC         z.city_list,
# MAGIC         z.distance,
# MAGIC         -- CJ - 07-08-2026.1
# MAGIC         z.alt_region,
# MAGIC         b.`Avg Delivery Time` as est_delv_time,
# MAGIC         
# MAGIC         s.COGS,
# MAGIC 
# MAGIC         ( ( (s.carton_len * s.carton_width) / POW(12.0,2) ) * 0.83 * (s.ss_plt_qty - coalesce(s.pallet_present, 0) ) / (NULLIF(s.ss_plt_qty, 0)) ) as pallet_cost,
# MAGIC 
# MAGIC         (349.0840712 * (4653/5106)) -- CJ - 07-17-2026.1
# MAGIC             + (0.000234524 * (s.billable_weight * z.distance) ) AS ltl_base_cost,
# MAGIC 
# MAGIC         -- CJ - 06-11-2026.1
# MAGIC         t.half_container_units,
# MAGIC         t.fc_sales_days,
# MAGIC         t.daily_storage_rate,
# MAGIC         t.fc_sales_units,
# MAGIC         t.fc_ADS,
# MAGIC         t.half_container_DOS,
# MAGIC         t.total_storage_cost,
# MAGIC         t.total_storage_cost_per_unit
# MAGIC 
# MAGIC     FROM sku s
# MAGIC     JOIN origins o
# MAGIC     JOIN zip_distances z ON z.ship_point = o.shipping_point_desc
# MAGIC     LEFT JOIN final_storage_costs t on s.material = t.Material and shipping_point_key in ('367G - 06') -- CJ - 06-11-2026.1
# MAGIC     -- CJ - 07-08-2026.1
# MAGIC     left join `DIM LTL State to State` b on o.origin_state = b.`Origin State`
# MAGIC         and z.alt_region = b.`Destination State`
# MAGIC )
# MAGIC 
# MAGIC SELECT * FROM final
# MAGIC -- WHERE material in ('255122')
# MAGIC --     and destination_zip in ('30305')
# MAGIC ;

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
