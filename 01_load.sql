-- 01_load.sql
-- Load Online Retail II (UCI) into local PostgreSQL.

CREATE DATABASE retail;

-- Everything below runs in the retail database.
-- All columns are TEXT on purpose: raw data goes in as-is, types are cast in 03_clean.sql.
CREATE TABLE retail_raw (
    invoice      TEXT,
    stock_code   TEXT,
    description  TEXT,
    quantity     TEXT,
    invoice_date TEXT,
    price        TEXT,
    customer_id  TEXT,
    country      TEXT
);

-- Run in SQL Shell (psql), one command per file.
-- The CSV files were exported from Excel with European settings, so the delimiter is ';'.
-- \copy retail_raw FROM 'W:/SQL Practice/L20-project/retail_2009.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ';')
-- \copy retail_raw FROM 'W:/SQL Practice/L20-project/retail_2010.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ';')

-- Q: Did every row load?
SELECT COUNT(*)
FROM retail_raw;
-- Result: 1,067,371 (525,461 + 541,910)
-- So: matches the UCI record count.
