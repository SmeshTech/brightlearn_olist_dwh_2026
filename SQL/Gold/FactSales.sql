USE Olist_DWH;
GO

-- ==========================================
-- GOLD LAYER: CREATE FACTSALES
-- ==========================================

IF OBJECT_ID('gold.FactSales', 'U') IS NULL
BEGIN
    CREATE TABLE gold.FactSales
    (
        SalesKey BIGINT IDENTITY(1,1) PRIMARY KEY,

        OrderID VARCHAR(100) NOT NULL,
        OrderItemID INT NOT NULL,

        CustomerKey BIGINT NOT NULL,
        ProductKey BIGINT NOT NULL,
        SellerKey BIGINT NOT NULL,
        DateKey INT NOT NULL,

        OrderPurchaseTimestamp DATETIME2(7) NOT NULL,

        ItemPrice DECIMAL(18,2) NOT NULL,
        FreightValue DECIMAL(18,2) NOT NULL,

        LoadDate DATETIME2(7) NOT NULL
            DEFAULT SYSDATETIME(),

        CONSTRAINT UQ_FactSales_OrderItem
            UNIQUE (OrderID, OrderItemID),

        CONSTRAINT FK_FactSales_Customer
            FOREIGN KEY (CustomerKey)
            REFERENCES gold.DimCustomer(CustomerKey),

        CONSTRAINT FK_FactSales_Product
            FOREIGN KEY (ProductKey)
            REFERENCES gold.DimProduct(ProductKey),

        CONSTRAINT FK_FactSales_Seller
            FOREIGN KEY (SellerKey)
            REFERENCES gold.DimSeller(SellerKey),

        CONSTRAINT FK_FactSales_Date
            FOREIGN KEY (DateKey)
            REFERENCES gold.DimDate(DateKey)
    );

    PRINT 'FactSales created successfully.';
END;
GO

-- ==========================================
-- LOAD FACTSALES FROM SILVER
-- ==========================================

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO gold.FactSales
    (
        OrderID,
        OrderItemID,
        CustomerKey,
        ProductKey,
        SellerKey,
        DateKey,
        OrderPurchaseTimestamp,
        ItemPrice,
        FreightValue
    )

    SELECT
        oi.order_id,
        oi.order_item_id,

        dc.CustomerKey,
        dp.ProductKey,
        ds.SellerKey,
        dd.DateKey,

        o.order_purchase_timestamp,
        oi.price,
        oi.freight_value

    FROM Olist_Staging.silver.olist_order_items oi

    INNER JOIN Olist_Staging.silver.olist_orders o
        ON oi.order_id = o.order_id

    INNER JOIN Olist_Staging.silver.olist_customers c
        ON o.customer_id = c.customer_id

    INNER JOIN gold.DimCustomer dc
        ON dc.CustomerUniqueID = c.customer_unique_id
        AND o.order_purchase_timestamp >= dc.EffectiveStartDate
        AND (
            o.order_purchase_timestamp < dc.EffectiveEndDate
            OR dc.EffectiveEndDate IS NULL
        )

    INNER JOIN gold.DimProduct dp
        ON oi.product_id = dp.ProductID

    INNER JOIN gold.DimSeller ds
        ON oi.seller_id = ds.SellerID

    INNER JOIN gold.DimDate dd
        ON CAST(o.order_purchase_timestamp AS DATE) = dd.FullDate

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM gold.FactSales f
        WHERE f.OrderID = oi.order_id
          AND f.OrderItemID = oi.order_item_id
    );

    -- Essential validation before committing
    IF
    (
        SELECT COUNT_BIG(*)
        FROM gold.FactSales
    ) <>
    (
        SELECT COUNT_BIG(*)
        FROM Olist_Staging.silver.olist_order_items
    )
    BEGIN
        THROW 51000,
            'FactSales row count mismatch. Load rolled back.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'FactSales loaded successfully.';

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- ==========================================
-- VALIDATE FACTSALES
-- ==========================================

SELECT
    (SELECT COUNT(*)
     FROM Olist_Staging.silver.olist_order_items)
        AS Silver_Order_Items,

    COUNT(*) AS Gold_Sales_Rows,

    COUNT(DISTINCT SalesKey)
        AS Unique_Sales_Keys,

    SUM(ItemPrice)
        AS Total_Item_Value,

    SUM(FreightValue)
        AS Total_Freight_Value

FROM gold.FactSales;