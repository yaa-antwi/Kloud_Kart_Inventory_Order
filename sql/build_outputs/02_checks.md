# Checks

One row per check. A row with t in the passed column passed. A row with nothing in passed is information only.

## The checks
```text
 check_number |                                 check_name                                  |               result                |                              expected                               | passed 
--------------+-----------------------------------------------------------------------------+-------------------------------------+---------------------------------------------------------------------+--------
            1 | Low stock: every product is in exactly one line (top level + 2 extra lines) | 4023                                | 4023                                                                | t
            2 | Low stock: out-of-stock products add up                                     | 591                                 | 591                                                                 | t
            3 | Low stock: low-stock products add up                                        | 833                                 | 833                                                                 | t
            4 | Category tree: deepest level reached (information)                          | 4                                   | 4 in the loaded data                                                | 
            5 | Category tree: categories reached out of all categories (information)       | 91 of 94                            | 3 are in a loop or have a missing parent                            | 
            6 | Report: every customer appears once                                         | 40420                               | 40420                                                               | t
            7 | Report: total spent equals an independent sum                               | 428442749.40                        | 428442749.40                                                        | t
            8 | Report: order count equals an independent count                             | 140015                              | 140015                                                              | t
            9 | Report: 12 months for every customer                                        | 485040                              | 485040                                                              | t
           10 | Report: last running total equals total spent (customers that differ)       | 0                                   | 0                                                                   | t
           11 | Report: top 100 has 100 rows (more only if tied at rank 100)                | 100                                 | 100                                                                 | t
           12 | Trail: no movement names an order that is missing                           | 0                                   | 0                                                                   | t
           13 | Order function and stock rule exist                                         | 3 functions, rule validated = false | 3 functions, rule validated = false (it skips the 14 old negatives) | t
(13 rows)

```

## What the Monday report leaves out (one row)
```text
-[ RECORD 1 ]-----------------------------------+------
orders_with_no_customer_on_file                 | 210
orders_dated_in_the_future                      | 15
cancelled_or_refunded_orders                    | 19176
counted_orders_whose_total_disagrees_with_items | 2111
customer_rows_sharing_an_email                  | 1068

```

## What the stock trail cannot explain (one row)
```text
-[ RECORD 1 ]-----------------------------------+-------
movement_rows                                   | 282352
sales_with_no_order_link                        | 262088
movements_naming_a_missing_order                | 0
movements_naming_a_missing_product              | 120
movements_dated_in_the_future                   | 33
products_whose_stock_differs_from_their_history | 144
products_below_zero                             | 14

```
