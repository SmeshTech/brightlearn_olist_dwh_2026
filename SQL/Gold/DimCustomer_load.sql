USE Olist_DWH;
GO

-- GOLD DIMCUSTOMER: INITIAL SCD TYPE 2 LOAD

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
              OR ISNULL(customer_city, '') <> ISNULL(PreviousCity, '')
              OR ISNULL(customer_state, '') <> ISNULL(PreviousState, '')
              OR ISNULL(customer_zip_code_prefix, '') <> ISNULL(PreviousZip, '')
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

-- VERIFY THE INITIAL LOAD

SELECT
    COUNT(*) AS Total_DimCustomer_Rows,

    COUNT(DISTINCT CustomerUniqueID)
        AS Unique_Customers,

    SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END)
        AS Current_Customer_Records,

    SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END)
        AS Historical_Customer_Records

FROM gold.DimCustomer;