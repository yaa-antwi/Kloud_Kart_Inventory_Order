-- PHASE 4: BUSINESS IMPACT

-- WHAT THIS CHECKS
--   How much each confirmed problem moves a number that Nana or Adwoa
--   actually uses: money, customer counts, rankings, stock and the
--   category rollup. Phases 1 to 3 counted faulty rows. This phase
--   measures what those rows cost.

-- ASSUMPTIONS (judgement calls, to be defended in the decisions document)
--   A. "Spend" counts every order except cancelled, canceled and refunded.
--      Pending and shipped orders are included.
--   B. "complete" and "completed" mean the same thing.
--   C. Two customer rows with the same email (spaces and capitals ignored)
--      are one person.
--   D. When an order's recorded total disagrees with its line items,
--      both versions are shown. Neither is assumed to be right.
--   E. Customer rankings only include customers that exist in the
--      customers table.

-- CHECKS IN THIS FILE
--   1   Status: orders a "completed" filter misses
--   2   Money: recorded totals against line item totals
--   3   Ranking: top 100 customers by recorded total against line items
--   4   Customers: duplicate rows and the top 100 by person
--   5   Orphans: orders and items pointing to missing records
--   6   Future orders: money and statuses
--   7   Negative stock: units and value
--   8   Stock against log: units, value and best sellers affected
--   9   Category rollup: products it would never reach
--   10  Bad item prices: orders affected

-- READ-ONLY: this file only counts. It changes no data.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/diagnosis/04_impact.sql

-- QUERIES

\set QUIET on
\pset null '(null)'


\echo 'PHASE 4, Check 1: Status: orders a "completed" filter misses'

SELECT
    count(*) AS all_orders,
    count(*) FILTER (
        WHERE status = 'completed'
    ) AS orders_found_by_exact_filter,
    count(*) FILTER (
        WHERE lower(trim(status)) IN ('completed', 'complete')
    ) AS orders_that_are_really_completed,
    count(*) FILTER (
        WHERE lower(trim(status)) IN ('completed', 'complete')
          AND status <> 'completed'
    ) AS orders_missed,
    round(100.0 * count(*) FILTER (
        WHERE lower(trim(status)) IN ('completed', 'complete')
          AND status <> 'completed'
    ) / count(*) FILTER (
        WHERE lower(trim(status)) IN ('completed', 'complete')
    ), 1) AS percent_of_completed_missed,
    round(SUM(total_amount) FILTER (
        WHERE lower(trim(status)) IN ('completed', 'complete')
          AND status <> 'completed'
    )) AS money_missed
FROM orders;


\echo 'PHASE 4, Check 2: Money: recorded totals against line item totals'

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    count(*)                                     AS orders_counted_as_spend,
    round(SUM(orders.total_amount))              AS recorded_total_spend,
    round(SUM(item_totals.items_total))          AS line_item_total_spend,
    round(SUM(orders.total_amount - item_totals.items_total)) AS difference,
    round(100.0 * SUM(orders.total_amount - item_totals.items_total)
        / SUM(item_totals.items_total), 2)       AS difference_percent,
    count(*) FILTER (
        WHERE abs(orders.total_amount - item_totals.items_total) > 0.01
    ) AS orders_with_wrong_total,
    count(DISTINCT orders.customer_id) FILTER (
        WHERE abs(orders.total_amount - item_totals.items_total) > 0.01
    ) AS customers_with_a_wrong_order
FROM orders
JOIN item_totals
    ON item_totals.order_id = orders.order_id
WHERE lower(trim(orders.status)) NOT IN ('cancelled', 'canceled', 'refunded');


\echo 'PHASE 4, Check 3: Ranking: top 100 customers by recorded total against line items'

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
),
customer_spend AS (
    SELECT
        orders.customer_id,
        SUM(orders.total_amount)     AS recorded_spend,
        SUM(item_totals.items_total) AS items_spend
    FROM orders
    JOIN item_totals
        ON item_totals.order_id = orders.order_id
    JOIN customers
        ON customers.customer_id = orders.customer_id
    WHERE lower(trim(orders.status)) NOT IN ('cancelled', 'canceled', 'refunded')
    GROUP BY orders.customer_id
),
top_recorded AS (
    SELECT customer_id
    FROM customer_spend
    ORDER BY recorded_spend DESC
    LIMIT 100
),
top_items AS (
    SELECT customer_id
    FROM customer_spend
    ORDER BY items_spend DESC
    LIMIT 100
)
SELECT
    count(*) FILTER (
        WHERE top_recorded.customer_id IS NOT NULL
          AND top_items.customer_id IS NOT NULL
    ) AS in_both_top_100_lists,
    count(*) FILTER (
        WHERE top_items.customer_id IS NULL
    ) AS only_in_recorded_list,
    count(*) FILTER (
        WHERE top_recorded.customer_id IS NULL
    ) AS only_in_line_item_list
FROM top_recorded
FULL JOIN top_items
    ON top_items.customer_id = top_recorded.customer_id;


\echo 'PHASE 4, Check 4: Customers: duplicate rows and the top 100 by person'

-- one person = one email (spaces and capitals ignored); no email = own person
WITH order_spend AS (
    SELECT
        orders.customer_id,
        SUM(orders.total_amount) AS spend
    FROM orders
    WHERE lower(trim(orders.status)) NOT IN ('cancelled', 'canceled', 'refunded')
    GROUP BY orders.customer_id
),
row_spend AS (
    SELECT
        customers.customer_id,
        COALESCE(
            NULLIF(lower(trim(customers.email)), ''),
            'id:' || customers.customer_id
        ) AS person_key,
        COALESCE(order_spend.spend, 0) AS spend
    FROM customers
    LEFT JOIN order_spend
        ON order_spend.customer_id = customers.customer_id
),
person_spend AS (
    SELECT
        person_key,
        SUM(spend)  AS spend,
        count(*)    AS customer_rows
    FROM row_spend
    GROUP BY person_key
),
top_rows AS (
    SELECT person_key
    FROM row_spend
    ORDER BY spend DESC
    LIMIT 100
),
top_people AS (
    SELECT person_key
    FROM person_spend
    ORDER BY spend DESC
    LIMIT 100
)
SELECT
    (SELECT count(*) FROM row_spend)                         AS customer_rows,
    (SELECT count(*) FROM person_spend)                      AS real_people,
    (SELECT count(*) FROM person_spend WHERE customer_rows > 1) AS people_split_across_rows,
    count(*) FILTER (
        WHERE top_rows.person_key IS NULL
    ) AS true_top_100_people_missing_from_row_ranking
FROM top_people
LEFT JOIN top_rows
    ON top_rows.person_key = top_people.person_key;


\echo 'PHASE 4, Check 5: Orphans: orders and items pointing to missing records'

SELECT
    (SELECT count(*)
       FROM orders
      WHERE NOT EXISTS (
            SELECT 1 FROM customers
            WHERE customers.customer_id = orders.customer_id
      )) AS orders_without_customer,
    (SELECT round(SUM(total_amount))
       FROM orders
      WHERE NOT EXISTS (
            SELECT 1 FROM customers
            WHERE customers.customer_id = orders.customer_id
      )) AS money_on_those_orders,
    (SELECT round(100.0 * SUM(total_amount) FILTER (
            WHERE NOT EXISTS (
                SELECT 1 FROM customers
                WHERE customers.customer_id = orders.customer_id
            )) / SUM(total_amount), 2)
       FROM orders) AS percent_of_all_order_money,
    (SELECT count(*)
       FROM order_items
      WHERE NOT EXISTS (
            SELECT 1 FROM orders
            WHERE orders.order_id = order_items.order_id
      )) AS items_without_order,
    (SELECT round(SUM(quantity * unit_price))
       FROM order_items
      WHERE NOT EXISTS (
            SELECT 1 FROM orders
            WHERE orders.order_id = order_items.order_id
      )) AS money_on_those_items;


\echo 'PHASE 4, Check 6: Future orders: money and statuses'

SELECT
    lower(trim(status))        AS status,
    count(*)                   AS future_orders,
    round(SUM(total_amount))   AS money
FROM orders
WHERE order_date > now()
GROUP BY lower(trim(status))
ORDER BY future_orders DESC;


\echo 'PHASE 4, Check 7: Negative stock: units and value'

SELECT
    count(*)                                AS products_below_zero,
    SUM(stock_quantity)                     AS units_below_zero,
    min(stock_quantity)                     AS worst_single_product,
    round(SUM(stock_quantity * price))      AS value_of_units_sold_without_stock
FROM products
WHERE stock_quantity < 0;


\echo 'PHASE 4, Check 8: Stock against log: units, value and best sellers affected'

WITH log_totals AS (
    SELECT
        product_id,
        SUM(change_qty) AS log_sum
    FROM inventory_log
    GROUP BY product_id
),
best_sellers AS (
    SELECT product_id
    FROM order_items
    GROUP BY product_id
    ORDER BY SUM(quantity) DESC
    LIMIT 100
),
differing AS (
    SELECT
        products.product_id,
        products.price,
        products.stock_quantity - log_totals.log_sum AS difference
    FROM products
    JOIN log_totals
        ON log_totals.product_id = products.product_id
    WHERE products.stock_quantity <> log_totals.log_sum
)
SELECT
    count(*)                                   AS products_differing,
    SUM(abs(difference))                       AS units_out_either_way,
    SUM(difference)                            AS net_units_stock_minus_log,
    round(SUM(abs(difference) * price))        AS value_out_either_way,
    count(*) FILTER (
        WHERE differing.product_id IN (SELECT product_id FROM best_sellers)
    ) AS of_top_100_best_sellers,
    count(*) FILTER (WHERE difference < 0) AS stock_below_log,
    count(*) FILTER (WHERE difference > 0) AS stock_above_log
FROM differing;


\echo 'PHASE 4, Check 9: Category rollup: products it would never reach'

-- walk DOWN from every top-level category; UNION (not UNION ALL) drops
-- repeats, so a loop cannot run forever
WITH RECURSIVE reachable AS (
    SELECT category_id
    FROM categories
    WHERE parent_id IS NULL

    UNION

    SELECT categories.category_id
    FROM categories
    JOIN reachable
        ON categories.parent_id = reachable.category_id
)
SELECT
    count(*) AS products_total,
    count(*) FILTER (
        WHERE products.category_id IN (SELECT category_id FROM reachable)
    ) AS products_the_rollup_reaches,
    count(*) FILTER (
        WHERE products.category_id IS NULL
    ) AS products_uncategorised,
    count(*) FILTER (
        WHERE products.category_id IS NOT NULL
          AND products.category_id NOT IN (SELECT category_id FROM reachable)
    ) AS products_in_unreachable_categories
FROM products;


\echo 'PHASE 4, Check 10: Bad item prices: orders affected'

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price)                         AS items_total,
        bool_or(unit_price IS NULL OR unit_price <= 0)     AS has_bad_price
    FROM order_items
    GROUP BY order_id
)
SELECT
    count(*) AS orders_with_a_bad_price,
    count(*) FILTER (
        WHERE abs(orders.total_amount - item_totals.items_total) > 0.01
    ) AS of_those_total_also_wrong,
    round(SUM(orders.total_amount)) AS recorded_money_on_those_orders
FROM orders
JOIN item_totals
    ON item_totals.order_id = orders.order_id
WHERE item_totals.has_bad_price;