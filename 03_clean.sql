-- 03_clean.sql
-- Check each text column, record the revenue decisions and build retail_clean.
-- Sections C1-C2 use retail_raw, so their numbers include the 1-9 Dec 2010 overlap.

-- =====================================================================
-- C1. price to NUMERIC
-- =====================================================================

-- Q: Does every price cast to a number?
SELECT REPLACE(price, ',', '.')::NUMERIC
FROM retail_raw;
-- Result: runs over all 1,067,371 rows without an error.
-- So: one bad value would fail the whole query, so every price casts.

-- Q: Are there empty prices?
SELECT COUNT(*)
FROM retail_raw
WHERE price IS NULL;
-- Result: 0

-- Q: Do min and max look like product prices?
SELECT MIN(REPLACE(price, ',', '.')::NUMERIC) AS min_price,
       MAX(REPLACE(price, ',', '.')::NUMERIC) AS max_price
FROM retail_raw;
-- Result: -53594.36 and 38970
-- So: neither looks like a gift-shop price, so both rows are checked below.
--     MIN/MAX on raw text gives -11062,06 and 99,96 because text sorts character
--     by character, so the cast must come before the aggregate.

SELECT *
FROM retail_raw
WHERE price = '-53594,36';
-- Result: A506401 | B | Adjust bad debt | qty 1 | 29.04.2010 | no customer
-- So: a bad-debt write-off, not a sale. Keeping it would show a false 53k drop
--     in April 2010 sales. Decision: exclude it from revenue.

SELECT *
FROM retail_raw
WHERE price = '38970';
-- Result: C556445 | M | Manual | qty -1 | 10.06.2011 | customer 15098

SELECT *
FROM retail_raw
WHERE customer_id = '15098';
-- Result: 556444: 60 x PICNIC BASKET WICKER 60 PIECES at 649.5 = 38,970
--         C556445: Manual, cancels exactly 38,970
--         556446: re-orders 1 piece
--         C556448: cancels a separate 60 x 4.95 order
-- So: an ordering mistake, cancelled and re-ordered. The day nets to one basket
--     only if cancellations are summed with their minus.
--     Decision: keep cancellations and subtract them from revenue.
--     The sale sits under code 22502 and its cancellation under M, so revenue
--     by product would overstate this basket by 38,970.

-- Q: Are all zero prices written as '0'?
SELECT COUNT(*)
FROM retail_raw
WHERE REPLACE(price, ',', '.')::NUMERIC = 0;
-- Result: 6,202, same as the text check price = '0'.
-- So: there are no other zero formats.

-- ---------------------------------------------------------------------
-- Service codes
-- ---------------------------------------------------------------------

-- Q: Which rows are not products? Product codes start with a digit.
SELECT COUNT(*)                   AS service_rows,
       COUNT(DISTINCT stock_code) AS service_codes
FROM retail_raw
WHERE stock_code !~ '^[0-9]';
-- Result: 6,093 rows, 62 codes

-- Q: Could NULL stock codes slip past the rule?
SELECT COUNT(*)
FROM retail_raw
WHERE stock_code IS NULL;
-- Result: 0
-- So: all service rows are covered. NULL !~ '...' would be UNKNOWN and drop out of WHERE.

-- Q: Which service codes move money?
SELECT stock_code,
       COUNT(*) AS rows_count,
       SUM(quantity::INTEGER * REPLACE(price, ',', '.')::NUMERIC) AS total_sum
FROM retail_raw
WHERE stock_code !~ '^[0-9]'
GROUP BY stock_code
ORDER BY ABS(SUM(quantity::INTEGER * REPLACE(price, ',', '.')::NUMERIC)) DESC;
-- Result: 11 codes above 6k in absolute value:
--   DOT 322,647 | AMAZONFEE -260,764 | B -147,614 | POST 112,341
--   M -82,796 | BANK CHARGES -35,563 | D -13,485 | C2 13,386
--   CRUK -7,933 | ADJUST 6,835 | S -6,066
--   Every other code is below 1,000.
-- So: decisions are needed only for these 11. Gift vouchers are a separate
--     revenue group; other small codes stay out.
--     Row count and money are different things: B has 6 rows and -147k.

-- Gift vouchers (gift_0001_xx): no negative rows, no customer on any row.
-- A 30 pound voucher costs 25 (30 / 1.2), and prices follow UK VAT rates
-- (15%, 17.5%, 20%), so revenue in this project is net of VAT.

-- Q: Which of the top 11 codes belong in revenue?
SELECT stock_code,
       description,
       COUNT(*) AS rows_count
FROM retail_raw
WHERE stock_code IN ('DOT', 'AMAZONFEE', 'B', 'POST', 'M', 'BANK CHARGES',
                     'D', 'C2', 'CRUK', 'ADJUST', 'S')
GROUP BY stock_code, description
ORDER BY stock_code;
-- Decisions:
--   code          | what it is                           | in revenue?
--   --------------+--------------------------------------+-----------------
--   DOT           | postage (website orders)             | no
--   POST          | postage                              | no
--   C2            | carriage                             | no
--   AMAZONFEE     | Amazon fees                          | no
--   BANK CHARGES  | bank fees                            | no
--   CRUK          | Cancer Research UK commission        | no
--   S             | samples                              | no
--   B             | bad-debt write-off                   | no
--   ADJUST        | manual adjustment by named staff,    | no
--                 | purpose unknown                      |
--   M             | manual corrections, incl. product    | yes (mixed code)
--                 | cancellations                        |
--   D             | discounts                            | yes, as a minus
--
-- Rules:
--   Store revenue   = product codes + M + D + gift vouchers.
--   Product revenue = product codes only. M and D can't be tied to a product,
--                     so a by-product report shows them as separate lines.

-- =====================================================================
-- C2. quantity to INTEGER
-- =====================================================================

-- Q: Does every quantity cast to INTEGER?
SELECT quantity::INTEGER
FROM retail_raw;
-- Result: runs over all rows without an error.

-- Q: Are there empty quantities?
SELECT COUNT(*)
FROM retail_raw
WHERE quantity IS NULL;
-- Result: 0

-- Q: Are there zero quantities?
SELECT COUNT(*)
FROM retail_raw
WHERE quantity::INTEGER = 0;
-- Result: 0

-- Q: Do min and max look like order quantities?
SELECT MAX(quantity::INTEGER) AS max_quantity,
       MIN(quantity::INTEGER) AS min_quantity
FROM retail_raw;
-- Result: 80995 and -80995
-- So: one pair, 581483 and C581484: 80,995 x PAPER CRAFT LITTLE BIRDIE,
--     ordered and cancelled 12 minutes later. It nets to 0.

-- Q: Are the largest lines by money explained?
SELECT invoice, stock_code, description, quantity, price, customer_id, invoice_date,
       quantity::INTEGER * REPLACE(price, ',', '.')::NUMERIC AS line_total
FROM retail_raw
ORDER BY ABS(quantity::INTEGER * REPLACE(price, ',', '.')::NUMERIC) DESC
LIMIT 20;
-- Result: all 20 rows fall into known groups:
--   order and cancellation pairs that net to 0 (birdie, storage jar, picnic basket
--   via M, a Manual pair); service codes B, BANK CHARGES, AMAZONFEE;
--   one large real sale (9,360 x T-light holder).
--   Two identical AMAZONFEE rows on 07.12.2010 are part of the F6 overlap.
-- So: no unexplained outliers. Dropping cancellations would add hundreds of
--     thousands to revenue.

-- =====================================================================
-- C3. invoice_date to TIMESTAMP
-- =====================================================================

-- Raw format: '01.12.2009 07:45', template 'DD.MM.YYYY HH24:MI'.
-- A plain ::TIMESTAMP doesn't fit this format.

-- Q: Does every date convert?
SELECT TO_TIMESTAMP(invoice_date, 'DD.MM.YYYY HH24:MI')
FROM retail_raw;
-- Result: 1,067,371 rows, no errors.

-- Q: Are there empty dates?
SELECT COUNT(*)
FROM retail_raw
WHERE invoice_date IS NULL
   OR invoice_date = '';
-- Result: 0

-- Q: Does the date range match the dataset?
SELECT MIN(TO_TIMESTAMP(invoice_date, 'DD.MM.YYYY HH24:MI')),
       MAX(TO_TIMESTAMP(invoice_date, 'DD.MM.YYYY HH24:MI'))
FROM retail_raw;
-- Result: 2009-12-01 07:45 to 2011-12-09 12:50
-- So: it matches. Day and month aren't swapped: a swapped template would fail
--     on any day above 12, and the data has those days.

-- =====================================================================
-- C4. customer_id to INTEGER
-- =====================================================================

-- Raw sample: '13085'. Digits only, so no REPLACE is needed.
-- Why INTEGER: whole-number IDs, and it catches any non-numeric value.

-- Q: Does every value convert, and do filled + empty = all rows?
SELECT COUNT(customer_id::INTEGER)
FROM retail_raw;
-- Result: 824,364 filled; 824,364 + 243,007 empty = 1,067,371

-- Q: Does the empty count match F1?
SELECT COUNT(*)
FROM retail_raw
WHERE customer_id IS NULL;
-- Result: 243,007
-- So: it matches. There are no empty strings: ''::INTEGER would have failed.

-- =====================================================================
-- Build retail_clean
-- =====================================================================

-- All rows with real types. Revenue rules are applied in 04_revenue.sql.
-- 1-9 Dec 2010 is kept from sheet 2 only (see 02b_reload.sql).
-- Expected rows: 1,067,371 - 22,523 = 1,044,848
CREATE TABLE retail_clean AS
SELECT invoice,
       stock_code,
       description,
       quantity::INTEGER AS quantity,
       TO_TIMESTAMP(invoice_date, 'DD.MM.YYYY HH24:MI')::TIMESTAMP AS invoice_date,
       REPLACE(price, ',', '.')::NUMERIC AS price,
       customer_id::INTEGER AS customer_id,
       country,
       sheet
FROM retail_raw
WHERE NOT (invoice_date LIKE '0_.12.2010%' AND sheet = 1);
-- Result: 1,044,848 rows, as expected.
-- ::TIMESTAMP drops the time zone that TO_TIMESTAMP adds.

-- Q: Did the columns get the right types?
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'retail_clean';
-- Result: quantity, customer_id, sheet: integer; price: numeric;
--         invoice_date: timestamp without time zone; the rest: text.
