USE Olist_DWH;
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ============================================
    -- CREATE GOLD FACTPAYMENTS
    -- ============================================

    IF OBJECT_ID('gold.FactPayments', 'U') IS NULL
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

    -- ============================================
    -- LOAD PAYMENTS FROM SILVER
    -- ============================================

    INSERT INTO gold.FactPayments
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

    -- ============================================
    -- ESSENTIAL ROW COUNT VALIDATION
    -- ============================================

    IF
    (
        SELECT COUNT_BIG(*)
        FROM gold.FactPayments
    ) <>
    (
        SELECT COUNT_BIG(*)
        FROM Olist_Staging.silver.olist_order_payments
    )
    BEGIN
        THROW 51001,
            'FactPayments row count mismatch. Load rolled back.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'FactPayments loaded successfully.';

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- ============================================
-- VALIDATE GOLD FACTPAYMENTS
-- ============================================

SELECT
    (SELECT COUNT(*)
     FROM Olist_Staging.silver.olist_order_payments)
        AS Silver_Payment_Rows,

    COUNT(*) AS Gold_Payment_Rows,

    COUNT(DISTINCT PaymentKey)
        AS Unique_Payment_Keys,

    COUNT(*) - COUNT(DISTINCT PaymentKey)
        AS Duplicate_Payment_Keys,

    SUM(PaymentValue)
        AS Total_Payment_Value

FROM gold.FactPayments;