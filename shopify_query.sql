/*
===============================================================================
CREATE SALES TABLE
===============================================================================
*/

CREATE TABLE sales(
    admin_graphql_api VARCHAR,
    id_order_number INTEGER,
    billing_address_country TEXT,
    billing_address_first_name TEXT,
    billing_address_last_name TEXT,
    billing_address_province TEXT,
    billing_address_zip_city TEXT,
    currency TEXT,
    city VARCHAR,
    customer_id TEXT,
    invoice_date TIMESTAMP,
    gateway TEXT,
    product_id FLOAT,
    product_type TEXT,
    variant_id FLOAT,
    quantity INTEGER,
    subtotal_price FLOAT,
    total_price_usd FLOAT,
    total_tax FLOAT
);


/*
===============================================================================
1. DATA CLEANING
===============================================================================
Purpose:
    - Remove duplicate records
    - Handle missing values
    - Standardize text formatting
    - Validate numerical values
    - Ensure proper date formatting
===============================================================================
*/

-- Check for Duplicate Orders
SELECT
    id_order_number,
    COUNT(*) AS duplicate_count
FROM sales
GROUP BY id_order_number
HAVING COUNT(*) > 1;


-- Check for Missing Values
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,

    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_id,

    COUNT(*) FILTER (WHERE invoice_date IS NULL) AS missing_invoice_date,

    COUNT(*) FILTER (WHERE total_price_usd IS NULL) AS missing_total_price,

    COUNT(*) FILTER (WHERE quantity IS NULL) AS missing_quantity

FROM sales;


-- Standardize Country Names
UPDATE sales
SET billing_address_country = TRIM(UPPER(billing_address_country));


-- Standardize Province Names
UPDATE sales
SET billing_address_province = TRIM(INITCAP(billing_address_province));


-- Remove Invalid Sales Values
DELETE FROM sales
WHERE total_price_usd <= 0
   OR quantity <= 0;


-- Verify Date Format and Range
SELECT
    MIN(invoice_date) AS earliest_invoice_date,
    MAX(invoice_date) AS latest_invoice_date
FROM sales;


/*
===============================================================================
2. BUSINESS SUMMARY REPORT
===============================================================================
*/

SELECT
    'Total Sales' AS measure_name,
    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS measure_value
FROM sales

UNION ALL

SELECT
    'Total Quantity',
    ROUND(SUM(quantity)::NUMERIC, 2)
FROM sales

UNION ALL

SELECT
    'Average Order Value',
    ROUND(AVG(total_price_usd)::NUMERIC, 2)
FROM sales

UNION ALL

SELECT
    'Total Orders',
    COUNT(DISTINCT id_order_number)::NUMERIC
FROM sales

UNION ALL

SELECT
    'Total Customers',
    COUNT(DISTINCT customer_id)::NUMERIC
FROM sales

UNION ALL

SELECT
    'Total Products',
    COUNT(DISTINCT product_id)::NUMERIC
FROM sales;


/*
===============================================================================
3. MAGNITUDE ANALYSIS
===============================================================================
*/

-- Revenue by Country
SELECT
    billing_address_country,
    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue
FROM sales
GROUP BY billing_address_country
ORDER BY total_revenue DESC;


-- Revenue by Province
SELECT
    billing_address_province,
    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue
FROM sales
GROUP BY billing_address_province
ORDER BY total_revenue DESC;


-- Orders by Payment Gateway
SELECT
    gateway,
    COUNT(DISTINCT id_order_number) AS total_orders
FROM sales
GROUP BY gateway
ORDER BY total_orders DESC;


-- Revenue by Customer
SELECT
    customer_id,

    CONCAT(
        billing_address_first_name,
        ' ',
        billing_address_last_name
    ) AS full_name,

    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue

FROM sales

GROUP BY
    customer_id,
    full_name

ORDER BY total_revenue DESC;


/*
===============================================================================
4. RANKING ANALYSIS
===============================================================================
*/

-- Top 5 Customers by Revenue
SELECT
    customer_id,

    CONCAT(
        billing_address_first_name,
        ' ',
        billing_address_last_name
    ) AS full_name,

    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue

FROM sales

GROUP BY
    customer_id,
    full_name

ORDER BY total_revenue DESC

LIMIT 5;


-- Top 5 Products by Revenue
SELECT
    product_id,

    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue

FROM sales

GROUP BY product_id

ORDER BY total_revenue DESC

LIMIT 5;


-- Lowest Performing Products
SELECT
    product_id,

    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_revenue

FROM sales

GROUP BY product_id

ORDER BY total_revenue ASC

LIMIT 5;


/*
===============================================================================
5. DAILY SALES ANALYSIS
===============================================================================
Purpose:
    - Analyze sales by weekday
    - Arrange days Monday → Sunday
===============================================================================
*/

SELECT

    CASE
        WHEN EXTRACT(DOW FROM invoice_date) = 0 THEN 7
        ELSE EXTRACT(DOW FROM invoice_date)
    END AS day_number,

    TRIM(TO_CHAR(invoice_date, 'Day')) AS day_name,

    ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_sales,

    COUNT(DISTINCT id_order_number) AS total_orders

FROM sales

GROUP BY
    day_number,
    day_name

ORDER BY day_number;


/*
===============================================================================
6. CUSTOMER SEGMENTATION ANALYSIS
===============================================================================
*/

WITH customer_spending AS
(
    SELECT

        customer_id,

        ROUND(SUM(total_price_usd)::NUMERIC, 2) AS total_spending

    FROM sales

    GROUP BY customer_id
)

SELECT

    customer_segment,

    COUNT(*) AS total_customers

FROM
(
    SELECT

        customer_id,

        CASE
            WHEN total_spending > 5000 THEN 'VIP'
            WHEN total_spending BETWEEN 1000 AND 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment

    FROM customer_spending

) t

GROUP BY customer_segment;


/*
===============================================================================
7. PRODUCT REPORT VIEW
===============================================================================
*/

DROP VIEW IF EXISTS report_products;

CREATE OR REPLACE VIEW report_products AS

WITH product_summary AS
(
    SELECT

        product_id,

        COUNT(DISTINCT id_order_number) AS total_orders,

        COUNT(DISTINCT customer_id) AS total_customers,

        CAST(SUM(total_price_usd) AS NUMERIC(12,2)) AS total_sales,

        CAST(SUM(quantity) AS NUMERIC(12,2)) AS total_quantity,

        CAST(AVG(total_price_usd) AS NUMERIC(12,2)) AS avg_price,

        MAX(invoice_date) AS last_sale_date,

        MIN(invoice_date) AS first_sale_date

    FROM sales

    GROUP BY product_id
)

SELECT

    product_id,

    total_orders,

    total_customers,

    total_sales,

    total_quantity,

    avg_price,

    last_sale_date,

    AGE(last_sale_date, first_sale_date) AS product_lifespan,

    CASE
        WHEN total_sales > 50000 THEN 'High Performer'
        WHEN total_sales > 10000 THEN 'Mid Range'
        ELSE 'Low Performer'
    END AS product_segment

FROM product_summary

ORDER BY total_sales DESC;