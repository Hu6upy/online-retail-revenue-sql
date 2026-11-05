-- 04_revenue.sql
-- Reconcile all rows and calculate monthly revenue.
-- Source: retail_clean (1,044,848 rows). Money = quantity * price, GBP, net of VAT.

-- =====================================================================
-- 4.1 Reconciliation
-- =====================================================================

-- Q: Does every row fall into one group, and do the groups add up to the table?
SELECT CASE
           WHEN stock_code = 'D' THEN 'discount'
           WHEN stock_code = 'M' THEN 'manual'
           WHEN invoice ~ '^C[0-9]' AND stock_code ~ '^[0-9]' THEN 'cancellation'
           WHEN stock_code ~ '^[0-9]' THEN 'product_sales'
           WHEN stock_code LIKE 'gift%' THEN 'gift'
           ELSE 'other'
       END AS line_group,
       COUNT(*) AS count_rows,
       SUM(price * quantity) AS total_money
FROM retail_clean
GROUP BY line_group;
-- Result:
--   product_sales   1,020,883 rows   19,699,784.97
--   cancellation       17,973 rows     -719,656.34
--   manual              1,398 rows      -82,950.62
--   discount              173 rows      -12,879.63
--   gift                  100 rows        1,686.61
--   other               4,321 rows       23,777.128
--   total           1,044,848 rows   18,909,762.118
-- So: matches SELECT COUNT(*), SUM(price * quantity) FROM retail_clean.
--     Store revenue (all groups except 'other'): 18,885,984.99

-- =====================================================================
-- 4.2 Monthly revenue
-- =====================================================================

-- product_revenue: product sales + cancellations
-- store_revenue:   product revenue + manual + discount + gift
WITH labeled AS (
    SELECT DATE_TRUNC('month', invoice_date) AS month,
           price * quantity AS money,
           CASE
               WHEN stock_code = 'D' THEN 'discount'
               WHEN stock_code = 'M' THEN 'manual'
               WHEN invoice ~ '^C[0-9]' AND stock_code ~ '^[0-9]' THEN 'cancellation'
               WHEN stock_code ~ '^[0-9]' THEN 'product_sales'
               WHEN stock_code LIKE 'gift%' THEN 'gift'
               ELSE 'other'
           END AS line_group
    FROM retail_clean
)
SELECT month,
       SUM(CASE WHEN line_group IN ('product_sales', 'cancellation')
                THEN money ELSE 0 END) AS product_revenue,
       SUM(CASE WHEN line_group IN ('product_sales', 'cancellation', 'discount', 'manual', 'gift')
                THEN money ELSE 0 END) AS store_revenue
FROM labeled
GROUP BY month
ORDER BY month;
-- Result: 25 months, Dec 2009 to Dec 2011.
-- Check: store_revenue over all months = 18,885,984.99 (same as 4.1);
--        product_revenue over all months = 18,980,128.63 (product_sales + cancellation in 4.1).
-- So: Dec 2011 is a partial month (data ends 09.12.2011), so it can't be compared
--     with full months. Dec 2009 is a full month.
--     store_revenue is usually below product_revenue: discounts and manual
--     corrections outweigh the small gift voucher sales.
