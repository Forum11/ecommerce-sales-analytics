-- ============================================================
-- Olist E-commerce Analytics - PostgreSQL Schema Setup
-- ============================================================
-- Run this BEFORE the ingestion script to set up the database.
-- Usage: psql -U postgres -f setup_database.sql
-- ============================================================

-- Create the database (run as superuser)
-- DROP DATABASE IF EXISTS olist;
-- CREATE DATABASE olist;

-- Connect to olist database before running the rest
-- \c olist

-- Create schemas for the medallion architecture
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Grant usage (adjust role name as needed)
-- GRANT USAGE ON SCHEMA raw, bronze, silver, gold TO your_role;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw, bronze, silver, gold TO your_role;
