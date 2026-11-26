USE Olist_DWH;
GO

-- =============================================
-- GOLD LAYER: DIMPRODUCT
-- Create Product Dimension
-- =============================================

IF OBJECT_ID('gold.DimProduct', 'U') IS NULL
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

    PRINT 'DimProduct table created successfully.';

END;
GO


-- =============================================
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

PRINT 'DimProduct loading completed.';


-- =============================================
-- VALIDATE GOLD DIMPRODUCT
-- =============================================

SELECT
    (SELECT COUNT(*)
     FROM Olist_Staging.silver.olist_products)
        AS Silver_Product_Rows,

    COUNT(*) AS Gold_Product_Rows,

    COUNT(DISTINCT ProductID)
        AS Unique_Product_IDs,

    COUNT(*) - COUNT(DISTINCT ProductID)
        AS Duplicate_Product_IDs,

    SUM(
        CASE
            WHEN ProductID IS NULL
                 OR LTRIM(RTRIM(ProductID)) = ''
            THEN 1
            ELSE 0
        END
    ) AS Missing_Product_IDs

FROM gold.DimProduct;