# Olist Data Warehouse — Data Dictionary

**BrightLearn | Olist Data Engineering 2026**  
**Source of schema facts:** `Olist_Table_Metadata.csv`, exported from SQL Server `INFORMATION_SCHEMA.COLUMNS` on 20 November 2026.  
**Scope:** `Olist_Staging.bronze` (9 tables), `Olist_Staging.silver` (9 tables), `Olist_DWH.gold` (6 tables).  
**Coverage:** **24 tables; 160 columns.**  
**Record counts:** latest confirmed project snapshot from post-rerun validation on 17 November 2026; not derived from the metadata CSV.

## How to read this dictionary

- **Data type / nullable**: reproduced from the uploaded SQL Server metadata. `YES` permits SQL `NULL`; `NO` does not. `nvarchar(MAX)` means the metadata reported a length of `-1`.
- **Key / role**: business or relational meaning inferred from the field name, warehouse SQL, and prior validation. **¹** PK/FK/unique designations come from the supplied *Gold table creation SQL*, not from a live SQL Server constraints query; they must be confirmed on existing tables before claiming they are physically enforced.
- **Business description**: descriptive documentation of source or transformation meaning, not a guarantee that a source value is always present or valid.
- **Gold customer history**: the SCD Type 2 version starts reflect observed order purchase timestamps when recorded city/state/ZIP changes, **not proven physical relocation dates**.
- **Currency**: item prices, freight amounts, and payment values are expressed in Brazilian reais (BRL). Sales item price is not the same as net revenue or profit.
- **Snapshot caveat**: expected row counts and the master pipeline checks are tailored to the current static Olist dataset; an incremental new-data pipeline has not been verified.

## Bronze layer — `Olist_Staging.bronze`

Raw source ingestion; source values such as dates and money commonly remain text.

| Table | Purpose | Grain | Validated rows |
|---|---|---|---:|
| [`olist_customers`](#bronze-olist-customers) | Customer records associated with orders | One row per customer_id (order-associated customer record) | 99,441 |
| [`olist_geolocation`](#bronze-olist-geolocation) | Geographic observations by postal-code prefix | One row per source geolocation observation; zip prefixes can repeat | 1,000,163 |
| [`olist_order_items`](#bronze-olist-order-items) | Individual line items making up orders | One row per (order_id, order_item_id) | 112,650 |
| [`olist_order_payments`](#bronze-olist-order-payments) | Order payment entries | One row per (order_id, payment_sequential) | 103,886 |
| [`olist_order_reviews`](#bronze-olist-order-reviews) | Ratings and optional comments left for orders | One row per source review record (order_id may repeat) | 99,224 |
| [`olist_orders`](#bronze-olist-orders) | Order headers and lifecycle timestamps | One row per order_id | 99,441 |
| [`olist_products`](#bronze-olist-products) | Products and listing attributes | One row per product_id | 32,951 |
| [`olist_sellers`](#bronze-olist-sellers) | Seller identities and locations | One row per seller_id | 3,095 |
| [`product_category_translation`](#bronze-product-category-translation) | Portuguese-to-English category translation lookup | One row per Portuguese/English category pair in the validated snapshot | 71 |

<a id="bronze-olist-customers"></a>
### bronze: `olist_customers`

**Physical table:** `Olist_Staging.bronze.olist_customers`  
**Purpose:** Customer records associated with orders.  
**Grain:** One row per customer_id (order-associated customer record).  
**Primary source:** `customers CSV`  
**Columns:** 5 | **Verified rows:** 99,441

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `customer_id` | `varchar(100)` | YES | Logical record identifier | Identifier for the customer record linked to an order; distinct from the repeat-buyer identifier. |
| `customer_unique_id` | `varchar(100)` | YES | Repeat-buyer business ID | Identifier used to recognize the same underlying customer across multiple customer records. |
| `customer_zip_code_prefix` | `varchar(20)` | YES | — | First five digits of the customer postal code, stored as text to preserve leading zeros. |
| `customer_city` | `varchar(200)` | YES | — | Customer city as provided by the source. |
| `customer_state` | `varchar(10)` | YES | — | Two-character Brazilian state abbreviation for the customer. |

<a id="bronze-olist-geolocation"></a>
### bronze: `olist_geolocation`

**Physical table:** `Olist_Staging.bronze.olist_geolocation`  
**Purpose:** Geographic observations by postal-code prefix.  
**Grain:** One row per source geolocation observation; zip prefixes can repeat.  
**Primary source:** `geolocation CSV`  
**Columns:** 5 | **Verified rows:** 1,000,163

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `geolocation_zip_code_prefix` | `varchar(50)` | YES | — | Postal-code prefix for a geolocation observation; multiple records can share a prefix. |
| `geolocation_lat` | `varchar(50)` | YES | — | Latitude of the geographic observation, in decimal degrees. |
| `geolocation_lng` | `varchar(50)` | YES | — | Longitude of the geographic observation, in decimal degrees. |
| `geolocation_city` | `varchar(200)` | YES | — | City recorded for the geographic observation. |
| `geolocation_state` | `varchar(50)` | YES | — | Brazilian state abbreviation for the geographic observation. |

<a id="bronze-olist-order-items"></a>
### bronze: `olist_order_items`

**Physical table:** `Olist_Staging.bronze.olist_order_items`  
**Purpose:** Individual line items making up orders.  
**Grain:** One row per (order_id, order_item_id).  
**Primary source:** `order_items CSV`  
**Columns:** 7 | **Verified rows:** 112,650

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `varchar(100)` | YES | Composite logical key part | Identifier of the customer order; joins order-level and item/payment/review records. |
| `order_item_id` | `varchar(20)` | YES | Composite logical key part | Item sequence number within an order; combines with order_id to identify one line item. |
| `product_id` | `varchar(100)` | YES | Product reference | Source-system identifier of the product associated with an item. |
| `seller_id` | `varchar(100)` | YES | Seller reference | Source-system identifier of the seller fulfilling an item. |
| `shipping_limit_date` | `varchar(50)` | YES | — | Deadline by which the seller is expected to hand off the order item for shipment. |
| `price` | `varchar(50)` | YES | — | Recorded selling price of the order item in Brazilian reais (BRL), excluding freight. |
| `freight_value` | `varchar(50)` | YES | — | Recorded freight charge for the order item in Brazilian reais (BRL). |

<a id="bronze-olist-order-payments"></a>
### bronze: `olist_order_payments`

**Physical table:** `Olist_Staging.bronze.olist_order_payments`  
**Purpose:** Order payment entries.  
**Grain:** One row per (order_id, payment_sequential).  
**Primary source:** `order_payments CSV`  
**Columns:** 5 | **Verified rows:** 103,886

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `varchar(100)` | YES | Composite logical key part | Identifier of the customer order; joins order-level and item/payment/review records. |
| `payment_sequential` | `varchar(20)` | YES | Composite logical key part | Sequence number distinguishing payment records attached to the same order. |
| `payment_type` | `varchar(50)` | YES | — | Payment method recorded for the order payment (for example, credit card or boleto). |
| `payment_installments` | `varchar(20)` | YES | — | Number of installments selected for the payment. |
| `payment_value` | `varchar(50)` | YES | — | Recorded amount of the payment in Brazilian reais (BRL). |

<a id="bronze-olist-order-reviews"></a>
### bronze: `olist_order_reviews`

**Physical table:** `Olist_Staging.bronze.olist_order_reviews`  
**Purpose:** Ratings and optional comments left for orders.  
**Grain:** One row per source review record (order_id may repeat).  
**Primary source:** `order_reviews CSV`  
**Columns:** 7 | **Verified rows:** 99,224

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `review_id` | `nvarchar(100)` | YES | Source review identifier | Source review identifier; uniqueness is not established by this metadata export. |
| `order_id` | `nvarchar(100)` | YES | Order reference | Identifier of the customer order; joins order-level and item/payment/review records. |
| `review_score` | `nvarchar(20)` | YES | — | Customer review rating on the source scoring scale. |
| `review_comment_title` | `nvarchar(1000)` | YES | — | Optional title supplied with the customer review. |
| `review_comment_message` | `nvarchar(MAX)` | YES | — | Optional free-text customer review content. |
| `review_creation_date` | `nvarchar(50)` | YES | — | Timestamp associated with creation of the review. |
| `review_answer_timestamp` | `nvarchar(50)` | YES | — | Timestamp associated with submission of the review response. |

<a id="bronze-olist-orders"></a>
### bronze: `olist_orders`

**Physical table:** `Olist_Staging.bronze.olist_orders`  
**Purpose:** Order headers and lifecycle timestamps.  
**Grain:** One row per order_id.  
**Primary source:** `orders CSV`  
**Columns:** 8 | **Verified rows:** 99,441

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `varchar(100)` | YES | Logical record identifier | Identifier of the customer order; joins order-level and item/payment/review records. |
| `customer_id` | `varchar(100)` | YES | Customer reference | Identifier for the customer record linked to an order; distinct from the repeat-buyer identifier. |
| `order_status` | `varchar(50)` | YES | — | Source order status (for example, delivered or canceled). |
| `order_purchase_timestamp` | `varchar(50)` | YES | — | Timestamp when the customer placed the order. |
| `order_approved_at` | `varchar(50)` | YES | — | Timestamp when the order was approved, if known. |
| `order_delivered_carrier_date` | `varchar(50)` | YES | — | Timestamp when the order was handed over to the carrier, if known. |
| `order_delivered_customer_date` | `varchar(50)` | YES | — | Timestamp when the order was delivered to the customer, if known. |
| `order_estimated_delivery_date` | `varchar(50)` | YES | — | Delivery date estimated for the order. |

<a id="bronze-olist-products"></a>
### bronze: `olist_products`

**Physical table:** `Olist_Staging.bronze.olist_products`  
**Purpose:** Products and listing attributes.  
**Grain:** One row per product_id.  
**Primary source:** `products CSV`  
**Columns:** 9 | **Verified rows:** 32,951

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `product_id` | `varchar(100)` | YES | Logical record identifier | Source-system identifier of the product associated with an item. |
| `product_category_name` | `varchar(200)` | YES | — | Original Portuguese product category name. |
| `product_name_lenght` | `varchar(20)` | YES | — | Number of characters in the product name; source column spelling is preserved (lenght). |
| `product_description_lenght` | `varchar(20)` | YES | — | Number of characters in the product description; source column spelling is preserved (lenght). |
| `product_photos_qty` | `varchar(20)` | YES | — | Number of product listing photos. |
| `product_weight_g` | `varchar(30)` | YES | — | Product weight in grams. |
| `product_length_cm` | `varchar(30)` | YES | — | Product length in centimeters. |
| `product_height_cm` | `varchar(30)` | YES | — | Product height in centimeters. |
| `product_width_cm` | `varchar(30)` | YES | — | Product width in centimeters. |

<a id="bronze-olist-sellers"></a>
### bronze: `olist_sellers`

**Physical table:** `Olist_Staging.bronze.olist_sellers`  
**Purpose:** Seller identities and locations.  
**Grain:** One row per seller_id.  
**Primary source:** `sellers CSV`  
**Columns:** 4 | **Verified rows:** 3,095

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `seller_id` | `varchar(100)` | YES | Logical record identifier | Source-system identifier of the seller fulfilling an item. |
| `seller_zip_code_prefix` | `varchar(20)` | YES | — | First five digits of the seller postal code, stored as text to preserve leading zeros. |
| `seller_city` | `varchar(200)` | YES | — | Seller city as provided by the source. |
| `seller_state` | `varchar(10)` | YES | — | Two-character Brazilian state abbreviation for the seller. |

<a id="bronze-product-category-translation"></a>
### bronze: `product_category_translation`

**Physical table:** `Olist_Staging.bronze.product_category_translation`  
**Purpose:** Portuguese-to-English category translation lookup.  
**Grain:** One row per Portuguese/English category pair in the validated snapshot.  
**Primary source:** `product_category_name_translation CSV`  
**Columns:** 2 | **Verified rows:** 71

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `product_category_name` | `nvarchar(200)` | YES | Lookup category identifier | Original Portuguese product category name. |
| `product_category_name_english` | `nvarchar(200)` | YES | Translated label | English translation of the Portuguese product category name. |

## Silver layer — `Olist_Staging.silver`

Cleaned and data-type-converted source records.

| Table | Purpose | Grain | Validated rows |
|---|---|---|---:|
| [`olist_customers`](#silver-olist-customers) | Customer records associated with orders | One row per customer_id (order-associated customer record) | 99,441 |
| [`olist_geolocation`](#silver-olist-geolocation) | Geographic observations by postal-code prefix | One row per source geolocation observation; zip prefixes can repeat | 1,000,163 |
| [`olist_order_items`](#silver-olist-order-items) | Individual line items making up orders | One row per (order_id, order_item_id) | 112,650 |
| [`olist_order_payments`](#silver-olist-order-payments) | Order payment entries | One row per (order_id, payment_sequential) | 103,886 |
| [`olist_order_reviews`](#silver-olist-order-reviews) | Ratings and optional comments left for orders | One row per source review record (order_id may repeat) | 99,224 |
| [`olist_orders`](#silver-olist-orders) | Order headers and lifecycle timestamps | One row per order_id | 99,441 |
| [`olist_products`](#silver-olist-products) | Products and listing attributes | One row per product_id | 32,951 |
| [`olist_sellers`](#silver-olist-sellers) | Seller identities and locations | One row per seller_id | 3,095 |
| [`product_category_translation`](#silver-product-category-translation) | Portuguese-to-English category translation lookup | One row per Portuguese/English category pair in the validated snapshot | 71 |

<a id="silver-olist-customers"></a>
### silver: `olist_customers`

**Physical table:** `Olist_Staging.silver.olist_customers`  
**Purpose:** Customer records associated with orders.  
**Grain:** One row per customer_id (order-associated customer record).  
**Primary source:** `customers CSV`  
**Columns:** 5 | **Verified rows:** 99,441

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `customer_id` | `varchar(100)` | NO | Logical record identifier | Identifier for the customer record linked to an order; distinct from the repeat-buyer identifier. |
| `customer_unique_id` | `varchar(100)` | NO | Repeat-buyer business ID | Identifier used to recognize the same underlying customer across multiple customer records. |
| `customer_zip_code_prefix` | `varchar(20)` | NO | — | First five digits of the customer postal code, stored as text to preserve leading zeros. |
| `customer_city` | `varchar(200)` | NO | — | Customer city as provided by the source. |
| `customer_state` | `varchar(10)` | NO | — | Two-character Brazilian state abbreviation for the customer. |

<a id="silver-olist-geolocation"></a>
### silver: `olist_geolocation`

**Physical table:** `Olist_Staging.silver.olist_geolocation`  
**Purpose:** Geographic observations by postal-code prefix.  
**Grain:** One row per source geolocation observation; zip prefixes can repeat.  
**Primary source:** `geolocation CSV`  
**Columns:** 6 | **Verified rows:** 1,000,163

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `geolocation_id` | `bigint` | NO | Technical row ID | Technical row identifier assigned to the cleaned geolocation record. |
| `geolocation_zip_code_prefix` | `varchar(50)` | NO | — | Postal-code prefix for a geolocation observation; multiple records can share a prefix. |
| `geolocation_lat` | `decimal(18,12)` | NO | — | Latitude of the geographic observation, in decimal degrees. |
| `geolocation_lng` | `decimal(18,12)` | NO | — | Longitude of the geographic observation, in decimal degrees. |
| `geolocation_city` | `varchar(200)` | NO | — | City recorded for the geographic observation. |
| `geolocation_state` | `varchar(50)` | NO | — | Brazilian state abbreviation for the geographic observation. |

<a id="silver-olist-order-items"></a>
### silver: `olist_order_items`

**Physical table:** `Olist_Staging.silver.olist_order_items`  
**Purpose:** Individual line items making up orders.  
**Grain:** One row per (order_id, order_item_id).  
**Primary source:** `order_items CSV`  
**Columns:** 7 | **Verified rows:** 112,650

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `varchar(100)` | NO | Composite logical key part | Identifier of the customer order; joins order-level and item/payment/review records. |
| `order_item_id` | `int` | NO | Composite logical key part | Item sequence number within an order; combines with order_id to identify one line item. |
| `product_id` | `varchar(100)` | NO | Product reference | Source-system identifier of the product associated with an item. |
| `seller_id` | `varchar(100)` | NO | Seller reference | Source-system identifier of the seller fulfilling an item. |
| `shipping_limit_date` | `datetime2(7)` | YES | — | Deadline by which the seller is expected to hand off the order item for shipment. |
| `price` | `decimal(18,2)` | YES | — | Recorded selling price of the order item in Brazilian reais (BRL), excluding freight. |
| `freight_value` | `decimal(18,2)` | YES | — | Recorded freight charge for the order item in Brazilian reais (BRL). |

<a id="silver-olist-order-payments"></a>
### silver: `olist_order_payments`

**Physical table:** `Olist_Staging.silver.olist_order_payments`  
**Purpose:** Order payment entries.  
**Grain:** One row per (order_id, payment_sequential).  
**Primary source:** `order_payments CSV`  
**Columns:** 5 | **Verified rows:** 103,886

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `varchar(100)` | NO | Composite logical key part | Identifier of the customer order; joins order-level and item/payment/review records. |
| `payment_sequential` | `int` | NO | Composite logical key part | Sequence number distinguishing payment records attached to the same order. |
| `payment_type` | `varchar(50)` | YES | — | Payment method recorded for the order payment (for example, credit card or boleto). |
| `payment_installments` | `int` | YES | — | Number of installments selected for the payment. |
| `payment_value` | `decimal(18,2)` | YES | — | Recorded amount of the payment in Brazilian reais (BRL). |

<a id="silver-olist-order-reviews"></a>
### silver: `olist_order_reviews`

**Physical table:** `Olist_Staging.silver.olist_order_reviews`  
**Purpose:** Ratings and optional comments left for orders.  
**Grain:** One row per source review record (order_id may repeat).  
**Primary source:** `order_reviews CSV`  
**Columns:** 7 | **Verified rows:** 99,224

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `review_id` | `nvarchar(100)` | NO | Source review identifier | Source review identifier; uniqueness is not established by this metadata export. |
| `order_id` | `nvarchar(100)` | NO | Order reference | Identifier of the customer order; joins order-level and item/payment/review records. |
| `review_score` | `int` | NO | — | Customer review rating on the source scoring scale. |
| `review_comment_title` | `nvarchar(1000)` | YES | — | Optional title supplied with the customer review. |
| `review_comment_message` | `nvarchar(MAX)` | YES | — | Optional free-text customer review content. |
| `review_creation_date` | `datetime2(7)` | YES | — | Timestamp associated with creation of the review. |
| `review_answer_timestamp` | `datetime2(7)` | YES | — | Timestamp associated with submission of the review response. |

<a id="silver-olist-orders"></a>
### silver: `olist_orders`

**Physical table:** `Olist_Staging.silver.olist_orders`  
**Purpose:** Order headers and lifecycle timestamps.  
**Grain:** One row per order_id.  
**Primary source:** `orders CSV`  
**Columns:** 8 | **Verified rows:** 99,441

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `order_id` | `nvarchar(100)` | YES | Logical record identifier | Identifier of the customer order; joins order-level and item/payment/review records. |
| `customer_id` | `nvarchar(100)` | YES | Customer reference | Identifier for the customer record linked to an order; distinct from the repeat-buyer identifier. |
| `order_status` | `nvarchar(50)` | YES | — | Source order status (for example, delivered or canceled). |
| `order_purchase_timestamp` | `datetime2(0)` | YES | — | Timestamp when the customer placed the order. |
| `order_approved_at` | `datetime2(0)` | YES | — | Timestamp when the order was approved, if known. |
| `order_delivered_carrier_date` | `datetime2(0)` | YES | — | Timestamp when the order was handed over to the carrier, if known. |
| `order_delivered_customer_date` | `datetime2(0)` | YES | — | Timestamp when the order was delivered to the customer, if known. |
| `order_estimated_delivery_date` | `datetime2(0)` | YES | — | Delivery date estimated for the order. |

<a id="silver-olist-products"></a>
### silver: `olist_products`

**Physical table:** `Olist_Staging.silver.olist_products`  
**Purpose:** Products and listing attributes.  
**Grain:** One row per product_id.  
**Primary source:** `products CSV`  
**Columns:** 9 | **Verified rows:** 32,951

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `product_id` | `varchar(100)` | NO | Logical record identifier | Source-system identifier of the product associated with an item. |
| `product_category_name` | `varchar(200)` | YES | — | Original Portuguese product category name. |
| `product_name_lenght` | `int` | YES | — | Number of characters in the product name; source column spelling is preserved (lenght). |
| `product_description_lenght` | `int` | YES | — | Number of characters in the product description; source column spelling is preserved (lenght). |
| `product_photos_qty` | `int` | YES | — | Number of product listing photos. |
| `product_weight_g` | `int` | YES | — | Product weight in grams. |
| `product_length_cm` | `int` | YES | — | Product length in centimeters. |
| `product_height_cm` | `int` | YES | — | Product height in centimeters. |
| `product_width_cm` | `int` | YES | — | Product width in centimeters. |

<a id="silver-olist-sellers"></a>
### silver: `olist_sellers`

**Physical table:** `Olist_Staging.silver.olist_sellers`  
**Purpose:** Seller identities and locations.  
**Grain:** One row per seller_id.  
**Primary source:** `sellers CSV`  
**Columns:** 4 | **Verified rows:** 3,095

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `seller_id` | `varchar(100)` | NO | Logical record identifier | Source-system identifier of the seller fulfilling an item. |
| `seller_zip_code_prefix` | `varchar(20)` | YES | — | First five digits of the seller postal code, stored as text to preserve leading zeros. |
| `seller_city` | `varchar(200)` | YES | — | Seller city as provided by the source. |
| `seller_state` | `varchar(10)` | YES | — | Two-character Brazilian state abbreviation for the seller. |

<a id="silver-product-category-translation"></a>
### silver: `product_category_translation`

**Physical table:** `Olist_Staging.silver.product_category_translation`  
**Purpose:** Portuguese-to-English category translation lookup.  
**Grain:** One row per Portuguese/English category pair in the validated snapshot.  
**Primary source:** `product_category_name_translation CSV`  
**Columns:** 2 | **Verified rows:** 71

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `product_category_name` | `nvarchar(200)` | NO | Lookup category identifier | Original Portuguese product category name. |
| `product_category_name_english` | `nvarchar(200)` | NO | Translated label | English translation of the Portuguese product category name. |

## Gold layer — `Olist_DWH.gold`

Analytics-ready dimensional model using dimensions and item/payment facts.

| Table | Purpose | Grain | Validated rows |
|---|---|---|---:|
| [`DimCustomer`](#gold-dimcustomer) | Customer profiles with Type 2 history of observed location differences | One row per (CustomerUniqueID, EffectiveStartDate) version | 96,355 |
| [`DimDate`](#gold-dimdate) | Date attributes derived from order purchase-date range | One row per FullDate / DateKey | 774 |
| [`DimProduct`](#gold-dimproduct) | Product attributes used for analysis | One row per ProductID | 32,951 |
| [`DimSeller`](#gold-dimseller) | Seller attributes used for analysis | One row per SellerID | 3,095 |
| [`FactPayments`](#gold-factpayments) | Order-level payment events joined to customer and date dimensions | One row per (OrderID, PaymentSequential) | 103,886 |
| [`FactSales`](#gold-factsales) | Order item sales measures joined to related dimensions | One row per (OrderID, OrderItemID) | 112,650 |

<a id="gold-dimcustomer"></a>
### gold: `DimCustomer`

**Physical table:** `Olist_DWH.gold.DimCustomer`  
**Purpose:** Customer profiles with Type 2 history of observed location differences.  
**Grain:** One row per (CustomerUniqueID, EffectiveStartDate) version.  
**Primary source:** `silver.olist_customers joined to silver.olist_orders`  
**Columns:** 9 | **Verified rows:** 96,355

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `CustomerKey` | `bigint` | NO | PK¹ | Warehouse-generated surrogate key for a particular customer-dimension history version. |
| `CustomerUniqueID` | `varchar(100)` | NO | SCD2 business key | Source customer_unique_id used as the SCD Type 2 business identifier. |
| `CustomerCity` | `varchar(200)` | YES | — | City for the customer location version. |
| `CustomerState` | `varchar(10)` | YES | — | State abbreviation for the customer location version. |
| `CustomerZipCodePrefix` | `varchar(20)` | YES | — | Postal-code prefix for the customer location version. |
| `EffectiveStartDate` | `datetime2(7)` | NO | SCD2 version identifier | Start of the observed customer-location version, using a purchase timestamp; not independently verified as a physical move date. |
| `EffectiveEndDate` | `datetime2(7)` | YES | — | Exclusive end of the version validity interval; NULL for the current version. |
| `IsCurrent` | `bit` | NO | — | 1 for the current recorded version of the customer; 0 for a historical version. |
| `LoadDate` | `datetime2(7)` | NO | — | Timestamp when this warehouse row was inserted. |

<a id="gold-dimdate"></a>
### gold: `DimDate`

**Physical table:** `Olist_DWH.gold.DimDate`  
**Purpose:** Date attributes derived from order purchase-date range.  
**Grain:** One row per FullDate / DateKey.  
**Primary source:** `silver.olist_orders.purchase timestamp range`  
**Columns:** 9 | **Verified rows:** 774

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `DateKey` | `int` | NO | PK¹ | Calendar-date surrogate identifier formatted as YYYYMMDD (integer). |
| `FullDate` | `date` | NO | Unique business key¹ | Calendar date represented by this dimension row. |
| `YearNumber` | `int` | NO | — | Four-digit calendar year. |
| `QuarterNumber` | `int` | NO | — | Calendar quarter number (1–4). |
| `MonthNumber` | `int` | NO | — | Calendar month number (1–12). |
| `MonthName` | `varchar(20)` | NO | — | English-language calendar month name (subject to SQL Server language settings). |
| `DayOfMonth` | `int` | NO | — | Day number within the month (1–31). |
| `DayName` | `varchar(20)` | NO | — | Weekday name (subject to SQL Server language settings). |
| `IsWeekend` | `bit` | NO | — | 1 for Saturday or Sunday; 0 for Monday through Friday. |

<a id="gold-dimproduct"></a>
### gold: `DimProduct`

**Physical table:** `Olist_DWH.gold.DimProduct`  
**Purpose:** Product attributes used for analysis.  
**Grain:** One row per ProductID.  
**Primary source:** `silver.olist_products`  
**Columns:** 11 | **Verified rows:** 32,951

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `ProductKey` | `bigint` | NO | PK¹ | Warehouse-generated surrogate key for a product. |
| `ProductID` | `varchar(100)` | NO | Unique business key¹ | Source-system product_id retained as the product business identifier. |
| `ProductCategoryName` | `varchar(200)` | YES | — | Original Portuguese product category name carried from the product source. |
| `ProductNameLength` | `int` | YES | — | Length of the product listing name, in characters. |
| `ProductDescriptionLength` | `int` | YES | — | Length of the product listing description, in characters. |
| `ProductPhotosQty` | `int` | YES | — | Number of product listing photos. |
| `ProductWeightG` | `int` | YES | — | Product weight in grams. |
| `ProductLengthCM` | `int` | YES | — | Product length in centimeters. |
| `ProductHeightCM` | `int` | YES | — | Product height in centimeters. |
| `ProductWidthCM` | `int` | YES | — | Product width in centimeters. |
| `LoadDate` | `datetime2(7)` | NO | — | Timestamp when this warehouse row was inserted. |

<a id="gold-dimseller"></a>
### gold: `DimSeller`

**Physical table:** `Olist_DWH.gold.DimSeller`  
**Purpose:** Seller attributes used for analysis.  
**Grain:** One row per SellerID.  
**Primary source:** `silver.olist_sellers`  
**Columns:** 6 | **Verified rows:** 3,095

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `SellerKey` | `bigint` | NO | PK¹ | Warehouse-generated surrogate key for a seller. |
| `SellerID` | `varchar(100)` | NO | Unique business key¹ | Source-system seller_id retained as the seller business identifier. |
| `SellerZipCodePrefix` | `varchar(20)` | YES | — | Seller postal-code prefix, stored as text. |
| `SellerCity` | `varchar(200)` | YES | — | City of the seller. |
| `SellerState` | `varchar(10)` | YES | — | Brazilian state abbreviation for the seller. |
| `LoadDate` | `datetime2(7)` | NO | — | Timestamp when this warehouse row was inserted. |

<a id="gold-factpayments"></a>
### gold: `FactPayments`

**Physical table:** `Olist_DWH.gold.FactPayments`  
**Purpose:** Order-level payment events joined to customer and date dimensions.  
**Grain:** One row per (OrderID, PaymentSequential).  
**Primary source:** `silver.olist_order_payments joined to orders, customers and Gold dimensions`  
**Columns:** 9 | **Verified rows:** 103,886

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `PaymentKey` | `bigint` | NO | PK¹ | Warehouse-generated surrogate key for an order payment record. |
| `OrderID` | `varchar(100)` | NO | Unique business key¹ | Source order identifier; combined with PaymentSequential to identify a payment record. |
| `PaymentSequential` | `int` | NO | Unique business key¹ | Payment sequence number within the order. |
| `CustomerKey` | `bigint` | NO | FK¹ | Reference to the customer history version active at the order purchase timestamp. |
| `DateKey` | `int` | NO | FK¹ | Reference to gold.DimDate.DateKey for the order purchase date. |
| `PaymentType` | `varchar(100)` | YES | — | Payment method associated with the payment event. |
| `PaymentInstallments` | `int` | YES | — | Number of installments associated with the payment event. |
| `PaymentValue` | `decimal(18,2)` | YES | — | Payment amount in BRL, including what the source records for that payment. |
| `LoadDate` | `datetime2(7)` | NO | — | Timestamp when this warehouse row was inserted. |

<a id="gold-factsales"></a>
### gold: `FactSales`

**Physical table:** `Olist_DWH.gold.FactSales`  
**Purpose:** Order item sales measures joined to related dimensions.  
**Grain:** One row per (OrderID, OrderItemID).  
**Primary source:** `silver.olist_order_items joined to orders, customers and Gold dimensions`  
**Columns:** 11 | **Verified rows:** 112,650

| Column | SQL Server type | Nullable | Key / role | Business meaning |
|---|---|:---:|---|---|
| `SalesKey` | `bigint` | NO | PK¹ | Warehouse-generated surrogate key for a sales line-item record. |
| `OrderID` | `varchar(100)` | NO | Unique business key¹ | Source order identifier; combined with OrderItemID to identify a sales line item. |
| `OrderItemID` | `int` | NO | Unique business key¹ | Item sequence within the order; together with OrderID forms the line-item grain. |
| `CustomerKey` | `bigint` | NO | FK¹ | Reference to the customer history version that was active at the order purchase timestamp. |
| `ProductKey` | `bigint` | NO | FK¹ | Reference to gold.DimProduct.ProductKey. |
| `SellerKey` | `bigint` | NO | FK¹ | Reference to gold.DimSeller.SellerKey. |
| `DateKey` | `int` | NO | FK¹ | Reference to gold.DimDate.DateKey for the order purchase date. |
| `OrderPurchaseTimestamp` | `datetime2(7)` | NO | — | Timestamp at which the associated order was purchased. |
| `ItemPrice` | `decimal(18,2)` | NO | — | Item selling price in BRL, excluding freight; not net profit. |
| `FreightValue` | `decimal(18,2)` | NO | — | Item-level freight amount in BRL. |
| `LoadDate` | `datetime2(7)` | NO | — | Timestamp when this warehouse row was inserted. |

## Gold relationship reference

| From table.column | References | Meaning |
|---|---|---|
| `gold.FactSales.CustomerKey` | `gold.DimCustomer.CustomerKey` | Buyer SCD Type 2 history row at purchase time |
| `gold.FactSales.ProductKey` | `gold.DimProduct.ProductKey` | Purchased product |
| `gold.FactSales.SellerKey` | `gold.DimSeller.SellerKey` | Fulfilling seller |
| `gold.FactSales.DateKey` | `gold.DimDate.DateKey` | Order purchase date |
| `gold.FactPayments.CustomerKey` | `gold.DimCustomer.CustomerKey` | Buyer SCD Type 2 history row at purchase time |
| `gold.FactPayments.DateKey` | `gold.DimDate.DateKey` | Order purchase date |

**Gold declared keys in the supplied bootstrap SQL:** `DimCustomer.CustomerKey`, `DimProduct.ProductKey`, `DimSeller.SellerKey`, `DimDate.DateKey`, `FactSales.SalesKey`, and `FactPayments.PaymentKey` are declared as primary keys in their create-table statements. The scripts also declare unique constraints for `DimProduct.ProductID`, `DimSeller.SellerID`, `DimDate.FullDate`, `FactSales(OrderID, OrderItemID)` and `FactPayments(OrderID, PaymentSequential)`. `DimCustomer` has checks on version end date and current flags. Because those create statements run only when tables do not already exist, **the statements are not conclusive evidence of the constraints on the existing live tables**.

## SQL Server metadata / constraint verification still needed

The source metadata export describes **column names, data types, and nullability**; it does **not** report actual primary keys, unique constraints, foreign keys, default values, computed columns, or identity properties. A follow-up metadata extraction from `sys.key_constraints`, `sys.foreign_keys`, `sys.indexes` and `sys.identity_columns` is required to document which constraints the live server enforces. No constraints were fabricated for Bronze or Silver.

## Recommended repository placement

Store this document at `docs/Olist_Data_Dictionary.md` alongside the original metadata export at `docs/Olist_Table_Metadata.csv`. Keep the Gold load SQL under the `sql/` folder. Link this dictionary from the root `README.md`.

