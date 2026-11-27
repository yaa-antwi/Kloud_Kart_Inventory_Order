# Build summary

Written by sql/build/run_all.sql. Every table below should show the loaded row counts, and every object below should exist.

## Database and time
```text
                                                 postgresql_version                                                 |     written_at      
--------------------------------------------------------------------------------------------------------------------+---------------------
 PostgreSQL 18.7 (Debian 18.7-1.pgdg13+5) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit | 2026-11-27 14:07:25
(1 row)

```

## Row counts (a fresh load gives 94, 4023, 40420, 159384, 336559, 282352)
```text
  table_name   |  rows  
---------------+--------
 categories    |     94
 products      |   4023
 customers     |  40420
 orders        | 159386
 order_items   | 336561
 inventory_log | 282354
(6 rows)

```

## The three id columns (expect is_identity = YES and BY DEFAULT)
```text
  table_name   |  column_name  | is_identity | identity_generation 
---------------+---------------+-------------+---------------------
 inventory_log | log_id        | YES         | BY DEFAULT
 order_items   | order_item_id | YES         | BY DEFAULT
 orders        | order_id      | YES         | BY DEFAULT
(3 rows)

```

## Functions (expect 3)
```text
  function_name  |                                 arguments                                 
-----------------+---------------------------------------------------------------------------
 correct_stock   | p_product_id bigint, p_counted_quantity integer, p_reason_for_change text
 place_order     | p_customer_id bigint, p_product_id bigint, p_quantity integer
 restock_product | p_product_id bigint, p_quantity integer, p_note text
(3 rows)

```

## Views (expect 10)
```text
        view_name        
-------------------------
 category_branches
 category_tree
 low_stock_by_category
 monday_counted_orders
 monday_customer_summary
 monday_monthly_spend
 monday_report_notes
 monday_top_100
 stock_movement_trail
 stock_trail_check
(10 rows)

```

## Stock rule (expect validated = f: it skips the 14 old negatives)
```text
          rule_name          | validated 
-----------------------------+-----------
 products_stock_not_negative | f
(1 row)

```
