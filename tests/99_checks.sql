-- CHECKS: one row per check. Every row with a passed column should say t.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f tests/99_checks.sql
-- The results are written to sql/build_outputs/02_checks.md (the folder must exist).

\set QUIET on
\o sql/build_outputs/02_checks.md
\qecho '# Checks'
\qecho
\qecho 'One row per check. A row with t in the passed column passed. A row with nothing in passed is information only.'
\qecho
\qecho '## The checks'
\qecho '```text'

BEGIN;

CREATE TEMP TABLE stock_guard_probe (
    negative_insert_blocked boolean NOT NULL,
    negative_update_blocked boolean NOT NULL,
    direct_update_logged    boolean NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    v_probe_product_id       integer;
    v_existing_product_id    integer;
    v_existing_stock         integer;
    v_log_id_before          integer;
    v_negative_insert_blocked boolean := false;
    v_negative_update_blocked boolean := false;
    v_direct_update_logged    boolean := false;
BEGIN
    SELECT coalesce(max(products.product_id), 0) + 1
      INTO v_probe_product_id
      FROM products;

    BEGIN
        INSERT INTO products (product_id, product_name, price, stock_quantity)
        VALUES (v_probe_product_id, 'stock-guard-check', 0, -1);
    EXCEPTION WHEN check_violation THEN
        v_negative_insert_blocked := true;
    END;

    SELECT products.product_id, products.stock_quantity
      INTO v_existing_product_id, v_existing_stock
      FROM products
     WHERE products.stock_quantity >= 0
       AND products.stock_quantity < 2147483647
     ORDER BY products.product_id
     LIMIT 1;

    IF v_existing_product_id IS NOT NULL THEN
        BEGIN
            UPDATE products
               SET stock_quantity = -1
             WHERE products.product_id = v_existing_product_id;
        EXCEPTION WHEN check_violation THEN
            v_negative_update_blocked := true;
        END;

        SELECT coalesce(max(inventory_log.log_id), 0)
          INTO v_log_id_before
          FROM inventory_log;

        UPDATE products
           SET stock_quantity = v_existing_stock + 1
         WHERE products.product_id = v_existing_product_id;

        SELECT EXISTS (
            SELECT 1
            FROM inventory_log
            WHERE inventory_log.log_id > v_log_id_before
              AND inventory_log.product_id = v_existing_product_id
              AND inventory_log.change_qty = 1
              AND inventory_log.reason = 'manual_update'
        )
          INTO v_direct_update_logged;

        UPDATE products
           SET stock_quantity = v_existing_stock
         WHERE products.product_id = v_existing_product_id;
    END IF;

    INSERT INTO pg_temp.stock_guard_probe
    VALUES (v_negative_insert_blocked, v_negative_update_blocked, v_direct_update_logged);
END $$;

WITH category_totals AS (
    SELECT sum(low_stock_by_category.products_in_branch) AS products,
           sum(low_stock_by_category.out_of_stock_in_branch) AS out_of_stock,
           sum(low_stock_by_category.low_stock_in_branch) AS low_stock
    FROM low_stock_by_category
    WHERE low_stock_by_category.depth = 1
       OR low_stock_by_category.depth IS NULL
)
SELECT 1 AS check_number,
       'Low stock: every product is in exactly one line (top level + 2 extra lines)' AS check_name,
       category_totals.products::text AS result,
       (SELECT count(*) FROM products)::text AS expected,
       category_totals.products = (SELECT count(*) FROM products) AS passed
FROM category_totals
UNION ALL
SELECT 2, 'Low stock: out-of-stock products add up',
       category_totals.out_of_stock::text,
       (SELECT count(*) FROM products WHERE products.stock_quantity <= 0)::text,
       category_totals.out_of_stock =
           (SELECT count(*) FROM products WHERE products.stock_quantity <= 0)
FROM category_totals
UNION ALL
SELECT 3, 'Low stock: low-stock products add up',
       category_totals.low_stock::text,
       (SELECT count(*) FROM products, stock_settings
         WHERE products.stock_quantity > 0
           AND products.stock_quantity < stock_settings.low_stock_threshold)::text,
       category_totals.low_stock =
           (SELECT count(*) FROM products, stock_settings
             WHERE products.stock_quantity > 0
               AND products.stock_quantity < stock_settings.low_stock_threshold)
FROM category_totals
ORDER BY check_number;

SELECT 4, 'Category tree: deepest level reached (information)',
       (SELECT max(depth) FROM category_tree)::text,
       '4 in the loaded data',
       NULL::boolean
UNION ALL
SELECT 5, 'Category tree: categories reached out of all categories (information)',
       (SELECT count(*) FROM category_tree)::text || ' of ' ||
           (SELECT count(*) FROM categories)::text,
       '3 are in a loop or have a missing parent',
       NULL::boolean
UNION ALL
SELECT 6, 'Report: every customer appears once',
       (SELECT count(*) FROM monday_customer_summary)::text,
       (SELECT count(*) FROM customers)::text,
       (SELECT count(*) FROM monday_customer_summary) = (SELECT count(*) FROM customers)
ORDER BY check_number;

WITH independent_counted_orders AS (
    -- Match monday_counted_orders exactly, but read directly from the tables.
    SELECT orders.customer_id, orders.total_amount
    FROM orders
    WHERE coalesce(lower(btrim(orders.status)), '') NOT IN
              ('cancelled', 'canceled', 'refunded')
      AND orders.order_date <= now()
      AND EXISTS (
          SELECT 1
          FROM customers
          WHERE customers.customer_id = orders.customer_id
      )
)
SELECT 7, 'Report: total spent equals an independent sum',
       (SELECT sum(monday_customer_summary.total_spent)
          FROM monday_customer_summary)::text,
       (SELECT sum(independent_counted_orders.total_amount)
          FROM independent_counted_orders)::text,
       (SELECT sum(monday_customer_summary.total_spent)
          FROM monday_customer_summary)
         = (SELECT sum(independent_counted_orders.total_amount)
              FROM independent_counted_orders)
UNION ALL
SELECT 8, 'Report: order count equals an independent count',
       (SELECT sum(monday_customer_summary.order_count)
          FROM monday_customer_summary)::text,
       (SELECT count(*) FROM independent_counted_orders)::text,
       (SELECT sum(monday_customer_summary.order_count)
          FROM monday_customer_summary)
         = (SELECT count(*) FROM independent_counted_orders)
ORDER BY check_number;

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
         WHERE abs(last_month.running_total - monday_customer_summary.total_spent) > 0.005)::text,
       '0 (differences greater than half a cent)',
       (SELECT count(*)
          FROM monday_customer_summary
          JOIN (SELECT DISTINCT ON (customer_id) customer_id, running_total
                  FROM monday_monthly_spend ORDER BY customer_id, month_start DESC) AS last_month
            ON last_month.customer_id = monday_customer_summary.customer_id
         WHERE abs(last_month.running_total - monday_customer_summary.total_spent) > 0.005) = 0
UNION ALL
SELECT 11, 'Report: top 100 has 100 rows unless rank 100 is tied',
       (SELECT count(*) FROM monday_top_100)::text,
       '100, or more only when rank 100 is tied',
       (
           (SELECT count(*) FROM monday_top_100) = 100
           OR (
               (SELECT count(*) FROM monday_top_100) > 100
               AND (SELECT count(*) FROM monday_top_100
                     WHERE monday_top_100.spend_rank = 100) > 1
           )
       )
       AND coalesce((SELECT max(monday_top_100.spend_rank)
                       FROM monday_top_100), 0) <= 100
UNION ALL
SELECT 12, 'Trail: no movement names an order that is missing',
       (SELECT movements_naming_a_missing_order FROM stock_trail_check)::text, '0',
       (SELECT movements_naming_a_missing_order FROM stock_trail_check) = 0
UNION ALL
SELECT 13, 'Order functions exist; stock rule and audit trigger work',
       (SELECT count(*)
          FROM (VALUES
              (to_regprocedure('place_order(bigint,bigint,integer)')),
              (to_regprocedure('restock_product(bigint,integer,text)')),
              (to_regprocedure('correct_stock(bigint,integer,text)'))
          ) AS signatures(function_signature)
         WHERE signatures.function_signature IS NOT NULL)::text
         || ' exact-signature functions; constraint NOT VALID = '
         || coalesce((SELECT (NOT pg_constraint.convalidated)::text
                        FROM pg_constraint
                       WHERE pg_constraint.conname = 'products_stock_not_negative'
                         AND pg_constraint.conrelid = 'public.products'::regclass), 'missing')
         || '; negative insert blocked = '
         || (SELECT stock_guard_probe.negative_insert_blocked::text
               FROM pg_temp.stock_guard_probe)
         || '; negative update blocked = '
         || (SELECT stock_guard_probe.negative_update_blocked::text
               FROM pg_temp.stock_guard_probe)
         || '; direct update logged = '
         || (SELECT stock_guard_probe.direct_update_logged::text
               FROM pg_temp.stock_guard_probe),
       '3 functions; constraint NOT VALID = true; negative insert blocked = true; negative update blocked = true; direct update logged = true',
       (SELECT count(*)
          FROM (VALUES
              (to_regprocedure('place_order(bigint,bigint,integer)')),
              (to_regprocedure('restock_product(bigint,integer,text)')),
              (to_regprocedure('correct_stock(bigint,integer,text)'))
          ) AS signatures(function_signature)
         WHERE signatures.function_signature IS NOT NULL) = 3
       AND EXISTS (
           SELECT 1
           FROM pg_constraint
           WHERE pg_constraint.conname = 'products_stock_not_negative'
             AND pg_constraint.conrelid = 'public.products'::regclass
             AND NOT pg_constraint.convalidated
       )
       AND (SELECT stock_guard_probe.negative_insert_blocked
              AND stock_guard_probe.negative_update_blocked
              AND stock_guard_probe.direct_update_logged
              FROM pg_temp.stock_guard_probe)
ORDER BY check_number;
\qecho
\qecho 'Checks 4 and 5 are informational and are not pass/fail gates.'
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
ROLLBACK;