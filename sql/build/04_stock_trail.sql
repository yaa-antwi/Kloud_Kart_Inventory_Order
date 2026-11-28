-- BUILD 4: THE STOCK MOVEMENT TRAIL

-- WHAT THIS DOES
--   Every change to stock that goes through the three functions leaves one row
--   in inventory_log, written in the same transaction as the change, so the
--   two cannot disagree:
--     sale        place_order        (file 01)
--     restock     restock_product    (this file)
--     correction  correct_stock      (this file), or stock_take when the count
--                                    matches the system
--   Two views let an auditor walk the trail and see what cannot be explained.

-- DECISIONS
--   A. Each movement is written by the same function that changes the stock,
--      under the same row lock, so a sale and a restock cannot interleave.
--   B. A correction needs a written reason and works from the COUNTED quantity,
--      so the log shows the physical count and the size of the gap.
--   C. A restock that would still leave a product below zero is refused with a
--      clear message: count the shelf and use correct_stock first. The stock
--      rule from file 01 would reject it anyway; this gives a clear reply.
--   D. No trigger. A stock number typed in by hand leaves no history row. This
--      is a stated limit; stock_trail_check shows the products whose stock
--      disagrees with their history.

-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/04_stock_trail.sql

\set QUIET on


-- Remove the trigger version if an earlier build left it behind.
DROP TRIGGER IF EXISTS products_stock_update_log ON products;
DROP TRIGGER IF EXISTS products_stock_insert_log ON products;
DROP FUNCTION IF EXISTS log_product_stock_change();


CREATE OR REPLACE FUNCTION restock_product(
    p_product_id bigint,
    p_quantity   integer,
    p_note       text DEFAULT NULL
)
RETURNS TABLE (success boolean, message text)
LANGUAGE plpgsql
SET lock_timeout = '5s'
AS $$
DECLARE
    v_stock integer;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RETURN QUERY SELECT false, 'Quantity must be above zero'::text;
        RETURN;
    END IF;

    BEGIN
        SELECT products.stock_quantity
          INTO v_stock
          FROM products
         WHERE products.product_id = p_product_id
           FOR UPDATE;
    EXCEPTION WHEN lock_not_available THEN
        RETURN QUERY SELECT false, 'Busy, please try again'::text;
        RETURN;
    END;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Product not found'::text;
        RETURN;
    END IF;

    -- decision C
    IF v_stock + p_quantity < 0 THEN
        RETURN QUERY SELECT false,
            'Stock is below zero: count the shelf and use correct_stock first'::text;
        RETURN;
    END IF;

    UPDATE products
       SET stock_quantity = stock_quantity + p_quantity
     WHERE products.product_id = p_product_id;

    INSERT INTO inventory_log (product_id, change_qty, reason, created_at, note)
    VALUES (p_product_id, p_quantity, 'restock', now(), p_note);

    RETURN QUERY SELECT true, 'Restocked'::text;
END $$;


CREATE OR REPLACE FUNCTION correct_stock(
    p_product_id        bigint,
    p_counted_quantity  integer,
    p_reason_for_change text
)
RETURNS TABLE (success boolean, message text)
LANGUAGE plpgsql
SET lock_timeout = '5s'
AS $$
DECLARE
    v_stock integer;
BEGIN
    IF p_counted_quantity IS NULL OR p_counted_quantity < 0 THEN
        RETURN QUERY SELECT false, 'The counted quantity cannot be below zero'::text;
        RETURN;
    END IF;

    -- decision B: no correction without a reason
    IF p_reason_for_change IS NULL OR btrim(p_reason_for_change) = '' THEN
        RETURN QUERY SELECT false, 'A reason for the correction is required'::text;
        RETURN;
    END IF;

    BEGIN
        SELECT products.stock_quantity
          INTO v_stock
          FROM products
         WHERE products.product_id = p_product_id
           FOR UPDATE;
    EXCEPTION WHEN lock_not_available THEN
        RETURN QUERY SELECT false, 'Busy, please try again'::text;
        RETURN;
    END;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Product not found'::text;
        RETURN;
    END IF;

    UPDATE products
       SET stock_quantity = p_counted_quantity
     WHERE products.product_id = p_product_id;

    INSERT INTO inventory_log (product_id, change_qty, reason, created_at, note)
    VALUES (p_product_id,
            p_counted_quantity - v_stock,
            CASE WHEN p_counted_quantity = v_stock THEN 'stock_take' ELSE 'correction' END,
            now(),
            p_reason_for_change);

    RETURN QUERY SELECT true, 'Stock corrected'::text;
END $$;


-- Every movement with its product and, for sales made since file 01, its order.
CREATE OR REPLACE VIEW stock_movement_trail AS
SELECT inventory_log.log_id,
       inventory_log.created_at,
       inventory_log.product_id,
       products.product_name,
       inventory_log.reason,
       inventory_log.change_qty,
       inventory_log.order_id,
       (orders.order_id IS NOT NULL) AS order_is_on_file,
       inventory_log.note
FROM inventory_log
LEFT JOIN products
  ON products.product_id = inventory_log.product_id
LEFT JOIN orders
  ON orders.order_id = inventory_log.order_id;


-- What the trail cannot explain, in one row.
CREATE OR REPLACE VIEW stock_trail_check AS
WITH movement_total_per_product AS (
    SELECT inventory_log.product_id,
           sum(inventory_log.change_qty) AS movement_total
    FROM inventory_log
    GROUP BY inventory_log.product_id
)
SELECT
    (SELECT count(*) FROM inventory_log)
        AS movement_rows,
    (SELECT count(*) FROM inventory_log
      WHERE inventory_log.reason = 'sale' AND inventory_log.order_id IS NULL)
        AS sales_with_no_order_link,
    (SELECT count(*) FROM inventory_log
      WHERE inventory_log.order_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM orders WHERE orders.order_id = inventory_log.order_id))
        AS movements_naming_a_missing_order,
    (SELECT count(*) FROM inventory_log
      WHERE NOT EXISTS (SELECT 1 FROM products WHERE products.product_id = inventory_log.product_id))
        AS movements_naming_a_missing_product,
    (SELECT count(*) FROM inventory_log WHERE inventory_log.created_at > now())
        AS movements_dated_in_the_future,
    (SELECT count(*)
       FROM products
       LEFT JOIN movement_total_per_product
         ON movement_total_per_product.product_id = products.product_id
      WHERE products.stock_quantity <> coalesce(movement_total_per_product.movement_total, 0))
        AS products_whose_stock_differs_from_their_history,
    (SELECT count(*) FROM products WHERE products.stock_quantity < 0)
        AS products_below_zero;
