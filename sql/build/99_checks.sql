-- CHECKS: one row per check. Every row with a passed column should say t.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/99_checks.sql
-- The results are written to sql/build_outputs/02_checks.md (the folder must exist).

\set QUIET on
\o sql/build_outputs/02_checks.md
\qecho '# Checks'
\qecho
\qecho 'One row per check. A row with t in the passed column passed. A row with nothing in passed is information only.'
\qecho
\qecho '## The checks'
\qecho '```text'

WITH independent_counted_orders AS (
    -- the same rule as the report, written a second way, straight from the tables
    SELECT orders.customer_id, orders.total_amount
    FROM orders
    WHERE lower(btrim(orders.status)) <> ALL (ARRAY['cancelled', 'canceled', 'refunded'])
      AND orders.order_date <= now()
      AND orders.customer_id IN (SELECT customers.customer_id FROM customers)
)
SELECT 1 AS check_number, 'Low stock: every product is in exactly one line (top level + 2 extra lines)' AS check_name,
       (SELECT sum(products_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)::text AS result,
       (SELECT count(*) FROM products)::text AS expected,
       (SELECT sum(products_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)
         = (SELECT count(*) FROM products) AS passed
UNION ALL
SELECT 2, 'Low stock: out-of-stock products add up',
       (SELECT sum(out_of_stock_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)::text,
       (SELECT count(*) FROM products WHERE stock_quantity <= 0)::text,
       (SELECT sum(out_of_stock_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)
         = (SELECT count(*) FROM products WHERE stock_quantity <= 0)
UNION ALL
SELECT 3, 'Low stock: low-stock products add up',
       (SELECT sum(low_stock_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)::text,
       (SELECT count(*) FROM products, stock_settings
         WHERE stock_quantity > 0 AND stock_quantity < low_stock_threshold)::text,
       (SELECT sum(low_stock_in_branch) FROM low_stock_by_category WHERE depth = 1 OR depth IS NULL)
         = (SELECT count(*) FROM products, stock_settings
             WHERE stock_quantity > 0 AND stock_quantity < low_stock_threshold)
UNION ALL
SELECT 4, 'Category tree: deepest level reached (information)',
       (SELECT max(depth) FROM category_tree)::text, '4 in the loaded data', NULL
UNION ALL
SELECT 5, 'Category tree: categories reached out of all categories (information)',
       (SELECT count(*) FROM category_tree)::text || ' of ' || (SELECT count(*) FROM categories)::text,
       '3 are in a loop or have a missing parent', NULL
UNION ALL
SELECT 6, 'Report: every customer appears once',
       (SELECT count(*) FROM monday_customer_summary)::text,
       (SELECT count(*) FROM customers)::text,
       (SELECT count(*) FROM monday_customer_summary) = (SELECT count(*) FROM customers)
UNION ALL
SELECT 7, 'Report: total spent equals an independent sum',
       (SELECT sum(total_spent) FROM monday_customer_summary)::text,
       (SELECT sum(total_amount) FROM independent_counted_orders)::text,
       (SELECT sum(total_spent) FROM monday_customer_summary)
         = (SELECT sum(total_amount) FROM independent_counted_orders)
UNION ALL
SELECT 8, 'Report: order count equals an independent count',
       (SELECT sum(order_count) FROM monday_customer_summary)::text,
       (SELECT count(*) FROM independent_counted_orders)::text,
       (SELECT sum(order_count) FROM monday_customer_summary)
         = (SELECT count(*) FROM independent_counted_orders)
UNION ALL
SELECT 9, 'Report: 12 months for every customer',
       (SELECT count(*) FROM monday_monthly_spend)::text,
       ((SELECT count(*) FROM customers) * 12)::text,
       (SELECT count(*) FROM monday_monthly_spend) = (SELECT count(*) FROM customers) * 12
UNION ALL
SELECT 10, 'Report: last running total equals total spent (customers that differ)',
       (SELECT count(*)
          FROM monday_customer_summary
          JOIN (SELECT DISTINCT ON (customer_id) customer_id, running_total
                  FROM monday_monthly_spend ORDER BY customer_id, month_start DESC) AS last_month
            ON last_month.customer_id = monday_customer_summary.customer_id
         WHERE last_month.running_total <> monday_customer_summary.total_spent)::text,
       '0',
       (SELECT count(*)
          FROM monday_customer_summary
          JOIN (SELECT DISTINCT ON (customer_id) customer_id, running_total
                  FROM monday_monthly_spend ORDER BY customer_id, month_start DESC) AS last_month
            ON last_month.customer_id = monday_customer_summary.customer_id
         WHERE last_month.running_total <> monday_customer_summary.total_spent) = 0
UNION ALL
SELECT 11, 'Report: top 100 has 100 rows (more only if tied at rank 100)',
       (SELECT count(*) FROM monday_top_100)::text, '100',
       (SELECT count(*) FROM monday_top_100) >= 100
UNION ALL
SELECT 12, 'Trail: no movement names an order that is missing',
       (SELECT movements_naming_a_missing_order FROM stock_trail_check)::text, '0',
       (SELECT movements_naming_a_missing_order FROM stock_trail_check) = 0
UNION ALL
SELECT 13, 'Order function and stock rule exist',
       (SELECT count(*) FROM pg_proc WHERE proname IN ('place_order', 'restock_product', 'correct_stock'))::text
         || ' functions, rule validated = '
         || coalesce((SELECT convalidated::text FROM pg_constraint WHERE conname = 'products_stock_not_negative'), 'missing'),
       '3 functions, rule validated = false (it skips the 14 old negatives)',
       (SELECT count(*) FROM pg_proc WHERE proname IN ('place_order', 'restock_product', 'correct_stock')) = 3
ORDER BY check_number;
\qecho '```'
\qecho
\qecho '## What the Monday report leaves out (one row)'
\qecho '```text'
\x on
SELECT * FROM monday_report_notes;
\qecho '```'
\qecho
\qecho '## What the stock trail cannot explain (one row)'
\qecho '```text'
SELECT * FROM stock_trail_check;
\x off
\qecho '```'
\o