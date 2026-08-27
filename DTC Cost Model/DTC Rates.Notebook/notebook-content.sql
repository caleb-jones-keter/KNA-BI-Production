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

-- MAGIC %%sql
-- MAGIC -- Change Log
-- MAGIC -- CJ - 08-13-2026.1: filter out states with 0 forecast
-- MAGIC -- CJ - 08-05-2026.1: update delivery_weight to combined_qty_weight
-- MAGIC -- CJ - 08-04-2026.3: only pull for USA until we're ready to show Canada
-- MAGIC -- CJ - 08-04-2026.2: included combined_qty in fact_ecomm_material_zip_weight_matrix
-- MAGIC -- CJ - 08-04-2026.1: update allocation so sum(state_fc_qty) = fc_qty
-- MAGIC -- CJ - 07-29-2026.1: use est_delv_time instead of net_fulfillment_cost as the tie breaker
-- MAGIC -- CJ - 07-22-2026.1: bring in ship_to_us_region and manually exclude later (so we can include AK and HI in Product Cost Estimator)
-- MAGIC -- CJ - 07-17-2026.2: filter ecomm inside fact forecast earlier
-- MAGIC -- CJ - 07-17-2026.1: protect against null ordering
-- MAGIC -- CJ - 07-15-2026.1: weight by zip instead of material-zip
-- MAGIC -- CJ - 07-14-2026.1: ensure deliveries align with fact_ys10n_past
-- MAGIC -- CJ - 07-08-2026.1: add estimated delivery time
-- MAGIC -- CJ - 07-07-2026.1: add distance changes
-- MAGIC -- CJ - 06-19-2026.1: bring in reworked storage costs
-- MAGIC -- CJ - 06-18-2026.1: add total cost ranking without storage
-- MAGIC -- CJ - 06-12-2026.1: add avg_unit_storage_cost
-- MAGIC -- CJ - 06-04-2026.1: per Tanya, remove COGS from calculation
-- MAGIC -- CJ - 06-02-2026.1: add all ECOMM payers
-- MAGIC -- CJ - 05-28-2026.2: add IB costs at the end
-- MAGIC -- CJ - 05-28-2026.1: add Walmart
-- MAGIC -- CJ - 05-14-2026.1: added YR60 (DHL Warehouse costs)
-- MAGIC -- CJ - 04-27-2026.3: add LTL Rates for Rancho and DHL
-- MAGIC -- CJ - 04-27-2026.1: Add LTL / Parcel logic, include carton weight
-- MAGIC -- CJ - 04-24-2026.1: Add model, min_model_cont_qty, ss_plt_qty, stacked_cont_tl, pallet_present, max_model_cogs, act_cogs, pallet_cost

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

-- MAGIC %%sql
-- MAGIC CREATE OR REPLACE TABLE fact_dtc_rate_matrix
-- MAGIC USING DELTA
-- MAGIC AS
-- MAGIC 
-- MAGIC with base as (
-- MAGIC     select
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         YR53, -- Local Haulage NA
-- MAGIC         YR60, -- Warehouse fees -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         YR50/cont_qty as YR50_ea_cost,
-- MAGIC         YR73/cont_qty as YR73_ea_cost,
-- MAGIC         YR51/cont_qty as YR51_ea_cost,
-- MAGIC         YR53/cont_qty as YR53_ea_cost,
-- MAGIC         YR60_ea_cost, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type, -- CJ - 04-27-2026.1
-- MAGIC         cont_qty,
-- MAGIC         tl_qty,
-- MAGIC         ss_plt_qty, -- CJ - 05-14-2026.1
-- MAGIC         
-- MAGIC         fedex_ahs_category as parcel_ahs_type,
-- MAGIC         das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC         
-- MAGIC         null as IB_Trans_Cost,
-- MAGIC         base_rate as base_fulfillment_cost,
-- MAGIC         0 as pallet_cost,
-- MAGIC         COGS,
-- MAGIC         net_cost as net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- half_container_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_fedex_dtc_rates
-- MAGIC     -- CJ - 08-04-2026.3
-- MAGIC     where dest_country in ('USA')
-- MAGIC 
-- MAGIC     union all 
-- MAGIC 
-- MAGIC     select
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         (YR52+YR53) as YR53, -- Local Haulage NA/door delivery
-- MAGIC         0 as YR60, -- Warehouse fees -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         YR50/cont_qty as YR50_ea_cost,
-- MAGIC         YR73/cont_qty as YR73_ea_cost,
-- MAGIC         YR51/cont_qty as YR51_ea_cost,
-- MAGIC         (YR52+YR53)/cont_qty as YR53_ea_cost,
-- MAGIC         0 as YR60_ea_cost, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type, -- CJ - 04-27-2026.1
-- MAGIC         min_model_cont_qty as cont_qty, -- CJ - 04-24-2026.1
-- MAGIC         tl_qty as tl_qty,
-- MAGIC         ss_plt_qty, -- CJ - 05-14-2026.1
-- MAGIC         
-- MAGIC         null as parcel_ahs_type,
-- MAGIC         delivery_area_surcharge_type as das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC         
-- MAGIC         null as IB_Trans_Cost,
-- MAGIC         spreetail_base_rate as base_fulfillment_cost,
-- MAGIC         pallet_cost,
-- MAGIC         COGS,
-- MAGIC         spreetail_net_rate as net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- half_container_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_spreetail_dtc_rates
-- MAGIC 
-- MAGIC     union all
-- MAGIC 
-- MAGIC     -- CJ - 04-27-2026.3
-- MAGIC     select 
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         YR53, -- Local Haulage NA
-- MAGIC         YR60, -- Warehouse fees -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         YR50/cont_qty as YR50_ea_cost,
-- MAGIC         YR73/cont_qty as YR73_ea_cost,
-- MAGIC         YR51/cont_qty as YR51_ea_cost,
-- MAGIC         YR53/cont_qty as YR53_ea_cost,
-- MAGIC         YR60_ea_cost, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type, -- CJ - 04-27-2026.1
-- MAGIC         cont_qty,
-- MAGIC         tl_qty,
-- MAGIC         ss_plt_qty, -- CJ - 05-14-2026.1
-- MAGIC         
-- MAGIC         null as parcel_ahs_type,
-- MAGIC         null as das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC         
-- MAGIC         null as IB_Trans_Cost,
-- MAGIC         null as base_fulfillment_cost,
-- MAGIC         pallet_cost,
-- MAGIC         COGS,
-- MAGIC         ltl_base_cost as net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- half_container_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_ltl_dtc_rates
-- MAGIC 
-- MAGIC     union all
-- MAGIC 
-- MAGIC     select 
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         YR53, -- Local Haulage NA
-- MAGIC         YR60, -- DHL Warehouse fees -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         YR50/cont_qty as YR50_ea_cost,
-- MAGIC         YR73/cont_qty as YR73_ea_cost,
-- MAGIC         YR51/cont_qty as YR51_ea_cost,
-- MAGIC         YR53/cont_qty as YR53_ea_cost,
-- MAGIC         YR60_ea_cost, -- CJ - 07-07-2026.1
-- MAGIC         -- YR60/ss_plt_qty as YR60_ea_cost, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type,
-- MAGIC         cont_qty,
-- MAGIC         tl_qty,
-- MAGIC         ss_plt_qty, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         null as parcel_ahs_type,
-- MAGIC         null as das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC 
-- MAGIC         unload_fee + freight_pickup_rate as IB_Trans_Cost,
-- MAGIC         pick_ship_rate as base_fulfillment_cost,
-- MAGIC         0 as pallet_cost,
-- MAGIC         cogs as COGS,
-- MAGIC         net_fulfillment_rate as net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         2 as est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- avg_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_castlegate_dtc_rates
-- MAGIC 
-- MAGIC     union all
-- MAGIC 
-- MAGIC     select 
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         YR53, -- Local Haulage NA
-- MAGIC         YR60, -- DHL Warehouse fees
-- MAGIC 
-- MAGIC         YR50_ea_cost,
-- MAGIC         YR73_ea_cost,
-- MAGIC         YR51_ea_cost,
-- MAGIC         YR53_ea_cost,
-- MAGIC         YR60_ea_cost,
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type,
-- MAGIC         cont_qty,
-- MAGIC         tl_qty,
-- MAGIC         ss_plt_qty,
-- MAGIC 
-- MAGIC         null as parcel_ahs_type,
-- MAGIC         null as das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC 
-- MAGIC         IB_ea_cost as IB_Trans_Cost,
-- MAGIC         pick_pack_ship_fees as base_fulfillment_cost,
-- MAGIC         pallet_cost,
-- MAGIC         cogs as COGS,
-- MAGIC         net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         IF(shipping_point_type = '07', 2, 3) as est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- avg_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_amazon_dtc_rates
-- MAGIC 
-- MAGIC     union all
-- MAGIC 
-- MAGIC     -- CJ - 05-28-2026.1
-- MAGIC     select
-- MAGIC         Port as port,
-- MAGIC         shipping_point,
-- MAGIC         shipping_point_desc,
-- MAGIC         shipping_point_type,
-- MAGIC         shipping_point_type_desc,
-- MAGIC         shipping_point_zip,
-- MAGIC         shipping_point_key,
-- MAGIC         shipping_point_key_desc,
-- MAGIC         YR50, -- Local Haulage IL
-- MAGIC         YR73, -- Port Handling IL
-- MAGIC         YR51, -- Ocean Freight
-- MAGIC         YR53, -- Local Haulage NA
-- MAGIC         YR60, -- Warehouse fees -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         YR50_ea_cost,
-- MAGIC         YR73_ea_cost,
-- MAGIC         YR51_ea_cost,
-- MAGIC         YR53_ea_cost,
-- MAGIC         YR60_ea_cost, -- CJ - 05-14-2026.1
-- MAGIC 
-- MAGIC         material,
-- MAGIC         ltl_parcel as sku_ship_type, -- CJ - 04-27-2026.1
-- MAGIC         cont_qty,
-- MAGIC         tl_qty,
-- MAGIC         ss_plt_qty, -- CJ - 05-14-2026.1
-- MAGIC         
-- MAGIC         null as parcel_ahs_type,
-- MAGIC         null as das_type,
-- MAGIC         destination_zip,
-- MAGIC         dest_zip_clean,
-- MAGIC         
-- MAGIC         IB_ea_cost as IB_Trans_Cost,
-- MAGIC         fulfillment_fees as base_fulfillment_cost,
-- MAGIC         0 as pallet_cost,
-- MAGIC         cogs as COGS,
-- MAGIC         net_fulfillment_cost,
-- MAGIC 
-- MAGIC         -- CJ - 07-07-2026.1
-- MAGIC         distance,
-- MAGIC         -- CJ - 07-08-2026.1
-- MAGIC         2 as est_delv_time
-- MAGIC 
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         -- CJ - 06-19-2026.1
-- MAGIC         -- fc_ADS as ADS,
-- MAGIC         -- avg_DOS as avg_DOS,
-- MAGIC         -- total_storage_cost_per_unit as avg_unit_storage_cost
-- MAGIC 
-- MAGIC     from fact_walmart_dtc_rates
-- MAGIC )
-- MAGIC 
-- MAGIC select 
-- MAGIC     a.*,
-- MAGIC     -- CJ - 06-19-2026.1
-- MAGIC     b.fc_sales_days,
-- MAGIC     b.avg_DOS,
-- MAGIC     b.fc_sales_units,
-- MAGIC     b.fc_ADS as ADS,
-- MAGIC     b.total_storage_cost,
-- MAGIC     b.total_storage_cost_per_unit as avg_unit_storage_cost,
-- MAGIC 
-- MAGIC     a.net_fulfillment_cost 
-- MAGIC         + coalesce(YR50_ea_cost, 0) + coalesce(YR73_ea_cost, 0) + coalesce(YR51_ea_cost, 0) + coalesce(YR53_ea_cost, 0)
-- MAGIC         + coalesce(YR60_ea_cost, 0)
-- MAGIC         + coalesce(IB_Trans_Cost, 0) -- CJ - 05-28-2026.2
-- MAGIC         + coalesce(pallet_cost, 0)
-- MAGIC         -- + coalesce(COGS, 0) -- CJ - 06-04-2026.1
-- MAGIC         -- CJ - 06-12-2026.1
-- MAGIC         + coalesce(b.total_storage_cost_per_unit, 0)
-- MAGIC     as total_cost,
-- MAGIC 
-- MAGIC     -- CJ - 06-18-2026.1 rank without storage cost
-- MAGIC     a.net_fulfillment_cost 
-- MAGIC         + coalesce(YR50_ea_cost, 0) + coalesce(YR73_ea_cost, 0) + coalesce(YR51_ea_cost, 0) + coalesce(YR53_ea_cost, 0)
-- MAGIC         + coalesce(YR60_ea_cost, 0)
-- MAGIC         + coalesce(IB_Trans_Cost, 0) -- CJ - 05-28-2026.2
-- MAGIC         + coalesce(pallet_cost, 0)
-- MAGIC     as total_cost_no_storage
-- MAGIC     
-- MAGIC from base a
-- MAGIC left join fact_dtc_storage_rates b 
-- MAGIC     on a.shipping_point_key = b.shipping_point_key
-- MAGIC     and a.material = b.Material
-- MAGIC     and b.node_count = 2

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%sql
-- MAGIC CREATE OR REPLACE TABLE fact_dummy_ys10n_top_12
-- MAGIC USING DELTA
-- MAGIC AS
-- MAGIC 
-- MAGIC WITH ranked_matrix AS (
-- MAGIC     select a.*
-- MAGIC         ,row_number() over (partition by material, dest_zip_clean order by total_cost, est_delv_time) as total_cost_rn -- CJ - 07-29-2026.1
-- MAGIC         -- CJ - 06-18-2026.1
-- MAGIC         ,row_number() over (partition by material, dest_zip_clean order by total_cost_no_storage, est_delv_time) as total_cost_no_storage_rn -- CJ - 07-29-2026.1
-- MAGIC     from fact_dtc_rate_matrix a
-- MAGIC ),
-- MAGIC 
-- MAGIC ecom_customers AS (
-- MAGIC     select *
-- MAGIC     from `DIM Customer`
-- MAGIC     where ECOM is not null
-- MAGIC )
-- MAGIC 
-- MAGIC SELECT  
-- MAGIC     a.SourceTable
-- MAGIC     ,a.`YS10N Source` as ys10n_source
-- MAGIC     ,a.`Data Source` as data_source
-- MAGIC     ,a.SBU
-- MAGIC     ,a.AcquisitionStatus
-- MAGIC     ,a.Material
-- MAGIC     ,a.RetailerKey
-- MAGIC     ,a.`Sales Order` as sales_order
-- MAGIC     ,a.ship_to
-- MAGIC     ,a.OrderLine
-- MAGIC     ,a.Plant
-- MAGIC     ,a.`New Storage Location` shipping_point
-- MAGIC     ,a.Payer
-- MAGIC     ,a.`PO Number` as po_number
-- MAGIC     ,a.`Shipment Number` as shipment_number
-- MAGIC     ,a.Delivery
-- MAGIC     ,a.`Shipping type` as shipping_type
-- MAGIC     ,a.ship_to_zip
-- MAGIC     ,a.`ShipToZip_Clean` as ship_to_zip_clean
-- MAGIC     ,a.`Act. Gds Mvmnt Date Converted` as act_gds_mvmnt_date
-- MAGIC     ,a.`Combined Date` as combined_date
-- MAGIC     ,a.`Combined Qty` as combined_qty
-- MAGIC 
-- MAGIC     ,b.total_cost_rn as actual_cost_ranking
-- MAGIC     ,b.total_cost_no_storage_rn as actual_cost_ranking_no_storage -- CJ - 06-18-2026.1
-- MAGIC     ,b.port as actual_port
-- MAGIC 
-- MAGIC     ,b.shipping_point as actual_shipping_point
-- MAGIC     ,b.shipping_point_desc as actual_ship_point
-- MAGIC     ,b.shipping_point_type as actual_shipping_point_type
-- MAGIC     ,b.shipping_point_type_desc as actual_ship_type
-- MAGIC     ,b.shipping_point_zip as actual_ship_point_zip
-- MAGIC     ,b.shipping_point_key as actual_ship_point_key
-- MAGIC     ,b.shipping_point_key_desc as actual_shipping_point_key_desc
-- MAGIC 
-- MAGIC     ,b.YR50 as actual_YR50
-- MAGIC     ,b.YR73 as actual_YR73
-- MAGIC     ,b.YR51 as actual_YR51
-- MAGIC     ,b.YR53 as actual_YR53
-- MAGIC     ,b.YR60 as actual_YR60
-- MAGIC 
-- MAGIC     ,b.YR50_ea_cost as actual_YR50_ea_cost
-- MAGIC     ,b.YR73_ea_cost as actual_YR73_ea_cost
-- MAGIC     ,b.YR51_ea_cost as actual_YR51_ea_cost
-- MAGIC     ,b.YR53_ea_cost as actual_YR53_ea_cost
-- MAGIC     ,b.YR60_ea_cost as actual_YR60_ea_cost
-- MAGIC 
-- MAGIC     -- ,b.material as actual_material
-- MAGIC     ,b.parcel_ahs_type as actual_parcel_ahs_type
-- MAGIC     ,b.das_type as actual_das_type
-- MAGIC     -- ,b.destination_zip as actual_destination_zip
-- MAGIC     -- ,b.dest_zip_clean as actual_dest_zip_clean
-- MAGIC     ,b.IB_Trans_Cost as actual_IB_Trans_Cost
-- MAGIC     -- CJ - 06-12-2026.1
-- MAGIC     ,b.ADS actual_ADS
-- MAGIC     ,b.avg_DOS actual_avg_DOS
-- MAGIC     ,b.avg_unit_storage_cost actual_avg_unit_storage_cost
-- MAGIC 
-- MAGIC     ,b.base_fulfillment_cost as actual_base_fulfillment_cost
-- MAGIC     ,b.pallet_cost as actual_pallet_cost
-- MAGIC     ,b.COGS as actual_COGS
-- MAGIC     ,b.net_fulfillment_cost as actual_net_fulfillment_cost
-- MAGIC     ,b.total_cost as actual_total_cost
-- MAGIC     ,b.total_cost_no_storage as actual_total_cost_no_storage -- CJ - 06-18-2026.1
-- MAGIC     ,b.distance as actual_distance -- CJ - 07-07-2026.1
-- MAGIC     ,b.est_delv_time as actual_est_delv_time -- CJ - 07-08-2026.1
-- MAGIC 
-- MAGIC     ,c.total_cost_rn as cost_ranking
-- MAGIC     ,c.total_cost_no_storage_rn as cost_ranking_no_storage -- CJ - 06-18-2026.1
-- MAGIC     ,c.port as ranked_port
-- MAGIC 
-- MAGIC     ,c.shipping_point as ranked_shipping_point
-- MAGIC     ,c.shipping_point_desc as ranked_ship_point
-- MAGIC     ,c.shipping_point_type as ranked_shipping_point_type
-- MAGIC     ,c.shipping_point_type_desc as ranked_ship_type
-- MAGIC     ,c.shipping_point_zip as ranked_ship_point_zip
-- MAGIC     ,c.shipping_point_key as ranked_ship_point_key
-- MAGIC     ,c.shipping_point_key_desc as ranked_shipping_point_key_desc
-- MAGIC 
-- MAGIC     ,c.YR50 as ranked_YR50
-- MAGIC     ,c.YR73 as ranked_YR73
-- MAGIC     ,c.YR51 as ranked_YR51
-- MAGIC     ,c.YR53 as ranked_YR53
-- MAGIC     ,c.YR60 as ranked_YR60
-- MAGIC 
-- MAGIC     ,c.YR50_ea_cost as ranked_YR50_ea_cost
-- MAGIC     ,c.YR73_ea_cost as ranked_YR73_ea_cost
-- MAGIC     ,c.YR51_ea_cost as ranked_YR51_ea_cost
-- MAGIC     ,c.YR53_ea_cost as ranked_YR53_ea_cost
-- MAGIC     ,c.YR60_ea_cost as ranked_YR60_ea_cost
-- MAGIC     
-- MAGIC     -- ,c.material as ranked_material
-- MAGIC     ,c.parcel_ahs_type as ranked_parcel_ahs_type
-- MAGIC     ,c.das_type as ranked_das_type
-- MAGIC     -- ,c.destination_zip as ranked_destination_zip
-- MAGIC     -- ,c.dest_zip_clean as ranked_dest_zip_clean
-- MAGIC     ,c.IB_Trans_Cost as ranked_IB_Trans_Cost
-- MAGIC     -- CJ - 06-12-2026.1
-- MAGIC     ,c.ADS as ranked_ADS
-- MAGIC     ,c.avg_DOS as ranked_avg_DOS
-- MAGIC     ,c.avg_unit_storage_cost as ranked_avg_unit_storage_cost
-- MAGIC 
-- MAGIC     ,c.base_fulfillment_cost as ranked_base_fulfillment_cost
-- MAGIC     ,c.pallet_cost as ranked_pallet_cost
-- MAGIC     ,c.COGS as ranked_COGS
-- MAGIC     ,c.net_fulfillment_cost as ranked_net_fulfillment_cost
-- MAGIC     ,c.total_cost as ranked_total_cost
-- MAGIC     ,c.total_cost_no_storage as ranked_total_cost_no_storage
-- MAGIC     ,c.distance as ranked_distance -- CJ - 07-07-2026.1
-- MAGIC     ,c.est_delv_time as ranked_est_delv_time -- CJ - 07-08-2026.1
-- MAGIC 
-- MAGIC FROM `FACT YS10N Past` a
-- MAGIC 
-- MAGIC INNER JOIN ranked_matrix b
-- MAGIC     on a.Material = b.material
-- MAGIC     and a.ShipToZip_Clean  = b.dest_zip_clean
-- MAGIC     and a.`New Storage Location` = b.shipping_point
-- MAGIC     and a.`Shipping type` = b.shipping_point_type
-- MAGIC 
-- MAGIC LEFT JOIN ranked_matrix c
-- MAGIC     on a.Material = c.material
-- MAGIC     and a.ShipToZip_Clean  = c.dest_zip_clean
-- MAGIC 
-- MAGIC INNER JOIN ecom_customers d
-- MAGIC     on a.Payer = d.`Payer Key`
-- MAGIC ;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

CREATE OR REPLACE TABLE fact_ecomm_material_zip_weight_matrix
USING DELTA
AS

WITH zip_deliveries AS (
    SELECT
        a.Material,
        a.`ShipToZip_Clean` AS ship_to_zip_clean,
        z.`REGION` AS ship_to_state,
        z.`DAT US Region` as ship_to_us_region,
        z.`Postal Code Country` AS ship_to_country,
        COUNT(DISTINCT a.Delivery) AS delivery_count,
        -- CJ - 08-04-2026.2
        -SUM(a.`Combined Qty`) AS combined_qty

    FROM `FACT YS10N Past` a

    INNER JOIN `DIM Customer` d
        ON a.Payer = d.`Payer Key`
        AND d.ECOM IS NOT NULL

    INNER JOIN `DIM USA CA Zips` z ON a.`ShipToZip_Clean` = z.`Postal Code Clean`

    WHERE `Act. Gds Mvmnt Date Converted` >= date_add(current_date, -365)
        AND z.`Postal Code Country` = 'USA'
        -- AND z.`DAT US Region` is not null CJ - 07-22-2026.1

    GROUP BY
        a.Material,
        a.`ShipToZip_Clean`,
        z.`REGION`,
        z.`DAT US Region`,
        z.`Postal Code Country` 
)

SELECT
    Material,
    ship_to_zip_clean,
    ship_to_state,
    ship_to_us_region,
    ship_to_country,

    delivery_count,

    SUM(delivery_count) OVER (x) AS state_delivery_count,
    (delivery_count * 1.0) / SUM(delivery_count) OVER (x) AS delivery_weight,

    -- CJ - 08-04-2026.2
    combined_qty, -- CJ - 08-04-2026.2
    SUM(combined_qty) OVER (x) AS state_combined_qty,
    (combined_qty * 1.0) / SUM(combined_qty) OVER (x) AS combined_qty_weight

FROM zip_deliveries

window x as (PARTITION BY Material, ship_to_state)

-- ORDER BY
--     state_combined_qty desc,
--     Material,
--     combined_qty DESC
;


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

CREATE OR REPLACE TABLE fact_ecomm_material_state_ship_point_rankings
USING DELTA
AS

WITH
-- CJ - 07-15-2026.1
zip_weight_matrix as (
    select
        ship_to_zip_clean
        ,ship_to_state
        ,ship_to_country
        -- CJ - 08-05-2026.1
        ,sum(combined_qty) as combined_qty
        ,sum( sum(combined_qty) ) over (partition by ship_to_state) as state_combined_qty
        ,sum(combined_qty) /
            sum( sum(combined_qty) ) over (partition by ship_to_state)
        as combined_qty_weight
        -- ,sum(delivery_count) as delivery_count
        -- ,sum( sum(delivery_count) ) over (partition by ship_to_state) as state_delivery_count
        -- ,sum(delivery_count) /
        --     sum( sum(delivery_count) ) over (partition by ship_to_state)
        -- as delivery_weight

    from fact_ecomm_material_zip_weight_matrix
    where ship_to_country in ('USA') and ship_to_us_region is not null -- CJ - 07-22-2026.1
    group by 
        ship_to_zip_clean
        ,ship_to_state
        ,ship_to_country
    -- order by ship_to_state, delivery_weight desc
),

state_costs AS (
    SELECT
        r.material,
        d.ship_to_state,
        d.ship_to_country,

        r.shipping_point,
        r.shipping_point_desc,
        r.shipping_point_type,
        r.shipping_point_type_desc,
        r.shipping_point_key,
        r.shipping_point_key_desc,

        -- CJ - 08-05-2026.1
        SUM(d.combined_qty_weight) AS coverage_weight,

        SUM(d.combined_qty_weight * r.IB_Trans_Cost) AS weighted_avg_IB_Trans_Cost,
        SUM(d.combined_qty_weight * r.COGS) AS weighted_avg_COGS,
        SUM(d.combined_qty_weight * r.net_fulfillment_cost) AS weighted_avg_net_fulfillment_cost,
        SUM(d.combined_qty_weight * r.distance) AS weighted_avg_distance,
        SUM(d.combined_qty_weight * r.est_delv_time) AS weighted_avg_est_delv_time,
        SUM(d.combined_qty_weight * r.avg_unit_storage_cost) AS weighted_avg_unit_storage_cost,
        SUM(d.combined_qty_weight * r.total_cost) AS weighted_avg_total_cost,
        SUM(d.combined_qty_weight * r.total_cost_no_storage) AS weighted_avg_total_cost_no_storage

    FROM fact_dtc_rate_matrix r

    -- CJ - 07-15-2026.1
    INNER JOIN zip_weight_matrix d -- fact_ecomm_material_zip_weight_matrix d
        -- ON d.Material = r.material
        ON d.ship_to_zip_clean = r.dest_zip_clean

    GROUP BY 
        r.material,
        d.ship_to_state,
        d.ship_to_country,
        r.shipping_point,
        r.shipping_point_desc,
        r.shipping_point_type,
        r.shipping_point_type_desc,
        r.shipping_point_key,
        r.shipping_point_key_desc

    -- HAVING SUM(d.delivery_weight) >= 0.999
),

ranked_ship_points AS (
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY material, ship_to_state, ship_to_country
            ORDER BY 
                weighted_avg_total_cost ASC NULLS LAST, -- CJ - 07-17-2026.1
                weighted_avg_est_delv_time ASC NULLS LAST, -- CJ - 07-29-2026.1
                weighted_avg_net_fulfillment_cost ASC NULLS LAST, -- CJ - 07-17-2026.1
                shipping_point_key_desc
        ) AS state_total_cost_rn,

        ROW_NUMBER() OVER (
            PARTITION BY material, ship_to_state, ship_to_country
            ORDER BY 
                weighted_avg_total_cost_no_storage ASC NULLS LAST, -- CJ - 07-17-2026.1
                weighted_avg_est_delv_time ASC NULLS LAST, -- CJ - 07-29-2026.1
                weighted_avg_net_fulfillment_cost ASC NULLS LAST, -- CJ - 07-17-2026.1
                shipping_point_key_desc
        ) AS state_total_cost_no_storage_rn

    FROM state_costs
)

SELECT *
FROM ranked_ship_points;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

CREATE OR REPLACE TABLE fact_ys10n_past_with_material_state_rankings
USING DELTA
AS

WITH
base as (
    SELECT        
        a.SourceTable
        ,a.`YS10N Source` as ys10n_source
        ,a.`Data Source` as data_source
        ,a.SBU
        ,a.AcquisitionStatus
        ,a.Material
        ,a.RetailerKey
        ,a.`Sales Order` as sales_order
        ,a.ship_to
        ,a.OrderLine
        ,a.Plant
        ,a.`New Storage Location` actual_shipping_point
        ,a.Payer
        ,a.`PO Number` as po_number
        ,a.`Shipment Number` as shipment_number
        ,a.Delivery
        ,a.`Shipping type` as shipping_type
        ,a.ship_to_zip
        ,a.`ShipToZip_Clean` as ship_to_zip_clean
        ,a.`Act. Gds Mvmnt Date Converted` as act_gds_mvmnt_date
        ,a.`Combined Date` as combined_date
        ,a.`Combined Qty` as combined_qty

        ,b.ship_to_state
        ,z.REGION
        ,b.ship_to_country
        ,b.shipping_point
        ,b.shipping_point_desc
        ,b.shipping_point_type
        ,b.shipping_point_type_desc
        ,b.shipping_point_key
        ,b.shipping_point_key_desc

        ,b.coverage_weight
        ,b.weighted_avg_IB_Trans_Cost
        ,b.weighted_avg_COGS
        ,b.weighted_avg_net_fulfillment_cost
        ,b.weighted_avg_distance
        ,b.weighted_avg_est_delv_time
        ,b.weighted_avg_unit_storage_cost
        ,b.weighted_avg_total_cost
        ,b.weighted_avg_total_cost_no_storage

        ,b.state_total_cost_rn
        ,b.state_total_cost_no_storage_rn

    FROM `FACT YS10N Past` a

    -- CJ - 07-14-2026.1
    INNER JOIN fact_dtc_rate_matrix d 
        on a.Material = d.material
        and a.ShipToZip_Clean  = d.dest_zip_clean
        and a.`New Storage Location` = d.shipping_point
        and a.`Shipping type` = d.shipping_point_type

    LEFT JOIN `DIM USA CA Zips` z
        ON a.`ShipToZip_Clean` = z.`Postal Code Clean`

    LEFT JOIN fact_ecomm_material_state_ship_point_rankings b
        ON a.Material = b.material
        AND z.`REGION` = b.ship_to_state
        AND z.`Postal Code Country` = b.ship_to_country
    
    INNER JOIN `DIM Customer` c
        ON a.Payer = c.`Payer Key`
        AND c.ECOM IS NOT NULL

    -- WHERE a.Material IS NOT NULL
    --     AND a.`ShipToZip_Clean` IS NOT NULL
)

select *
from base
-- where Material in ('250950')
--     and ship_to_state in ('NY')
--     and Payer in ('172315') 
--     and act_gds_mvmnt_date >

-- ORDER BY Material, ship_to_state, state_total_cost_rn

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

CREATE OR REPLACE TABLE fact_forecast_with_material_state_rankings
USING DELTA
AS

with
state_matrix as (
    select
        ship_to_state
        ,ship_to_country
        ,sum(combined_qty) as combined_qty
        ,sum(sum(combined_qty)) over (partition by ship_to_country) as total_combined_qty

        ,cast(sum(combined_qty) as double)
        /
        cast(
            sum(sum(combined_qty)) over (partition by ship_to_country)
        as double) as state_ratio

    from fact_ecomm_material_zip_weight_matrix
    where ship_to_country in ('USA')
        and ship_to_us_region is not null -- CJ - 07-22-2026.1
    group by 
        ship_to_state
        ,ship_to_country
)

,fact_forecast as (
    select
        a.Material
        ,a.Payer
        ,a.`MRP Area` as MRP_Area
        ,a.`Combined Date` as combined_date
        ,a.`MRPSKU Key` as MRP_SKU_Key
        ,sum(-a.`Combined Qty`) as fc_qty

    from `FACT Component Forecast Initial` a

    -- CJ - 07-17-2026.2
    inner join `DIM Customer` c
        on a.Payer = c.`Payer Key`
        and c.ECOM is not null
    where (`BOM Type` is null or `BOM Type` = 'Finished Goods')
    group by 
        a.Material
        ,a.Payer
        ,a.`MRP Area`
        ,a.`Combined Date`
        ,a.`MRPSKU Key`
    -- order by Material, Payer, MRP_Area, combined_date, fc_qty
)

-- CJ - 08-04-2026.1
-- ,state_fc_qty as (
--     select a.*
--         ,b.ship_to_state
--         ,b.ship_to_country
--         ,b.state_ratio

--         ,b.state_ratio * fc_qty as state_fc_qty
--     from fact_forecast a
--     cross join state_matrix b
-- )
,state_fc_qty_base as (
    select
        a.*
        ,b.ship_to_state
        ,b.ship_to_country
        ,b.state_ratio

        ,b.state_ratio * a.fc_qty as raw_state_fc_qty

        ,floor(b.state_ratio * a.fc_qty) as base_state_fc_qty

        ,(b.state_ratio * a.fc_qty)
            - floor(b.state_ratio * a.fc_qty) as fractional_remainder

    from fact_forecast a
    cross join state_matrix b
)
,state_fc_qty_ranked as (
    select
        *

        ,row_number() over (
            partition by
                Material
                ,Payer
                ,MRP_Area
                ,combined_date
                ,MRP_SKU_Key
            order by fractional_remainder desc,
                ship_to_state
        ) as remainder_rank

        ,fc_qty
            - sum(base_state_fc_qty) over (
                partition by
                    Material
                    ,Payer
                    ,MRP_Area
                    ,combined_date
                    ,MRP_SKU_Key
            ) as units_to_distribute

    from state_fc_qty_base
)
,state_fc_qty as (
    select
        *
        ,cast(
            base_state_fc_qty
            +
            case
                when remainder_rank <= units_to_distribute
                then 1
                else 0
            end
        as bigint) as state_fc_qty

    from state_fc_qty_ranked
)

select 
    a.Material
    ,a.Payer
    ,a.MRP_Area
    ,a.combined_date
    ,a.MRP_SKU_Key
    ,a.ship_to_state
    ,a.ship_to_country
    ,a.fc_qty as country_fc_qty
    ,a.state_ratio
    -- CJ - 08-04-2026.1
    ,a.raw_state_fc_qty
    ,a.base_state_fc_qty

    ,a.state_fc_qty

    ,b.shipping_point
    ,b.shipping_point_desc
    ,b.shipping_point_type
    ,b.shipping_point_type_desc
    ,b.shipping_point_key
    ,b.shipping_point_key_desc

    ,b.weighted_avg_IB_Trans_Cost
    ,b.weighted_avg_COGS
    ,b.weighted_avg_net_fulfillment_cost
    ,b.weighted_avg_distance
    ,b.weighted_avg_est_delv_time
    ,b.weighted_avg_unit_storage_cost
    ,b.weighted_avg_total_cost
    ,b.weighted_avg_total_cost_no_storage

    ,b.state_total_cost_rn
    ,b.state_total_cost_no_storage_rn
from state_fc_qty a

-- CJ - 07-17-2026.2

-- INNER JOIN `DIM Customer` c
--     ON a.Payer = c.`Payer Key`
--     AND c.ECOM IS NOT NULL

LEFT JOIN fact_ecomm_material_state_ship_point_rankings b
    ON a.Material = b.material
    AND a.ship_to_state = b.ship_to_state
    AND a.ship_to_country = b.ship_to_country

WHERE a.Material IS NOT NULL AND a.state_fc_qty > 0 -- CJ - 08-13-2026.1    
    -- and a.Material in ('250950')
    -- and a.Payer in ('172315')
    -- and a.ship_to_state in ('CA')
    -- and b.state_total_cost_rn = 1
-- order by Material, Payer, MRP_Area, combined_date, state_fc_qty desc, ship_to_state, state_total_cost_rn

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }
