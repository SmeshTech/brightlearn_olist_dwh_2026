USE Olist_DWH;
GO

-- ============================================
-- GOLD LAYER: CREATE DIMDATE
-- ============================================

IF OBJECT_ID('gold.DimDate', 'U') IS NULL
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

    PRINT 'DimDate created successfully.';
END;
GO

-- ============================================
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
        WHEN DATEDIFF(DAY, '19000101', d.FullDate) % 7
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

PRINT 'DimDate loading completed.';

-- ============================================
-- VALIDATE DIMDATE
-- ============================================

SELECT
    COUNT(*) AS Total_Dates,

    MIN(FullDate) AS Earliest_Date,

    MAX(FullDate) AS Latest_Date,

    COUNT(DISTINCT DateKey) AS Unique_Date_Keys,

    COUNT(*) - COUNT(DISTINCT DateKey)
        AS Duplicate_Date_Keys

FROM gold.DimDate;