# Retail Sales Analysis — SQL Project
### Product performance, stockout risk, and customer retention using pure SQL

**Goal:** Answer concrete business questions directly in SQL — joins, CTEs, and window functions — on a 4-table retail database (customers, products, orders, order_items) covering ~1,700 orders and 500 customers over 15 months.

## Database design
- `customers` (customer_id, signup_date, region)
- `products` (product_id, product_name, category, unit_price, stock_qty)
- `orders` (order_id, customer_id, order_date)
- `order_items` (order_item_id, order_id, product_id, quantity)

Standard normalized schema — orders and products are many-to-many through `order_items`, which is where most of the query complexity (joins + aggregation) comes from.

## Questions answered

**1. Monthly revenue trend** — Aggregated revenue and average order value by month to check growth trajectory. Revenue grew from ~$31K (Apr 2024) to a peak above $640K/month by late 2024, driven by both order volume and rising average order value.

**2. Top 5 products by revenue** — Notebook Set, Storage Bin, Jump Rope, Yoga Mat, and Foam Roller together account for **~40% of total revenue** despite being 5 of 20 SKUs — a clear signal for inventory prioritization.

**3. Stockout risk** — Using a rolling 60-day sales window against current stock, Sticky Notes Pack has only **3 days of cover** at current sales velocity — the most urgent restock priority, ahead of Cushion Cover Set (10 days) and Wireless Earbuds (13 days).

**4. Cohort retention** — Built a month-by-month retention table (CTE + date-math) showing what % of each signup cohort placed an order in months 0–3 after joining. Retention is noisy across early cohorts (10–35% in month 1) with no strong upward trend — a signal that early customer engagement, not just acquisition, needs work.

**5. Top spenders by region** — Used `RANK() OVER (PARTITION BY region ORDER BY total_spend DESC)` to find the top 3 customers per region — a direct input list for a regional loyalty program.

## Techniques demonstrated
- Multi-table `JOIN`s across a normalized schema
- Aggregation (`SUM`, `COUNT`, `GROUP BY`)
- Common Table Expressions (CTEs), including chained/nested CTEs
- Window functions (`RANK() OVER (PARTITION BY ... ORDER BY ...)`)
- Date arithmetic for cohort-month calculations
- A derived "days of cover" metric combining current inventory with recent sales velocity

## Files
- `retail.db` — SQLite database (import into any SQL client, or query directly)
- `generate_sql_data.py` — script that built the synthetic dataset
- `analysis_queries.sql` — all 5 queries, commented with the business question each answers
- `chart1_monthly_revenue.png`, `chart2_top_products.png`, `chart3_cohort_retention.png`
