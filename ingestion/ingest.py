"""
Olist E-commerce Data Ingestion Script
---------------------------------------
Downloads the Brazilian E-commerce dataset from Kaggle,
cleans the data, and loads it into PostgreSQL (raw schema).
"""

import os
import zipfile
import logging
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
load_dotenv()

KAGGLE_DATASET = "olistbr/brazilian-ecommerce"
DATA_DIR = Path(__file__).parent / "data"
DATA_DIR.mkdir(exist_ok=True)

PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DATABASE = os.getenv("PG_DATABASE", "olist")
PG_USER = os.getenv("PG_USER", "postgres")
PG_PASSWORD = os.getenv("PG_PASSWORD", "")

DATABASE_URL = f"postgresql://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DATABASE}"

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Mapping from CSV filenames to PostgreSQL table names
FILE_TABLE_MAP = {
    "olist_orders_dataset.csv": "raw_orders",
    "olist_order_items_dataset.csv": "raw_order_items",
    "olist_order_payments_dataset.csv": "raw_order_payments",
    "olist_order_reviews_dataset.csv": "raw_order_reviews",
    "olist_customers_dataset.csv": "raw_customers",
    "olist_products_dataset.csv": "raw_products",
    "olist_sellers_dataset.csv": "raw_sellers",
    "olist_geolocation_dataset.csv": "raw_geolocation",
    "product_category_name_translation.csv": "raw_product_category_translation",
}

# ---------------------------------------------------------------------------
# Step 1: Download dataset from Kaggle
# ---------------------------------------------------------------------------
def download_dataset():
    """Download the Olist dataset using the Kaggle API."""
    logger.info("Downloading dataset from Kaggle: %s", KAGGLE_DATASET)

    kaggle_key = os.getenv("KAGGLE_KEY", "")

    if kaggle_key.startswith("KGAT_"):
        # Newer Kaggle API Token format — set as KAGGLE_KEY only
        os.environ["KAGGLE_KEY"] = kaggle_key
        os.environ.pop("KAGGLE_USERNAME", None)
    else:
        # Legacy username + hex key pair format
        os.environ["KAGGLE_USERNAME"] = os.getenv("KAGGLE_USERNAME", "")
        os.environ["KAGGLE_KEY"] = kaggle_key

    from kaggle.api.kaggle_api_extended import KaggleApi

    api = KaggleApi()
    api.authenticate()
    api.dataset_download_files(KAGGLE_DATASET, path=str(DATA_DIR), unzip=False)

    zip_path = DATA_DIR / "brazilian-ecommerce.zip"
    if zip_path.exists():
        logger.info("Extracting zip file...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(DATA_DIR)
        zip_path.unlink()
        logger.info("Extraction complete.")
    else:
        logger.info("No zip file found — files may already be extracted.")


# ---------------------------------------------------------------------------
# Step 2: Clean data
# ---------------------------------------------------------------------------
def clean_dataframe(df: pd.DataFrame, table_name: str) -> pd.DataFrame:
    """Apply generic and table-specific cleaning."""

    initial_rows = len(df)

    # Strip whitespace from string columns
    str_cols = df.select_dtypes(include="object").columns
    df[str_cols] = df[str_cols].apply(lambda col: col.str.strip())

    # Drop fully duplicate rows
    df = df.drop_duplicates()

    # Table-specific cleaning
    if table_name == "raw_orders":
        date_cols = [
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ]
        for col in date_cols:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    elif table_name == "raw_order_items":
        df["shipping_limit_date"] = pd.to_datetime(df["shipping_limit_date"], errors="coerce")
        df["price"] = pd.to_numeric(df["price"], errors="coerce")
        df["freight_value"] = pd.to_numeric(df["freight_value"], errors="coerce")

    elif table_name == "raw_order_payments":
        df["payment_value"] = pd.to_numeric(df["payment_value"], errors="coerce")
        df["payment_installments"] = pd.to_numeric(df["payment_installments"], errors="coerce")

    elif table_name == "raw_order_reviews":
        df["review_creation_date"] = pd.to_datetime(df["review_creation_date"], errors="coerce")
        df["review_answer_timestamp"] = pd.to_datetime(df["review_answer_timestamp"], errors="coerce")
        df["review_score"] = pd.to_numeric(df["review_score"], errors="coerce")

    elif table_name == "raw_products":
        numeric_cols = [
            "product_name_lenght",
            "product_description_lenght",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm",
        ]
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")

    elif table_name == "raw_geolocation":
        # Deduplicate geolocation by zip code prefix (keep first)
        df = df.drop_duplicates(subset=["geolocation_zip_code_prefix"], keep="first")

    final_rows = len(df)
    removed = initial_rows - final_rows
    if removed > 0:
        logger.info("  Removed %d duplicate/invalid rows from %s", removed, table_name)

    return df


# ---------------------------------------------------------------------------
# Step 3: Load into PostgreSQL
# ---------------------------------------------------------------------------
def load_to_postgres(engine):
    """Load all CSV files into the raw schema in PostgreSQL."""

    # Create raw schema
    with engine.connect() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))
        conn.commit()

    for filename, table_name in FILE_TABLE_MAP.items():
        filepath = DATA_DIR / filename
        if not filepath.exists():
            logger.warning("File not found: %s — skipping", filepath)
            continue

        logger.info("Loading %s → raw.%s", filename, table_name)
        df = pd.read_csv(filepath, low_memory=False)
        logger.info("  Raw shape: %s", df.shape)

        df = clean_dataframe(df, table_name)
        logger.info("  Cleaned shape: %s", df.shape)

        df.to_sql(
            name=table_name,
            con=engine,
            schema="raw",
            if_exists="replace",
            index=False,
            method="multi",
            chunksize=5000,
        )
        logger.info("  ✓ Loaded %d rows into raw.%s", len(df), table_name)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    logger.info("=" * 60)
    logger.info("Olist E-commerce Data Ingestion")
    logger.info("=" * 60)

    # Step 1: Download
    download_dataset()

    # Step 2 & 3: Clean and load
    engine = create_engine(DATABASE_URL)

    # Verify connection
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    logger.info("PostgreSQL connection successful.")

    load_to_postgres(engine)

    # Summary
    logger.info("=" * 60)
    logger.info("Ingestion complete. Tables loaded into 'raw' schema:")
    with engine.connect() as conn:
        result = conn.execute(
            text(
                "SELECT table_name FROM information_schema.tables "
                "WHERE table_schema = 'raw' ORDER BY table_name"
            )
        )
        for row in result:
            logger.info("  - raw.%s", row[0])
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
