```text
PHASE 4, Check 1: Status: orders a "completed" filter misses
 all_orders | orders_found_by_exact_filter | orders_that_are_really_completed | orders_missed | percent_of_completed_missed | money_missed 
------------+------------------------------+----------------------------------+---------------+-----------------------------+--------------
     159384 |                        22091 |                           111351 |         89260 |                        80.2 |    273128670
(1 row)

PHASE 4, Check 2: Money: recorded totals against line item totals
 orders_counted_as_spend | recorded_total_spend | line_item_total_spend | difference | difference_percent | orders_with_wrong_total | customers_with_a_wrong_order 
-------------------------+----------------------+-----------------------+------------+--------------------+-------------------------+------------------------------
                  140208 |            429065903 |             430428557 |   -1438192 |              -0.33 |                    2114 |                         2060
(1 row)

PHASE 4, Check 3: Ranking: top 100 customers by recorded total against line items
 in_both_top_100_lists | only_in_recorded_list | only_in_line_item_list 
-----------------------+-----------------------+------------------------
                    98 |                     2 |                      2
(1 row)

PHASE 4, Check 4: Customers: duplicate rows and the top 100 by person
 customer_rows | real_people | people_split_across_rows | true_top_100_people_missing_from_row_ranking 
---------------+-------------+--------------------------+----------------------------------------------
         40420 |       39885 |                      533 |                                            1
(1 row)

PHASE 4, Check 5: Orphans: orders and items pointing to missing records
 orders_without_customer | money_on_those_orders | percent_of_all_order_money | items_without_order | money_on_those_items 
-------------------------+-----------------------+----------------------------+---------------------+----------------------
                     210 |                665181 |                       0.14 |                 692 |               826328
(1 row)

PHASE 4, Check 6: Future orders: money and statuses
  status   | future_orders | money 
-----------+---------------+-------
 completed |            11 | 35506
 shipped   |             2 |  4691
 cancelled |             1 |   580
 complete  |             1 |    95
 refunded  |             1 |   477
(5 rows)

PHASE 4, Check 7: Negative stock: units and value
 products_below_zero | units_below_zero | worst_single_product | value_of_units_sold_without_stock 
---------------------+------------------+----------------------+-----------------------------------
                  14 |              -27 |                   -4 |                            -20628
(1 row)

PHASE 4, Check 8: Stock against log: units, value and best sellers affected
 products_differing | units_out_either_way | net_units_stock_minus_log | value_out_either_way | of_top_100_best_sellers | stock_below_log | stock_above_log 
--------------------+----------------------+---------------------------+----------------------+-------------------------+-----------------+-----------------
                144 |                 2553 |                     -2375 |              3865699 |                       8 |             122 |              22
(1 row)

PHASE 4, Check 9: Category rollup: products it would never reach
 products_total | products_the_rollup_reaches | products_uncategorised | products_in_unreachable_categories 
----------------+-----------------------------+------------------------+------------------------------------
           4023 |                        3980 |                     37 |                                  6
(1 row)

PHASE 4, Check 10: Bad item prices: orders affected
 orders_with_a_bad_price | of_those_total_also_wrong | recorded_money_on_those_orders 
-------------------------+---------------------------+--------------------------------
                     298 |                       269 |                        1455332
(1 row)

```
