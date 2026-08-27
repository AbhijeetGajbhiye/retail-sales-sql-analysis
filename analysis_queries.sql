/* ============================================================
   PRODUCT & CUSTOMER ANALYTICS — SQL PROJECT
   Database: retail.db (customers, products, orders, order_items)
   Goal: answer concrete business questions using SQL only
   (joins, aggregation, window functions, CTEs) — no external
   scripting language for the analysis itself.
   ============================================================ */

/* ------------------------------------------------------------
   Q1. Monthly revenue trend
   Business question: Is revenue growing month over month?
------------------------------------------------------------ */
SELECT
    strftime('%Y-%m', o.order_date)                        AS month,
    ROUND(SUM(oi.quantity * p.unit_price), 2)               AS revenue,
    COUNT(DISTINCT o.order_id)                              AS orders,
    ROUND(SUM(oi.quantity * p.unit_price)
          / COUNT(DISTINCT o.order_id), 2)                  AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p      ON p.product_id = oi.product_id
GROUP BY month
ORDER BY month;


/* ------------------------------------------------------------
   Q2. Top 5 products by revenue, and their share of total revenue
   Business question: Which products should we never let go out
   of stock?
------------------------------------------------------------ */
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.quantity * p.unit_price) AS revenue,
        SUM(oi.quantity)                AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.product_id
),
totals AS (
    SELECT SUM(revenue) AS total_revenue FROM product_revenue
)
SELECT
    pr.product_name,
    pr.category,
    pr.units_sold,
    ROUND(pr.revenue, 2)                              AS revenue,
    ROUND(100.0 * pr.revenue / t.total_revenue, 1)     AS pct_of_total_revenue
FROM product_revenue pr, totals t
ORDER BY pr.revenue DESC
LIMIT 5;


/* ------------------------------------------------------------
   Q3. Products at risk of stockout
   Business question: Given recent sales velocity, which products
   will run out soonest? (stock_qty vs. units sold in the last
   60 days, projected days-of-cover)
------------------------------------------------------------ */
WITH recent_sales AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) AS units_last_60d
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_date >= date((SELECT MAX(order_date) FROM orders), '-60 days')
    GROUP BY oi.product_id
)
SELECT
    p.product_name,
    p.category,
    p.stock_qty,
    COALESCE(rs.units_last_60d, 0)                                  AS units_last_60d,
    ROUND(p.stock_qty / NULLIF(COALESCE(rs.units_last_60d, 0) / 60.0, 0), 1) AS days_of_cover
FROM products p
LEFT JOIN recent_sales rs ON rs.product_id = p.product_id
WHERE COALESCE(rs.units_last_60d, 0) > 0
ORDER BY days_of_cover ASC
LIMIT 5;


/* ------------------------------------------------------------
   Q4. Customer cohort retention by signup month
   Business question: Of customers who signed up in a given
   month, what % placed an order in each following month?
   (classic cohort analysis using window functions + CTEs)
------------------------------------------------------------ */
WITH cohorts AS (
    SELECT
        customer_id,
        strftime('%Y-%m', signup_date) AS cohort_month
    FROM customers
),
order_months AS (
    SELECT
        o.customer_id,
        strftime('%Y-%m', o.order_date) AS order_month
    FROM orders o
    GROUP BY o.customer_id, order_month
),
cohort_activity AS (
    SELECT
        c.cohort_month,
        CAST(
          (strftime('%Y', om.order_month || '-01') - strftime('%Y', c.cohort_month || '-01')) * 12
          + (strftime('%m', om.order_month || '-01') - strftime('%m', c.cohort_month || '-01'))
        AS INTEGER) AS month_index,
        om.customer_id
    FROM cohorts c
    JOIN order_months om ON om.customer_id = c.customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS customers
    FROM cohorts
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.customers                                        AS cohort_customers,
    ca.month_index,
    COUNT(DISTINCT ca.customer_id)                       AS active_customers,
    ROUND(100.0 * COUNT(DISTINCT ca.customer_id) / cs.customers, 1) AS pct_retained
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_month = ca.cohort_month
WHERE ca.month_index BETWEEN 0 AND 3
GROUP BY ca.cohort_month, ca.month_index
ORDER BY ca.cohort_month, ca.month_index;


/* ------------------------------------------------------------
   Q5. Rank customers within each region by total spend
   Business question: Who are the top 3 spenders per region,
   for a regional loyalty program? (window function: RANK)
------------------------------------------------------------ */
WITH customer_spend AS (
    SELECT
        c.customer_id,
        c.region,
        SUM(oi.quantity * p.unit_price) AS total_spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY c.customer_id
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY region ORDER BY total_spend DESC) AS rank_in_region
    FROM customer_spend
)
SELECT region, customer_id, ROUND(total_spend, 2) AS total_spend, rank_in_region
FROM ranked
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;
