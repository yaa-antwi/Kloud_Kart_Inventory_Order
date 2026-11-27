-- BUILD 3: THE MONDAY CUSTOMER SPENDING REPORT

-- WHAT THIS DOES
--   For every customer: total spent, number of orders, spend in each of the
--   last 12 months, a running total, and a top-100 ranking. The work is done
--   once for all customers together, not once per customer.

-- DECISIONS
--   A. Which orders count: every status except cancelled, canceled and refunded,
--      with capitals and stray spaces ignored (the 15 spellings are 7 meanings).
--      "complete" and "completed" are treated as the same. Orders dated in the
--      future and orders for a customer who is not on file are left out, and
--      counted in monday_report_notes so nothing disappears quietly.
--      Pending and shipped orders DO count. Cost if wrong: spend overstated by
--      the value of orders that never get paid.
--   B. The recorded order total is used. 2,398 orders have a total that differs
--      from their items and nobody can say which is right, so the report does
--      not choose: monday_report_notes shows how many counted orders disagree.
--   C. One row per customer record. Records sharing an email are FLAGGED, not
--      merged, because two real people can share an address.
--   D. Last 12 months means the 12 calendar months ending with the current
--      month. report_settings.anchor_month can be set to another month (for
--      example to look at the busy months of the sample data); NULL means now.
--   E. The running total is the customer's lifetime spend up to the end of that
--      month, so it starts from what they spent before the 12 months.
--   F. Rank uses RANK: customers with the same spend share a rank, so the
--      top 100 can hold more than 100 rows only if there is a tie at 100.
--   G. Normal views, always current. Each reads in well under a second.
--      Whether to store a copy (a materialised view) or add indexes is decided
--      only after a real before/after comparison, not assumed.
--   H. The month window is read through a one-row subquery, not by joining the
--      settings table. A one-row table that has never been analysed made
--      PostgreSQL misjudge the size of the work and the monthly view took about
--      12 seconds instead of about half a second (measured). A one-row table
--      never triggers the automatic analyse, so it would not have corrected
--      itself.

-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/03_monday_report.sql

\set QUIET on


CREATE TABLE IF NOT EXISTS report_settings (
    only_row     boolean PRIMARY KEY DEFAULT true CHECK (only_row),
    anchor_month date            -- NULL means the current month
);

INSERT INTO report_settings (only_row) VALUES (true)
ON CONFLICT (only_row) DO NOTHING;


-- The orders that count as money spent (decision A).
CREATE OR REPLACE VIEW monday_counted_orders AS
SELECT orders.order_id,
       orders.customer_id,
       orders.order_date,
       orders.total_amount
FROM orders
JOIN customers
  ON customers.customer_id = orders.customer_id
WHERE coalesce(lower(btrim(orders.status)), '') NOT IN ('cancelled', 'canceled', 'refunded')
  AND orders.order_date <= now();


-- One row per customer: totals and rank (decisions C and F).
CREATE OR REPLACE VIEW monday_customer_summary AS
WITH spend_per_customer AS (
    SELECT monday_counted_orders.customer_id,
           sum(monday_counted_orders.total_amount) AS total_spent,
           count(*)                                AS order_count
    FROM monday_counted_orders
    GROUP BY monday_counted_orders.customer_id
),
shared_emails AS (
    SELECT lower(btrim(customers.email)) AS clean_email
    FROM customers
    WHERE customers.email IS NOT NULL
    GROUP BY lower(btrim(customers.email))
    HAVING count(*) > 1
)
SELECT customers.customer_id,
       customers.full_name,
       customers.email,
       coalesce(spend_per_customer.total_spent, 0) AS total_spent,
       coalesce(spend_per_customer.order_count, 0) AS order_count,
       rank() OVER (ORDER BY coalesce(spend_per_customer.total_spent, 0) DESC) AS spend_rank,
       (shared_emails.clean_email IS NOT NULL)     AS shares_email_with_another_row
FROM customers
LEFT JOIN spend_per_customer
  ON spend_per_customer.customer_id = customers.customer_id
LEFT JOIN shared_emails
  ON shared_emails.clean_email = lower(btrim(customers.email));


CREATE OR REPLACE VIEW monday_top_100 AS
SELECT *
FROM monday_customer_summary
WHERE spend_rank <= 100;


-- One row per customer per month for the last 12 months, quiet months as 0 (decisions D and E).
CREATE OR REPLACE VIEW monday_monthly_spend AS
WITH report_window AS (
    -- one row, read through a subquery on purpose (decision H)
    SELECT (date_trunc('month', coalesce((SELECT report_settings.anchor_month
                                          FROM report_settings
                                          LIMIT 1)::timestamp, now()))
            - interval '11 months')::date AS first_month
),
months AS (
    SELECT (report_window.first_month + make_interval(months => month_number))::date AS month_start
    FROM report_window
    CROSS JOIN generate_series(0, 11) AS month_numbers(month_number)
),
spend_by_month AS (
    SELECT monday_counted_orders.customer_id,
           date_trunc('month', monday_counted_orders.order_date)::date AS month_start,
           sum(monday_counted_orders.total_amount)                     AS month_spend
    FROM monday_counted_orders
    GROUP BY monday_counted_orders.customer_id,
             date_trunc('month', monday_counted_orders.order_date)
),
spend_before_window AS (
    SELECT spend_by_month.customer_id,
           sum(spend_by_month.month_spend) AS spend_before
    FROM spend_by_month
    CROSS JOIN report_window
    WHERE spend_by_month.month_start < report_window.first_month
    GROUP BY spend_by_month.customer_id
)
SELECT customers.customer_id,
       months.month_start,
       coalesce(spend_by_month.month_spend, 0) AS month_spend,
       coalesce(spend_before_window.spend_before, 0)
         + sum(coalesce(spend_by_month.month_spend, 0))
             OVER (PARTITION BY customers.customer_id ORDER BY months.month_start) AS running_total
FROM customers
CROSS JOIN months
LEFT JOIN spend_by_month
  ON spend_by_month.customer_id = customers.customer_id
 AND spend_by_month.month_start = months.month_start
LEFT JOIN spend_before_window
  ON spend_before_window.customer_id = customers.customer_id;


-- What the report leaves out or cannot vouch for, in one row.
CREATE OR REPLACE VIEW monday_report_notes AS
WITH item_totals AS (
    SELECT order_items.order_id,
           sum(order_items.quantity * order_items.unit_price) AS items_total
    FROM order_items
    GROUP BY order_items.order_id
)
SELECT
    (SELECT count(*) FROM orders
      WHERE NOT EXISTS (SELECT 1 FROM customers WHERE customers.customer_id = orders.customer_id))
                                                              AS orders_with_no_customer_on_file,
    (SELECT count(*) FROM orders WHERE orders.order_date > now())
                                                              AS orders_dated_in_the_future,
    (SELECT count(*) FROM orders
      WHERE coalesce(lower(btrim(orders.status)), '') IN ('cancelled', 'canceled', 'refunded'))
                                                              AS cancelled_or_refunded_orders,
    (SELECT count(*)
       FROM monday_counted_orders
       JOIN item_totals
         ON item_totals.order_id = monday_counted_orders.order_id
      WHERE abs(monday_counted_orders.total_amount - item_totals.items_total) > 0.005)
                                                              AS counted_orders_whose_total_disagrees_with_items,
    (SELECT count(*) FROM monday_customer_summary
      WHERE monday_customer_summary.shares_email_with_another_row)
                                                              AS customer_rows_sharing_an_email;