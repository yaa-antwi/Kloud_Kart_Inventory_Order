-- PHASE 1: BROKEN LINKS

-- WHAT THIS CHECKS
--   Rows that point to something that does not exist. Example: an order
--   that names a customer who is not in the customers table.
--   Each check counts two different situations separately:
--     1. NO VALUE: the link column is empty (NULL), so nothing was supplied
--     2. MISSING TARGET: the link column has a value, but nothing matches it

-- WHY IT HAPPENS
--   The database has no foreign keys, so nothing stops a row from
--   pointing at a missing record.

-- WHY IT MATTERS
--   Orphaned rows silently drop out of joins. Reports that join across
--   tables (spend per customer, low stock by category) can leave them out
--   without any error, so the totals look fine but are wrong.

-- CHECKS IN THIS FILE
--   1   Orders with no customer ID or a missing customer
--   2   Order items with no order ID or a missing order
--   3   Inventory log rows with no product ID or a missing product
--   4   Products without a category or pointing to a missing category
--   5   Categories whose parent does not exist
--   6   Category loops and categories hanging below a loop
--   7   Order items with no product ID or a missing product

-- READ-ONLY: this file only counts. It changes no data.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/diagnosis/01_broken_links.sql

-- QUERIES

\set QUIET on
\pset null '(null)'

--- 1. Orders whose customer does not exist
\echo 'PHASE 1, Check 1: Orders with no customer ID or a missing customer'

SELECT
    count(*) FILTER (
        WHERE customer_id IS NULL
    ) AS orders_with_no_customer_id,
    count(*) FILTER (
        WHERE customer_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM customers
              WHERE customers.customer_id = orders.customer_id
          )
    ) AS orders_pointing_to_missing_customer
FROM orders;


--- 2. Order items whose order does not exist
\echo 'PHASE 1, Check 2: Order items with no order ID or a missing order'

SELECT
    count(*) FILTER (
        WHERE order_id IS NULL
    ) AS items_with_no_order_id,
    count(*) FILTER (
        WHERE order_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM orders
              WHERE orders.order_id = order_items.order_id
          )
    ) AS items_pointing_to_missing_order
FROM order_items;


--- 3. Inventory log rows whose product does not exist
\echo 'PHASE 1, Check 3: Inventory log rows with no product ID or a missing product'

SELECT
    count(*) FILTER (
        WHERE product_id IS NULL
    ) AS log_rows_with_no_product_id,
    count(*) FILTER (
        WHERE product_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM products
              WHERE products.product_id = inventory_log.product_id
          )
    ) AS log_rows_pointing_to_missing_product
FROM inventory_log;


--- 4. Products whose category does not exist
\echo 'PHASE 1, Check 4: Products without a category or pointing to a missing category'

-- an empty category means "uncategorised"; a value with no match is a broken link
SELECT
    count(*) FILTER (
        WHERE category_id IS NULL
    ) AS products_uncategorised,
    count(*) FILTER (
        WHERE category_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM categories
              WHERE categories.category_id = products.category_id
          )
    ) AS products_pointing_to_missing_category
FROM products;


--- 5. Categories whose parent does not exist
\echo 'PHASE 1, Check 5: Categories whose parent does not exist'

SELECT count(*) AS categories_with_missing_parent
FROM categories
-- a category with no parent is a top-level category, which is normal
WHERE categories.parent_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM categories AS parent
    WHERE parent.category_id = categories.parent_id
);


--- 6. Category loops (a category that is its own ancestor)
\echo 'PHASE 1, Check 6: Category loops and categories hanging below a loop'

-- walk upwards from every category, one parent at a time, remembering the path
WITH RECURSIVE walk AS (
    -- start: every category begins at itself
    SELECT
        category_id        AS start_id,
        category_id        AS node_id,
        ARRAY[category_id] AS path,
        NULL::integer      AS repeated_id
    FROM categories

    UNION ALL

    -- step: move to the parent; if it is already on the path, record it and stop
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
)
SELECT
    -- the walk came back to where it started: this category is part of a loop
    count(DISTINCT start_id) FILTER (
        WHERE repeated_id = start_id
    ) AS categories_in_a_loop,
    -- the walk entered a loop elsewhere: this category only sits below one
    count(DISTINCT start_id) FILTER (
        WHERE repeated_id IS NOT NULL
          AND repeated_id <> start_id
    ) AS categories_hanging_below_a_loop
FROM walk;


--- 7. Order items whose product is missing
\echo 'PHASE 1, Check 7: Order items with no product ID or a missing product'

SELECT
    count(*) FILTER (
        WHERE product_id IS NULL
    ) AS items_with_no_product_id,
    count(*) FILTER (
        WHERE product_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM products
              WHERE products.product_id = order_items.product_id
          )
    ) AS items_pointing_to_missing_product
FROM order_items;