-- Load Kloud Kart's extract. Run from this directory so the relative paths
-- resolve:
--
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f schema.sql
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f load.sql
--
-- \copy runs client-side, so this works against a database in Docker or on
-- another host without needing server filesystem access.

\set ON_ERROR_STOP on
\timing on

\copy categories    (category_id, category_name, parent_id)                                  FROM 'data/categories.csv'    WITH (FORMAT csv, HEADER true, NULL '')
\copy products      (product_id, product_name, category_id, price, stock_quantity, created_at) FROM 'data/products.csv'      WITH (FORMAT csv, HEADER true, NULL '')
\copy customers     (customer_id, full_name, email, phone, city, registered_at)              FROM 'data/customers.csv'     WITH (FORMAT csv, HEADER true, NULL '')
\copy orders        (order_id, customer_id, order_date, status, total_amount)                FROM 'data/orders.csv'        WITH (FORMAT csv, HEADER true, NULL '')
\copy order_items   (order_item_id, order_id, product_id, quantity, unit_price)              FROM 'data/order_items.csv'   WITH (FORMAT csv, HEADER true, NULL '')
\copy inventory_log (log_id, product_id, change_qty, reason, created_at, note)               FROM 'data/inventory_log.csv' WITH (FORMAT csv, HEADER true, NULL '')

ANALYZE;

SELECT 'categories'    AS table_name, count(*) FROM categories
UNION ALL SELECT 'products',      count(*) FROM products
UNION ALL SELECT 'customers',     count(*) FROM customers
UNION ALL SELECT 'orders',        count(*) FROM orders
UNION ALL SELECT 'order_items',   count(*) FROM order_items
UNION ALL SELECT 'inventory_log', count(*) FROM inventory_log
ORDER BY 1;
