-- BrightLearn | Olist Data Engineering 2026
-- Eight business analytics questions. Read-only; SQL Server T-SQL.
-- Monetary values are in BRL. Gold facts include all recorded statuses.
-- Item value is not net revenue or profit; payment value is separate.
-- Run the entire file in SSMS. Expect eight result sets, Q01-Q08.
USE Olist_DWH;
SET NOCOUNT ON;

-- Q01: What is the overall sales activity and average order item value?
-- Average order value here means sum of item prices / orders with items.
SELECT
    'Q01' AS Question,
    COUNT(DISTINCT OrderID) AS Orders_With_Items,
    COUNT_BIG(*) AS Order_Items,
    SUM(ItemPrice) AS Total_Item_Value_BRL,
    SUM(FreightValue) AS Total_Freight_BRL,
    CAST(SUM(ItemPrice) / NULLIF(COUNT(DISTINCT OrderID), 0)
         AS DECIMAL(18,2)) AS Avg_Order_Value_Excl_Freight_BRL
FROM gold.FactSales;

-- Q02: How do order volume and item value change by month?
-- Months with recorded items only, grouped by purchase date.
SELECT
    'Q02' AS Question,
    DATEFROMPARTS(d.YearNumber, d.MonthNumber, 1) AS Purchase_Month,
    COUNT(DISTINCT f.OrderID) AS Orders_With_Items,
    SUM(f.ItemPrice) AS Item_Value_BRL
FROM gold.FactSales AS f
INNER JOIN gold.DimDate AS d ON f.DateKey = d.DateKey
GROUP BY d.YearNumber, d.MonthNumber
ORDER BY d.YearNumber, d.MonthNumber;

-- Q03: Which ten product categories generate the highest item value?
-- Retain the original category names from DimProduct (Portuguese).
;WITH CategorySales AS
(
    SELECT
        COALESCE(NULLIF(LTRIM(RTRIM(p.ProductCategoryName)), ''),
                 '(Unknown)') AS Product_Category,
        f.OrderID, f.ItemPrice
    FROM gold.FactSales AS f
    INNER JOIN gold.DimProduct AS p ON f.ProductKey = p.ProductKey
)
SELECT TOP (10)
    'Q03' AS Question,
    Product_Category,
    COUNT_BIG(*) AS Order_Items,
    COUNT(DISTINCT OrderID) AS Orders_With_Category,
    SUM(ItemPrice) AS Item_Value_BRL
FROM CategorySales
GROUP BY Product_Category
ORDER BY SUM(ItemPrice) DESC, Product_Category;

-- Q04: Which ten sellers generate the highest item value?
-- An order may contain items from more than one seller.
SELECT TOP (10)
    'Q04' AS Question,
    s.SellerID,
    s.SellerState,
    COUNT(DISTINCT f.OrderID) AS Orders_With_Seller,
    SUM(f.ItemPrice) AS Item_Value_BRL
FROM gold.FactSales AS f
INNER JOIN gold.DimSeller AS s ON f.SellerKey = s.SellerKey
GROUP BY s.SellerID, s.SellerState
ORDER BY SUM(f.ItemPrice) DESC, s.SellerID;

-- Q05: Which ten customer states have the most orders with items?
-- SCD2 customer state is the version associated with the purchase.
;WITH StateSales AS
(
    SELECT
        COALESCE(NULLIF(LTRIM(RTRIM(c.CustomerState)), ''),
                 '(Unknown)') AS Customer_State,
        c.CustomerUniqueID, f.OrderID, f.ItemPrice
    FROM gold.FactSales AS f
    INNER JOIN gold.DimCustomer AS c ON f.CustomerKey = c.CustomerKey
)
SELECT TOP (10)
    'Q05' AS Question,
    Customer_State,
    COUNT(DISTINCT CustomerUniqueID) AS Distinct_Customers,
    COUNT(DISTINCT OrderID) AS Orders_With_Items,
    SUM(ItemPrice) AS Item_Value_BRL
FROM StateSales
GROUP BY Customer_State
ORDER BY COUNT(DISTINCT OrderID) DESC, Customer_State;

-- Q06: Which payment methods are most frequently recorded?
-- Grain: one payment sequence; an order can use several methods.
;WITH PaymentMethods AS
(
    SELECT
        COALESCE(NULLIF(LTRIM(RTRIM(PaymentType)), ''),
                 '(Unknown)') AS Payment_Method,
        OrderID, PaymentValue
    FROM gold.FactPayments
)
SELECT
    'Q06' AS Question,
    Payment_Method,
    COUNT_BIG(*) AS Payment_Records,
    CAST(100.0 * COUNT_BIG(*) /
         NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
         AS DECIMAL(9,2)) AS Pct_Of_Payment_Records,
    COUNT(DISTINCT OrderID) AS Orders_Using_Method,
    SUM(PaymentValue) AS Payment_Value_BRL
FROM PaymentMethods
GROUP BY Payment_Method
ORDER BY COUNT_BIG(*) DESC, Payment_Method;

-- Q07: What proportion of purchasing customers have repeat orders?
-- Use the durable customer business key, not the SCD2 surrogate key.
-- Only customers with at least one order in FactSales are counted.
;WITH CustomerOrders AS
(
    SELECT c.CustomerUniqueID,
           COUNT(DISTINCT f.OrderID) AS Order_Count
    FROM gold.FactSales AS f
    INNER JOIN gold.DimCustomer AS c ON f.CustomerKey = c.CustomerKey
    GROUP BY c.CustomerUniqueID
)
SELECT
    'Q07' AS Question,
    COUNT_BIG(*) AS Purchasing_Customers,
    COUNT_BIG(CASE WHEN Order_Count = 1 THEN 1 END) AS Single_Order_Customers,
    COUNT_BIG(CASE WHEN Order_Count > 1 THEN 1 END) AS Repeat_Customers,
    CAST(100.0 * COUNT_BIG(CASE WHEN Order_Count > 1 THEN 1 END) /
         NULLIF(COUNT_BIG(*), 0) AS DECIMAL(9,2)) AS Repeat_Customer_Pct
FROM CustomerOrders;

-- Q08: What is the delivered-order on-time rate and average delivery time?
-- Use Silver orders: Gold does not store actual/estimated delivery dates.
-- On time = delivered on or before the estimated calendar date.
-- Exclude delivered orders with missing required dates or delivery before
-- purchase; show the excluded count explicitly. Never modify source dates.
;WITH DeliveredOrders AS
(
    SELECT order_purchase_timestamp, order_delivered_customer_date,
           order_estimated_delivery_date,
           CASE WHEN order_purchase_timestamp IS NOT NULL
                  AND order_delivered_customer_date IS NOT NULL
                  AND order_estimated_delivery_date IS NOT NULL
                  AND order_delivered_customer_date >= order_purchase_timestamp
                THEN 1 ELSE 0 END AS Eligible
    FROM Olist_Staging.silver.olist_orders
    WHERE order_status = 'delivered'
), DeliveryMetrics AS
(
    SELECT Eligible,
           CASE WHEN Eligible = 1 THEN
                CASE WHEN CAST(order_delivered_customer_date AS DATE) <=
                          CAST(order_estimated_delivery_date AS DATE)
                     THEN 1 ELSE 0 END END AS OnTime,
           CASE WHEN Eligible = 1 THEN
                DATEDIFF_BIG(SECOND, order_purchase_timestamp,
                             order_delivered_customer_date) / 86400.0
           END AS DeliveryDays
    FROM DeliveredOrders
)
SELECT
    'Q08' AS Question,
    COUNT_BIG(*) AS Delivered_Status_Orders,
    COUNT_BIG(CASE WHEN Eligible = 1 THEN 1 END) AS Eligible_Orders,
    COUNT_BIG(CASE WHEN Eligible = 0 THEN 1 END) AS Excluded_Orders,
    COUNT_BIG(CASE WHEN OnTime = 1 THEN 1 END) AS On_Time_Orders,
    COUNT_BIG(CASE WHEN OnTime = 0 THEN 1 END) AS Late_Orders,
    CAST(100.0 * COUNT_BIG(CASE WHEN OnTime = 1 THEN 1 END) /
         NULLIF(COUNT_BIG(CASE WHEN Eligible = 1 THEN 1 END), 0)
         AS DECIMAL(9,2)) AS On_Time_Pct,
    CAST(AVG(DeliveryDays) AS DECIMAL(18,2)) AS Avg_Delivery_Days
FROM DeliveryMetrics;

-- END OF SCRIPT: all eight questions completed.
