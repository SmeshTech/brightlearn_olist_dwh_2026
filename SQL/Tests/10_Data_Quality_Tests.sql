-- BrightLearn Olist Data Engineering 2026
-- Ten read-only checks, revised to avoid UNION ALL.
-- Only a session-local table variable receives rows; no warehouse data is changed.
-- Execute the entire file in SSMS after row-count validation.
USE Olist_DWH;
SET NOCOUNT ON;

DECLARE @TestResults TABLE
(
    TestID INT NOT NULL PRIMARY KEY,
    TestName VARCHAR(150) NOT NULL,
    FailureCount BIGINT NOT NULL
);

-- 01: Required customer IDs; one row per customer_id in Silver.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 1 AS TestID, 'Silver customer IDs valid and unique' AS TestName,
       COUNT_BIG(*) AS FailureCount
FROM
(
    SELECT customer_id
    FROM Olist_Staging.silver.olist_customers
    GROUP BY customer_id
    HAVING COUNT_BIG(*) > 1 OR NULLIF(LTRIM(RTRIM(customer_id)), '') IS NULL
) AS InvalidCustomers;

-- 02: Required order IDs; one row per order_id in Silver.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 2, 'Silver order IDs valid and unique', COUNT_BIG(*)
FROM
(
    SELECT order_id
    FROM Olist_Staging.silver.olist_orders
    GROUP BY order_id
    HAVING COUNT_BIG(*) > 1 OR NULLIF(LTRIM(RTRIM(order_id)), '') IS NULL
) AS InvalidOrders;

-- 03: Every Silver order has a matching customer.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 3, 'Silver orders have matching customers', COUNT_BIG(*)
FROM Olist_Staging.silver.olist_orders o
WHERE NOT EXISTS
(
    SELECT 1 FROM Olist_Staging.silver.olist_customers c
    WHERE c.customer_id = o.customer_id
);

-- 04: Exactly one current SCD2 version per source customer_unique_id.
;WITH SourceCustomers AS
(
    SELECT customer_unique_id
    FROM Olist_Staging.silver.olist_customers
    GROUP BY customer_unique_id
),
CustomerVersions AS
(
    SELECT CustomerUniqueID,
           SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentVersions
    FROM gold.DimCustomer
    GROUP BY CustomerUniqueID
)
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 4, 'DimCustomer has one current version per source customer', COUNT_BIG(*)
FROM SourceCustomers s
FULL OUTER JOIN CustomerVersions d ON s.customer_unique_id = d.CustomerUniqueID
WHERE s.customer_unique_id IS NULL OR d.CustomerUniqueID IS NULL
   OR d.CurrentVersions <> 1;

-- 05: Valid, contiguous SCD2 periods; final version is current.
;WITH CustomerTimeline AS
(
    SELECT CustomerUniqueID, EffectiveStartDate, EffectiveEndDate, IsCurrent,
           LEAD(EffectiveStartDate) OVER
           (PARTITION BY CustomerUniqueID ORDER BY EffectiveStartDate, CustomerKey) AS NextStart
    FROM gold.DimCustomer
)
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 5, 'DimCustomer history dates and current flags valid', COUNT_BIG(*)
FROM CustomerTimeline
WHERE EffectiveStartDate IS NULL
   OR (EffectiveEndDate IS NOT NULL AND EffectiveEndDate <= EffectiveStartDate)
   OR (NextStart IS NOT NULL AND
       (EffectiveEndDate IS NULL OR EffectiveEndDate <> NextStart OR IsCurrent <> 0))
   OR (NextStart IS NULL AND (EffectiveEndDate IS NOT NULL OR IsCurrent <> 1))
   OR IsCurrent IS NULL;

-- 06: Every source sales key appears exactly once in each layer.
;WITH SilverSalesGrain AS
(
    SELECT order_id, order_item_id, COUNT_BIG(*) AS Copies
    FROM Olist_Staging.silver.olist_order_items
    GROUP BY order_id, order_item_id
),
GoldSalesGrain AS
(
    SELECT OrderID, OrderItemID, COUNT_BIG(*) AS Copies
    FROM gold.FactSales
    GROUP BY OrderID, OrderItemID
)
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 6, 'FactSales grain unique and matches Silver', COUNT_BIG(*)
FROM SilverSalesGrain s
FULL OUTER JOIN GoldSalesGrain g
  ON s.order_id = g.OrderID AND s.order_item_id = g.OrderItemID
WHERE ISNULL(s.Copies, 0) <> 1 OR ISNULL(g.Copies, 0) <> 1
   OR s.order_id IS NULL OR s.order_item_id IS NULL
   OR g.OrderID IS NULL OR g.OrderItemID IS NULL;

-- 07: Every source payment key appears exactly once in each layer.
;WITH SilverPaymentsGrain AS
(
    SELECT order_id, payment_sequential, COUNT_BIG(*) AS Copies
    FROM Olist_Staging.silver.olist_order_payments
    GROUP BY order_id, payment_sequential
),
GoldPaymentsGrain AS
(
    SELECT OrderID, PaymentSequential, COUNT_BIG(*) AS Copies
    FROM gold.FactPayments
    GROUP BY OrderID, PaymentSequential
)
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 7, 'FactPayments grain unique and matches Silver', COUNT_BIG(*)
FROM SilverPaymentsGrain s
FULL OUTER JOIN GoldPaymentsGrain g
  ON s.order_id = g.OrderID AND s.payment_sequential = g.PaymentSequential
WHERE ISNULL(s.Copies, 0) <> 1 OR ISNULL(g.Copies, 0) <> 1
   OR s.order_id IS NULL OR s.payment_sequential IS NULL
   OR g.OrderID IS NULL OR g.PaymentSequential IS NULL;

-- 08: Sales fact dimension references must exist.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 8, 'FactSales dimension keys valid', COUNT_BIG(*)
FROM gold.FactSales f
LEFT JOIN gold.DimCustomer c ON f.CustomerKey = c.CustomerKey
LEFT JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
LEFT JOIN gold.DimSeller s ON f.SellerKey = s.SellerKey
LEFT JOIN gold.DimDate d ON f.DateKey = d.DateKey
WHERE c.CustomerKey IS NULL OR p.ProductKey IS NULL
   OR s.SellerKey IS NULL OR d.DateKey IS NULL;

-- 09: Payments fact dimension references must exist.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 9, 'FactPayments dimension keys valid', COUNT_BIG(*)
FROM gold.FactPayments f
LEFT JOIN gold.DimCustomer c ON f.CustomerKey = c.CustomerKey
LEFT JOIN gold.DimDate d ON f.DateKey = d.DateKey
WHERE c.CustomerKey IS NULL OR d.DateKey IS NULL;

-- 10: Reconcile monetary values per matched source record, to cents.
-- Tests 06 and 07 independently check for missing/extra/duplicate keys.
INSERT INTO @TestResults (TestID, TestName, FailureCount)
SELECT 10, 'Gold monetary values match Silver',
       (SELECT COUNT_BIG(*)
        FROM gold.FactSales f
        INNER JOIN Olist_Staging.silver.olist_order_items s
          ON f.OrderID = s.order_id AND f.OrderItemID = s.order_item_id
        WHERE EXISTS
        (
            SELECT f.ItemPrice, f.FreightValue
            EXCEPT
            SELECT CONVERT(DECIMAL(18,2), s.price),
                   CONVERT(DECIMAL(18,2), s.freight_value)
        ))
       +
       (SELECT COUNT_BIG(*)
        FROM gold.FactPayments f
        INNER JOIN Olist_Staging.silver.olist_order_payments s
          ON f.OrderID = s.order_id AND f.PaymentSequential = s.payment_sequential
        WHERE EXISTS
        (
            SELECT f.PaymentValue
            EXCEPT
            SELECT CONVERT(DECIMAL(18,2), s.payment_value)
        ));

-- Final report: one row per test.
SELECT TestID, TestName, FailureCount,
       CASE WHEN FailureCount = 0 THEN 'PASS' ELSE 'FAIL' END AS TestStatus
FROM @TestResults
ORDER BY TestID;