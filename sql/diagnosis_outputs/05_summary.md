```text
PHASE 5: One row per check
       check_name        |                           what_is_counted                            | rows_found 
-------------------------+----------------------------------------------------------------------+------------
 Phase 1, Check 1        | Orders with no customer ID or a missing customer                     |        210
 Phase 1, Check 2        | Order items with no order ID or a missing order                      |        692
 Phase 1, Check 3        | Stock log rows with no product ID or a missing product               |        120
 Phase 1, Check 4        | Products without a category or pointing to a missing category        |         37
 Phase 1, Check 5        | Categories whose parent does not exist                               |          1
 Phase 1, Check 6        | Categories in a loop (their own ancestor)                            |          2
 Phase 1, Check 7        | Order items with no product ID or a missing product                  |          0
 Phase 2, Check 1        | Orders whose total does not match their line items                   |       2398
 Phase 2, Check 2        | Orders with no line items at all                                     |          0
 Phase 2, Check 3        | Products with negative stock                                         |         14
 Phase 2, Check 4        | Products whose stock does not match the stock log                    |        144
 Phase 2, Check 5        | Orders dated in the future                                           |         16
 Phase 2, Check 7        | Order items with a bad quantity or a missing, zero or negative price |        300
 Phase 3, Checks 1 and 2 | Orders whose status has capital letters or stray spaces              |      90900
 Phase 3, Checks 1 and 2 | Orders using "complete" or "canceled" (variant spellings)            |      25494
 Phase 3, Check 3        | Extra customer rows sharing an email with another row                |        535
 Phase 3, Check 4        | Customers whose phone does not start with +233                       |      32161
 Phase 3, Check 5        | Emails with stray spaces at the start or end                         |       1314
(18 rows)

```
