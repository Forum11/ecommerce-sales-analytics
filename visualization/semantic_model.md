# Power BI Semantic Model - Olist E-commerce Analytics

## Data Source Connection

- **Type:** PostgreSQL
- **Server:** localhost
- **Port:** 5432
- **Database:** olist
- **Schema:** gold (for all tables below)

## Tables to Import

Import the following tables from the `gold` schema:

| Table | Type | Grain |
|-------|------|-------|
| `gold.gld_fact_orders` | Fact | One row per order item |
| `gold.gld_dim_customers` | Dimension | One row per customer |
| `gold.gld_dim_products` | Dimension | One row per product |
| `gold.gld_dim_sellers` | Dimension | One row per seller |
| `gold.gld_dim_date` | Dimension | One row per calendar date |

## Relationships (Star Schema)

Configure these relationships in Power BI Model View:

```
gld_fact_orders.customer_key  →  gld_dim_customers.customer_key  (Many-to-One)
gld_fact_orders.product_key   →  gld_dim_products.product_key    (Many-to-One)
gld_fact_orders.seller_key    →  gld_dim_sellers.seller_key       (Many-to-One)
gld_fact_orders.date_key      →  gld_dim_date.date_key            (Many-to-One)
```

All relationships: Single direction, Active.

## DAX Measures

Create a "Measures" table in Power BI with these DAX measures:

```dax
// Revenue Measures
Total Revenue = SUM(gld_fact_orders[price])

Total Freight = SUM(gld_fact_orders[freight_value])

Total Order Value = SUM(gld_fact_orders[total_item_value])

Average Order Value =
    DIVIDE(
        [Total Revenue],
        DISTINCTCOUNT(gld_fact_orders[order_id]),
        0
    )

// Volume Measures
Total Orders = DISTINCTCOUNT(gld_fact_orders[order_id])

Total Items Sold = COUNTROWS(gld_fact_orders)

// Customer Measures
Total Customers = DISTINCTCOUNT(gld_fact_orders[customer_key])

// Delivery Measures
Average Delivery Days =
    AVERAGE(gld_fact_orders[delivery_days])

On-Time Delivery Rate =
    DIVIDE(
        CALCULATE(
            DISTINCTCOUNT(gld_fact_orders[order_id]),
            gld_fact_orders[is_delivered_on_time] = TRUE
        ),
        DISTINCTCOUNT(gld_fact_orders[order_id]),
        0
    )

// Review Measures
Average Review Score = AVERAGE(gld_fact_orders[review_score])

// Period-over-Period
Revenue MoM % =
    VAR CurrentMonth = [Total Revenue]
    VAR PreviousMonth =
        CALCULATE(
            [Total Revenue],
            DATEADD(gld_dim_date[order_date], -1, MONTH)
        )
    RETURN
        DIVIDE(CurrentMonth - PreviousMonth, PreviousMonth, 0)

// Delivery Impact
Late Delivery Avg Review =
    CALCULATE(
        AVERAGE(gld_fact_orders[review_score]),
        gld_fact_orders[is_delivered_on_time] = FALSE
    )

On-Time Delivery Avg Review =
    CALCULATE(
        AVERAGE(gld_fact_orders[review_score]),
        gld_fact_orders[is_delivered_on_time] = TRUE
    )
```

## Dashboard Pages

### Page 1: Executive Summary
- **KPI Cards:** Total Revenue, Total Orders, Avg Order Value, Avg Review Score
- **Line Chart:** Revenue trend over time (gld_dim_date[year_month] on X, [Total Revenue] on Y)
- **Donut Chart:** Orders by order_status
- **Slicer:** gld_dim_date[year], gld_dim_date[quarter]

### Page 2: Product Performance
- **Bar Chart:** Top 10 categories by revenue (gld_dim_products[product_category], [Total Revenue])
- **Scatter Plot:** Revenue vs order volume by category
- **Table:** Category details with Revenue, Orders, Avg Review Score
- **Slicer:** gld_dim_products[product_category]

### Page 3: Customer Analysis
- **Map Visual:** Customer distribution by state (gld_dim_customers[customer_state])
- **Donut Chart:** Customer segment breakdown (gld_dim_customers[customer_segment])
- **Bar Chart:** Avg order value by state
- **Card:** Total Customers, Repeat Customer %
- **Slicer:** gld_dim_customers[customer_segment]

### Page 4: Delivery & Satisfaction
- **Histogram:** Delivery days distribution
- **Line Chart:** Avg delivery days vs avg review score (grouped by delivery day buckets)
- **KPI Cards:** On-Time Rate, Avg Delivery Days, Late Delivery Avg Review vs On-Time Avg Review
- **Bar Chart:** On-time vs late delivery counts by month
- **Slicer:** gld_dim_date[year_month]

### Page 5: Seller Performance
- **Bar Chart:** Top 20 sellers by revenue
- **Bar Chart:** Seller distribution by tier (gld_dim_sellers[seller_tier])
- **Scatter Plot:** Revenue vs Avg Review Score by seller
- **Table:** Seller scorecard (seller_id, city, state, orders, revenue, avg_review, tier)
- **Slicer:** gld_dim_sellers[seller_tier], gld_dim_sellers[seller_state]

## Color Theme

Use a consistent theme across all pages:
- Primary: #2E86AB (blue)
- Secondary: #A23B72 (magenta)
- Accent: #F18F01 (orange)
- Success: #2CA58D (green)
- Warning: #E15554 (red)
- Background: #F7F7F7
