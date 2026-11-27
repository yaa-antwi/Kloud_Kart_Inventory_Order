-- BEFORE AND AFTER: HOW THE MONDAY REPORT WAS MADE FAST
-- Writes sql/build_outputs/04_before_after.md (the folder must exist).
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/report/01_before_after.sql
--
-- WHAT IT COMPARES
--   1. BEFORE: the per-customer way (separate lookups for each customer, 12 monthly
--      lookups, and a rank that re-adds every customer's spending). This is a
--      RECONSTRUCTION of the shape of the slow way, because the real report was
--      never seen. It runs on 20 customers and is scaled up, so read it as the
--      shape of the cost, not as the real 40 minutes.
--   2. AFTER: the finished views, which do the work once for all customers.
--   3. AFTER, with a candidate index, to see whether PostgreSQL uses it, whether
--      the time proves it, and what it costs every sale.
-- The candidate index is created and dropped by this file. Test sales are made
-- inside a transaction that is rolled back, so no data is left behind.

\set QUIET on
\o sql/build_outputs/04_before_after.md
\qecho '# Before and after: the Monday report'
\qecho
\qecho '## Database and time'
\qecho '```text'
SELECT version() AS postgresql_version, now()::timestamp(0) AS written_at;
\qecho '```'

DROP INDEX IF EXISTS report_orders_by_customer;
ANALYZE;
CREATE TEMP TABLE timing_results (step text, run_group text, milliseconds numeric);

-- The per-customer way for the first 20 customers. Each column is its own lookup
-- per customer, the way a report written one customer at a time would do it.
CREATE TEMP VIEW per_customer_way AS
SELECT customers.customer_id,
       (SELECT coalesce(sum(orders.total_amount), 0) FROM orders
         WHERE orders.customer_id = customers.customer_id
           AND coalesce(lower(btrim(orders.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
           AND orders.order_date <= now()) AS total_spent,
       (SELECT count(*) FROM orders
         WHERE orders.customer_id = customers.customer_id
           AND coalesce(lower(btrim(orders.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
           AND orders.order_date <= now()) AS order_count,
       (SELECT sum((SELECT coalesce(sum(orders.total_amount), 0) FROM orders
                     WHERE orders.customer_id = customers.customer_id
                       AND coalesce(lower(btrim(orders.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
                       AND date_trunc('month', orders.order_date)
                           = date_trunc('month', now()) - make_interval(months => month_number)))
          FROM generate_series(0, 11) AS month_numbers(month_number)) AS last_12_months,
       (SELECT count(*) + 1 FROM (
             SELECT every_order.customer_id, sum(every_order.total_amount) AS spend
             FROM orders AS every_order
             WHERE coalesce(lower(btrim(every_order.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
               AND every_order.order_date <= now()
             GROUP BY every_order.customer_id) AS everyone
         WHERE everyone.spend > (SELECT coalesce(sum(orders.total_amount), 0) FROM orders
                                  WHERE orders.customer_id = customers.customer_id
                                    AND coalesce(lower(btrim(orders.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
                                    AND orders.order_date <= now())) AS spend_rank
FROM customers
ORDER BY customers.customer_id
LIMIT 20;

-- Runs a statement p_runs times and records every run, so noise is visible.
CREATE OR REPLACE FUNCTION pg_temp.time_it(p_step text, p_group text, p_sql text, p_runs integer DEFAULT 3)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_start timestamptz;
BEGIN
    FOR run_number IN 1..p_runs LOOP
        v_start := clock_timestamp();
        EXECUTE p_sql;
        INSERT INTO timing_results
        VALUES (p_step || ', run ' || run_number, p_group,
                round(extract(epoch FROM clock_timestamp() - v_start) * 1000, 1));
    END LOOP;
END $$;

-- ---------------------------------------------------------------- BEFORE
SELECT pg_temp.time_it('per-customer way, 20 customers', 'before',
    'SELECT sum(total_spent) + sum(order_count) + sum(last_12_months) + sum(spend_rank) FROM per_customer_way', 1) \gset

\qecho
\qecho '## 1. BEFORE: the per-customer way, plan for 20 customers'
\qecho 'Read from the bottom up. Look at loops: each lookup is repeated for every customer.'
\qecho '```text'
EXPLAIN (ANALYZE, COSTS OFF)
SELECT sum(total_spent) + sum(order_count) + sum(last_12_months) + sum(spend_rank) FROM per_customer_way;
\qecho '```'

-- ---------------------------------------------------------------- AFTER, no new index
SELECT pg_temp.time_it('summary view, all 40,420 customers', 'after, no index', 'SELECT count(*), sum(total_spent) FROM monday_customer_summary') \gset
SELECT pg_temp.time_it('top 100 view', 'after, no index', 'SELECT count(*) FROM monday_top_100') \gset
SELECT pg_temp.time_it('monthly view, 485,040 rows with running total', 'after, no index', 'SELECT count(*), sum(running_total) FROM monday_monthly_spend') \gset

\qecho
\qecho '## 2. AFTER: the finished summary view, all customers, no new index'
\qecho '```text'
EXPLAIN (ANALYZE, COSTS OFF) SELECT count(*), sum(total_spent) FROM monday_customer_summary;
\qecho '```'

-- ---------------------------------------------------------------- write cost without the index
BEGIN;
INSERT INTO products (product_id, product_name, category_id, price, stock_quantity, created_at)
VALUES (9999901, 'WRITE COST TEST', NULL, 10.00, 100000, now());
SELECT clock_timestamp() AS started_at \gset
-- the g.n in the call makes the function run once per sale, not once in total
SELECT count(*) AS sales_made FROM generate_series(1, 3000) AS g(n), LATERAL place_order(100001, 9999901, 1 + g.n * 0) \gset
SELECT round(extract(epoch FROM clock_timestamp() - :'started_at'::timestamptz) * 1000, 1) AS sales_ms \gset
SELECT count(*) AS items_made FROM order_items WHERE product_id = 9999901 \gset
ROLLBACK;
INSERT INTO timing_results VALUES ('3,000 sales through place_order (' || :items_made || ' order items written)', 'sales, no index', :sales_ms);

-- ---------------------------------------------------------------- with the candidate index
CREATE INDEX report_orders_by_customer
    ON orders (customer_id, order_date) INCLUDE (status, total_amount);
ANALYZE orders;

SELECT pg_temp.time_it('per-customer way, 20 customers', 'before, with index',
    'SELECT sum(total_spent) + sum(order_count) + sum(last_12_months) + sum(spend_rank) FROM per_customer_way', 1) \gset
SELECT pg_temp.time_it('summary view, all 40,420 customers', 'after, with index', 'SELECT count(*), sum(total_spent) FROM monday_customer_summary') \gset
SELECT pg_temp.time_it('monthly view, 485,040 rows with running total', 'after, with index', 'SELECT count(*), sum(running_total) FROM monday_monthly_spend') \gset

\qecho
\qecho '## 3. AFTER, WITH the candidate index: does the planner use it for the whole report?'
\qecho '```text'
EXPLAIN (ANALYZE, COSTS OFF) SELECT count(*), sum(total_spent) FROM monday_customer_summary;
\qecho '```'

BEGIN;
INSERT INTO products (product_id, product_name, category_id, price, stock_quantity, created_at)
VALUES (9999901, 'WRITE COST TEST', NULL, 10.00, 100000, now());
SELECT clock_timestamp() AS started_at \gset
-- the g.n in the call makes the function run once per sale, not once in total
SELECT count(*) AS sales_made FROM generate_series(1, 3000) AS g(n), LATERAL place_order(100001, 9999901, 1 + g.n * 0) \gset
SELECT round(extract(epoch FROM clock_timestamp() - :'started_at'::timestamptz) * 1000, 1) AS sales_ms \gset
SELECT count(*) AS items_made FROM order_items WHERE product_id = 9999901 \gset
ROLLBACK;
INSERT INTO timing_results VALUES ('3,000 sales through place_order (' || :items_made || ' order items written)', 'sales, with index', :sales_ms);

DROP INDEX report_orders_by_customer;
ANALYZE orders;

-- ---------------------------------------------------------------- the summary table
\qecho
\qecho '## 4. All timings (milliseconds)'
\qecho '```text'
SELECT run_group, step, milliseconds FROM timing_results ORDER BY CASE run_group WHEN 'before' THEN 1 WHEN 'after, no index' THEN 2 WHEN 'sales, no index' THEN 3 WHEN 'before, with index' THEN 4 WHEN 'after, with index' THEN 5 ELSE 6 END, step;
\qecho '```'
\qecho
\qecho '## 5. The per-customer way scaled to every customer (shape of the cost only)'
\qecho '```text'
SELECT run_group, milliseconds AS ms_for_20_customers,
       round(milliseconds / 20 * 40420 / 1000 / 60, 1) AS minutes_for_all_40420_customers
FROM timing_results WHERE run_group IN ('before', 'before, with index') ORDER BY run_group DESC;
\qecho '```'
\qecho
\qecho '## 6. Write cost of the candidate index: 3,000 sales, without and with it'
\qecho '```text'
SELECT run_group, milliseconds AS ms_for_3000_sales, round(milliseconds / 3000, 3) AS ms_per_sale
FROM timing_results WHERE run_group LIKE 'sales%' ORDER BY run_group DESC;
\qecho '```'
\o