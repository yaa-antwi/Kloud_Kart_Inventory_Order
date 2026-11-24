-- PHASE 2: WRONG NUMBERS

-- WHAT THIS CHECKS
--   Numbers that contradict each other or make no sense. Example: an
--   order whose total does not equal the sum of its items, or a product
--   with negative stock.

-- WHY IT HAPPENS
--   The application writes totals and stock at checkout, and nothing in
--   the database checks them. Overselling can push stock below zero.

-- WHY IT MATTERS
--   These are the numbers Nana and Adwoa actually use: money spent,
--   stock on hand, and order dates. If they are wrong, decisions based
--   on them are wrong.

-- CHECKS IN THIS FILE
--   1   Orders whose total does not match their line items
--   2   Orders with no line items at all
--   3   Products with negative stock
--   4   Products whose stock does not match the sum of the stock log
--   5   Orders dated in the future
--   6   Overall order date range
--   7   Order items with zero, negative or missing quantity or price
--   8   How the wrong totals cluster (recorded total divided by items total)
--   9   What the stock log records (reasons and units)

-- READ-ONLY: this file only counts. It changes no data.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/diagnosis/02_wrong_numbers.sql

-- QUERIES

\set QUIET on
\pset null '(null)'


--- 1. Orders whose total does not match their line items
\echo 'PHASE 2, Check 1: Orders whose total does not match their line items'

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
),
differences AS (
    SELECT
        orders.order_id,
        orders.total_amount - item_totals.items_total AS difference
    FROM orders
    JOIN item_totals
        ON item_totals.order_id = orders.order_id
)
SELECT
    count(*) AS orders_compared,
    -- differences of 0.01 or less are treated as rounding, not errors
    count(*) FILTER (WHERE abs(difference) > 0.01) AS orders_with_wrong_total,
    count(*) FILTER (WHERE difference < -0.01)     AS recorded_lower_than_items,
    count(*) FILTER (WHERE difference > 0.01)      AS recorded_higher_than_items,
    round(SUM(difference) FILTER (WHERE abs(difference) > 0.01), 2)      AS net_difference,
    round(SUM(abs(difference)) FILTER (WHERE abs(difference) > 0.01), 2) AS gross_difference
FROM differences;


--- 2. Orders that have no line items at all
\echo 'PHASE 2, Check 2: Orders that have no line items at all'

SELECT count(*) AS orders_without_items
FROM orders
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items
    WHERE order_items.order_id = orders.order_id
);


--- 3. Products with negative stock
\echo 'PHASE 2, Check 3: Products with negative stock'

SELECT
    count(*)            AS products_with_negative_stock,
    SUM(stock_quantity) AS total_units_below_zero
FROM products
WHERE stock_quantity < 0;


--- 4. Products where stock does not match the sum of the log
\echo 'PHASE 2, Check 4: Products where stock does not match the sum of the log'

WITH log_totals AS (
    SELECT
        product_id,
        SUM(change_qty) AS log_sum
    FROM inventory_log
    GROUP BY product_id
)
SELECT
    count(*) AS products_checked,
    -- a product with no log rows is treated as a log total of 0
    count(*) FILTER (
        WHERE products.stock_quantity = COALESCE(log_totals.log_sum, 0)
    ) AS products_matching_log_exactly,
    count(*) FILTER (
        WHERE products.stock_quantity IS DISTINCT FROM COALESCE(log_totals.log_sum, 0)
    ) AS products_where_stock_differs_from_log,
    count(*) FILTER (WHERE log_totals.product_id IS NULL) AS products_with_no_log_at_all
FROM products
LEFT JOIN log_totals
    ON log_totals.product_id = products.product_id;


---5. Orders dated in the future
\echo 'PHASE 2, Check 5: Orders dated in the future'

SELECT
    count(*)                             AS future_orders,
    min(order_date)                      AS earliest_future,
    max(order_date)                      AS latest_future,
    min(order_date)::date - current_date AS earliest_days_ahead,
    max(order_date)::date - current_date AS latest_days_ahead
FROM orders
-- "future" means later than the database server's clock right now
WHERE order_date > now();


--- 6. Order date range overall
\echo 'PHASE 2, Check 6: Order date range overall'

SELECT
    min(order_date) AS first_order,
    max(order_date) AS last_order
FROM orders;


-- 7. Order items with zero, negative or missing quantities or prices
\echo 'PHASE 2, Check 7: Order items with zero, negative or missing quantity or price'

SELECT
    count(*) FILTER (WHERE quantity <= 0 OR quantity IS NULL) AS bad_quantity,
    count(*) FILTER (WHERE unit_price IS NULL)                AS missing_unit_price,
    count(*) FILTER (WHERE unit_price = 0)                    AS zero_unit_price,
    count(*) FILTER (WHERE unit_price < 0)                    AS negative_unit_price,
    count(DISTINCT order_id) FILTER (
        WHERE unit_price IS NULL OR unit_price <= 0
    ) AS orders_affected
FROM order_items;


-- 8. Identify repeated patterns in incorrect order totals
\echo 'PHASE 2, Check 8: How the wrong totals cluster (recorded total divided by items total)'

-- if the same ratios repeat, the errors follow a pattern rather than being random
WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    round(orders.total_amount / item_totals.items_total, 2) AS recorded_divided_by_items,
    count(*)                                                AS orders
FROM orders
JOIN item_totals
    ON item_totals.order_id = orders.order_id
WHERE abs(orders.total_amount - item_totals.items_total) > 0.01
  AND item_totals.items_total > 0
GROUP BY round(orders.total_amount / item_totals.items_total, 2)
ORDER BY orders DESC
LIMIT 10;


-- 9. Summarise stock movements by reason and quantity
\echo 'PHASE 2, Check 9: What the stock log records (reasons and units)'

-- no "opening balance" reason here means the log starts from zero stock
SELECT
    reason,
    count(*)        AS log_rows,
    SUM(change_qty) AS units
FROM inventory_log
GROUP BY reason
ORDER BY log_rows DESC;

