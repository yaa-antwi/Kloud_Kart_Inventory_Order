-- BUILD 2: LOW STOCK BY CATEGORY

-- WHAT THIS DOES
--   Adds a view, low_stock_by_category, that shows for every category how
--   many products are out of stock and how many are running low. Each
--   category's figure counts the products directly in it AND everything
--   beneath it, however deep the tree goes. Nothing about the depth is
--   written into the query.

-- NEW OBJECTS (schema changes, documented for Nana's team)
--   stock_settings        one row holding the low-stock number, so it can be
--                         changed in one place
--   category_tree         every category reachable from a top category, with
--                         its depth and its full path
--   category_branches     for every category, every category beneath it
--   low_stock_by_category the view Adwoa and Nana read

-- DECISIONS (each one is a judgement call and can be changed)
--   A. "Out of stock" means stock of zero or less. This includes the 14
--      products already below zero.
--   B. "Low stock" means stock above zero but below the number in
--      stock_settings. The starting number is 5. It is my judgement: with a
--      median stock of 12, a rule of 10 would flag almost half of all
--      products, which is not "at a glance". Change it with:
--        UPDATE stock_settings SET low_stock_threshold = 10;
--   C. Out of stock and low stock are separate columns, so a product that is
--      already gone is not buried inside "low".
--   D. Every figure comes in two forms: "here" (products directly in this
--      category) and "in_branch" (this category plus everything beneath it).
--      The in_branch figure never counts a product twice within one row.
--      Adding the rows of different depths together WOULD count products
--      twice, so only add rows of one depth, or use the top level.
--   E. Products with no category, and products in categories that cannot
--      be reached from the top of the tree (a loop or a missing parent), get
--      their own two lines at the bottom. They are shown, never dropped.
--   F. It is a normal view, not a stored copy, so the figures are always
--      current. Stock changes with every order, and a stored copy would
--      go stale.
--   G. Two safeguards stop a loop running forever: a depth limit of 20, and
--      PostgreSQL's CYCLE clause, which marks the row where a loop closes.
--      The 20 is a safety limit, not an assumption about the tree: the tree
--      is 4 levels deep today.
--      Honest note: walking DOWN from the top categories can never enter a
--      loop, because each category has only one parent, so a loop is always
--      cut off from the top. The safeguards stay in case the tree is ever
--      walked another way.

-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/02_low_stock.sql

-- BUILD

\set QUIET on


-- The low-stock number lives in one place. The id column and its rule keep
-- the table to a single row.
CREATE TABLE IF NOT EXISTS stock_settings (
    setting_id           boolean PRIMARY KEY DEFAULT true CHECK (setting_id),
    low_stock_threshold  integer NOT NULL DEFAULT 5 CHECK (low_stock_threshold > 0)
);

INSERT INTO stock_settings DEFAULT VALUES
ON CONFLICT DO NOTHING;


-- Every category that can be reached from a top category, with its depth
-- and its path, for example: Electronics > Phones > Phone Accessories
CREATE OR REPLACE VIEW category_tree AS
WITH RECURSIVE tree AS (
    -- start: the top categories, which have no parent
    SELECT
        categories.category_id,
        COALESCE(categories.category_name, '(no name)')       AS category_name,
        categories.parent_id,
        1                                                     AS depth,
        COALESCE(categories.category_name, '(no name)')::text AS path
    FROM categories
    WHERE categories.parent_id IS NULL

    UNION ALL

    -- repeat: the children of the categories found in the last round
    SELECT
        categories.category_id,
        COALESCE(categories.category_name, '(no name)'),
        categories.parent_id,
        tree.depth + 1,
        tree.path || ' > ' || COALESCE(categories.category_name, '(no name)')
    FROM categories
    JOIN tree
        ON categories.parent_id = tree.category_id
    WHERE tree.depth < 20                      -- safeguard 1: depth limit
)
CYCLE category_id SET is_loop USING loop_path  -- safeguard 2: loop marker
SELECT
    category_id,
    category_name,
    parent_id,
    depth,
    path
FROM tree
WHERE NOT is_loop;


-- For every category, itself and every category beneath it
CREATE OR REPLACE VIEW category_branches AS
WITH RECURSIVE branch AS (
    -- start: each reachable category is the top of its own branch
    SELECT
        category_tree.category_id AS ancestor_id,
        category_tree.category_id AS descendant_id,
        0                         AS steps_down
    FROM category_tree

    UNION ALL

    -- repeat: move one level further down every branch
    SELECT
        branch.ancestor_id,
        categories.category_id,
        branch.steps_down + 1
    FROM branch
    JOIN categories
        ON categories.parent_id = branch.descendant_id
    WHERE branch.steps_down < 20
)
CYCLE descendant_id SET is_loop USING loop_path
SELECT
    ancestor_id,
    descendant_id
FROM branch
WHERE NOT is_loop;


-- The view people read
CREATE OR REPLACE VIEW low_stock_by_category AS
WITH threshold AS (
    SELECT low_stock_threshold AS value
    FROM stock_settings
),
-- one row per category: its own products, counted once
product_flags AS (
    SELECT
        products.category_id,
        count(*) AS products,
        count(*) FILTER (
            WHERE products.stock_quantity <= 0
        ) AS out_of_stock,
        count(*) FILTER (
            WHERE products.stock_quantity > 0
              AND products.stock_quantity < (SELECT value FROM threshold)
        ) AS low_stock
    FROM products
    GROUP BY products.category_id
),
-- one row per category: its own products plus everything beneath it
branch_totals AS (
    SELECT
        category_branches.ancestor_id                           AS category_id,
        COALESCE(SUM(product_flags.products), 0)::bigint        AS products,
        COALESCE(SUM(product_flags.out_of_stock), 0)::bigint    AS out_of_stock,
        COALESCE(SUM(product_flags.low_stock), 0)::bigint       AS low_stock
    FROM category_branches
    LEFT JOIN product_flags
        ON product_flags.category_id = category_branches.descendant_id
    GROUP BY category_branches.ancestor_id
)
SELECT
    category_tree.category_id,
    category_tree.path                                   AS category_path,
    category_tree.depth,
    COALESCE(product_flags.products, 0)                  AS products_here,
    COALESCE(product_flags.out_of_stock, 0)              AS out_of_stock_here,
    COALESCE(product_flags.low_stock, 0)                 AS low_stock_here,
    branch_totals.products                               AS products_in_branch,
    branch_totals.out_of_stock                           AS out_of_stock_in_branch,
    branch_totals.low_stock                              AS low_stock_in_branch
FROM category_tree
JOIN branch_totals
    ON branch_totals.category_id = category_tree.category_id
LEFT JOIN product_flags
    ON product_flags.category_id = category_tree.category_id

UNION ALL

-- decision E: products with no category
SELECT
    NULL::integer,
    'Uncategorised (no category set)',
    NULL::integer,
    COALESCE(SUM(products), 0)::bigint,
    COALESCE(SUM(out_of_stock), 0)::bigint,
    COALESCE(SUM(low_stock), 0)::bigint,
    COALESCE(SUM(products), 0)::bigint,
    COALESCE(SUM(out_of_stock), 0)::bigint,
    COALESCE(SUM(low_stock), 0)::bigint
FROM product_flags
WHERE category_id IS NULL

UNION ALL

-- decision E: products whose category cannot be reached from the top
SELECT
    NULL::integer,
    'Unreachable (category in a loop or with a missing parent)',
    NULL::integer,
    COALESCE(SUM(products), 0)::bigint,
    COALESCE(SUM(out_of_stock), 0)::bigint,
    COALESCE(SUM(low_stock), 0)::bigint,
    COALESCE(SUM(products), 0)::bigint,
    COALESCE(SUM(out_of_stock), 0)::bigint,
    COALESCE(SUM(low_stock), 0)::bigint
FROM product_flags
WHERE category_id IS NOT NULL
  AND category_id NOT IN (SELECT category_id FROM category_tree);