-- Kloud Kart Ltd. — operational schema, as it exists today.
--
-- The schema the business grew on, reproduced as-is.

DROP TABLE IF EXISTS order_items, orders, inventory_log, products, customers, categories CASCADE;

CREATE TABLE categories (
    category_id     integer PRIMARY KEY,
    category_name   text,
    parent_id       integer          -- self-reference. No foreign key.
);

CREATE TABLE products (
    product_id      integer PRIMARY KEY,
    product_name    text,
    category_id     integer,         -- No foreign key.
    price           numeric(12,2),
    stock_quantity  integer,
    created_at      timestamp
);

CREATE TABLE customers (
    customer_id     integer PRIMARY KEY,
    full_name       text,
    email           text,            -- Not unique. Never was.
    phone           text,
    city            text,
    registered_at   timestamp
);

CREATE TABLE orders (
    order_id        integer PRIMARY KEY,
    customer_id     integer,         -- No foreign key.
    order_date      timestamp,       -- No time zone. Nobody remembers why.
    status          text,            -- Free text. No check constraint.
    total_amount    numeric(12,2)    -- Written by the application at checkout.
);

CREATE TABLE order_items (
    order_item_id   integer PRIMARY KEY,
    order_id        integer,         -- No foreign key.
    product_id      integer,         -- No foreign key.
    quantity        integer,
    unit_price      numeric(12,2)
);

CREATE TABLE inventory_log (
    log_id          integer PRIMARY KEY,
    product_id      integer,         -- No foreign key.
    change_qty      integer,         -- Negative for outward movement.
    reason          text,            -- Free text.
    created_at      timestamp,
    note            text
);

-- No indexes beyond the primary keys, and no foreign keys. That is the current
-- state of the database, not an omission in this file.
