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
# MAGIC -- CJ - 07-07-2026.3: update YR60 to either be DHL or Rancho
# MAGIC -- CJ - 07-07-2026.2: add distance (based on Rancho or DHL)
# MAGIC -- CJ - 07-07-2026.1: update positioning fee to be based on actual final zip destination
# MAGIC -- CJ - 06-11-2026.1: add daily storage rates based on 30 DOS
# MAGIC -- CJ - 06-05-2026.1: add daily storage rates (based on dwell days)
# MAGIC -- CJ - 06-04-2026.1: factor in dim weight for multichannel eligibility
# MAGIC -- CJ - 05-28-2026.1: don't include IB costs in net fulfillment fees (include in total at the end)
# MAGIC -- CJ - 05-14-2026.1: added YR60 (DHL Warehouse costs)

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC CREATE OR REPLACE TABLE fact_castlegate_dtc_rates
# MAGIC USING DELTA
# MAGIC AS
# MAGIC 
# MAGIC with
# MAGIC origin as (
# MAGIC     select *
# MAGIC     from `DIM DTC Ship Point Key`
# MAGIC     where shipping_point_key = '699 - 07'
# MAGIC )
# MAGIC ,sku AS (
# MAGIC     SELECT
# MAGIC         CAST(P.Material AS STRING) AS material,
# MAGIC         P.`Specs.Carton - Volume`  AS carton_volume_ft3,  
# MAGIC         P.`Specs.Carton - Length`  AS carton_len,  
# MAGIC         P.`Specs.Carton - Width`   AS carton_width,  
# MAGIC         P.`Specs.Carton - Height`  AS carton_height,
# MAGIC         P.`Specs.Carton - Weight`  AS carton_weight,
# MAGIC         (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139 as dim_weight, -- CJ - 06-04-2026.1
# MAGIC         GREATEST( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS max_dim,
# MAGIC         LEAST   ( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS small_dim,
# MAGIC         ceil(P.`Specs.Carton - Length`) + ceil(P.`Specs.Carton - Width`) + ceil(P.`Specs.Carton - Height`) 
# MAGIC             - GREATEST( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) )
# MAGIC             - LEAST   ( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS med_dim,
# MAGIC         P.`Length & Girth` as length_girth,
# MAGIC         P.`Cont_Qty`                                      AS cont_qty,
# MAGIC         P.`TL Qty`                                        AS tl_qty,
# MAGIC         P.LTL_Parcel                                      AS ltl_parcel,
# MAGIC         Z.COGS                                            AS cogs,
# MAGIC         P.`Model`                                         AS model,
# MAGIC         P.`SS/PLT_Qty`                                    AS ss_plt_qty,
# MAGIC         P.`Stacked_Cont/TL`                               AS stacked_cont_tl,
# MAGIC         IF(upper(`Stacked_Cont/TL`) like ('%P%'), 1, 0)   AS pallet_present,
# MAGIC         -- CJ - 05-14-2026.1
# MAGIC         P.`PC Business Unit`                              AS pc_business_unit
# MAGIC 
# MAGIC         -- CJ - 07-07-2026.3
# MAGIC 
# MAGIC         -- CASE
# MAGIC         --     WHEN P.`PC Business Unit` = 'GF NA' THEN 181.21
# MAGIC         --     WHEN P.`PC Business Unit` = 'Tools' THEN 108.21
# MAGIC         --     WHEN P.`PC Business Unit` = 'F & P EU' THEN 75.99
# MAGIC         --     WHEN P.`PC Business Unit` = 'Cabinets & Shelving EU' THEN 74.62
# MAGIC         --     WHEN P.`PC Business Unit` = 'Sheds & Buildings' THEN 68.97
# MAGIC         --     WHEN P.`PC Business Unit` = 'Deck Boxes' THEN 87.41
# MAGIC         --     WHEN P.`PC Business Unit` = 'Packout' THEN 117.22
# MAGIC         --     WHEN P.`PC Business Unit` IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
# MAGIC         --     ELSE NULL
# MAGIC         -- END AS YR60
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
# MAGIC     -- WHERE ltl_parcel in ('Parcel')
# MAGIC )
# MAGIC 
# MAGIC ,sku_category as (
# MAGIC     select *,
# MAGIC         CASE
# MAGIC             -- BIN CATEGORIES
# MAGIC             -- WHEN max_dim <= 6  AND med_dim <= 6 AND small_dim <= 6 AND carton_weight <= 25 THEN 'BIN_SINGLE_PICK'
# MAGIC             WHEN max_dim <= 19 AND med_dim <= 12 AND small_dim <= 6 AND carton_weight <= 25 THEN 'BIN_SMALL'
# MAGIC             WHEN max_dim <= 26 AND med_dim <= 17 AND small_dim <= 14 AND carton_weight <= 25 THEN 'BIN_LARGE'
# MAGIC             WHEN max_dim <= 26 AND med_dim <= 17 AND small_dim <= 14 AND carton_weight BETWEEN 25 AND 50 THEN 'BIN_HEAVY'
# MAGIC             -- STANDARD CATEGORIES
# MAGIC             WHEN max_dim <= 48 AND med_dim <= 30 AND small_dim <= 30 AND length_girth <= 105 AND carton_weight <= 50 AND carton_volume_ft3 <= 6   THEN 'STANDARD_SMALL'
# MAGIC             WHEN max_dim <= 96 AND length_girth <= 130 AND carton_weight <= 110 AND carton_volume_ft3 <= 10 THEN 'STANDARD_MEDIUM'
# MAGIC             WHEN max_dim <= 108 AND length_girth <= 165 AND carton_weight <= 120 THEN 'STANDARD_LARGE'
# MAGIC             WHEN max_dim <= 108 AND length_girth <= 165 AND carton_weight <= 150 THEN 'STANDARD_OVERSIZE'
# MAGIC             -- LARGE / NON-PARCEL
# MAGIC             WHEN carton_weight < 250 THEN 'LARGE_STANDARD'
# MAGIC             WHEN max_dim <= 144 AND carton_weight BETWEEN 250 AND 800 THEN 'LARGE_HEAVY'
# MAGIC             ELSE NULL            
# MAGIC         END AS sku_category,
# MAGIC 
# MAGIC         CASE WHEN greatest(carton_weight, dim_weight) <= 150 AND max_dim <= 108 AND length_girth <= 165 THEN TRUE ELSE FALSE END AS multichannel_eligibile -- CJ - 06-04-2026.1
# MAGIC     from sku
# MAGIC )
# MAGIC 
# MAGIC -- CJ - 06-11-2026.1 BEGIN
# MAGIC ,storage_base as (
# MAGIC     select
# MAGIC         a.Material,
# MAGIC         b.carton_volume_ft3,
# MAGIC         b.sku_category,
# MAGIC         sum(-a.`Combined Qty`) as fc_sales_units
# MAGIC     from `FACT Component Forecast Initial` a
# MAGIC     left join sku_category b 
# MAGIC         on a.Material = b.material
# MAGIC     join (
# MAGIC         select distinct Material
# MAGIC         from `DIM Account` a
# MAGIC         join `DIM Customer` b 
# MAGIC             on a.Payer = b.`Payer Key`
# MAGIC         where b.ECOM is not null
# MAGIC     ) c 
# MAGIC         on a.Material = c.Material
# MAGIC     where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
# MAGIC     group by a.Material, b.carton_volume_ft3, b.sku_category
# MAGIC )
# MAGIC 
# MAGIC ,storage_calc as (
# MAGIC     select
# MAGIC         *,
# MAGIC         140 as fc_sales_days,
# MAGIC         30 as avg_DOS,
# MAGIC 
# MAGIC         -- core drivers
# MAGIC         fc_sales_units / 140.0 as fc_ADS,
# MAGIC         30 * (fc_sales_units / 140.0) as avg_inventory
# MAGIC     from storage_base
# MAGIC )
# MAGIC 
# MAGIC ,storage_rate_per_day as (
# MAGIC     select
# MAGIC         *,
# MAGIC         case
# MAGIC             when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY')
# MAGIC                 then (0.44 / 30.4167) * carton_volume_ft3
# MAGIC             else (0.35 / 30.4167) * carton_volume_ft3
# MAGIC         end as storage_rate_per_day
# MAGIC     from storage_calc
# MAGIC )
# MAGIC 
# MAGIC ,storage_final as (
# MAGIC     select
# MAGIC         Material,
# MAGIC         carton_volume_ft3,
# MAGIC         sku_category,
# MAGIC         fc_sales_days,
# MAGIC         avg_DOS,
# MAGIC 
# MAGIC         fc_sales_units,
# MAGIC         fc_ADS,
# MAGIC         avg_inventory,
# MAGIC 
# MAGIC         -- total storage cost
# MAGIC         0.5 * avg_DOS * avg_inventory * storage_rate_per_day as total_storage_cost,
# MAGIC         -- per unit cost
# MAGIC         0.5 * avg_DOS * storage_rate_per_day as total_storage_cost_per_unit
# MAGIC 
# MAGIC     from storage_rate_per_day
# MAGIC )
# MAGIC -- CJ - 06-11-2026.1 END
# MAGIC 
# MAGIC 
# MAGIC ,rates as (
# MAGIC     select a.*
# MAGIC         -- ,CASE
# MAGIC         --     WHEN sku_category = 'BIN_SINGLE_PICK' THEN 0.26
# MAGIC         --     WHEN sku_category = 'BIN_SMALL' THEN 0.45
# MAGIC         --     WHEN sku_category = 'BIN_LARGE' THEN 0.91
# MAGIC         --     WHEN sku_category = 'BIN_HEAVY' THEN 1.81
# MAGIC 
# MAGIC         --     WHEN sku_category = 'STANDARD_SMALL' THEN 3.15
# MAGIC         --     WHEN sku_category = 'STANDARD_MEDIUM' THEN 3.88
# MAGIC         --     WHEN sku_category = 'STANDARD_LARGE' THEN 4.49
# MAGIC         --     WHEN sku_category = 'STANDARD_OVERSIZE' THEN 4.80
# MAGIC 
# MAGIC         --     ELSE NULL
# MAGIC         -- END AS fulfillment_fee
# MAGIC 
# MAGIC         ,CASE
# MAGIC             WHEN a.sku_category = 'BIN_SINGLE_PICK' THEN 0.02
# MAGIC             WHEN a.sku_category = 'BIN_SMALL' THEN 0.02
# MAGIC             WHEN a.sku_category = 'BIN_LARGE' THEN 0.09
# MAGIC             WHEN a.sku_category = 'BIN_HEAVY' THEN 0.12
# MAGIC 
# MAGIC             WHEN a.sku_category = 'STANDARD_SMALL' THEN 0.33
# MAGIC             WHEN a.sku_category = 'STANDARD_MEDIUM' THEN 0.54
# MAGIC             WHEN a.sku_category = 'STANDARD_LARGE' THEN 0.77
# MAGIC             WHEN a.sku_category = 'STANDARD_OVERSIZE' THEN 0.57
# MAGIC 
# MAGIC             WHEN a.sku_category = 'LARGE_STANDARD' THEN 2.55
# MAGIC             WHEN a.sku_category = 'LARGE_HEAVY' THEN 4.96
# MAGIC 
# MAGIC             ELSE NULL
# MAGIC         END AS unload_fee
# MAGIC 
# MAGIC         ,CASE
# MAGIC             WHEN a.sku_category = 'BIN_SINGLE_PICK' THEN 12.57 + (0.15 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'BIN_SMALL' THEN 12.35 + (0.17 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'BIN_LARGE' THEN 15.10 + (0.17 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'BIN_HEAVY' THEN 15.42 + (0.17 * (ceil(carton_weight) - 1 ))
# MAGIC 
# MAGIC             WHEN a.sku_category = 'STANDARD_SMALL' THEN 17.05 + (0.20 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'STANDARD_MEDIUM' THEN 23.78 + (0.24 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'STANDARD_LARGE' THEN 49.83 + (0.31 * (ceil(carton_weight) - 1 ))
# MAGIC             WHEN a.sku_category = 'STANDARD_OVERSIZE' THEN 52.43 + (0.34 * (ceil(carton_weight) - 1 ))
# MAGIC 
# MAGIC             ELSE NULL
# MAGIC         END AS pick_ship_rate --AK/HI Rate = Pick & Ship Rate + $85 + ($4.5* lb)
# MAGIC 
# MAGIC         ,0.15 as multichannel_only_fee
# MAGIC 
# MAGIC         -- CJ - 07-07-2026.1
# MAGIC         -- ,((0.59 + 0.22) / 2.0) * a.carton_volume_ft3 AS positioning_fee -- avg of west coast hub / non-west coast hub positioning service
# MAGIC 
# MAGIC         ,(1886.11 / a.tl_qty )as freight_pickup_rate
# MAGIC 
# MAGIC         -- ,10.26 as sig_required_fee  -- CJ - 05-14-2026.1
# MAGIC 
# MAGIC         ,case
# MAGIC             when a.sku_category like ('BIN%') then 0.88
# MAGIC             WHEN a.sku_category = 'STANDARD_SMALL' THEN 1.09
# MAGIC             WHEN a.sku_category = 'STANDARD_MEDIUM' THEN 2.21
# MAGIC             WHEN a.sku_category = 'STANDARD_LARGE' THEN 8.20
# MAGIC             WHEN a.sku_category = 'STANDARD_OVERSIZE' THEN 8.20
# MAGIC         END AS peak_surcharge_rates -- US Peak Surcharges are effective on items shipped between October 20, 2026 through January 17, 2027.
# MAGIC 
# MAGIC         ,0.075 as fuel_surcharge_rate
# MAGIC 
# MAGIC         -- CJ - 06-05-2026.1
# MAGIC         -- ,case
# MAGIC         --     when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY') then (0.44 / (365/12) ) * carton_volume_ft3
# MAGIC         --     else (0.35 / (365/12) ) * carton_volume_ft3
# MAGIC         -- end as daily_storage_0_120
# MAGIC 
# MAGIC         -- ,case
# MAGIC         --     when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY') then (0.70 / (365/12) ) * carton_volume_ft3
# MAGIC         --     else (0.56 / (365/12) ) * carton_volume_ft3
# MAGIC         -- end as daily_storage_121_180
# MAGIC 
# MAGIC         -- ,case
# MAGIC         --     when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY') then (1.05 / (365/12) ) * carton_volume_ft3
# MAGIC         --     else (0.84 / (365/12) ) * carton_volume_ft3
# MAGIC         -- end as daily_storage_181_270
# MAGIC 
# MAGIC         -- ,case
# MAGIC         --     when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY') then (1.40 / (365/12) ) * carton_volume_ft3
# MAGIC         --     else (1.12 / (365/12) ) * carton_volume_ft3
# MAGIC         -- end as daily_storage_271_365
# MAGIC 
# MAGIC         -- ,case
# MAGIC         --     when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY') then (4.20 / (365/12) ) * carton_volume_ft3
# MAGIC         --     else (3.36 / (365/12) ) * carton_volume_ft3
# MAGIC         -- end as daily_storage_365_plus
# MAGIC 
# MAGIC         -- CJ - 06-11-2026.1
# MAGIC         ,b.fc_sales_days
# MAGIC         ,b.avg_DOS
# MAGIC         ,b.fc_sales_units
# MAGIC         ,b.fc_ADS
# MAGIC         ,b.avg_inventory
# MAGIC         ,b.total_storage_cost
# MAGIC         ,b.total_storage_cost_per_unit
# MAGIC 
# MAGIC     from sku_category a
# MAGIC     -- CJ - 06-11-2026.1
# MAGIC     left join storage_final b on a.material = b.Material
# MAGIC 
# MAGIC     where multichannel_eligibile
# MAGIC )
# MAGIC 
# MAGIC select 
# MAGIC     c.*
# MAGIC     ,a.*
# MAGIC     ,case when b.`Distance from DHL` <= b.`Distance from Rancho` then (a.carton_volume_ft3 * 0.22) else (a.carton_volume_ft3 * 0.59) end as positioning_fee -- CJ - 07-07-2026.1
# MAGIC     ,(
# MAGIC         -- unload_fee + -- CJ - 05-28-2026.1
# MAGIC         (
# MAGIC             case
# MAGIC                 when REGION in ('AK', 'HI') then 
# MAGIC                     (pick_ship_rate + 85 + (4.5 * ceil(carton_weight)) ) + 
# MAGIC                     ((pick_ship_rate + 85 + (4.5 * ceil(carton_weight)) ) * multichannel_only_fee ) +
# MAGIC                     ((pick_ship_rate + 85 + (4.5 * ceil(carton_weight)) ) * fuel_surcharge_rate )
# MAGIC                 else 
# MAGIC                     pick_ship_rate + 
# MAGIC                     (pick_ship_rate*multichannel_only_fee) +
# MAGIC                     (pick_ship_rate*fuel_surcharge_rate)
# MAGIC             end
# MAGIC         ) + 
# MAGIC         -- CJ - 07-07-2026.1
# MAGIC         -- positioning_fee +
# MAGIC         case when b.`Distance from DHL` <= b.`Distance from Rancho` then (a.carton_volume_ft3 * 0.22) else (a.carton_volume_ft3 * 0.59) end +
# MAGIC 
# MAGIC         -- freight_pickup_rate + -- CJ - 05-28-2026.1
# MAGIC         -- sig_required_fee + -- CJ - 05-14-2026.1
# MAGIC         peak_surcharge_rates
# MAGIC     ) as net_fulfillment_rate
# MAGIC     ,b.POSTAL_CODE as destination_zip
# MAGIC     ,b.`Postal Code Clean` as dest_zip_clean
# MAGIC     ,b.REGION as state
# MAGIC     ,b.`City List` as city
# MAGIC     -- CJ - 07-07-2026.2
# MAGIC     ,case when b.`Distance from DHL` <= b.`Distance from Rancho` then '4674' else '367G' end as shipping_point_origin
# MAGIC     ,case when b.`Distance from DHL` <= b.`Distance from Rancho` then b.`Distance from DHL` else b.`Distance from Rancho` end as distance
# MAGIC 
# MAGIC     -- CJ - 07-07-2026.3
# MAGIC     ,CASE
# MAGIC         WHEN b.`Distance from DHL` > b.`Distance from Rancho` THEN
# MAGIC             (450.0) + -- container receipt
# MAGIC             (2.50) + -- order_processing
# MAGIC             CASE
# MAGIC                 WHEN ltl_parcel = 'LTL' THEN (6.75) -- shed_picking
# MAGIC                 ELSE (0.75) -- parcel_picking
# MAGIC             END
# MAGIC         WHEN b.`Distance from DHL` <= b.`Distance from Rancho` THEN
# MAGIC             CASE
# MAGIC                 WHEN pc_business_unit = 'GF NA' THEN 181.21
# MAGIC                 WHEN pc_business_unit = 'Tools' THEN 108.21
# MAGIC                 WHEN pc_business_unit = 'F & P EU' THEN 75.99
# MAGIC                 WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62
# MAGIC                 WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97
# MAGIC                 WHEN pc_business_unit = 'Deck Boxes' THEN 87.41
# MAGIC                 WHEN pc_business_unit = 'Packout' THEN 117.22
# MAGIC                 WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
# MAGIC                 ELSE NULL
# MAGIC             END  
# MAGIC         ELSE NULL
# MAGIC     END AS YR60
# MAGIC 
# MAGIC     ,CASE
# MAGIC         WHEN b.`Distance from DHL` > b.`Distance from Rancho` THEN
# MAGIC             (450.0)/nullif(cont_qty, 0) + -- container receipt
# MAGIC             (2.50) + -- order_processing
# MAGIC             CASE
# MAGIC                 WHEN ltl_parcel = 'LTL' THEN (6.75) -- shed_picking
# MAGIC                 ELSE (0.75) -- parcel_picking
# MAGIC             END
# MAGIC         WHEN b.`Distance from DHL` <= b.`Distance from Rancho` THEN
# MAGIC             CASE
# MAGIC                 WHEN pc_business_unit = 'GF NA' THEN 181.21/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'Tools' THEN 108.21/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'F & P EU' THEN 75.99/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'Sheds & Buildings' THEN 68.97/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'Deck Boxes' THEN 87.41/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit = 'Packout' THEN 117.22/nullif(ss_plt_qty, 0)
# MAGIC                 WHEN pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89/nullif(ss_plt_qty, 0)
# MAGIC                 ELSE NULL
# MAGIC             END
# MAGIC         ELSE NULL
# MAGIC     END AS YR60_ea_cost
# MAGIC 
# MAGIC 
# MAGIC from rates a
# MAGIC cross join origin c
# MAGIC cross join `DIM USA CA Zips` b
# MAGIC where b.`Postal Code Country` = 'USA'
# MAGIC --     and a.material in ('255123')
# MAGIC --     and b.`Postal Code Clean` in ('90065', '30305')
# MAGIC -- order by material
# MAGIC ;

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }
