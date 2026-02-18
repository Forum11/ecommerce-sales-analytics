# Architecture Documentation

## Overview

This project implements a modern analytics pipeline for analyzing Brazilian e-commerce data. The architecture follows the ELT (Extract, Load, Transform) pattern using dbt for the transformation layer.

## Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────────────┐     ┌──────────┐
│  Kaggle API │────►│   Python    │────►│        PostgreSQL            │────►│ Power BI │
│  (Source)   │     │ (Ingestion) │     │                             │     │(Dashbrd) │
└─────────────┘     └─────────────┘     │  raw → bronze → silver → gold│     └──────────┘
                                        │         ▲                   │
                                        │         │                   │
                                        │       dbt                   │
                                        └─────────────────────────────┘
```

## Layer Details

### 1. Extraction Layer (Python)

**Script:** `ingestion/ingest.py`

- Authenticates with Kaggle API using credentials from `.env`
- Downloads the `olistbr/brazilian-ecommerce` dataset
- Extracts CSV files from the zip archive
- Performs initial cleaning:
  - Strips whitespace from string columns
  - Removes duplicate rows
  - Casts date columns to proper timestamps
  - Casts numeric columns to proper types
  - Deduplicates geolocation by zip code prefix
- Loads each CSV into the `raw` schema as a separate table

**Tables created in `raw` schema:**

| Table | Row Count (approx.) | Description |
|-------|---------------------|-------------|
| raw_orders | 99,441 | Order header data |
| raw_order_items | 112,650 | Line items per order |
| raw_order_payments | 103,886 | Payment records |
| raw_order_reviews | 99,224 | Customer reviews |
| raw_customers | 99,441 | Customer demographics |
| raw_products | 32,951 | Product catalog |
| raw_sellers | 3,095 | Seller information |
| raw_geolocation | ~23,000 | Zip code coordinates (deduplicated) |
| raw_product_category_translation | 71 | Category name translations |

### 2. Bronze Layer (dbt views)

**Location:** `transform/models/bronze/`

Purpose: Clean, rename, and type-cast raw data. No business logic.

- `brz_orders` — Typed timestamps, null filtering
- `brz_customers` — Standardized city (InitCap) and state (Upper)
- `brz_products` — Fixed typos in column names (lenght → length)
- `brz_sellers` — Standardized city/state formatting
- `brz_order_items` — Typed price/freight as numeric(10,2)
- `brz_order_payments` — Typed payment values, validated payment types
- `brz_order_reviews` — Typed review scores and timestamps

### 3. Silver Layer (dbt views)

**Location:** `transform/models/silver/`

Purpose: Join and enrich data across bronze tables.

- `slv_orders_enriched` — Denormalized order-level table combining:
  - Order header (timestamps, status)
  - Aggregated items (count, total price, freight)
  - Aggregated payments (total value, payment type)
  - Aggregated reviews (avg score, count)
  - Calculated delivery metrics (days, on-time flag)

- `slv_products_translated` — Products joined with English category names

### 4. Gold Layer (dbt tables)

**Location:** `transform/models/gold/`

Purpose: Final analytical tables in a star schema. Materialized as tables for Power BI performance.

**Fact Table:**
- `gld_fact_orders` — Grain: one row per order item. Contains all measures (price, freight, delivery days, review score) and foreign keys to all dimensions.

**Dimension Tables:**
- `gld_dim_customers` — Customer demographics + lifetime metrics + segmentation
- `gld_dim_products` — Product catalog + English categories + sales metrics
- `gld_dim_sellers` — Seller info + performance metrics + tier classification
- `gld_dim_date` — Calendar dimension (2016-2018) with time attributes

### 5. Visualization Layer (Power BI)

**Documentation:** `visualization/semantic_model.md`

Connects to PostgreSQL `gold` schema. Implements:
- Star schema relationships
- DAX measures for KPIs
- 5-page interactive dashboard

## Data Quality

### dbt Tests

**Schema tests (in YAML files):**
- `unique` and `not_null` on all primary keys
- `relationships` tests between fact and dimension tables
- `accepted_values` on categorical columns (order_status, payment_type)

**Custom tests (in `tests/` directory):**
- `assert_positive_payment_values` — No negative prices or freight
- `assert_valid_delivery_days` — No negative delivery days for delivered orders
- `assert_review_score_range` — Review scores between 1 and 5

## Design Decisions

1. **PostgreSQL over DuckDB:** Chosen for industry relevance and Power BI compatibility, despite DuckDB being simpler for local development.

2. **Views for bronze/silver, tables for gold:** Bronze and silver layers are views to avoid data duplication. Gold is materialized as tables for Power BI query performance.

3. **Surrogate keys via dbt_utils:** Using `generate_surrogate_key` for the fact table's primary key rather than composite keys, following dimensional modeling best practices.

4. **Customer segmentation in gld_dim_customers:** Pre-calculated in the dimension rather than at query time to simplify Power BI measures and improve dashboard performance.

5. **Seller tiering in gld_dim_sellers:** Revenue-based tiers (Bronze/Silver/Gold/Platinum) pre-calculated for easy filtering and scorecard visualization.

6. **Date dimension as generated series:** Rather than depending on order dates, generates a complete calendar spine (2016-2018) to handle date gaps in visualizations.
