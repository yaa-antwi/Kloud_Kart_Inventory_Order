# Before and after: the Monday report

## Database and time
```text
                                                 postgresql_version                                                 |     written_at      
--------------------------------------------------------------------------------------------------------------------+---------------------
 PostgreSQL 18.7 (Debian 18.7-1.pgdg13+5) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit | 2026-11-27 13:58:57
(1 row)

```

## 1. BEFORE: the per-customer way, plan for 20 customers
Read from the bottom up. Look at loops: each lookup is repeated for every customer.
```text
                                                                                                                                                                       QUERY PLAN                                                                                                                                                                       
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=4113.272..4113.280 rows=1.00 loops=1)
   Buffers: shared hit=437123, temp read=4100 written=7300
   ->  Limit (actual time=506.031..4113.208 rows=20.00 loops=1)
         Buffers: shared hit=437123, temp read=4100 written=7300
         ->  Index Only Scan using customers_pkey on customers (actual time=250.123..3857.269 rows=20.00 loops=1)
               Heap Fetches: 0
               Index Searches: 1
               Buffers: shared hit=437123, temp read=4100 written=7300
               SubPlan 1
                 ->  Aggregate (actual time=4.602..4.602 rows=1.00 loops=20)
                       Buffers: shared hit=27320
                       ->  Seq Scan on orders (actual time=1.253..4.587 rows=3.70 loops=20)
                             Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                             Rows Removed by Filter: 159382
                             Buffers: shared hit=27320
               SubPlan 2
                 ->  Aggregate (actual time=4.066..4.066 rows=1.00 loops=20)
                       Buffers: shared hit=27320
                       ->  Seq Scan on orders orders_1 (actual time=1.064..4.055 rows=3.70 loops=20)
                             Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                             Rows Removed by Filter: 159382
                             Buffers: shared hit=27320
               SubPlan 4
                 ->  Aggregate (actual time=51.154..51.155 rows=1.00 loops=20)
                       Buffers: shared hit=327840
                       ->  Function Scan on generate_series month_numbers (actual time=0.002..0.022 rows=12.00 loops=20)
                       SubPlan 3
                         ->  Aggregate (actual time=4.253..4.253 rows=1.00 loops=240)
                               Buffers: shared hit=327840
                               ->  Seq Scan on orders orders_2 (actual time=3.802..4.243 rows=0.26 loops=240)
                                     Filter: ((customer_id = customers.customer_id) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])) AND (date_trunc('month'::text, order_date) = (date_trunc('month'::text, now()) - make_interval(0, month_numbers.month_number, 0, 0, 0, 0, '0'::double precision))))
                                     Rows Removed by Filter: 159386
                                     Buffers: shared hit=327840
               SubPlan 6
                 ->  Aggregate (actual time=133.008..133.008 rows=1.00 loops=20)
                       Buffers: shared hit=54640, temp read=4100 written=7300
                       InitPlan 5
                         ->  Aggregate (actual time=4.314..4.314 rows=1.00 loops=20)
                               Buffers: shared hit=27320
                               ->  Seq Scan on orders orders_3 (actual time=1.110..4.298 rows=3.70 loops=20)
                                     Filter: ((customer_id = customers.customer_id) AND (order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                     Rows Removed by Filter: 159382
                                     Buffers: shared hit=27320
                       ->  HashAggregate (actual time=112.438..132.057 rows=20690.10 loops=20)
                             Group Key: every_order.customer_id
                             Filter: (sum(every_order.total_amount) > (InitPlan 5).col1)
                             Batches: 81  Memory Usage: 8241kB  Disk Usage: 1752kB
                             Rows Removed by Filter: 18667
                             Buffers: shared hit=54640, temp read=4100 written=7300
                             ->  Seq Scan on orders every_order (actual time=0.012..65.212 rows=140196.00 loops=20)
                                   Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                   Rows Removed by Filter: 19190
                                   Buffers: shared hit=27320
 Planning Time: 0.291 ms
 Execution Time: 4115.123 ms
(55 rows)

```

## 2. AFTER: the finished summary view, all customers, no new index
```text
                                                                              QUERY PLAN                                                                               
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=195.183..195.191 rows=1.00 loops=1)
   Buffers: shared hit=2406, temp read=203 written=364
   ->  Hash Left Join (actual time=182.235..191.728 rows=40420.00 loops=1)
         Hash Cond: (customers.customer_id = spend_per_customer.customer_id)
         Buffers: shared hit=2406, temp read=203 written=364
         ->  Seq Scan on customers (actual time=0.007..1.744 rows=40420.00 loops=1)
               Buffers: shared hit=520
         ->  Hash (actual time=182.206..182.212 rows=39193.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 2246kB
               Buffers: shared hit=1886, temp read=203 written=364
               ->  Subquery Scan on spend_per_customer (actual time=154.179..176.428 rows=39193.00 loops=1)
                     Buffers: shared hit=1886, temp read=203 written=364
                     ->  HashAggregate (actual time=154.177..174.025 rows=39193.00 loops=1)
                           Group Key: orders.customer_id
                           Batches: 5  Memory Usage: 8241kB  Disk Usage: 1752kB
                           Buffers: shared hit=1886, temp read=203 written=364
                           ->  Hash Join (actual time=4.838..109.147 rows=140017.00 loops=1)
                                 Hash Cond: (orders.customer_id = customers_1.customer_id)
                                 Buffers: shared hit=1886
                                 ->  Seq Scan on orders (actual time=0.014..70.865 rows=140196.00 loops=1)
                                       Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                       Rows Removed by Filter: 19190
                                       Buffers: shared hit=1366
                                 ->  Hash (actual time=4.740..4.741 rows=40420.00 loops=1)
                                       Buckets: 65536  Batches: 1  Memory Usage: 1934kB
                                       Buffers: shared hit=520
                                       ->  Seq Scan on customers customers_1 (actual time=0.003..2.007 rows=40420.00 loops=1)
                                             Buffers: shared hit=520
 Planning:
   Buffers: shared hit=6
 Planning Time: 0.359 ms
 Execution Time: 195.946 ms
(32 rows)

```

## 3. AFTER, WITH the candidate index: does the planner use it for the whole report?
```text
                                                                              QUERY PLAN                                                                               
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate (actual time=184.479..184.485 rows=1.00 loops=1)
   Buffers: shared hit=2428, temp read=203 written=364
   ->  Hash Left Join (actual time=172.220..181.028 rows=40420.00 loops=1)
         Hash Cond: (customers.customer_id = spend_per_customer.customer_id)
         Buffers: shared hit=2428, temp read=203 written=364
         ->  Seq Scan on customers (actual time=0.008..1.736 rows=40420.00 loops=1)
               Buffers: shared hit=520
         ->  Hash (actual time=172.186..172.191 rows=39193.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 2246kB
               Buffers: shared hit=1908, temp read=203 written=364
               ->  Subquery Scan on spend_per_customer (actual time=146.322..167.014 rows=39193.00 loops=1)
                     Buffers: shared hit=1908, temp read=203 written=364
                     ->  HashAggregate (actual time=146.320..164.741 rows=39193.00 loops=1)
                           Group Key: orders.customer_id
                           Batches: 5  Memory Usage: 8241kB  Disk Usage: 1752kB
                           Buffers: shared hit=1908, temp read=203 written=364
                           ->  Hash Join (actual time=5.290..103.854 rows=140017.00 loops=1)
                                 Hash Cond: (orders.customer_id = customers_1.customer_id)
                                 Buffers: shared hit=1908
                                 ->  Seq Scan on orders (actual time=0.015..68.853 rows=140196.00 loops=1)
                                       Filter: ((order_date <= now()) AND (COALESCE(lower(btrim(status)), ''::text) <> ALL ('{cancelled,canceled,refunded}'::text[])))
                                       Rows Removed by Filter: 19190
                                       Buffers: shared hit=1388
                                 ->  Hash (actual time=5.257..5.258 rows=40420.00 loops=1)
                                       Buckets: 65536  Batches: 1  Memory Usage: 1934kB
                                       Buffers: shared hit=520
                                       ->  Seq Scan on customers customers_1 (actual time=0.003..2.150 rows=40420.00 loops=1)
                                             Buffers: shared hit=520
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.335 ms
 Execution Time: 184.753 ms
(32 rows)

```

## 4. All timings (milliseconds)
```text
     run_group      |                            step                            | milliseconds 
--------------------+------------------------------------------------------------+--------------
 before             | per-customer way, 20 customers, run 1                      |       4079.5
 after, no index    | monthly view, 485,040 rows with running total, run 1       |        883.3
 after, no index    | monthly view, 485,040 rows with running total, run 2       |        913.1
 after, no index    | monthly view, 485,040 rows with running total, run 3       |       1010.7
 after, no index    | summary view, all 40,420 customers, run 1                  |        156.8
 after, no index    | summary view, all 40,420 customers, run 2                  |        167.3
 after, no index    | summary view, all 40,420 customers, run 3                  |        178.8
 after, no index    | top 100 view, run 1                                        |        165.0
 after, no index    | top 100 view, run 2                                        |        165.2
 after, no index    | top 100 view, run 3                                        |        175.3
 sales, no index    | 3,000 sales through place_order (3000 order items written) |        529.2
 before, with index | per-customer way, 20 customers, run 1                      |       2444.5
 after, with index  | monthly view, 485,040 rows with running total, run 1       |        938.2
 after, with index  | monthly view, 485,040 rows with running total, run 2       |       1478.3
 after, with index  | monthly view, 485,040 rows with running total, run 3       |       1076.2
 after, with index  | summary view, all 40,420 customers, run 1                  |        155.9
 after, with index  | summary view, all 40,420 customers, run 2                  |        157.4
 after, with index  | summary view, all 40,420 customers, run 3                  |        155.7
 sales, with index  | 3,000 sales through place_order (3000 order items written) |        540.0
(19 rows)

```

## 5. The per-customer way scaled to every customer (shape of the cost only)
```text
     run_group      | ms_for_20_customers | minutes_for_all_40420_customers 
--------------------+---------------------+---------------------------------
 before, with index |              2444.5 |                            82.3
 before             |              4079.5 |                           137.4
(2 rows)

```

## 6. Write cost of the candidate index: 3,000 sales, without and with it
```text
     run_group     | ms_for_3000_sales | ms_per_sale 
-------------------+-------------------+-------------
 sales, with index |             540.0 |       0.180
 sales, no index   |             529.2 |       0.176
(2 rows)

```
