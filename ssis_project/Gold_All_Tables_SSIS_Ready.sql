-- BrightLearn Olist 2026 | SSIS-ready Gold bootstrap + insert-only load
-- Generated from the six supplied Gold scripts, retaining their SELECT/JOIN logic.
-- Compatible with an SSIS Execute SQL Task (OLE DB; SQLSourceType=Direct input;
-- ResultSet=None). No GO batch separators. Run AFTER populated Silver tables.
-- Uses the existing Olist_DWH database; creates the gold schema and Gold tables
-- when absent. Does not DROP, TRUNCATE, UPDATE, or DELETE any existing records.
-- Full transaction: validation failure rolls back ALL inserts/DDL from this run.
-- NOTE: Static assignment dataset expectations, not an incremental CDC loader.
USE Olist_DWH;
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'gold') IS NULL
        EXEC(N'CREATE SCHEMA gold');

    -- Create DimCustomer (matches prior SCD2 design)
    EXEC sys.sp_executesql N'IF OBJECT_ID(N''gold.DimCustomer'', N''U'') IS NULL
BEGIN
    CREATE TABLE gold.DimCustomer
    (
        CustomerKey BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CustomerUniqueID VARCHAR(100) NOT NULL,
        CustomerCity VARCHAR(200) NULL,
        CustomerState VARCHAR(10) NULL,
        CustomerZipCodePrefix VARCHAR(20) NULL,
        EffectiveStartDate DATETIME2(7) NOT NULL,
        EffectiveEndDate DATETIME2(7) NULL,
        IsCurrent BIT NOT NULL,
        LoadDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT CK_DimCustomer_Dates CHECK
           (EffectiveEndDate IS NULL OR EffectiveEndDate > EffectiveStartDate),
        CONSTRAINT CK_DimCustomer_Current CHECK
           ((IsCurrent = 1 AND EffectiveEndDate IS NULL)
            OR (IsCurrent = 0 AND EffectiveEndDate IS NOT NULL))
    );
END;
    ';
    -- Create DimProduct
    EXEC sys.sp_executesql N'-- =============================================
-- GOLD LAYER: DIMPRODUCT
-- Create Product Dimension
-- =============================================

IF OBJECT_ID(''gold.DimProduct'', ''U'') IS NULL
BEGIN

    CREATE TABLE gold.DimProduct
    (
        ProductKey BIGINT IDENTITY(1,1) PRIMARY KEY,

        ProductID VARCHAR(100) NOT NULL,

        ProductCategoryName VARCHAR(200) NULL,

        ProductNameLength INT NULL,

        ProductDescriptionLength INT NULL,

        ProductPhotosQty INT NULL,

        ProductWeightG INT NULL,

        ProductLengthCM INT NULL,

        ProductHeightCM INT NULL,

        ProductWidthCM INT NULL,

        LoadDate DATETIME2(7) NOT NULL
            DEFAULT SYSDATETIME(),

        CONSTRAINT UQ_DimProduct_ProductID
            UNIQUE (ProductID)
    );

    PRINT ''DimProduct table created successfully.'';

END;
    ';
    -- Create DimSeller
    EXEC sys.sp_executesql N'-- ============================================
-- GOLD LAYER: CREATE DIMSELLER
-- ============================================

IF OBJECT_ID(''gold.DimSeller'', ''U'') IS NULL
BEGIN
    CREATE TABLE gold.DimSeller
    (
        SellerKey BIGINT IDENTITY(1,1) PRIMARY KEY,

        SellerID VARCHAR(100) NOT NULL,

        SellerZipCodePrefix VARCHAR(20) NULL,

        SellerCity VARCHAR(200) NULL,

        SellerState VARCHAR(10) NULL,

        LoadDate DATETIME2(7) NOT NULL
            DEFAULT SYSDATETIME(),

        CONSTRAINT UQ_DimSeller_SellerID
            UNIQUE (SellerID)
    );

    PRINT ''DimSeller created successfully.'';
END;
    ';
    -- Create DimDate
    EXEC sys.sp_executesql N'-- ============================================
-- GOLD LAYER: CREATE DIMDATE
-- ============================================

IF OBJECT_ID(''gold.DimDate'', ''U'') IS NULL
BEGIN
    CREATE TABLE gold.DimDate
    (
        DateKey INT PRIMARY KEY,

        FullDate DATE NOT NULL UNIQUE,

        YearNumber INT NOT NULL,

        QuarterNumber INT NOT NULL,

        MonthNumber INT NOT NULL,

        MonthName VARCHAR(20) NOT NULL,

        DayOfMonth INT NOT NULL,

        DayName VARCHAR(20) NOT NULL,

        IsWeekend BIT NOT NULL
    );

    PRINT ''DimDate created successfully.'';
END;
    ';
    -- Create FactSales
    EXEC sys.sp_executesql N'-- ==========================================
-- GOLD LAYER: CREATE FACTSALES
-- ==========================================

IF OBJECT_ID(''gold.FactSales'', ''U'') IS NULL
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

    PRINT ''FactSales created successfully.'';
END;
    ';
    -- Create FactPayments
    EXEC sys.sp_executesql N'IF OBJECT_ID(''gold.FactPayments'', ''U'') IS NULL
    BEGIN
        CREATE TABLE gold.FactPayments
        (
            PaymentKey BIGINT IDENTITY(1,1) PRIMARY KEY,

            OrderID VARCHAR(100) NOT NULL,
            PaymentSequential INT NOT NULL,

            CustomerKey BIGINT NOT NULL,
            DateKey INT NOT NULL,

            PaymentType VARCHAR(100) NULL,
            PaymentInstallments INT NULL,
            PaymentValue DECIMAL(18,2) NULL,

            LoadDate DATETIME2(7) NOT NULL
                DEFAULT SYSDATETIME(),

            CONSTRAINT UQ_FactPayments_OrderPayment
                UNIQUE (OrderID, PaymentSequential),

            CONSTRAINT FK_FactPayments_Customer
                FOREIGN KEY (CustomerKey)
                REFERENCES gold.DimCustomer(CustomerKey),

            CONSTRAINT FK_FactPayments_Date
                FOREIGN KEY (DateKey)
                REFERENCES gold.DimDate(DateKey)
        );
    END;
    ';

    -- Load dimensions before facts (to satisfy FK relationships).
    -- Load DimCustomer
    EXEC sys.sp_executesql N'-- GOLD DIMCUSTOMER: INITIAL SCD TYPE 2 LOAD

;WITH CustomerObservations AS
(
    SELECT
        c.customer_unique_id,
        c.customer_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,
        o.order_purchase_timestamp,

        ROW_NUMBER() OVER
        (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, c.customer_id
        ) AS RowNum,

        LAG(c.customer_city) OVER
        (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, c.customer_id
        ) AS PreviousCity,

        LAG(c.customer_state) OVER
        (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, c.customer_id
        ) AS PreviousState,

        LAG(c.customer_zip_code_prefix) OVER
        (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, c.customer_id
        ) AS PreviousZip

    FROM Olist_Staging.silver.olist_customers c

    INNER JOIN Olist_Staging.silver.olist_orders o
        ON c.customer_id = o.customer_id
),

LocationChanges AS
(
    SELECT
        *,
        CASE
            WHEN RowNum = 1
              OR ISNULL(customer_city, '''') <> ISNULL(PreviousCity, '''')
              OR ISNULL(customer_state, '''') <> ISNULL(PreviousState, '''')
              OR ISNULL(customer_zip_code_prefix, '''') <> ISNULL(PreviousZip, '''')
            THEN 1
            ELSE 0
        END AS IsNewVersion
    FROM CustomerObservations
),

VersionGroups AS
(
    SELECT
        *,
        SUM(IsNewVersion) OVER
        (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, customer_id
            ROWS UNBOUNDED PRECEDING
        ) AS VersionNumber
    FROM LocationChanges
),

VersionStarts AS
(
    SELECT
        customer_unique_id,
        VersionNumber,
        MAX(customer_city) AS CustomerCity,
        MAX(customer_state) AS CustomerState,
        MAX(customer_zip_code_prefix) AS CustomerZipCodePrefix,
        MIN(order_purchase_timestamp) AS EffectiveStartDate

    FROM VersionGroups

    GROUP BY
        customer_unique_id,
        VersionNumber
),

CustomerHistory AS
(
    SELECT
        *,
        LEAD(EffectiveStartDate) OVER
        (
            PARTITION BY customer_unique_id
            ORDER BY VersionNumber
        ) AS EffectiveEndDate

    FROM VersionStarts
)

INSERT INTO gold.DimCustomer
(
    CustomerUniqueID,
    CustomerCity,
    CustomerState,
    CustomerZipCodePrefix,
    EffectiveStartDate,
    EffectiveEndDate,
    IsCurrent
)

SELECT
    h.customer_unique_id,
    h.CustomerCity,
    h.CustomerState,
    h.CustomerZipCodePrefix,
    h.EffectiveStartDate,
    h.EffectiveEndDate,

    CASE
        WHEN h.EffectiveEndDate IS NULL THEN 1
        ELSE 0
    END

FROM CustomerHistory h

WHERE NOT EXISTS
(
    SELECT 1
    FROM gold.DimCustomer d
    WHERE d.CustomerUniqueID = h.customer_unique_id
      AND d.EffectiveStartDate = h.EffectiveStartDate
);
    ';
    -- Load DimProduct
    EXEC sys.sp_executesql N'-- =============================================
-- LOAD PRODUCTS FROM SILVER INTO GOLD
-- =============================================

INSERT INTO gold.DimProduct
(
    ProductID,
    ProductCategoryName,
    ProductNameLength,
    ProductDescriptionLength,
    ProductPhotosQty,
    ProductWeightG,
    ProductLengthCM,
    ProductHeightCM,
    ProductWidthCM
)

SELECT
    p.product_id,
    p.product_category_name,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm

FROM Olist_Staging.silver.olist_products p

WHERE NOT EXISTS
(
    SELECT 1
    FROM gold.DimProduct d
    WHERE d.ProductID = p.product_id
);

PRINT ''DimProduct loading completed.'';


-- =============================================
    ';
    -- Load DimSeller
    EXEC sys.sp_executesql N'-- ============================================
-- LOAD SELLERS FROM SILVER
-- ============================================

INSERT INTO gold.DimSeller
(
    SellerID,
    SellerZipCodePrefix,
    SellerCity,
    SellerState
)

SELECT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state

FROM Olist_Staging.silver.olist_sellers s

WHERE NOT EXISTS
(
    SELECT 1
    FROM gold.DimSeller d
    WHERE d.SellerID = s.seller_id
);

PRINT ''DimSeller loading completed.'';

-- ============================================
    ';
    -- Load DimDate
    EXEC sys.sp_executesql N'-- ============================================
-- LOAD DIMDATE
-- ============================================

;WITH DateRange AS
(
    SELECT
        CAST(MIN(order_purchase_timestamp) AS DATE)
            AS StartDate,

        CAST(MAX(order_purchase_timestamp) AS DATE)
            AS EndDate

    FROM Olist_Staging.silver.olist_orders
    WHERE order_purchase_timestamp IS NOT NULL
),

DateSeries AS
(
    SELECT
        StartDate AS FullDate,
        EndDate
    FROM DateRange
    WHERE StartDate IS NOT NULL

    UNION ALL

    SELECT
        DATEADD(DAY, 1, FullDate),
        EndDate
    FROM DateSeries
    WHERE FullDate < EndDate
)

INSERT INTO gold.DimDate
(
    DateKey,
    FullDate,
    YearNumber,
    QuarterNumber,
    MonthNumber,
    MonthName,
    DayOfMonth,
    DayName,
    IsWeekend
)

SELECT
    YEAR(d.FullDate) * 10000
        + MONTH(d.FullDate) * 100
        + DAY(d.FullDate),

    d.FullDate,

    YEAR(d.FullDate),

    DATEPART(QUARTER, d.FullDate),

    MONTH(d.FullDate),

    DATENAME(MONTH, d.FullDate),

    DAY(d.FullDate),

    DATENAME(WEEKDAY, d.FullDate),

    CASE
        WHEN DATEDIFF(DAY, ''19000101'', d.FullDate) % 7
             IN (5, 6)
        THEN 1
        ELSE 0
    END

FROM DateSeries d

WHERE NOT EXISTS
(
    SELECT 1
    FROM gold.DimDate existing
    WHERE existing.FullDate = d.FullDate
)

OPTION (MAXRECURSION 0);

PRINT ''DimDate loading completed.'';

-- ============================================
    ';
    -- Load FactSales
    EXEC sys.sp_executesql N'INSERT INTO gold.FactSales
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
    ';
    -- Load FactPayments
    EXEC sys.sp_executesql N'INSERT INTO gold.FactPayments
    (
        OrderID,
        PaymentSequential,
        CustomerKey,
        DateKey,
        PaymentType,
        PaymentInstallments,
        PaymentValue
    )

    SELECT
        p.order_id,
        p.payment_sequential,

        dc.CustomerKey,
        dd.DateKey,

        p.payment_type,
        p.payment_installments,
        p.payment_value

    FROM Olist_Staging.silver.olist_order_payments p

    INNER JOIN Olist_Staging.silver.olist_orders o
        ON p.order_id = o.order_id

    INNER JOIN Olist_Staging.silver.olist_customers c
        ON o.customer_id = c.customer_id

    INNER JOIN gold.DimCustomer dc
        ON dc.CustomerUniqueID = c.customer_unique_id
        AND o.order_purchase_timestamp >= dc.EffectiveStartDate
        AND (
            o.order_purchase_timestamp < dc.EffectiveEndDate
            OR dc.EffectiveEndDate IS NULL
        )

    INNER JOIN gold.DimDate dd
        ON CAST(o.order_purchase_timestamp AS DATE) = dd.FullDate

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM gold.FactPayments f
        WHERE f.OrderID = p.order_id
          AND f.PaymentSequential = p.payment_sequential
    );
    ';
    -- Validate six Gold row counts and fact relationships
    EXEC sys.sp_executesql N'-- Essential completeness checks against expected static Olist snapshot.
IF (SELECT COUNT_BIG(*) FROM gold.DimCustomer) <> 96355
    THROW 51010, ''DimCustomer: unexpected row count; Gold load rolled back.'', 1;
IF (SELECT COUNT_BIG(*) FROM gold.DimProduct) <> 32951
    THROW 51011, ''DimProduct: unexpected row count; Gold load rolled back.'', 1;
IF (SELECT COUNT_BIG(*) FROM gold.DimSeller) <> 3095
    THROW 51012, ''DimSeller: unexpected row count; Gold load rolled back.'', 1;
IF (SELECT COUNT_BIG(*) FROM gold.DimDate) <> 774
    THROW 51013, ''DimDate: unexpected row count; Gold load rolled back.'', 1;
IF (SELECT COUNT_BIG(*) FROM gold.FactSales) <> 112650
    THROW 51014, ''FactSales: unexpected row count; Gold load rolled back.'', 1;
IF (SELECT COUNT_BIG(*) FROM gold.FactPayments) <> 103886
    THROW 51015, ''FactPayments: unexpected row count; Gold load rolled back.'', 1;

-- Verify fact relationships; foreign keys enforce referential integrity on
    -- newly created tables, while these tests also cover pre-existing tables.
    IF EXISTS
    (
        SELECT 1 FROM gold.FactSales AS f
        LEFT JOIN gold.DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        LEFT JOIN gold.DimProduct AS p ON p.ProductKey = f.ProductKey
        LEFT JOIN gold.DimSeller AS s ON s.SellerKey = f.SellerKey
        LEFT JOIN gold.DimDate AS d ON d.DateKey = f.DateKey
        WHERE c.CustomerKey IS NULL OR p.ProductKey IS NULL
           OR s.SellerKey IS NULL OR d.DateKey IS NULL
    )
        THROW 51016, ''FactSales has missing dimension keys; load rolled back.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM gold.FactPayments AS f
        LEFT JOIN gold.DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        LEFT JOIN gold.DimDate AS d ON d.DateKey = f.DateKey
        WHERE c.CustomerKey IS NULL OR d.DateKey IS NULL
    )
        THROW 51017, ''FactPayments has missing dimension keys; load rolled back.'', 1;
    ';

    COMMIT TRANSACTION;
    PRINT 'Gold tables loaded and verified. Existing rows were preserved.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
