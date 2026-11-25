-- PHASE 5: SUMMARY OF ALL CHECKS

-- WHAT THIS DOES
--   Runs every check from Phases 1 to 3 in one statement and prints one
--   row per check with a single count. Run it again after any change to
--   see what moved. The details behind each count are in files 01 to 03,
--   and what each fault costs is in file 04.

-- HOW TO READ IT
--   rows_found = 0 means the check looked and found nothing.
--   A count is not a ranking. A small count can still be a serious fault.

-- READ-ONLY: this file only counts. It changes no data.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/diagnosis/05_summary.sql

-- QUERY

\set QUIET on
\pset null '(null)'


\echo 'PHASE 5: One row per check'

WITH RECURSIVE walk AS (
    -- category loops: walk upwards from every category, remembering the path
    SELECT
        category_id        AS start_id,
        category_id        AS node_id,
        ARRAY[category_id] AS path,
        NULL::integer      AS repeated_id
    FROM categories

    UNION ALL

    SELECT
        walk.start_id,
        categories.parent_id,
        walk.path || categories.parent_id,
        CASE
            WHEN categories.parent_id = ANY(walk.path)
            THEN categories.parent_id
        END
    FROM walk
    JOIN categories
        ON categories.category_id = walk.node_id
    WHERE walk.repeated_id IS NULL
      AND categories.parent_id IS NOT NULL
),
item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
),
log_totals AS (
    SELECT
        product_id,
        SUM(change_qty) AS log_sum
    FROM inventory_log
    GROUP BY product_id
),
shared_emails AS (
    SELECT count(*) - 1 AS extra_rows
    FROM customers
    WHERE email IS NOT NULL
      AND trim(email) <> ''
    GROUP BY lower(trim(email))
    HAVING count(*) > 1
),
checks AS (
    -- PHASE 1: BROKEN LINKS
    SELECT 11 AS sort_order, 'Phase 1, Check 1' AS check_name,
           'Orders with no customer ID or a missing customer' AS what_is_counted,
           (SELECT count(*) FROM orders
             WHERE customer_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM customers
                                WHERE customers.customer_id = orders.customer_id)) AS rows_found
    UNION ALL
    SELECT 12, 'Phase 1, Check 2',
           'Order items with no order ID or a missing order',
           (SELECT count(*) FROM order_items
             WHERE order_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM orders
                                WHERE orders.order_id = order_items.order_id))
    UNION ALL
    SELECT 13, 'Phase 1, Check 3',
           'Stock log rows with no product ID or a missing product',
           (SELECT count(*) FROM inventory_log
             WHERE product_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM products
                                WHERE products.product_id = inventory_log.product_id))
    UNION ALL
    SELECT 14, 'Phase 1, Check 4',
           'Products without a category or pointing to a missing category',
           (SELECT count(*) FROM products
             WHERE category_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM categories
                                WHERE categories.category_id = products.category_id))
    UNION ALL
    SELECT 15, 'Phase 1, Check 5',
           'Categories whose parent does not exist',
           (SELECT count(*) FROM categories
             WHERE parent_id IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM categories AS parent
                                WHERE parent.category_id = categories.parent_id))
    UNION ALL
    SELECT 16, 'Phase 1, Check 6',
           'Categories in a loop (their own ancestor)',
           (SELECT count(DISTINCT start_id) FROM walk
             WHERE repeated_id = start_id)
    UNION ALL
    SELECT 17, 'Phase 1, Check 7',
           'Order items with no product ID or a missing product',
           (SELECT count(*) FROM order_items
             WHERE product_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM products
                                WHERE products.product_id = order_items.product_id))

    -- PHASE 2: WRONG NUMBERS
    UNION ALL
    SELECT 21, 'Phase 2, Check 1',
           'Orders whose total does not match their line items',
           (SELECT count(*) FROM orders
              JOIN item_totals ON item_totals.order_id = orders.order_id
             WHERE abs(orders.total_amount - item_totals.items_total) > 0.01)
    UNION ALL
    SELECT 22, 'Phase 2, Check 2',
           'Orders with no line items at all',
           (SELECT count(*) FROM orders
             WHERE NOT EXISTS (SELECT 1 FROM order_items
                                WHERE order_items.order_id = orders.order_id))
    UNION ALL
    SELECT 23, 'Phase 2, Check 3',
           'Products with negative stock',
           (SELECT count(*) FROM products WHERE stock_quantity < 0)
    UNION ALL
    SELECT 24, 'Phase 2, Check 4',
           'Products whose stock does not match the stock log',
           (SELECT count(*) FROM products
              LEFT JOIN log_totals ON log_totals.product_id = products.product_id
             WHERE products.stock_quantity IS DISTINCT FROM COALESCE(log_totals.log_sum, 0))
    UNION ALL
    SELECT 25, 'Phase 2, Check 5',
           'Orders dated in the future',
           (SELECT count(*) FROM orders WHERE order_date > now())
    UNION ALL
    SELECT 27, 'Phase 2, Check 7',
           'Order items with a bad quantity or a missing, zero or negative price',
           (SELECT count(*) FROM order_items
             WHERE quantity <= 0 OR quantity IS NULL
                OR unit_price <= 0 OR unit_price IS NULL)

    -- PHASE 3: MESSY LABELS
    UNION ALL
    SELECT 31, 'Phase 3, Checks 1 and 2',
           'Orders whose status has capital letters or stray spaces',
           (SELECT count(*) FROM orders WHERE status <> lower(trim(status)))
    UNION ALL
    SELECT 32, 'Phase 3, Checks 1 and 2',
           'Orders using "complete" or "canceled" (variant spellings)',
           (SELECT count(*) FROM orders
             WHERE lower(trim(status)) IN ('complete', 'canceled'))
    UNION ALL
    SELECT 33, 'Phase 3, Check 3',
           'Extra customer rows sharing an email with another row',
           (SELECT COALESCE(SUM(extra_rows), 0) FROM shared_emails)
    UNION ALL
    SELECT 34, 'Phase 3, Check 4',
           'Customers whose phone does not start with +233',
           (SELECT count(*) FROM customers
             WHERE phone IS NOT NULL AND phone NOT LIKE '+233%')
    UNION ALL
    SELECT 35, 'Phase 3, Check 5',
           'Emails with stray spaces at the start or end',
           (SELECT count(*) FROM customers WHERE email <> trim(email))
)
SELECT
    check_name,
    what_is_counted,
    rows_found
FROM checks
ORDER BY sort_order;