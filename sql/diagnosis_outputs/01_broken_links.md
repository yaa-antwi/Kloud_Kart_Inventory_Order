```text
PHASE 1, Check 1: Orders with no customer ID or a missing customer
 orders_with_no_customer_id | orders_pointing_to_missing_customer 
----------------------------+-------------------------------------
                          0 |                                 210
(1 row)

PHASE 1, Check 2: Order items with no order ID or a missing order
 items_with_no_order_id | items_pointing_to_missing_order 
------------------------+---------------------------------
                      0 |                             692
(1 row)

PHASE 1, Check 3: Inventory log rows with no product ID or a missing product
 log_rows_with_no_product_id | log_rows_pointing_to_missing_product 
-----------------------------+--------------------------------------
                           0 |                                  120
(1 row)

PHASE 1, Check 4: Products without a category or pointing to a missing category
 products_uncategorised | products_pointing_to_missing_category 
------------------------+---------------------------------------
                     37 |                                     0
(1 row)

PHASE 1, Check 5: Categories whose parent does not exist
 categories_with_missing_parent 
--------------------------------
                              1
(1 row)

PHASE 1, Check 6: Category loops and categories hanging below a loop
 categories_in_a_loop | categories_hanging_below_a_loop 
----------------------+---------------------------------
                    2 |                               0
(1 row)

PHASE 1, Check 7: Order items with no product ID or a missing product
 items_with_no_product_id | items_pointing_to_missing_product 
--------------------------+-----------------------------------
                        0 |                                 0
(1 row)

```
