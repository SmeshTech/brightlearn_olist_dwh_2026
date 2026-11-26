USE Olist_DWH;
GO

-- ============================================
-- GOLD LAYER: CREATE DIMSELLER
-- ============================================

IF OBJECT_ID('gold.DimSeller', 'U') IS NULL
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

    PRINT 'DimSeller created successfully.';
END;
GO

-- ============================================
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

PRINT 'DimSeller loading completed.';

-- ============================================
-- VALIDATE DIMSELLER
-- ============================================

SELECT
    (SELECT COUNT(*)
     FROM Olist_Staging.silver.olist_sellers)
        AS Silver_Seller_Rows,

    COUNT(*) AS Gold_Seller_Rows,

    COUNT(DISTINCT SellerID)
        AS Unique_Seller_IDs,

    COUNT(*) - COUNT(DISTINCT SellerID)
        AS Duplicate_Seller_IDs,

    SUM(
        CASE
            WHEN SellerID IS NULL
                 OR LTRIM(RTRIM(SellerID)) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Seller_IDs

FROM gold.DimSeller;