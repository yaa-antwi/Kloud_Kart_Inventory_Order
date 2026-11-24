```text
PHASE 3, Check 1: Status spellings, as stored (how many rows each)
   status   | status_with_brackets | rows_with_this_spelling 
------------+----------------------+-------------------------
 canceled   | [canceled]           |                    3209
 cancelled  | [cancelled]          |                    3238
 Cancelled  | [Cancelled]          |                    3131
 CANCELLED  | [CANCELLED]          |                    3119
 complete   | [complete]           |                   22285
  completed | [ completed]         |                   22395
 completed  | [completed]          |                   22091
 Completed  | [Completed]          |                   22188
 COMPLETED  | [COMPLETED]          |                   22392
 pending    | [pending]            |                    7928
 Pending    | [Pending]            |                    8081
 refunded   | [refunded]           |                    3217
 Refunded   | [Refunded]           |                    3262
 shipped    | [shipped]            |                    6516
 Shipped    | [Shipped]            |                    6332
(15 rows)

PHASE 3, Check 2: Status spellings after removing spaces and ignoring capital letters
 normalised_status | spellings_merged | orders 
-------------------+------------------+--------
 completed         |                4 |  89066
 complete          |                1 |  22285
 pending           |                2 |  16009
 shipped           |                2 |  12848
 cancelled         |                3 |   9488
 refunded          |                2 |   6479
 canceled          |                1 |   3209
(7 rows)

PHASE 3, Check 3: Customers sharing an email (spaces and capital letters ignored)
 emails_used_more_than_once | customer_rows_involved | extra_rows_if_one_person_each | groups_where_the_name_also_matches 
----------------------------+------------------------+-------------------------------+------------------------------------
                        533 |                   1068 |                           535 |                                533
(1 row)

PHASE 3, Check 4: Phone number formats
       phone_format        | customers |    example    
---------------------------+-----------+---------------
 starts with 0 (local)     |     16027 | 0201026831
 starts with +233          |      8259 | +233201016132
 other                     |      8110 | 201003577
 starts with 233 (no plus) |      8024 | 233009587
(4 rows)

PHASE 3, Check 5: Emails with stray spaces at the start or end
 emails_with_stray_spaces 
--------------------------
                     1314
(1 row)

```
