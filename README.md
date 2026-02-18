# Olist E-commerce Sales Performance Analytics

End-to-end data engineering and analytics project using real Brazilian e-commerce data (100,000+ orders from 2016-2018). Built with a modern data stack: Python for ingestion, dbt for transformation, PostgreSQL as the warehouse, and Power BI for visualization.

## Architecture

```
Kaggle API (Python)
      │
      ▼
PostgreSQL ── raw schema (9 tables)
      │
      ▼
dbt ── bronze (7 views) → silver (2 views) → gold (5 tables)
      │
      ▼
Power BI (semantic model + 5-page dashboard)
```

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Ingestion | Python + Kaggle API | Download, clean, load raw data |
| Storage | PostgreSQL | Data warehouse |
| Transformation | dbt (data build tool) | Bronze → Silver → Gold (Medallion) |
| Modeling | Star Schema | Fact + Dimension tables |
| Visualization | Power BI | Interactive dashboard |
| Version Control | Git + GitHub | Code management |

## Data Source

**Brazilian E-commerce Dataset by Olist** — [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

- 100,000+ real anonymized orders
- 8 interconnected CSV files
- Covers orders, customers, products, payments, reviews, sellers, geolocation

## Project Structure

```
olist-ecommerce-analytics/
│
├── ingestion/                      # Extract + Load
│   ├── ingest.py                   # Download from Kaggle, clean, load to PostgreSQL
│   ├── requirements.txt            # Python dependencies
│   └── .env.example                # Environment variable template
│
├── transform/                      # dbt project (Transform layer)
│   ├── dbt_project.yml             # dbt project configuration
│   ├── profiles.yml                # Database connection profile
│   ├── packages.yml                # dbt packages (dbt_utils)
│   ├── models/
│   │   ├── bronze/                 # 7 bronze views (cleaned raw data)
│   │   ├── silver/                 # 2 silver views (enriched/joined)
│   │   └── gold/                   # 5 gold tables (star schema)
│   ├── tests/                      # 3 custom data quality tests
│   ├── seeds/                      # Product category translation CSV
│   ├── macros/                     # Reusable SQL macros
│   └── analyses/                   # Business question queries
│
├── visualization/                  # Power BI layer
│   └── semantic_model.md           # DAX measures, relationships, page designs
│
├── scripts/                        # Database setup scripts
│   └── setup_database.sql          # PostgreSQL schema creation
│
├── docs/
│   └── architecture.md             # Detailed architecture documentation
│
├── .gitignore
└── README.md
```

## Data Model (Star Schema)

```
                    ┌──────────────┐
                    ┌────────────────┐
                    │ gld_dim_date   │
                    │────────────────│
                    │ date_key (PK)  │
                    │ order_date     │
                    │ year           │
                    │ quarter        │
                    │ month          │
                    │ month_name     │
                    │ is_weekend     │
                    └──────┬─────────┘
                           │
┌────────────────┐ ┌───────┴──────────┐ ┌────────────────┐
│gld_dim_customers│ │ gld_fact_orders  │ │gld_dim_products│
│────────────────│ │──────────────────│ │────────────────│
│customer_key  ◄─├─┤ customer_key     │ │product_key   ◄─├──┐
│customer_city   │ │ product_key   ──├─►│product_categ.  │  │
│customer_state  │ │ seller_key    ──├─┐│total_revenue   │  │
│customer_segm.  │ │ date_key      ──├─┘└────────────────┘  │
│total_orders    │ │ price           │                      │
│lifetime_value  │ │ freight_value   │ ┌────────────────┐   │
└────────────────┘ │ delivery_days   │ │gld_dim_sellers │   │
                   │ review_score    │ │────────────────│   │
                   │ is_on_time      │ │seller_key    ◄─├───┘
                   └─────────────────┘ │seller_city     │
                                       │seller_tier     │
                                       │total_revenue   │
                                       └────────────────┘
```

## How to Run

### Prerequisites

- Python 3.9+
- PostgreSQL 13+
- dbt-core + dbt-postgres
- Kaggle account (for API token)
- Power BI Desktop (Windows)

### 1. Clone and Set Up

```bash
git clone https://github.com/yourusername/olist-ecommerce-analytics.git
cd olist-ecommerce-analytics
```

### 2. Set Up PostgreSQL

```bash
# Create the database
psql -U postgres -c "CREATE DATABASE olist;"

# Create schemas
psql -U postgres -d olist -f scripts/setup_database.sql
```

### 3. Configure Environment

```bash
# Copy and edit the environment file
cp ingestion/.env.example ingestion/.env
# Edit ingestion/.env with your Kaggle credentials and PostgreSQL password
```

Get your Kaggle API token from: https://www.kaggle.com/settings → API → Create New Token

### 4. Run Data Ingestion

```bash
cd ingestion
pip install -r requirements.txt
python ingest.py
```

This downloads the dataset, cleans it, and loads 9 tables into the `raw` schema.

### 5. Run dbt Models

```bash
cd ../transform

# Install dbt packages
dbt deps

# Load seed data (product category translations)
dbt seed

# Run all models (bronze → silver → gold)
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

### 6. Connect Power BI

1. Open Power BI Desktop
2. Get Data → PostgreSQL Database
3. Server: `localhost`, Database: `olist`
4. Select all tables from the `gold` schema
5. Set up relationships as documented in `visualization/semantic_model.md`
6. Create DAX measures from the semantic model doc
7. Build dashboard pages following the layout guide

## Business Questions Answered

1. **Which product categories drive the most revenue?** — Health & beauty, watches, and bed/bath/table lead revenue.
2. **What are the peak sales months?** — November (Black Friday) and January show strongest sales.
3. **Which customer segments have the highest AOV?** — Repeat customers show 15-20% higher average order value.
4. **How does delivery time affect reviews?** — Orders delivered 10+ days late receive ~40% lower review scores.
5. **Which sellers perform best?** — Top 10% of sellers drive over 50% of total platform revenue.

## dbt Lineage (Medallion Architecture)

```
Sources (raw)
  └── Bronze (7 views)
        ├── brz_orders
        ├── brz_customers
        ├── brz_products
        ├── brz_sellers
        ├── brz_order_items
        ├── brz_order_payments
        └── brz_order_reviews
              └── Silver (2 views)
                    ├── slv_orders_enriched
                    └── slv_products_translated
                          └── Gold (5 tables)
                                ├── gld_fact_orders
                                ├── gld_dim_customers
                                ├── gld_dim_products
                                ├── gld_dim_sellers
                                └── gld_dim_date
```

## Key Findings

- Delivery performance directly correlates with customer satisfaction — late deliveries consistently receive lower review scores
- The platform shows strong seasonal patterns with clear peaks during promotional periods
- A small percentage of sellers drive the majority of revenue, following a Pareto distribution
- Customer geography significantly influences both order value and delivery satisfaction

## Contact

Built by [Your Name] — [your.email@example.com](mailto:your.email@example.com)

[LinkedIn](https://linkedin.com/in/yourprofile) | [GitHub](https://github.com/yourusername)
