-- BUILD 2: LOW STOCK, ROLLED UP THROUGH THE CATEGORY TREE

-- WHAT THIS DOES
--   low_stock_by_category gives, for every category, how many products are out
--   of stock or low, counting the products directly in the category ("here")
--   and everything beneath it ("in branch"). Two extra lines show the products
--   the tree cannot place, so the figures always add up to the whole catalogue.

-- DECISIONS
--   A. Out of stock means stock of zero or below (this includes the 14 products
--      below zero). Low means above zero but under the threshold. The two are
--      separate columns, because they ask for different action.
--   B. The threshold lives in one row (stock_settings) so Nana can change it
--      without touching code:  UPDATE stock_settings SET low_stock_threshold = 10;
--      It starts at 5. Cost if wrong: products wrongly flagged or missed.
--   C. "In branch" means the category itself plus everything beneath it. A
--      product is counted once in its own category and once in each category
--      above it, so do not add a category's figure to its parent's.
--   D. The depth of the tree is not written anywhere. The walk starts at the
--      top categories and goes down until nothing is left. Two protections
--      stop a bad tree from running forever: the CYCLE clause marks a loop, and
--      a bound equal to the NUMBER OF CATEGORIES. A tree with no loop can never
--      be deeper than its own category count, so the bound never cuts off a
--      real tree, and it grows with the data.
--   E. A normal view, not a stored copy: stock changes with every order, and
--      the whole view reads in well under a second.
--   F. The threshold is read through a one-row subquery, not a join, so a
--      settings table that has never been analysed cannot mislead the plan
--      (see decision H in file 03).

-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/02_low_stock.sql

\set QUIET on


CREATE TABLE IF NOT EXISTS stock_settings (
    only_row            boolean PRIMARY KEY DEFAULT true CHECK (only_row),
    low_stock_threshold integer NOT NULL DEFAULT 5 CHECK (low_stock_threshold > 0)
);

INSERT INTO stock_settings (only_row) VALUES (true)
ON CONFLICT (only_row) DO NOTHING;


-- Every category reachable from a top category, with its depth and path.
CREATE OR REPLACE VIEW category_tree AS
WITH RECURSIVE walk AS (
    -- starting rows: the top categories
    SELECT categories.category_id,
           categories.category_name,
           categories.parent_id,
           1                            AS depth,
           ARRAY[categories.category_id] AS ancestor_ids,   -- itself and every category above
           categories.category_name::text AS path
    FROM categories
    WHERE categories.parent_id IS NULL

    UNION ALL

    -- each round: the children of the previous round
    SELECT child.category_id,
           child.category_name,
           child.parent_id,
           walk.depth + 1,
           walk.ancestor_ids || child.category_id,
           walk.path || ' > ' || child.category_name
    FROM categories AS child
    JOIN walk
      ON child.parent_id = walk.category_id
    WHERE walk.depth < (SELECT count(*) FROM categories)    -- decision D
)
CYCLE category_id SET is_loop USING loop_path
SELECT walk.category_id,
       walk.category_name,
       walk.parent_id,
       walk.depth,
       walk.ancestor_ids,
       walk.path
FROM walk
WHERE NOT walk.is_loop;


-- One row for every (category, category beneath it), the category itself included.
CREATE OR REPLACE VIEW category_branches AS
SELECT ancestor.ancestor_id,
       category_tree.category_id
FROM category_tree
CROSS JOIN LATERAL unnest(category_tree.ancestor_ids) AS ancestor(ancestor_id);


CREATE OR REPLACE VIEW low_stock_by_category AS
WITH stock_by_category AS (
    -- products counted once per category, before any rolling up
    SELECT products.category_id,
           count(*)                                                    AS products_here,
           count(*) FILTER (WHERE products.stock_quantity <= 0)        AS out_of_stock_here,
           count(*) FILTER (WHERE products.stock_quantity > 0
                              AND products.stock_quantity < (SELECT stock_settings.low_stock_threshold
                                                             FROM stock_settings))
                                                                       AS low_stock_here
    FROM products
    GROUP BY products.category_id
),
branch_totals AS (
    SELECT category_branches.ancestor_id          AS category_id,
           sum(stock_by_category.products_here)::bigint      AS products_in_branch,
           sum(stock_by_category.out_of_stock_here)::bigint  AS out_of_stock_in_branch,
           sum(stock_by_category.low_stock_here)::bigint     AS low_stock_in_branch
    FROM category_branches
    JOIN stock_by_category
      ON stock_by_category.category_id = category_branches.category_id
    GROUP BY category_branches.ancestor_id
)
SELECT category_tree.category_id,
       category_tree.category_name,
       category_tree.depth,
       category_tree.path,
       coalesce(stock_by_category.products_here, 0)         AS products_here,
       coalesce(stock_by_category.out_of_stock_here, 0)     AS out_of_stock_here,
       coalesce(stock_by_category.low_stock_here, 0)        AS low_stock_here,
       coalesce(branch_totals.products_in_branch, 0)        AS products_in_branch,
       coalesce(branch_totals.out_of_stock_in_branch, 0)    AS out_of_stock_in_branch,
       coalesce(branch_totals.low_stock_in_branch, 0)       AS low_stock_in_branch
FROM category_tree
LEFT JOIN stock_by_category
  ON stock_by_category.category_id = category_tree.category_id
LEFT JOIN branch_totals
  ON branch_totals.category_id = category_tree.category_id

UNION ALL

-- products with no category at all
SELECT NULL::integer,
       'Uncategorised'::text,
       NULL::integer,
       'Uncategorised'::text,
       coalesce(sum(stock_by_category.products_here), 0)::bigint,
       coalesce(sum(stock_by_category.out_of_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.low_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.products_here), 0)::bigint,
       coalesce(sum(stock_by_category.out_of_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.low_stock_here), 0)::bigint
FROM stock_by_category
WHERE stock_by_category.category_id IS NULL

UNION ALL

-- products whose category cannot be reached from the top (a loop or a missing parent)
SELECT NULL::integer,
       'Unreachable (category in a loop or with a missing parent)'::text,
       NULL::integer,
       'Unreachable'::text,
       coalesce(sum(stock_by_category.products_here), 0)::bigint,
       coalesce(sum(stock_by_category.out_of_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.low_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.products_here), 0)::bigint,
       coalesce(sum(stock_by_category.out_of_stock_here), 0)::bigint,
       coalesce(sum(stock_by_category.low_stock_here), 0)::bigint
FROM stock_by_category
WHERE stock_by_category.category_id IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM category_tree
        WHERE category_tree.category_id = stock_by_category.category_id
      );