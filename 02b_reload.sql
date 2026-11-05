-- 02b_reload.sql
-- Reload retail_raw with a source marker: sheet 1 = 2009-10 file, sheet 2 = 2010-11 file.
-- 1-9 Dec 2010 is in both files. The marker lets us keep those days from one file
-- without touching real repeats inside a file.

TRUNCATE retail_raw;

ALTER TABLE retail_raw ADD COLUMN sheet INTEGER;

-- Run in SQL Shell (psql). The column list is needed because the table now has 9 columns.
-- \copy retail_raw(invoice, stock_code, description, quantity, invoice_date, price, customer_id, country) FROM 'W:/SQL Practice/L20-project/retail_2009.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ';')
UPDATE retail_raw
SET sheet = 1
WHERE sheet IS NULL;

-- \copy retail_raw(invoice, stock_code, description, quantity, invoice_date, price, customer_id, country) FROM 'W:/SQL Practice/L20-project/retail_2010.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ';')
UPDATE retail_raw
SET sheet = 2
WHERE sheet IS NULL;

-- Q: Did the reload keep every row?
SELECT COUNT(*)
FROM retail_raw;
-- Result: 1,067,371 (same as before the reload)

-- Q: How many rows came from each sheet?
SELECT COUNT(CASE WHEN sheet = 1 THEN 1 END) AS first_sheet,
       COUNT(CASE WHEN sheet = 2 THEN 1 END) AS second_sheet
FROM retail_raw;
-- Result: 525,461 + 541,910 = 1,067,371

-- Q: How many overlap rows are in each sheet?
SELECT COUNT(CASE WHEN sheet = 1 THEN 1 END) AS first_sheet,
       COUNT(CASE WHEN sheet = 2 THEN 1 END) AS second_sheet
FROM retail_raw
WHERE invoice_date LIKE '0_.12.2010%';
-- Result: 22,523 in each sheet

-- Q: Is the overlap an exact copy, row by row?
SELECT invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
FROM retail_raw
WHERE invoice_date LIKE '0_.12.2010%'
  AND sheet = 1
EXCEPT ALL
SELECT invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
FROM retail_raw
WHERE invoice_date LIKE '0_.12.2010%'
  AND sheet = 2;
-- Result: 0 rows
-- So: row counts are equal, so the reverse check is 0 too. The overlap is an exact copy.
--     22,523 of the 34,335 extra copies in F6 come from the overlap;
--     the other 11,812 are repeats inside the source files and are kept.
