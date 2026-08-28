-- Auto Generated (Do not modify) F29B2F0AD569F1BC21BA2F54BCE9BBF29B1B4B197F3E6D1459128A511D789782
CREATE VIEW DTC_RATES AS 
    WITH Origins as (
        SELECT 
            'DHL' as OriginName
            , '31326' as OriginZip
        UNION ALL
            SELECT 'Rancho'
            , '90220'
    )

    ,Base as (
        SELECT 
            -- A.*
            A.[Material]
            ,A.[Sales Order]
            ,A.[ship_to]
            ,A.[Plant]
            ,A.[Storage Location]
            ,A.[Shipping Point/Receiving Pt]
            ,A.[First Date]
            ,A.[Guarantee Date]
            ,A.[Combined Qty]
            ,A.[Payer]
            ,A.[Payer name]
            ,A.[CustomerTypeKey]
            ,A.[Order reason]
            ,A.[Order reason_1]
            ,A.[PO Number]
            ,A.[Shipment Number]
            ,A.[SO Created Date]
            ,A.[Delivery Creation Date]
            ,A.[Confirmation Date]
            ,A.[Combined Date]
            ,A.[Ship-To Party Region]
            ,A.[Act. Gds Mvmnt Date]
            ,A.[Act. Gds Mvmnt Date Converted]
            ,A.[OnTimeDate]
            ,A.[Ship Date]
            ,A.[MRP Area]
            ,A.[MRPSKU Key]
            ,A.[Data Source]
            ,A.[Net Value USD]
            ,A.[Gross Sales USD]
            ,A.[Parcel $]
            ,B.*
            ,C.[SKU & Desc]
            ,C.[Pack Type.Final]
            ,C.[Pack Type.General]
            ,C.[Specs.Carton - Length]
            ,C.[Specs.Carton - Width]
            ,C.[Specs.Carton - Height]
            ,C.[Specs.Carton - Volume - in_] as [Specs.Carton - Volume]
            ,C.[Length & Girth]
            ,C.[Specs.Carton - Weight]
            ,C.[FedEx US Final Billable Weight]
            ,C.[FedEx Applied AHS Category]
            
        FROM [NA_Supply_Chain_WH].[dbo].[FACT YS10N Past] A
        JOIN [NA_Supply_Chain_WH].[dbo].[DIM USA CA Zips] B ON A.[ShipToZip_Clean] = B.[Postal Code Clean]
        LEFT JOIN [NA_Supply_Chain_WH].[dbo].[DIM Product] C ON A.[Material] = C.[Material]
        WHERE [Shipping type] = '07'
    )

    SELECT *
    FROM Base A
    CROSS JOIN Origins B
    -- LEFT JOIN