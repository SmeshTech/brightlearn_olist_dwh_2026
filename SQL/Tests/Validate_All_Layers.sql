USE Olist_Staging;
GO

-- BRIGHTLEARN 2026
-- Final Bronze, Silver and Gold Row Count Validation

WITH LayerCounts AS
(
    SELECT *
    FROM
    (
        VALUES

        -- BRONZE LAYER
        ('Bronze', 'Customers',
         (SELECT COUNT_BIG(*) FROM bronze.olist_customers), 99441),

        ('Bronze', 'Orders',
         (SELECT COUNT_BIG(*) FROM bronze.olist_orders), 99441),

        ('Bronze', 'Order Items',
         (SELECT COUNT_BIG(*) FROM bronze.olist_order_items), 112650),

        ('Bronze', 'Payments',
         (SELECT COUNT_BIG(*) FROM bronze.olist_order_payments), 103886),

        ('Bronze', 'Reviews',
         (SELECT COUNT_BIG(*) FROM bronze.olist_order_reviews), 99224),

        ('Bronze', 'Products',
         (SELECT COUNT_BIG(*) FROM bronze.olist_products), 32951),

        ('Bronze', 'Sellers',
         (SELECT COUNT_BIG(*) FROM bronze.olist_sellers), 3095),

        ('Bronze', 'Geolocation',
         (SELECT COUNT_BIG(*) FROM bronze.olist_geolocation), 1000163),

        ('Bronze', 'Category Translation',
         (SELECT COUNT_BIG(*) FROM bronze.product_category_translation), 71),


        -- SILVER LAYER
        ('Silver', 'Customers',
         (SELECT COUNT_BIG(*) FROM silver.olist_customers), 99441),

        ('Silver', 'Orders',
         (SELECT COUNT_BIG(*) FROM silver.olist_orders), 99441),

        ('Silver', 'Order Items',
         (SELECT COUNT_BIG(*) FROM silver.olist_order_items), 112650),

        ('Silver', 'Payments',
         (SELECT COUNT_BIG(*) FROM silver.olist_order_payments), 103886),

        ('Silver', 'Reviews',
         (SELECT COUNT_BIG(*) FROM silver.olist_order_reviews), 99224),

        ('Silver', 'Products',
         (SELECT COUNT_BIG(*) FROM silver.olist_products), 32951),

        ('Silver', 'Sellers',
         (SELECT COUNT_BIG(*) FROM silver.olist_sellers), 3095),

        ('Silver', 'Geolocation',
         (SELECT COUNT_BIG(*) FROM silver.olist_geolocation), 1000163),

        ('Silver', 'Category Translation',
         (SELECT COUNT_BIG(*) FROM silver.product_category_translation), 71),


        -- GOLD LAYER
        ('Gold', 'DimCustomer',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.DimCustomer), 96355),

        ('Gold', 'DimProduct',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.DimProduct), 32951),

        ('Gold', 'DimSeller',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.DimSeller), 3095),

        ('Gold', 'DimDate',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.DimDate), 774),

        ('Gold', 'FactSales',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.FactSales), 112650),

        ('Gold', 'FactPayments',
         (SELECT COUNT_BIG(*) FROM Olist_DWH.gold.FactPayments), 103886)

    ) AS Counts(LayerName, TableName, ActualRows, ExpectedRows)
)

SELECT
    LayerName,
    TableName,
    ActualRows,
    ExpectedRows,
    ActualRows - ExpectedRows AS Difference,

    CASE
        WHEN ActualRows = ExpectedRows THEN 'PASS'
        ELSE 'INVESTIGATE'
    END AS ValidationStatus

FROM LayerCounts

ORDER BY
    CASE LayerName
        WHEN 'Bronze' THEN 1
        WHEN 'Silver' THEN 2
        WHEN 'Gold' THEN 3
    END,
    TableName;