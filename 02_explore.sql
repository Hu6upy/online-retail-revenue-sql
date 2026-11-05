-- 02_explore.sql
-- Profile retail_raw and document data issues F1-F6.

-- =====================================================================
-- Nulls and distinct values per column
-- =====================================================================

SELECT COUNT(*)                       AS total,
       COUNT(DISTINCT invoice)        AS invoice_distinct,
       COUNT(*) - COUNT(invoice)      AS invoice_nulls,
       COUNT(DISTINCT stock_code)     AS stock_code_distinct,
       COUNT(*) - COUNT(stock_code)   AS stock_code_nulls,
       COUNT(DISTINCT description)    AS description_distinct,
       COUNT(*) - COUNT(description)  AS description_nulls,
       COUNT(DISTINCT quantity)       AS quantity_distinct,
       COUNT(*) - COUNT(quantity)     AS quantity_nulls,
       COUNT(DISTINCT invoice_date)   AS invoice_date_distinct,
       COUNT(*) - COUNT(invoice_date) AS invoice_date_nulls,
       COUNT(DISTINCT price)          AS price_distinct,
       COUNT(*) - COUNT(price)        AS price_nulls,
       COUNT(DISTINCT customer_id)    AS customer_id_distinct,
       COUNT(*) - COUNT(customer_id)  AS customer_id_nulls,
       COUNT(DISTINCT country)        AS country_distinct,
       COUNT(*) - COUNT(country)      AS country_nulls
FROM retail_raw;
-- Result:
--   total                 1,067,371
--   invoice_distinct         53,628   invoice_nulls             0
--   stock_code_distinct       5,305   stock_code_nulls          0
--   description_distinct      5,698   description_nulls     4,382
--   quantity_distinct         1,057   quantity_nulls            0
--   invoice_date_distinct    47,635   invoice_date_nulls        0
--   price_distinct            2,807   price_nulls               0
--   customer_id_distinct      5,942   customer_id_nulls   243,007
--   country_distinct             43   country_nulls             0

-- =====================================================================
-- F1. Missing customer_id
-- =====================================================================

-- Result (from the profile above): 243,007 rows, about 23% of the data.
-- So: per-customer analysis is affected, revenue is not. Rows are kept.

-- =====================================================================
-- F2. Missing description
-- =====================================================================

-- Result (from the profile above): 4,382 rows.
-- So: revenue uses price and quantity, so these rows are kept.

-- =====================================================================
-- F3. Stock codes with several descriptions
-- =====================================================================

-- Q: What do the extra descriptions look like?
SELECT DISTINCT description
FROM retail_raw
WHERE stock_code = '20713';
-- Result: JUMBO BAG OWLS, found, Found, missing, Marked as 23343,
--         wrongly coded-23343, wrongly coded 23343,
--         wrongly marked 23343, wrongly marked. 23343 in box, NULL

-- Q: How many codes have more than one description?
WITH multi_desc_codes AS (
    SELECT stock_code
    FROM retail_raw
    GROUP BY stock_code
    HAVING COUNT(DISTINCT description) > 1
)
SELECT COUNT(*) AS codes_with_multiple_descriptions
FROM multi_desc_codes;
-- Result: 1,232 codes
-- So: grouping by description would split one product into several rows,
--     so product analysis must group by stock_code.
--     Only 393 more descriptions than codes (5,698 vs 5,305), yet 1,232 codes are
--     affected: the same note ('missing', 'found') sits on many different codes.

-- =====================================================================
-- F4. Cancellations and other invoice prefixes
-- =====================================================================

-- Q: How many cancellations are there? (Invoice starts with 'C', per UCI.)
SELECT COUNT(*)                AS cancellation_rows,
       COUNT(DISTINCT invoice) AS cancelled_invoices
FROM retail_raw
WHERE invoice LIKE 'C%';
-- Result: 19,494 rows, 8,292 invoices. No lowercase 'c' prefix.
-- So: quantity * price is negative here, so cancellations reduce revenue.
--     About 2-3 items per cancellation vs about 20 per regular invoice:
--     usually single items are cancelled, not whole orders.

-- Found during stage 3: a third invoice prefix.
-- Q: How many invoices start with 'A'?
SELECT COUNT(*)                AS a_rows,
       COUNT(DISTINCT invoice) AS a_invoices
FROM retail_raw
WHERE invoice LIKE 'A%';
-- Result: 6 rows, 6 invoices

-- Q: Are all 'A' rows bad-debt adjustments (code B)?
SELECT COUNT(*)
FROM retail_raw
WHERE invoice LIKE 'A%'
  AND stock_code <> 'B';
-- Result: 0
-- So: 'A' invoices are bad-debt adjustments. They aren't cancellations,
--     and code B is excluded from revenue (see 03_clean.sql).

-- =====================================================================
-- F5. Warehouse adjustments
-- =====================================================================

-- Signs: price 0, no customer, invoice without 'C', positive and negative quantity,
-- free-text notes in description ('found', 'missing', '?', 'check', 'broken').
-- Notes can't be used as the rule: too many spellings, and some rows have no description.

-- Q: How many rows have no customer and price 0?
SELECT COUNT(*) AS adjustment_rows
FROM retail_raw
WHERE customer_id IS NULL
  AND price = '0';
-- Result: 6,131 rows

SELECT description, stock_code, quantity, price, customer_id, invoice
FROM retail_raw
WHERE customer_id IS NULL
  AND price = '0'
LIMIT 20;
-- Result: two groups:
--   1) warehouse notes ('?', 'check', 'missing');
--   2) regular product names with small quantities (CHILDS GARDEN SPADE BLUE, CHILLI LIGHTS).
--      These may be samples, gifts or price-entry errors; the data can't tell.
-- So: price 0 adds nothing to revenue, but both groups distort units sold.
--     Only '0' is used for zero prices, so the text comparison catches them all.

-- =====================================================================
-- F6. Full-row duplicates
-- =====================================================================

-- Q: Are there rows identical in all 8 columns?
WITH distinct_rows AS (
    SELECT DISTINCT invoice, stock_code, description, quantity,
                    invoice_date, price, customer_id, country
    FROM retail_raw
)
SELECT COUNT(*)                                     AS distinct_rows,
       (SELECT COUNT(*) FROM retail_raw) - COUNT(*) AS duplicate_rows,
       ROUND(100.0 * ((SELECT COUNT(*) FROM retail_raw) - COUNT(*))
             / (SELECT COUNT(*) FROM retail_raw), 2) AS duplicate_pct
FROM distinct_rows;
-- Result: 1,033,036 distinct rows, 34,335 extra copies (3.22%)
-- So: most repeated rows are dated 1-9 Dec 2010. In the CSV files, sheet 1 ends on
--     09.12.2010 and sheet 2 starts on 01.12.2010, so those days were loaded twice.

-- Q: How many rows fall in the overlap?
SELECT COUNT(*) AS overlap_rows
FROM retail_raw
WHERE invoice_date LIKE '0_.12.2010%';
-- Result: 45,046 rows (22,523 from each sheet, see 02b_reload.sql)
-- So: 22,523 of 34,335 extra copies (about 2/3) come from the sheet overlap.
--     The other 11,812 were already repeated in the source data and may be real purchases.
-- Decision: remove the sheet 1 copy of the overlap and keep the source repeats.
