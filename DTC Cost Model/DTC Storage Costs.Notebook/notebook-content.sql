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

CREATE OR REPLACE TEMP VIEW walmart_storage_costs AS
    with
    node_scenarios as (
        select shipping_point_key
            ,explode(sequence(1,10)) as node_count
        from `DIM DTC Ship Point Key`
        where shipping_point in ('699-WMT')
    )

    ,material_fc as (
        select
            a.Material,
            n.shipping_point_key,
            n.node_count,
            sum(-a.`Combined Qty`) / n.node_count as fc_sales_units
        from `FACT Component Forecast Initial` a
        cross join node_scenarios n
        join (
            select distinct Material
            from `DIM Account` a
            join `DIM Customer` b 
                on a.Payer = b.`Payer Key`
            where b.ECOM is not null
        ) c using (Material)
        where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
        group by a.Material, n.shipping_point_key, n.node_count
    )

    ,avg_fc as (
        select 
            node_count,
            avg(fc_sales_units) as avg_fc_sales_units
        from material_fc
        group by node_count
    )

    ,storage_base AS (
        select
            P.Material,
            n.shipping_point_key,
            n.node_count,
            P.`Specs.Carton - Volume` as carton_volume_ft3,
            coalesce(a.fc_sales_units, b.avg_fc_sales_units) as fc_sales_units
        from `DIM Product` P
        cross join node_scenarios n
        left join material_fc a on P.Material = a.Material
            and n.shipping_point_key = a.shipping_point_key
            and n.node_count = a.node_count
        left join avg_fc b on n.node_count = b.node_count
    )

    ,storage_calc as (
        select
            *,
            140 as fc_sales_days,
            30 as avg_DOS,

            -- core drivers
            fc_sales_units / 140.0 as fc_ADS,
            30 * (fc_sales_units / 140.0) as avg_inventory,

            (0.75 / (365/12) ) * carton_volume_ft3 as daily_storage_0_30
            -- ( (0.75 * (9/12) + 1.5 * (3/12) ) / (365/12) ) * carton_volume_ft3 as daily_storage_31_365,
            -- (2.25 / (365/12) ) * carton_volume_ft3 as daily_storage_366_450,
            -- (7.50 / (365/12) ) * carton_volume_ft3 as daily_storage_450_plus
        from storage_base
    )

    ,storage_final as (
        select
            Material,
            shipping_point_key,
            node_count,
            
            carton_volume_ft3,
            fc_sales_days,
            avg_DOS,

            fc_sales_units,
            fc_ADS,
            avg_inventory,

            -- total storage cost
            0.5 * avg_DOS * avg_inventory * daily_storage_0_30 as total_storage_cost, -- *will need to update if we ever go beyond 30 DOS
            -- per unit cost
            0.5 * avg_DOS * daily_storage_0_30 as total_storage_cost_per_unit

        from storage_calc
    )

    select *
    from storage_final
    -- where Material in ('206042')
    -- order by Material, shipping_point_key, node_count
;

CREATE OR REPLACE TEMP VIEW rancho_storage_cost AS
    with
    node_scenarios as (
        select shipping_point_key
            ,explode(sequence(1,10)) as node_count
        from `DIM DTC Ship Point Key`
        where shipping_point in ('367G')
    ),

    material_fc AS (
        select
            a.Material,
            n.shipping_point_key,
            n.node_count,
            sum(-a.`Combined Qty`) / least(2, n.node_count) as fc_sales_units -- cap at 2 nodes, since SpreeTail can't take everything
        from `FACT Component Forecast Initial` a
        JOIN (
            select distinct Material 
            from `DIM Account` a
            join `DIM Customer` b on a.Payer = b. `Payer Key`
            where b.ECOM IS NOT NULL
        ) b on a.Material = b.Material
        cross join node_scenarios n
        where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
        group by n.shipping_point_key, n.node_count, a.Material
    ),

    avg_fc AS (
        SELECT
            node_count,
            AVG(fc_sales_units) AS avg_fc_sales_units
        FROM material_fc
        GROUP BY node_count
    ),

    storage_base AS (
        select
            P.Material,
            n.shipping_point_key,
            n.node_count,
            P.`Cont_Qty` / 2.0 as half_container_units,
            P.`Specs.Carton - Volume` as carton_volume_ft3,
            coalesce(a.fc_sales_units, b.avg_fc_sales_units) as fc_sales_units
        from `DIM Product` P
        cross join node_scenarios n
        left join material_fc a on P.Material = a.Material
            and n.shipping_point_key = a.shipping_point_key
            and n.node_count = a.node_count
        left join avg_fc b on n.node_count = b.node_count
    ),

    storage_drivers AS (
        SELECT
            Material,
            shipping_point_key,
            node_count,
            
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
            shipping_point_key,
            node_count,
            
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

    select *
    from final_storage_costs
    -- where material in ('206042')
    -- order by shipping_point_key, node_count
;

CREATE OR REPLACE TEMP VIEW castlegate_storage_cost AS 
    with
    node_scenarios as (
        select shipping_point_key
            ,explode(sequence(1,10)) as node_count
        from `DIM DTC Ship Point Key`
        where shipping_point in ('699')
    )

    ,sku AS (
        SELECT
            CAST(P.Material AS STRING) AS material,
            P.`Specs.Carton - Volume`  AS carton_volume_ft3,  
            P.`Specs.Carton - Length`  AS carton_len,  
            P.`Specs.Carton - Width`   AS carton_width,  
            P.`Specs.Carton - Height`  AS carton_height,
            P.`Specs.Carton - Weight`  AS carton_weight,
            (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139 as dim_weight, -- CJ - 06-04-2026.1
            GREATEST( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS max_dim,
            LEAST   ( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS small_dim,
            ceil(P.`Specs.Carton - Length`) + ceil(P.`Specs.Carton - Width`) + ceil(P.`Specs.Carton - Height`) 
                - GREATEST( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) )
                - LEAST   ( ceil(P.`Specs.Carton - Length`), ceil(P.`Specs.Carton - Width`), ceil(P.`Specs.Carton - Height`) ) AS med_dim,
            P.`Length & Girth` as length_girth,
            P.`Cont_Qty`                                      AS cont_qty,
            P.`TL Qty`                                        AS tl_qty,
            P.LTL_Parcel                                      AS ltl_parcel,
            Z.COGS                                            AS cogs,
            P.`Model`                                         AS model,
            P.`SS/PLT_Qty`                                    AS ss_plt_qty,
            P.`Stacked_Cont/TL`                               AS stacked_cont_tl,
            IF(upper(`Stacked_Cont/TL`) like ('%P%'), 1, 0)   AS pallet_present,
            -- CJ - 05-14-2026.1
            P.`PC Business Unit`                              AS pc_business_unit,
            CASE
                WHEN P.`PC Business Unit` = 'GF NA' THEN 181.21
                WHEN P.`PC Business Unit` = 'Tools' THEN 108.21
                WHEN P.`PC Business Unit` = 'F & P EU' THEN 75.99
                WHEN P.`PC Business Unit` = 'Cabinets & Shelving EU' THEN 74.62
                WHEN P.`PC Business Unit` = 'Sheds & Buildings' THEN 68.97
                WHEN P.`PC Business Unit` = 'Deck Boxes' THEN 87.41
                WHEN P.`PC Business Unit` = 'Packout' THEN 117.22
                WHEN P.`PC Business Unit` IN ('Lifestyle', 'Leisure', 'Deck Boxes & Leisure')  THEN 86.89
                ELSE NULL
            END AS YR60

        FROM `DIM Product` P
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
        -- WHERE ltl_parcel in ('Parcel')
    )

    ,sku_category as (
        select *,
            CASE
                -- BIN CATEGORIES
                -- WHEN max_dim <= 6  AND med_dim <= 6 AND small_dim <= 6 AND carton_weight <= 25 THEN 'BIN_SINGLE_PICK'
                WHEN max_dim <= 19 AND med_dim <= 12 AND small_dim <= 6 AND carton_weight <= 25 THEN 'BIN_SMALL'
                WHEN max_dim <= 26 AND med_dim <= 17 AND small_dim <= 14 AND carton_weight <= 25 THEN 'BIN_LARGE'
                WHEN max_dim <= 26 AND med_dim <= 17 AND small_dim <= 14 AND carton_weight BETWEEN 25 AND 50 THEN 'BIN_HEAVY'
                -- STANDARD CATEGORIES
                WHEN max_dim <= 48 AND med_dim <= 30 AND small_dim <= 30 AND length_girth <= 105 AND carton_weight <= 50 AND carton_volume_ft3 <= 6   THEN 'STANDARD_SMALL'
                WHEN max_dim <= 96 AND length_girth <= 130 AND carton_weight <= 110 AND carton_volume_ft3 <= 10 THEN 'STANDARD_MEDIUM'
                WHEN max_dim <= 108 AND length_girth <= 165 AND carton_weight <= 120 THEN 'STANDARD_LARGE'
                WHEN max_dim <= 108 AND length_girth <= 165 AND carton_weight <= 150 THEN 'STANDARD_OVERSIZE'
                -- LARGE / NON-PARCEL
                WHEN carton_weight < 250 THEN 'LARGE_STANDARD'
                WHEN max_dim <= 144 AND carton_weight BETWEEN 250 AND 800 THEN 'LARGE_HEAVY'
                ELSE NULL            
            END AS sku_category,

            CASE WHEN greatest(carton_weight, dim_weight) <= 150 AND max_dim <= 108 AND length_girth <= 165 THEN TRUE ELSE FALSE END AS multichannel_eligibile -- CJ - 06-04-2026.1
        from sku
    )

    ,material_fc as (
        select
            a.Material,
            n.shipping_point_key,
            n.node_count,
            sum(-a.`Combined Qty`) / n.node_count as fc_sales_units
        from `FACT Component Forecast Initial` a
        cross join node_scenarios n
        join (
            select distinct Material
            from `DIM Account` a
            join `DIM Customer` b 
                on a.Payer = b.`Payer Key`
            where b.ECOM is not null
        ) c using (Material)
        where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
        group by a.Material, n.shipping_point_key, n.node_count
    )

    ,avg_fc as (
        select 
            node_count,
            avg(fc_sales_units) as avg_fc_sales_units
        from material_fc
        group by node_count
    )

    ,storage_base AS (
        select
            P.Material,
            n.shipping_point_key,
            n.node_count,
            P.carton_volume_ft3,
            P.sku_category,
            coalesce(a.fc_sales_units, b.avg_fc_sales_units) as fc_sales_units
        from sku_category P
        cross join node_scenarios n
        left join material_fc a on P.Material = a.Material
            and n.shipping_point_key = a.shipping_point_key
            and n.node_count = a.node_count
        left join avg_fc b on n.node_count = b.node_count
    )

    ,storage_calc as (
        select
            *,
            140 as fc_sales_days,
            30 as avg_DOS,
            fc_sales_units / 140.0 as fc_ADS,
            30 * (fc_sales_units / 140.0) as avg_inventory,
            case
                when sku_category not in ('LARGE_STANDARD', 'LARGE_HEAVY')
                    then (0.44 / 30.4167) * carton_volume_ft3
                else (0.35 / 30.4167) * carton_volume_ft3
            end as storage_rate_per_day
        from storage_base
    )

    ,storage_final as (
        select
            Material,
            shipping_point_key,
            node_count,
            
            carton_volume_ft3,
            sku_category,
            fc_sales_days,
            avg_DOS,

            fc_sales_units,
            fc_ADS,
            avg_inventory,

            -- total storage cost
            0.5 * avg_DOS * avg_inventory * storage_rate_per_day as total_storage_cost,
            -- per unit cost
            0.5 * avg_DOS * storage_rate_per_day as total_storage_cost_per_unit

        from storage_calc
    )

    select *
    from storage_final
    -- where material in ('206042')
    -- order by shipping_point_key, node_count
;

CREATE OR REPLACE TEMP VIEW amazon_storage_cost AS
    with
    node_scenarios as (
        select shipping_point_key
            ,explode(sequence(1,10)) as node_count
        from `DIM DTC Ship Point Key`
        where shipping_point in ('699-AMZN')
    )

    ,sku AS (
        SELECT
            CAST(P.Material AS STRING) AS material,
            P.`Specs.Carton - Volume`  AS carton_volume_ft3,  
            P.`Specs.Carton - Length`  AS carton_len,  
            P.`Specs.Carton - Width`   AS carton_width,  
            P.`Specs.Carton - Height`  AS carton_height,
            P.`Specs.Carton - Weight`  AS carton_weight_lb,
            ceil(P.`Specs.Carton - Weight` * 16 ) as carton_weight_oz,
            (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139 as dim_weight_lb,
            ceil( ( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139)  * 16 ) as dim_weight_oz,
            GREATEST( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139, P.`Specs.Carton - Weight` ) as shipping_weight_lb,
            GREATEST( ceil(P.`Specs.Carton - Weight` * 16 ),  ceil( ( (P.`Specs.Carton - Length` * P.`Specs.Carton - Width` * P.`Specs.Carton - Height`) / 139)  * 16 ) ) as shipping_weight_oz,

            GREATEST( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) AS max_dim,
            LEAST   ( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) AS small_dim,
            ROUND(
                (P.`Specs.Carton - Length` + P.`Specs.Carton - Width` + P.`Specs.Carton - Height`)
                    - GREATEST( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` )
                    - LEAST   ( P.`Specs.Carton - Length`, P.`Specs.Carton - Width`, P.`Specs.Carton - Height` ) ,
                2
            ) AS med_dim,
            P.`Length & Girth` as length_girth,
            P.`Cont_Qty`                                              AS cont_qty,
            P.`TL Qty`                                                AS tl_qty,
            P.LTL_Parcel                                              AS ltl_parcel,
            case when P.LTL_Parcel = 'Parcel' then '07' else '06' end AS shipping_point_type,
            Z.COGS                                                    AS cogs,
            P.`Model`                                                 AS model,
            P.`SS/PLT_Qty`                                            AS ss_plt_qty,
            P.`Stacked_Cont/TL`                                       AS stacked_cont_tl,
            IF(upper(`Stacked_Cont/TL`) like ('%P%'), 1, 0)           AS pallet_present,

            P.`PC Business Unit`                              AS pc_business_unit

        FROM `DIM Product` P
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
        -- WHERE ltl_parcel in ('Parcel')
    )

    ,sku_category as (
        select *,
            CASE
                -- Product size tier
                WHEN shipping_weight_oz <= 16 AND max_dim <= 15 AND med_dim <= 12 AND small_dim <= 0.75 THEN 'Small standard'
                WHEN shipping_weight_lb <= 20 AND max_dim <= 18 AND med_dim <= 14 AND small_dim <= 8 THEN 'Large standard'
                WHEN shipping_weight_lb <= 50 AND max_dim <= 37 AND med_dim <= 28 AND small_dim <= 20 AND length_girth <= 130 THEN 'Small bulky'
                WHEN shipping_weight_lb <= 50 AND max_dim <= 59 AND med_dim <= 33 AND small_dim <= 33 AND length_girth <= 130 THEN 'Large bulky'
                WHEN (max_dim > 59 OR med_dim > 33 OR small_dim > 33 OR length_girth > 130 OR shipping_weight_lb > 50 ) THEN
                    CASE
                        WHEN shipping_weight_lb <= 50 THEN 'Extra large: Up to 50 lbs'
                        WHEN shipping_weight_lb > 50 AND shipping_weight_lb <= 70 THEN 'Extra large: 50+ to 70 lbs'
                        WHEN shipping_weight_lb > 70 AND shipping_weight_lb <= 150 THEN 'Extra large: 70+ to 150 lbs'
                        WHEN shipping_weight_lb > 150 THEN 'Extra large: 150+ lbs'
                    END                    
            END AS sku_category,

            CASE WHEN shipping_weight_lb <= 150 AND (max_dim > 96 OR length_girth > 130) THEN TRUE ELSE FALSE END AS overmax_flag

        from sku
    )

    ,material_fc as (
        select
            a.Material,
            n.shipping_point_key,
            n.node_count,
            sum(-a.`Combined Qty`) / n.node_count as fc_sales_units
        from `FACT Component Forecast Initial` a
        cross join node_scenarios n
        join (
            select distinct Material
            from `DIM Account` a
            join `DIM Customer` b 
                on a.Payer = b.`Payer Key`
            where b.ECOM is not null
        ) c using (Material)
        where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
        group by a.Material, n.shipping_point_key, n.node_count
    )

    ,avg_fc as (
        select 
            node_count,
            avg(fc_sales_units) as avg_fc_sales_units
        from material_fc
        group by node_count
    )

    ,storage_base AS (
        select
            P.material,
            n.shipping_point_key,
            n.node_count,
            P.carton_volume_ft3,
            P.sku_category,
            coalesce(a.fc_sales_units, b.avg_fc_sales_units) as fc_sales_units
        from sku_category P
        cross join node_scenarios n
        left join material_fc a on P.Material = a.Material
            and n.shipping_point_key = a.shipping_point_key
            and n.node_count = a.node_count
        left join avg_fc b on n.node_count = b.node_count
    )

    ,storage_calc as (
        select
            *,
            140 as fc_sales_days,
            30 as avg_DOS,

            -- core drivers
            fc_sales_units / 140.0 as fc_ADS,
            30 * (fc_sales_units / 140.0) as avg_inventory,

            case
                when sku_category in ('Small standard', 'Large standard') then (1.19 / 30.4167) * carton_volume_ft3
                else (0.77 / 30.4167) * carton_volume_ft3
            end as storage_rate_per_day
        from storage_base
    )

    ,storage_final as (
        select
            material,
            shipping_point_key,
            node_count,
            
            carton_volume_ft3,
            sku_category,
            fc_sales_days,
            avg_DOS,

            fc_sales_units,
            fc_ADS,
            avg_inventory,

            -- total storage cost
            0.5 * avg_DOS * avg_inventory * storage_rate_per_day as total_storage_cost,
            -- per unit cost
            0.5 * avg_DOS * storage_rate_per_day as total_storage_cost_per_unit

        from storage_calc
    )
    select *
    from storage_final
    -- where material in ('206042')
    -- order by shipping_point_key, node_count
;

CREATE OR REPLACE TEMP VIEW spreetail_storage_cost AS
    with 
    node_scenarios as (
        select shipping_point_key
            ,explode(sequence(1,10)) as node_count
        from `DIM DTC Ship Point Key`
        where shipping_point_key in (
            '367D - 06', '367B - 06','367A - 06', '367O - 06', '367I - 06'
        )
    ),

    material_fc as (
        select
            a.Material,
            n.shipping_point_key,
            n.node_count, 
            sum(-a.`Combined Qty`) as combined_qty,
            sum(-a.`Combined Qty`) / n.node_count as fc_sales_units
        from `FACT Component Forecast Initial` a
        cross join node_scenarios n
        where a.`SOW` between a.`Today SOW` and (a.`Today SOW` + 139)
            and a.payer = '172315'
        group by n.shipping_point_key, n.node_count, a.Material
        -- order by shipping_point_key, Material, node_count
    ),

    avg_fc as (
        select 
            node_count,
            avg(fc_sales_units) as avg_fc_sales_units
        from material_fc
        group by node_count
    ),

    storage_base as (
        select
            P.Material,
            n.shipping_point_key,
            n.node_count,
            P.`Cont_Qty` / 2.0 as half_container_units,
            P.`Specs.Carton - Volume` as carton_volume_ft3,
            -- a.fc_sales_units,
            -- b.avg_fc_sales_units,
            coalesce(
                a.fc_sales_units,
                b.avg_fc_sales_units
            ) as fc_sales_units
        from `DIM Product` P
        cross join node_scenarios n
        left join material_fc a on P.Material = a.Material
            and n.shipping_point_key = a.shipping_point_key
            and n.node_count = a.node_count
        left join avg_fc b on n.node_count = b.node_count
    ),

    storage_drivers as (
        select
            Material,
            shipping_point_key,
            node_count,
            half_container_units,
            carton_volume_ft3,

            140.0 as fc_sales_days,
            60.0 as free_storage_days,

            fc_sales_units,
            fc_sales_units / 140.0 as fc_ADS, 

            half_container_units / nullif(fc_sales_units / 140.0, 0) as half_container_DOS,

            (0.60 / 30.4167) * carton_volume_ft3 as daily_storage_rate_61_120,
            (1.20 / 30.4167) * carton_volume_ft3 as daily_storage_rate_121_plus
        from storage_base
    ),

    storage_inventory_points as (
        select
            *,

            greatest(half_container_units - (fc_ADS * free_storage_days), 0) as units_start_61_120,
            greatest(half_container_units - (fc_ADS * 120.0), 0) as units_start_121_plus,

            least(greatest(half_container_DOS - free_storage_days, 0), 60.0) as days_61_120,
            greatest(half_container_DOS - 120.0, 0) as days_121_plus
        from storage_drivers
    ),

    storage_tier_endpoints as (
        select
            *,

            greatest(units_start_61_120 - (fc_ADS * days_61_120), 0) as units_end_61_120,
            greatest(units_start_121_plus - (fc_ADS * days_121_plus), 0) as units_end_121_plus
        from storage_inventory_points
    ),

    storage_costs as (
        select
            *,

            (
                days_61_120
                * ((units_start_61_120 + units_end_61_120) / 2.0)
                * daily_storage_rate_61_120
            ) as total_storage_cost_61_120,

            (
                days_121_plus
                * ((units_start_121_plus + units_end_121_plus) / 2.0)
                * daily_storage_rate_121_plus
            ) as total_storage_cost_121_plus
        from storage_tier_endpoints
    ),

    final_storage_costs as (
        select
            Material,
            shipping_point_key,
            node_count,
            half_container_units,
            carton_volume_ft3,
            
            fc_sales_days,
            fc_sales_units,
            fc_ADS,
            half_container_DOS,

            total_storage_cost_61_120 + total_storage_cost_121_plus as total_storage_cost,

            (total_storage_cost_61_120 + total_storage_cost_121_plus)
                / nullif(half_container_units, 0) as total_storage_cost_per_unit
        from storage_costs
    )

    select *
    from final_storage_costs
    -- where Material in ('206042')
    -- order by Material, shipping_point_key, node_count
;

CREATE OR REPLACE TABLE FACT_DTC_STORAGE_RATES AS 
    with
    union_all as (
        select
            Material,
            shipping_point_key,
            node_count,

            fc_sales_days,
            avg_DOS,
            fc_sales_units,
            fc_ADS,
            total_storage_cost,
            total_storage_cost_per_unit
        from walmart_storage_costs

        union all 

        select
            Material,
            shipping_point_key,
            node_count,

            fc_sales_days,
            half_container_DOS as avg_DOS,
            fc_sales_units,
            fc_ADS,
            total_storage_cost,
            total_storage_cost_per_unit
        from rancho_storage_cost

        union all

        select
            Material,
            shipping_point_key,
            node_count,

            fc_sales_days,
            avg_DOS,
            fc_sales_units,
            fc_ADS,
            total_storage_cost,
            total_storage_cost_per_unit
        from castlegate_storage_cost

        union all

        select
            material as Material,
            shipping_point_key,
            node_count,

            fc_sales_days,
            avg_DOS,
            fc_sales_units,
            fc_ADS,
            total_storage_cost,
            total_storage_cost_per_unit
        from amazon_storage_cost

        union all

        select
            Material,
            shipping_point_key,
            node_count,

            fc_sales_days,
            half_container_DOS as avg_DOS,
            fc_sales_units,
            fc_ADS,
            total_storage_cost,
            total_storage_cost_per_unit
        from spreetail_storage_cost
    )

    select *
    from union_all
    -- where Material in ('250950')
    -- order by shipping_point_key, Material, node_count
;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT shipping_point_key, material, node_count, count(*)
FROM fact_dtc_storage_rates
-- WHERE node_count is not null
GROUP BY 1,2,3
HAVING COUNT(*) > 1
ORDER BY shipping_point_key, material, node_count

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

select *
from FACT_DTC_STORAGE_RATES
WHERE MATERIAL IN ('259301')
    AND node_count = 1
ORDER BY shipping_point_key, Material, node_count

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
