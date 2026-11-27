-- Builds everything, in order, on a freshly loaded database, then writes a
-- build summary to sql/build_outputs/01_build_summary.md
-- Run from the project root (the folder sql/build_outputs must exist):
--   docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql
-- After any reload (schema.sql + load.sql) run this file again: the reload drops
-- the tables and, with them, every view built on them.
\i sql/build/01_place_order.sql
\i sql/build/02_low_stock.sql
\i sql/build/03_monday_report.sql
\i sql/build/04_stock_trail.sql

\set QUIET on
\o sql/build_outputs/01_build_summary.md
\qecho '# Build summary'
\qecho
\qecho 'Written by sql/build/run_all.sql. Every table below should show the loaded row counts, and every object below should exist.'
\qecho
\qecho '## Database and time'
\qecho '```text'
SELECT version() AS postgresql_version, now()::timestamp(0) AS written_at;
\qecho '```'
\qecho
\qecho '## Row counts (a fresh load gives 94, 4023, 40420, 159384, 336559, 282352)'
\qecho '```text'
SELECT 'categories' AS table_name, count(*) AS rows FROM categories
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'inventory_log', count(*) FROM inventory_log;
\qecho '```'
\qecho
\qecho '## The three id columns (expect is_identity = YES and BY DEFAULT)'
\qecho '```text'
SELECT table_name, column_name, is_identity, identity_generation
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND ((table_name = 'orders' AND column_name = 'order_id')
    OR (table_name = 'order_items' AND column_name = 'order_item_id')
    OR (table_name = 'inventory_log' AND column_name = 'log_id'))
ORDER BY table_name, column_name;
\qecho '```'
\qecho
\qecho '## Functions (expect 3)'
\qecho '```text'
SELECT proname AS function_name, pg_get_function_identity_arguments(oid) AS arguments
FROM pg_proc
WHERE proname IN ('place_order', 'restock_product', 'correct_stock')
ORDER BY proname;
\qecho '```'
\qecho
\qecho '## Views (expect 10)'
\qecho '```text'
SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = current_schema()
ORDER BY table_name;
\qecho '```'
\qecho
\qecho '## Stock rule (expect validated = f: it skips the 14 old negatives)'
\qecho '```text'
SELECT conname AS rule_name, convalidated AS validated
FROM pg_constraint
WHERE conname = 'products_stock_not_negative';
\qecho '```'
\o