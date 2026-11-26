-- BUILD 2 CHECKS: PROVING THE LOW-STOCK VIEW

-- WHAT THIS DOES
--   Tests the view from 02_low_stock.sql. It proves four things:
--   1. No product is counted twice (the totals add up).
--   2. Nothing was cut off by the depth limit.
--   3. Which categories the view cannot reach.
--   4. The depth is not hard-coded: a deeper tree is added inside a
--      transaction, the view is read, and everything is rolled back.
--   Nothing is changed permanently.

-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/02_low_stock_checks.sql

-- CHECKS

\set QUIET on
\pset null '(null)'


\echo 'Check 1: Do the top level plus the two extra lines add up to the whole catalogue?'

-- the chapter's test: nothing counted twice, nothing dropped
WITH view_totals AS (
    SELECT
        SUM(products_in_branch)     AS products,
        SUM(out_of_stock_in_branch) AS out_of_stock,
        SUM(low_stock_in_branch)    AS low_stock
    FROM low_stock_by_category
    WHERE depth = 1 OR depth IS NULL
),
direct AS (
    SELECT
        count(*) AS products,
        count(*) FILTER (WHERE stock_quantity <= 0) AS out_of_stock,
        count(*) FILTER (
            WHERE stock_quantity > 0
              AND stock_quantity < (SELECT low_stock_threshold FROM stock_settings)
        ) AS low_stock
    FROM products
)
SELECT
    view_totals.products     AS view_products,     direct.products     AS table_products,
    view_totals.out_of_stock AS view_out_of_stock, direct.out_of_stock AS table_out_of_stock,
    view_totals.low_stock    AS view_low_stock,    direct.low_stock    AS table_low_stock,
    (view_totals.products     = direct.products
 AND view_totals.out_of_stock = direct.out_of_stock
 AND view_totals.low_stock    = direct.low_stock) AS all_three_match
FROM view_totals, direct;


\echo 'Check 2: How deep is the tree, against the depth limit of 20?'

SELECT
    max(depth) AS deepest_level_found,
    20         AS depth_limit,
    max(depth) < 20 AS limit_not_reached
FROM category_tree;


\echo 'Check 3: Categories the view cannot reach'

SELECT
    categories.category_id,
    categories.category_name,
    categories.parent_id
FROM categories
WHERE categories.category_id NOT IN (SELECT category_id FROM category_tree)
ORDER BY categories.category_id;


\echo 'Check 4: Is the depth hard-coded? Add a deeper tree, read it, roll it back'

BEGIN;

-- hang a chain of 6 new levels under an existing bottom-level category
INSERT INTO categories (category_id, category_name, parent_id)
SELECT
    900000 + level,
    'Test level ' || level,
    CASE WHEN level = 1
         THEN (SELECT max(category_id) FROM category_tree WHERE depth = 4)
         ELSE 900000 + level - 1
    END
FROM generate_series(1, 6) AS level;

-- one low-stock product at the very bottom of the new chain
INSERT INTO products (product_id, product_name, category_id, price, stock_quantity, created_at)
VALUES (900000001, 'DEPTH TEST PRODUCT', 900006, 1.00, 1, now());

SELECT
    category_path,
    depth,
    low_stock_here,
    low_stock_in_branch
FROM low_stock_by_category
WHERE category_id IN (900006, (SELECT max(category_id) FROM category_tree WHERE depth = 4 AND category_id < 900000))
ORDER BY depth;

ROLLBACK;


\echo 'Top-level view, as Nana would read it'

SELECT
    category_path,
    products_in_branch,
    out_of_stock_in_branch,
    low_stock_in_branch
FROM low_stock_by_category
WHERE depth = 1 OR depth IS NULL
ORDER BY depth IS NULL, category_path;


\echo 'Timing: reading the whole view'

\timing on
SELECT count(*) AS rows_in_view FROM low_stock_by_category;
\timing off