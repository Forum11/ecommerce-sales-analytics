-- ============================================================
-- Olist E-commerce Analytics - Key Business Questions
-- ============================================================
-- These queries run against the gold schema after dbt build.
-- Use these to validate findings before building the dashboard.
-- ============================================================


-- Q1: Which product categories drive the most revenue?
-- ============================================================
SELECT
    p.product_category,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    SUM(f.price)::NUMERIC(12,2)             AS total_revenue,
    AVG(f.price)::NUMERIC(10,2)             AS avg_price,
    AVG(f.review_score)::NUMERIC(3,2)       AS avg_review
FROM gold.gld_fact_orders f
JOIN gold.gld_dim_products p ON f.product_key = p.product_key
GROUP BY p.product_category
ORDER BY total_revenue DESC
LIMIT 15;


-- Q2: What are the peak sales months and seasonality patterns?
-- ============================================================
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    SUM(f.price)::NUMERIC(12,2)             AS total_revenue,
    AVG(f.price)::NUMERIC(10,2)             AS avg_item_price
FROM gold.gld_fact_orders f
JOIN gold.gld_dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- Q3: Which customer segments have the highest average order value?
-- ============================================================
SELECT
    c.customer_segment,
    c.customer_state,
    COUNT(DISTINCT c.customer_key)          AS customer_count,
    AVG(c.avg_order_value)::NUMERIC(10,2)   AS avg_order_value,
    AVG(c.lifetime_value)::NUMERIC(10,2)    AS avg_lifetime_value,
    AVG(c.avg_review_score)::NUMERIC(3,2)   AS avg_review
FROM gold.gld_dim_customers c
WHERE c.total_orders > 0
GROUP BY c.customer_segment, c.customer_state
ORDER BY avg_order_value DESC
LIMIT 20;


-- Q4: What is the average delivery time and how does it affect review scores?
-- ============================================================
SELECT
    CASE
        WHEN f.delivery_days <= 5  THEN '01. 0-5 days'
        WHEN f.delivery_days <= 10 THEN '02. 6-10 days'
        WHEN f.delivery_days <= 15 THEN '03. 11-15 days'
        WHEN f.delivery_days <= 20 THEN '04. 16-20 days'
        WHEN f.delivery_days <= 30 THEN '05. 21-30 days'
        ELSE '06. 30+ days'
    END                                     AS delivery_bucket,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    AVG(f.review_score)::NUMERIC(3,2)       AS avg_review_score,
    AVG(f.delivery_days)::NUMERIC(5,1)      AS avg_delivery_days
FROM gold.gld_fact_orders f
WHERE f.order_status = 'delivered'
  AND f.delivery_days IS NOT NULL
  AND f.review_score IS NOT NULL
GROUP BY delivery_bucket
ORDER BY delivery_bucket;


-- Q5: Which sellers have the best performance by volume and ratings?
-- ============================================================
SELECT
    s.seller_key,
    s.seller_city,
    s.seller_state,
    s.seller_tier,
    s.total_orders,
    s.total_revenue::NUMERIC(12,2),
    s.avg_review_score,
    s.total_items_sold
FROM gold.gld_dim_sellers s
WHERE s.total_orders > 0
ORDER BY s.total_revenue DESC
LIMIT 25;


-- Bonus: On-time delivery rate by month
-- ============================================================
SELECT
    d.year_month,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    COUNT(DISTINCT CASE WHEN f.is_delivered_on_time THEN f.order_id END)
                                            AS on_time_orders,
    (COUNT(DISTINCT CASE WHEN f.is_delivered_on_time THEN f.order_id END)::NUMERIC
     / NULLIF(COUNT(DISTINCT f.order_id), 0) * 100)::NUMERIC(5,2)
                                            AS on_time_rate_pct
FROM gold.gld_fact_orders f
JOIN gold.gld_dim_date d ON f.date_key = d.date_key
WHERE f.order_status = 'delivered'
GROUP BY d.year_month
ORDER BY d.year_month;
