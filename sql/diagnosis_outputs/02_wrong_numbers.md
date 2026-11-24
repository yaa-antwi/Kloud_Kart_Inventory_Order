```text
PHASE 2, Check 1: Orders whose total does not match their line items
 orders_compared | orders_with_wrong_total | recorded_lower_than_items | recorded_higher_than_items | net_difference | gross_difference 
-----------------+-------------------------+---------------------------+----------------------------+----------------+------------------
          159384 |                    2398 |                      1342 |                       1056 |    -3477551.62 |       5214733.92
(1 row)

PHASE 2, Check 2: Orders that have no line items at all
 orders_without_items 
----------------------
                    0
(1 row)

PHASE 2, Check 3: Products with negative stock
 products_with_negative_stock | total_units_below_zero 
------------------------------+------------------------
                           14 |                    -27
(1 row)

PHASE 2, Check 4: Products where stock does not match the sum of the log
 products_checked | products_matching_log_exactly | products_where_stock_differs_from_log | products_with_no_log_at_all 
------------------+-------------------------------+---------------------------------------+-----------------------------
             4023 |                          3879 |                                   144 |                           0
(1 row)

PHASE 2, Check 5: Orders dated in the future
 future_orders |   earliest_future   |    latest_future    | earliest_days_ahead | latest_days_ahead 
---------------+---------------------+---------------------+---------------------+-------------------
            16 | 2026-11-26 05:46:00 | 2027-08-20 19:30:00 |                   2 |               269
(1 row)

PHASE 2, Check 6: Order date range overall
     first_order     |     last_order      
---------------------+---------------------
 2025-08-02 05:00:54 | 2027-08-20 19:30:00
(1 row)

PHASE 2, Check 7: Order items with zero, negative or missing quantity or price
 bad_quantity | missing_unit_price | zero_unit_price | negative_unit_price | orders_affected 
--------------+--------------------+-----------------+---------------------+-----------------
            0 |                148 |             152 |                   0 |             298
(1 row)

PHASE 2, Check 8: How the wrong totals cluster (recorded total divided by items total)
 recorded_divided_by_items | orders 
---------------------------+--------
                      0.75 |    415
                      1.10 |    403
                      0.90 |    401
                      1.25 |    391
                      0.50 |    114
                      0.99 |     41
                      1.00 |     36
                      0.98 |     24
                      0.97 |     21
                      1.01 |     21
(10 rows)

PHASE 2, Check 9: What the stock log records (reasons and units)
   reason   | log_rows |  units  
------------+----------+---------
 sale       |   262088 | -412645
 restock    |    18857 |  671371
 return     |      564 |    1017
 correction |      485 |    -528
 damage     |      268 |    -622
 stock_take |       90 |       0
(6 rows)

```
