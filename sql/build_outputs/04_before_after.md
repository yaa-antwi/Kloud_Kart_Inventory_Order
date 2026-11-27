# Before and after: the Monday report

## Database and time
```text
                                                 postgresql_version                                                 |     written_at      
--------------------------------------------------------------------------------------------------------------------+---------------------
 PostgreSQL 18.7 (Debian 18.7-1.pgdg13+5) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit | 2026-11-27 08:21:39
(1 row)

```

## 1. BEFORE: the per-customer way, plan for 20 customers
Read from the bottom up. Look at loops: each lookup is repeated for every customer.
```text
                                                                                                                                                                       QUERY PLAN                                                                                                                                                                       
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=4789.442..4789.452 rows=1.00 loops=1)
   Buffers: shared hit=408963, temp read=4100 written=7300
   ->  Limit (actual time=558.742..4789.354 rows=20.00 loops=1)
         Buffers: shared hit=408963, temp read=4100 written=7300
         ->  Index Only Scan using customers_pkey on customers (actual time=278.306..4508.886 rows=20.00 loops=1)
               Heap Fetches: 0
               Index Searches: 1
               Buffers: shared hit=408963, temp read=4100 written=7300
               SubPlan 1
                 ->  Aggregate (actual time=4.851..4.851 rows=1.00 loops=20)
                       Buffers: shared hit=25560
                       ->  Seq Scan on orders (actual time=1.264..4.828 rows=3.60 loops=20)
                             Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                             Rows Removed by Filter: 159380
                             Buffers: shared hit=25560
               SubPlan 2
                 ->  Aggregate (actual time=4.337..4.337 rows=1.00 loops=20)
                       Buffers: shared hit=25560
                       ->  Seq Scan on orders orders_1 (actual time=1.118..4.321 rows=3.60 loops=20)
                             Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                             Rows Removed by Filter: 159380
                             Buffers: shared hit=25560
               SubPlan 4
                 ->  Aggregate (actual time=56.383..56.383 rows=1.00 loops=20)
                       Buffers: shared hit=306720
                       ->  Function Scan on generate_series month_numbers (actual time=0.003..0.025 rows=12.00 loops=20)
                       SubPlan 3
                         ->  Aggregate (actual time=4.687..4.687 rows=1.00 loops=240)
                               Buffers: shared hit=306720
                               ->  Seq Scan on orders orders_2 (actual time=4.209..4.673 rows=0.25 loops=240)
                                     Filter: ((customer_id = customers.customer_id) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])) AND (date_trunc('month'::text, order_date) = (date_trunc('month'::text, now()) - make_interval(0, month_numbers.month_number, 0, 0, 0, 0, '0'::double precision))))
                                     Rows Removed by Filter: 159384
                                     Buffers: shared hit=306720
               SubPlan 6
                 ->  Aggregate (actual time=159.834..159.834 rows=1.00 loops=20)
                       Buffers: shared hit=51120, temp read=4100 written=7300
                       InitPlan 5
                         ->  Aggregate (actual time=4.608..4.608 rows=1.00 loops=20)
                               Buffers: shared hit=25560
                               ->  Seq Scan on orders orders_3 (actual time=1.285..4.591 rows=3.60 loops=20)
                                     Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                     Rows Removed by Filter: 159380
                                     Buffers: shared hit=25560
                       ->  HashAggregate (actual time=135.820..158.777 rows=20704.25 loops=20)
                             Group Key: every_order.customer_id
                             Filter: (sum(every_order.total_amount) > (InitPlan 5).col1)
                             Batches: 81  Memory Usage: 8241kB  Disk Usage: 1752kB
                             Rows Removed by Filter: 18653
                             Buffers: shared hit=51120, temp read=4100 written=7300
                             ->  Seq Scan on orders every_order (actual time=0.016..77.362 rows=140194.00 loops=20)
                                   Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                   Rows Removed by Filter: 19190
                                   Buffers: shared hit=25560
 Planning Time: 0.280 ms
 Execution Time: 4791.518 ms
(55 rows)

```

## 2. AFTER: the finished summary view, all customers, no new index
```text
                                                                              QUERY PLAN                                                                               
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=298.166..298.174 rows=1.00 loops=1)
   Buffers: shared hit=2318, temp read=203 written=364
   ->  Hash Left Join (actual time=284.738..294.499 rows=40420.00 loops=1)
         Hash Cond: (customers.customer_id = spend_per_customer.customer_id)
         Buffers: shared hit=2318, temp read=203 written=364
         ->  Seq Scan on customers (actual time=0.007..1.823 rows=40420.00 loops=1)
               Buffers: shared hit=520
         ->  Hash (actual time=284.706..284.711 rows=39193.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 2246kB
               Buffers: shared hit=1798, temp read=203 written=364
               ->  Subquery Scan on spend_per_customer (actual time=244.006..275.654 rows=39193.00 loops=1)
                     Buffers: shared hit=1798, temp read=203 written=364
                     ->  HashAggregate (actual time=244.004..272.142 rows=39193.00 loops=1)
                           Group Key: orders.customer_id
                           Batches: 5  Memory Usage: 8241kB  Disk Usage: 1752kB
                           Buffers: shared hit=1798, temp read=203 written=364
                           ->  Hash Join (actual time=5.491..178.654 rows=140015.00 loops=1)
                                 Hash Cond: (orders.customer_id = customers_1.customer_id)
                                 Buffers: shared hit=1798
                                 ->  Seq Scan on orders (actual time=0.017..118.147 rows=140194.00 loops=1)
                                       Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                       Rows Removed by Filter: 19190
                                       Buffers: shared hit=1278
                                 ->  Hash (actual time=5.391..5.392 rows=40420.00 loops=1)
                                       Buckets: 65536  Batches: 1  Memory Usage: 1934kB
                                       Buffers: shared hit=520
                                       ->  Seq Scan on customers customers_1 (actual time=0.003..2.242 rows=40420.00 loops=1)
                                             Buffers: shared hit=520
 Planning:
   Buffers: shared hit=6
 Planning Time: 0.295 ms
 Execution Time: 299.035 ms
(32 rows)

```

## 3. AFTER, WITH the candidate index: does the planner use it for the whole report?
```text
                                                                              QUERY PLAN                                                                               
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=264.301..264.311 rows=1.00 loops=1)
   Buffers: shared hit=2340, temp read=203 written=364
   ->  Hash Left Join (actual time=247.581..260.015 rows=40420.00 loops=1)
         Hash Cond: (customers.customer_id = spend_per_customer.customer_id)
         Buffers: shared hit=2340, temp read=203 written=364
         ->  Seq Scan on customers (actual time=0.009..2.099 rows=40420.00 loops=1)
               Buffers: shared hit=520
         ->  Hash (actual time=247.542..247.549 rows=39193.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 2246kB
               Buffers: shared hit=1820, temp read=203 written=364
               ->  Subquery Scan on spend_per_customer (actual time=208.865..239.918 rows=39193.00 loops=1)
                     Buffers: shared hit=1820, temp read=203 written=364
                     ->  HashAggregate (actual time=208.863..237.003 rows=39193.00 loops=1)
                           Group Key: orders.customer_id
                           Batches: 5  Memory Usage: 8241kB  Disk Usage: 1752kB
                           Buffers: shared hit=1820, temp read=203 written=364
                           ->  Hash Join (actual time=7.264..148.645 rows=140015.00 loops=1)
                                 Hash Cond: (orders.customer_id = customers_1.customer_id)
                                 Buffers: shared hit=1820
                                 ->  Seq Scan on orders (actual time=0.018..95.038 rows=140194.00 loops=1)
                                       Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                       Rows Removed by Filter: 19190
                                       Buffers: shared hit=1300
                                 ->  Hash (actual time=7.219..7.220 rows=40420.00 loops=1)
                                       Buckets: 65536  Batches: 1  Memory Usage: 1934kB
                                       Buffers: shared hit=520
                                       ->  Seq Scan on customers customers_1 (actual time=0.003..3.321 rows=40420.00 loops=1)
                                             Buffers: shared hit=520
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.357 ms
 Execution Time: 264.661 ms
(32 rows)

```

## 4. All timings (milliseconds)
```text
     run_group      |                            step                            | milliseconds 
--------------------+------------------------------------------------------------+--------------
 before             | per-customer way, 20 customers, run 1                      |       4105.0
 after, no index    | monthly view, 485,040 rows with running total, run 1       |        993.1
 after, no index    | monthly view, 485,040 rows with running total, run 2       |        981.7
 after, no index    | monthly view, 485,040 rows with running total, run 3       |        991.9
 after, no index    | summary view, all 40,420 customers, run 1                  |        217.0
 after, no index    | summary view, all 40,420 customers, run 2                  |        280.6
 after, no index    | summary view, all 40,420 customers, run 3                  |        189.9
 after, no index    | top 100 view, run 1                                        |        192.4
 after, no index    | top 100 view, run 2                                        |        213.3
 after, no index    | top 100 view, run 3                                        |        191.5
 sales, no index    | 3,000 sales through place_order (3000 order items written) |        451.6
 before, with index | per-customer way, 20 customers, run 1                      |       2898.8
 after, with index  | monthly view, 485,040 rows with running total, run 1       |        987.0
 after, with index  | monthly view, 485,040 rows with running total, run 2       |       1025.4
 after, with index  | monthly view, 485,040 rows with running total, run 3       |        985.0
 after, with index  | summary view, all 40,420 customers, run 1                  |        176.7
 after, with index  | summary view, all 40,420 customers, run 2                  |        205.1
 after, with index  | summary view, all 40,420 customers, run 3                  |        416.6
 sales, with index  | 3,000 sales through place_order (3000 order items written) |        588.8
(19 rows)

```

## 5. The per-customer way scaled to every customer (shape of the cost only)
```text
     run_group      | ms_for_20_customers | minutes_for_all_40420_customers 
--------------------+---------------------+---------------------------------
 before, with index |              2898.8 |                            97.6
 before             |              4105.0 |                           138.3
(2 rows)

```

## 6. Write cost of the candidate index: 3,000 sales, without and with it
```text
     run_group     | ms_for_3000_sales | ms_per_sale 
-------------------+-------------------+-------------
 sales, with index |             588.8 |       0.196
 sales, no index   |             451.6 |       0.151
(2 rows)

```
