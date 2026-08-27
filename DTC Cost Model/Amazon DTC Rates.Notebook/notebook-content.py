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
# META     },
# META     "warehouse": {
# META       "known_warehouses": []
# META     }
# META   }
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC -- Change Log
# MAGIC -- CJ - 07-07-2026.1: add distance; update IB logic based on shortest distance
# MAGIC -- CJ - 06-12-2026.1: update total storage cost per unit calculation based on 30 DOS (remove 90 day storage rate calculation)
# MAGIC -- CJ - 06-08-2026.1: add 90 day storage rate back in
# MAGIC -- CJ - 06-05-2026.1: convert 90 day storage costs to daily storage costs
# MAGIC -- CJ - 05-28-2026.1: don't include IB costs in net fulfillment fees (include in total at the end)
# MAGIC -- CJ - 05-27-2026.1: update how IB costs are pulled to align with Walmart
# MAGIC -- CJ - 05-21-2026.3: add 90 day storage costs
# MAGIC -- CJ - 05-21-2026.2: update pallet costs to only apply to LTL
# MAGIC -- CJ - 05-21-2026.1: remove pallet cost from net fulfillment cost (added back in during combind stage in DTC Rates)

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC 
# MAGIC CREATE OR REPLACE TABLE fact_amazon_dtc_rates
# MAGIC USING DELTA
# MAGIC AS
# MAGIC 
# MAGIC with 
# MAGIC sku AS (
# MAGIC     SELECT
# MAGIC         CAST(P.Material AS STRING) AS material,
# MAGIC         P.`Specs.Carton - Volume`  AS carton_volume_ft3,  
# MAGIC         P.`Specs.Carton - Length`  AS carton_len,  
# MAGIC         P.`Specs.Carton - Width`   AS carton_width,  
# MAGIC         P.`Specs.Carton - Height`  AS carton_height,
# MAGIC         P.`Specs.Carton - Weight`  AS carton_weight_lb,
# MAGIC         ceil(P.`Specs.Carton - Weight` * 16 ) as carton_weight_oz,
# MAGIC         (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139 as dim_weight_lb,
# MAGIC         ceil( ( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139)  * 16 ) as dim_weight_oz,
# MAGIC         GREATEST( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139, P.`Specs.Carton - Weight` ) as shipping_weight_lb,
# MAGIC         GREATEST( ceil(P.`Specs.Carton - Weight` * 16 ),  ceil( ( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139)  * 16 ) ) as shipping_weight_oz,
# MAGIC 
# MAGIC         GREATEST( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) AS max_dim,
# MAGIC         LEAST   ( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) AS small_dim,
# MAGIC         ROUND(
# MAGIC             (P.`Specs.Carton - Length` + P.`Specs.Carton - Width` + P.`Specs.Carton - Height`)
# MAGIC                 - GREATEST( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` )
# MAGIC                 - LEAST   ( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) ,
# MAGIC             2
# MAGIC         ) AS med_dim,
# MAGIC         P.`Length & Girth` as length_girth,
# MAGIC         P.`Cont_Qty`                                              AS cont_qty,
# MAGIC         P.`TL Qty`                                                AS tl_qty,
# MAGIC         P.LTL_Parcel                                              AS ltl_parcel,
# MAGIC         case when P.LTL_Parcel = 'Parcel' then '07' else '06' end AS shipping_point_type,
# MAGIC         Z.COGS                                                    AS cogs,
# MAGIC         P.`Model`                                                 AS model,
# MAGIC         P.`SS/PLT_Qty`                                            AS ss_plt_qty,
# MAGIC         P.`Stacked_Cont/TL`                                       AS stacked_cont_tl,
# MAGIC         IF(upper(`Stacked_Cont/TL`) like ('%P%'), 1, 0)           AS pallet_present,
# MAGIC 
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
# MAGIC     -- WHERE ltl_parcel in ('Parcel')
# MAGIC )
# MAGIC 
# MAGIC ,sku_category as (
# MAGIC     select *,
# MAGIC         CASE
# MAGIC             -- Product size tier
# MAGIC             WHEN shipping_weight_oz <= 16 AND max_dim <= 15 AND med_dim <= 12 AND small_dim <= 0.75 THEN 'Small standard'
# MAGIC             WHEN shipping_weight_lb <= 20 AND max_dim <= 18 AND med_dim <= 14 AND small_dim <= 8 THEN 'Large standard'
# MAGIC             WHEN shipping_weight_lb <= 50 AND max_dim <= 37 AND med_dim <= 28 AND small_dim <= 20 AND length_girth <= 130 THEN 'Small bulky'
# MAGIC             WHEN shipping_weight_lb <= 50 AND max_dim <= 59 AND med_dim <= 33 AND small_dim <= 33 AND length_girth <= 130 THEN 'Large bulky'
# MAGIC             WHEN (max_dim > 59 OR med_dim > 33 OR small_dim > 33 OR length_girth > 130 OR shipping_weight_lb > 50 ) THEN
# MAGIC                 CASE
# MAGIC                     WHEN shipping_weight_lb <= 50 THEN 'Extra large: Up to 50 lbs'
# MAGIC                     WHEN shipping_weight_lb > 50 AND shipping_weight_lb <= 70 THEN 'Extra large: 50+ to 70 lbs'
# MAGIC                     WHEN shipping_weight_lb > 70 AND shipping_weight_lb <= 150 THEN 'Extra large: 70+ to 150 lbs'
# MAGIC                     WHEN shipping_weight_lb > 150 THEN 'Extra large: 150+ lbs'
# MAGIC                 END                    
# MAGIC         END AS sku_category,
# MAGIC 
# MAGIC         CASE WHEN shipping_weight_lb <= 150 AND (max_dim > 96 OR length_girth > 130) THEN TRUE ELSE FALSE END AS overmax_flag
# MAGIC 
# MAGIC     from sku
# MAGIC )
# MAGIC 
# MAGIC -- CJ - 06-12-2026.1 BEGIN
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
# MAGIC         and b.sku_category is not null
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
# MAGIC             when sku_category in ('Small standard', 'Large standard') then (1.19 / 30.4167) * carton_volume_ft3
# MAGIC             else (0.77 / 30.4167) * carton_volume_ft3
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
# MAGIC -- CJ - 06-12-2026.1 END
# MAGIC 
# MAGIC ,rates as (
# MAGIC     select a.*,
# MAGIC         CASE
# MAGIC             WHEN a.sku_category = 'Small standard' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.carton_weight_oz <= 4 THEN 7.34
# MAGIC                     WHEN a.carton_weight_oz > 4 AND a.carton_weight_oz <= 8 THEN 7.51
# MAGIC                     WHEN a.carton_weight_oz > 8 AND a.carton_weight_oz <= 12 THEN 8.17
# MAGIC                     WHEN a.carton_weight_oz > 12 AND a.carton_weight_oz <= 16 THEN 8.66
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Large standard' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_oz <= 4 THEN 7.56
# MAGIC                     WHEN a.shipping_weight_oz > 4 AND a.shipping_weight_oz <= 8 THEN 7.72
# MAGIC                     WHEN a.shipping_weight_oz > 8 AND a.shipping_weight_oz <= 12 THEN 8.61
# MAGIC                     WHEN a.shipping_weight_oz > 12 AND a.shipping_weight_oz <= 16 THEN 8.93
# MAGIC 
# MAGIC                     WHEN a.shipping_weight_lb > 1 AND a.shipping_weight_lb <= 2 THEN 10.64
# MAGIC                     WHEN a.shipping_weight_lb > 2 AND a.shipping_weight_lb <= 3 THEN 11.75
# MAGIC                     WHEN a.shipping_weight_lb > 3 AND a.shipping_weight_lb <= 20 THEN 11.75 + (0.7 * greatest((a.shipping_weight_lb - 3), 0) )
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Small bulky' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_lb <= 30 THEN 18.08 + (0.75 * greatest( (a.shipping_weight_lb - 2), 0) )
# MAGIC                     WHEN a.shipping_weight_lb > 30 THEN 39.13 + (0.75 * greatest((a.shipping_weight_lb - 30), 0) )
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Large bulky' THEN 
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_lb <= 30 THEN 18.43 + (0.77 * greatest((a.shipping_weight_lb - 2), 0) )
# MAGIC                     WHEN a.shipping_weight_lb > 30 THEN 39.89 + (0.77 * greatest((a.shipping_weight_lb - 30), 0) )
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Extra large: Up to 50 lbs' THEN 32.17 + (0.62 * greatest((a.shipping_weight_lb - 1), 0) )
# MAGIC             WHEN a.sku_category = 'Extra large: 50+ to 70 lbs' THEN 62.64 + (1.01 * greatest((a.shipping_weight_lb - 51),0) )
# MAGIC             WHEN a.sku_category = 'Extra large: 70+ to 150 lbs' THEN 84.66 + (1.41 * greatest((a.shipping_weight_lb - 71), 0) )
# MAGIC             WHEN a.sku_category = 'Extra large: 150+ lbs' THEN 253.97 + (1.69 * greatest((carton_weight_lb - 151), 0) )
# MAGIC         END AS pick_pack_ship_fees,
# MAGIC 
# MAGIC         CASE
# MAGIC             WHEN a.sku_category = 'Small standard' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.carton_weight_oz <= 8 THEN (0.14 + 0.32 ) / 2
# MAGIC                     WHEN a.carton_weight_oz > 8 AND a.carton_weight_oz <= 16 THEN (0.24 + 0.50 ) / 2
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Large standard' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_oz <= 12 THEN (0.20 + 0.40) / 2
# MAGIC                     WHEN a.shipping_weight_oz > 12 AND a.shipping_weight_lb <= 1.5 THEN (0.24 + 0.50) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 1.5 AND a.shipping_weight_lb <= 3 THEN (0.34 + 0.60) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 3 AND a.shipping_weight_lb <= 5 THEN (0.38 + 0.76) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 5 AND a.shipping_weight_lb <= 7 THEN (0.40 + 0.98) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 7 AND a.shipping_weight_lb <= 10 THEN (0.42 + 1.20) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 10 AND a.shipping_weight_lb <= 15 THEN (0.44 + 1.50) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 15 AND a.shipping_weight_lb <= 20 THEN (0.55 + 1.90) / 2
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Small bulky' THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_lb <= 5 THEN (1.10 + 1.60) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 5 AND a.shipping_weight_lb <= 12 THEN (1.75 + 2.40) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 12 AND a.shipping_weight_lb <= 28 THEN (2.74 + 3.50) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 28 AND a.shipping_weight_lb <= 42 THEN (3.95 + 4.95) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 42 AND a.shipping_weight_lb <= 50 THEN (4.80 + 5.95) / 2
# MAGIC                 END
# MAGIC             WHEN a.sku_category = 'Large bulky' THEN 
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_lb <= 5 THEN (1.30 + 1.80) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 5 AND a.shipping_weight_lb <= 12 THEN (2.10 + 2.90) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 12 AND a.shipping_weight_lb <= 28 THEN (3.40 + 4.10) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 28 AND a.shipping_weight_lb <= 42 THEN (4.70 + 5.60) / 2
# MAGIC                     WHEN a.shipping_weight_lb > 42 AND a.shipping_weight_lb <= 50 THEN (5.50 + 6.50) / 2
# MAGIC                 END
# MAGIC             WHEN a.sku_category LIKE ('Extra large%') THEN 0
# MAGIC             ELSE NULL
# MAGIC         END AS placement_fee,
# MAGIC 
# MAGIC         CASE 
# MAGIC             WHEN a.overmax_flag THEN
# MAGIC                 CASE
# MAGIC                     WHEN a.shipping_weight_lb <= 50 THEN 17
# MAGIC                     WHEN a.shipping_weight_lb > 50 AND a.shipping_weight_lb <= 70 THEN 21
# MAGIC                     WHEN a.shipping_weight_lb > 70 AND a.shipping_weight_lb <= 150 THEN 25
# MAGIC                     ELSE 0
# MAGIC                 END
# MAGIC             ELSE 0
# MAGIC         END AS overmax_handling_fee,
# MAGIC 
# MAGIC         -- CJ - 05-21-2026.2
# MAGIC         CASE
# MAGIC             WHEN a.ltl_parcel = 'LTL' THEN
# MAGIC                 ( ( (a.carton_len * a.carton_width) / POW(12.0,2) ) * 0.83 * (a.ss_plt_qty - a.pallet_present) / (a.ss_plt_qty) )
# MAGIC             ELSE 0
# MAGIC         END as pallet_cost,
# MAGIC 
# MAGIC         -- 05-21-2026.3
# MAGIC         -- CASE WHEN a.sku_category LIKE ('%standard%') THEN ( 0.0390 * carton_volume_ft3) ELSE ( 0.0253  * carton_volume_ft3) END AS base_daily_storage_rate -- CJ - 06-05-2026.1
# MAGIC 
# MAGIC         -- CJ - 06-12-2026.1
# MAGIC         b.fc_sales_days,
# MAGIC         b.avg_DOS,
# MAGIC         b.fc_sales_units,
# MAGIC         b.fc_ADS,
# MAGIC         b.avg_inventory,
# MAGIC         b.total_storage_cost,
# MAGIC         b.total_storage_cost_per_unit
# MAGIC 
# MAGIC     from sku_category a
# MAGIC     -- CJ - 06-12-2026.1
# MAGIC     left join storage_final b on a.material = b.Material
# MAGIC )
# MAGIC 
# MAGIC ,zip as (
# MAGIC     select 
# MAGIC         a.*
# MAGIC         -- CJ - 07-07-2026.1
# MAGIC         -- ,c.shipping_point
# MAGIC         ,case when `Distance from DHL` <= `Distance from Rancho` then '4674' else '367G' end as shipping_point
# MAGIC 
# MAGIC         ,c.IB_TL_Cost
# MAGIC         ,c.IB_TL_Cost/a.tl_qty as IB_ea_cost
# MAGIC         ,(pick_pack_ship_fees * 0.035) as fuel_logistics_surcharge
# MAGIC         -- ,coalesce(c.IB_TL_Cost/a.tl_qty,0) + -- CJ - 05-28-2026.1
# MAGIC             ,coalesce(pick_pack_ship_fees, 0) + (coalesce(pick_pack_ship_fees, 0) * 0.035) + coalesce(placement_fee, 0) + coalesce(overmax_handling_fee, 0) 
# MAGIC             -- + coalesce(pallet_cost, 0) -- CJ - 05-21-2026.1
# MAGIC         as net_fulfillment_cost
# MAGIC         ,b.POSTAL_CODE as destination_zip
# MAGIC         ,b.`Postal Code Clean` as dest_zip_clean
# MAGIC         ,b.REGION as state
# MAGIC         ,b.`City List` as city
# MAGIC         ,b.`DAT US Region` as dat_region
# MAGIC 
# MAGIC         -- CJ - 07-07-2026.1
# MAGIC         ,case when `Distance from DHL` <= `Distance from Rancho` then `Distance from DHL` else `Distance from Rancho` end as distance
# MAGIC                 
# MAGIC     from rates a
# MAGIC     cross join `dbo`.`DIM USA CA Zips` b
# MAGIC     left join (
# MAGIC         -- CJ - 05-27-2026.1
# MAGIC         -- with base as (
# MAGIC         --     select
# MAGIC         --         a.`DAT US Region` as DAT_Region
# MAGIC         --         ,avg(a.`DHL TL Cost`) as DHL_TL_Cost
# MAGIC         --         ,avg(a.`Rancho TL Cost`) as Rancho_TL_Cost
# MAGIC         --     from `DIM USA CA Zips` a
# MAGIC         --     group by 1
# MAGIC         -- )
# MAGIC 
# MAGIC         -- select 
# MAGIC         --     a.DAT_Region
# MAGIC         --     ,case when a.DHL_TL_Cost <= a.Rancho_TL_Cost then '4674' else '367G' end as shipping_point
# MAGIC         --     ,case when a.DHL_TL_Cost <= a.Rancho_TL_Cost then a.DHL_TL_Cost else a.Rancho_TL_Cost end as IB_TL_Cost
# MAGIC         -- from base a
# MAGIC         -- CJ - 07-07-2026.1
# MAGIC         SELECT
# MAGIC             a.`DAT US Region` AS DAT_Region,
# MAGIC             AVG(
# MAGIC                 CASE
# MAGIC                     WHEN a.`Distance from DHL` <= a.`Distance from Rancho`
# MAGIC                         THEN a.`DHL TL Cost`
# MAGIC                     ELSE a.`Rancho TL Cost`
# MAGIC                 END
# MAGIC             ) AS IB_TL_Cost
# MAGIC         FROM `DIM USA CA Zips` a
# MAGIC         GROUP BY a.`DAT US Region`
# MAGIC     ) c on b.`DAT US Region` = c.DAT_Region
# MAGIC     where b.`Postal Code Country` = 'USA'
# MAGIC         and sku_category is not null
# MAGIC )
# MAGIC 
# MAGIC select 
# MAGIC     a.material
# MAGIC     ,a.pc_business_unit
# MAGIC     ,a.carton_volume_ft3
# MAGIC     -- ,a.carton_len
# MAGIC     -- ,a.carton_width
# MAGIC     -- ,a.carton_height
# MAGIC     ,a.carton_weight_lb
# MAGIC     ,a.carton_weight_oz
# MAGIC     ,a.dim_weight_lb
# MAGIC     ,a.dim_weight_oz
# MAGIC     ,a.shipping_weight_lb
# MAGIC     ,a.shipping_weight_oz
# MAGIC     ,a.max_dim
# MAGIC     ,a.small_dim
# MAGIC     ,a.med_dim
# MAGIC     ,a.length_girth
# MAGIC     ,a.cont_qty
# MAGIC     ,a.tl_qty
# MAGIC     ,a.ltl_parcel
# MAGIC     -- ,a.shipping_point_type
# MAGIC     ,a.cogs
# MAGIC     ,a.model
# MAGIC     ,a.ss_plt_qty
# MAGIC     ,a.stacked_cont_tl
# MAGIC     ,a.pallet_present
# MAGIC 
# MAGIC     ,a.sku_category
# MAGIC     ,a.overmax_flag
# MAGIC 
# MAGIC     ,b.Port
# MAGIC     ,'699-AMZN' as shipping_point
# MAGIC     ,'Amazon' as shipping_point_desc
# MAGIC     ,b.shipping_point_type
# MAGIC     ,b.shipping_point_type_desc
# MAGIC     ,b.shipping_point_zip
# MAGIC     ,b.YR50
# MAGIC     ,b.YR73
# MAGIC     ,b.YR51
# MAGIC     ,b.YR53
# MAGIC     ,CASE
# MAGIC         WHEN a.shipping_point = '4674' THEN 
# MAGIC             CASE
# MAGIC                 WHEN a.pc_business_unit = 'GF NA' THEN 181.21
# MAGIC                 WHEN a.pc_business_unit = 'Tools' THEN 108.21
# MAGIC                 WHEN a.pc_business_unit = 'F & P EU' THEN 75.99
# MAGIC                 WHEN a.pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62
# MAGIC                 WHEN a.pc_business_unit = 'Sheds & Buildings' THEN 68.97
# MAGIC                 WHEN a.pc_business_unit = 'Deck Boxes' THEN 87.41
# MAGIC                 WHEN a.pc_business_unit = 'Packout' THEN 117.22
# MAGIC                 WHEN a.pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
# MAGIC                 ELSE NULL
# MAGIC             END
# MAGIC         WHEN a.shipping_point = '367G' THEN
# MAGIC             450.0 + --ContainerReceipt
# MAGIC             2.50 + --Order Processing
# MAGIC             CASE
# MAGIC                 WHEN a.ltl_parcel = 'LTL' THEN 
# MAGIC                     6.75 + --handling/picking of sheds
# MAGIC                     6.50 -- strapping
# MAGIC                 ELSE
# MAGIC                     0.75 --handling/picking for parcel
# MAGIC             END
# MAGIC         ELSE NULL
# MAGIC     END AS YR60
# MAGIC 
# MAGIC     ,b.YR50/a.cont_qty as YR50_ea_cost
# MAGIC     ,b.YR73/a.cont_qty as YR73_ea_cost
# MAGIC     ,b.YR51/a.cont_qty as YR51_ea_cost
# MAGIC     ,b.YR53/a.cont_qty as YR53_ea_cost
# MAGIC     ,CASE
# MAGIC         WHEN a.shipping_point = '4674' THEN
# MAGIC             CASE
# MAGIC                 WHEN a.pc_business_unit = 'GF NA' THEN 181.21/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'Tools' THEN 108.21/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'F & P EU' THEN 75.99/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'Cabinets & Shelving EU' THEN 74.62/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'Sheds & Buildings' THEN 68.97/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'Deck Boxes' THEN 87.41/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit = 'Packout' THEN 117.22/nullif(a.ss_plt_qty, 0)
# MAGIC                 WHEN a.pc_business_unit IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89/nullif(a.ss_plt_qty, 0)
# MAGIC                 ELSE NULL
# MAGIC             END
# MAGIC         WHEN shipping_point_key = '367G - 06' THEN
# MAGIC             450.0/ NULLIF(a.cont_qty, 0) + --ContainerReceipt
# MAGIC             2.50 + --Order Processing
# MAGIC             CASE
# MAGIC                 WHEN a.ltl_parcel = 'LTL' THEN 
# MAGIC                     6.75 + --handling/picking of sheds
# MAGIC                     6.50 -- strapping
# MAGIC                 ELSE
# MAGIC                     0.75 --handling/picking for parcel
# MAGIC             END
# MAGIC         ELSE NULL
# MAGIC     END AS YR60_ea_cost
# MAGIC 
# MAGIC     ,concat('Amazon', ' - ', b.shipping_point_type_desc) as shipping_point_key_desc
# MAGIC     ,concat('699-AMZN', ' - ', b.shipping_point_type ) as shipping_point_key
# MAGIC 
# MAGIC     ,a.IB_TL_Cost
# MAGIC     ,a.IB_ea_cost
# MAGIC 
# MAGIC     ,a.pick_pack_ship_fees
# MAGIC     ,a.placement_fee
# MAGIC     ,a.overmax_handling_fee
# MAGIC     ,a.pallet_cost
# MAGIC     -- CJ - 06-12-2026.1
# MAGIC     -- ,a.base_daily_storage_rate -- 05-21-2026.3; -- CJ - 06-05-2026.1
# MAGIC     -- ,a.base_daily_storage_rate * 90 as base_90_day_storage_rate -- CJ - 06-08-2026.1
# MAGIC     ,a.fc_sales_days
# MAGIC     ,a.avg_DOS
# MAGIC     ,a.fc_sales_units
# MAGIC     ,a.fc_ADS
# MAGIC     ,a.avg_inventory
# MAGIC     ,a.total_storage_cost
# MAGIC     ,a.total_storage_cost_per_unit
# MAGIC 
# MAGIC     ,a.shipping_point as shipping_point_origin
# MAGIC     ,a.fuel_logistics_surcharge
# MAGIC     ,a.net_fulfillment_cost
# MAGIC     ,a.destination_zip
# MAGIC     ,a.dest_zip_clean
# MAGIC     ,a.state
# MAGIC     ,a.city
# MAGIC     ,a.dat_region
# MAGIC 
# MAGIC     -- CJ - 07-07-2026.1
# MAGIC     ,a.distance
# MAGIC from zip a
# MAGIC inner join `DIM DTC Ship Point Key` b
# MAGIC     on a.shipping_point = b.shipping_point
# MAGIC     and a.shipping_point_type = b.shipping_point_type
# MAGIC -- where material in ('259417')
# MAGIC --     and destination_zip in ('30305', '90065') 
# MAGIC ;

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }
