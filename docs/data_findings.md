# Data findings - Kloud Kart Ltd.

## Summary

I checked all six tables and measured what each fault does to the numbers Nana and Adwoa use. The database enforces no rules of its own (no foreign keys, no value checks, free-text status), so nearly every fault follows from that. Nothing in the source data has been changed, and every figure comes from a re-runnable check in `sql/diagnosis/`. The three that matter most: stock below zero, status spellings that hide 80% of completed orders from a simple report, and order totals that disagree with their items.

## Reconciliation

| Stage | Rows | Delta | Reason |
|---|---|---|---|
| Orders loaded | 159,384 | 0 | All six files loaded in full (822,832 rows) |
| Orders with a known customer | 159,174 | -210 | F-07 |
| Orders counted as spend | 140,029 | -19,145 | Cancelled and refunded excluded (my assumption) |
| Order items with an order | 335,867 | -692 | F-07 |
| Customers counted as people | 39,885 | -535 | F-05 |
| Products the category rollup can reach | 3,980 | -43 | F-06 |

## Findings, ranked by risk

### F-01: Overselling, shown as negative stock - Severity: High

- **What it is:** Nothing keeps stock at zero or above, and 14 products are below zero.
- **How I detected it:** `02_wrong_numbers.sql`, Check 3.
- **Scale:** 14 of 4,023 products, 27 units in total, worst 4.
- **Effect on the client's number:** About 20,628 in goods sold with no stock behind them. Each case costs a refund, an apology and a review.
- **What I did about it:** Source data unchanged. Planned: an order function that checks and lowers stock in one step.
- **Residual risk:** Two orders racing for the last unit is Nana's account and my hypothesis. The data cannot confirm it.

### F-02: Order status written 15 ways - Severity: High

- **What it is:** Nothing limits status to a list. The 15 spellings are really 7 values.
- **How I detected it:** `03_messy_labels.sql`, Checks 1 and 2.
- **Scale:** 111,351 orders are completed. An exact "completed" filter finds 22,091.
- **Effect on the client's number:** That filter misses 89,260 orders (80.2%), about 273 million.
- **What I did about it:** Source data unchanged. Planned: one agreed mapping used by every report.
- **Residual risk:** Depends on Adwoa's report, which I have not seen. Treating "complete" as "completed" is my assumption.

### F-03: Order totals that do not match their items - Severity: High

- **What it is:** Nothing checks the total the application writes. 2,398 orders differ from the sum of their items, which is probably the right value but is unconfirmed.
- **How I detected it:** `02_wrong_numbers.sql`, Checks 1 and 8.
- **Scale:** 1,342 too low, 1,056 too high, 98.5% match. Most wrong ones sit at clean ratios (0.75, 1.10, 0.90, 1.25, 0.50).
- **Effect on the client's number:** The net gap is only 0.33%, but 2,060 customers have a wrong order, typically 25% off.
- **What I did about it:** Source data unchanged, as I cannot tell which total is right. Planned: new totals come from the items.
- **Residual risk:** Which total is correct is unknown.

### F-04: Stock that disagrees with its log - Severity: Medium

- **What it is:** Nothing ties stock to its movement log. 144 products disagree.
- **How I detected it:** `02_wrong_numbers.sql`, Checks 4 and 9.
- **Scale:** 144 of 4,023 products, 2,553 units, including 8 of the top 100 sellers.
- **Effect on the client's number:** Stock and reorder decisions for these products cannot be trusted either way.
- **What I did about it:** Source data unchanged. Planned: each stock change writes its log entry in the same step.
- **Residual risk:** Which number is right is unknown, and the log may be incomplete.

### F-05: Customers stored more than once - Severity: Medium

- **What it is:** Email is not unique. 533 emails sit on 1,068 rows, with matching names.
- **How I detected it:** `03_messy_labels.sql`, Checks 3 and 5. Trimming spaces raised the count from 419 to 533.
- **Scale:** 535 extra rows. 40,420 rows are 39,885 people.
- **Effect on the client's number:** Customer count overstated by 1.3%, spend split across rows, and 1 top-100 customer missed.
- **What I did about it:** Source data unchanged. Planned: the report groups by person. Merging for good needs a manual review first.
- **Residual risk:** Same email and name is strong evidence, not proof.

### F-06: Category loop and unreachable products - Severity: Medium

- **What it is:** Nothing stops a category being its own ancestor. 2 categories loop, 1 names a missing parent, 37 products have no category.
- **How I detected it:** `01_broken_links.sql`, Checks 4 to 6.
- **Scale:** 43 of 4,023 products (1.1%) cannot be reached from the top of the tree.
- **Effect on the client's number:** The low-stock rollup would silently omit them, and an unguarded one would never finish.
- **What I did about it:** Source data unchanged. Planned: the rollup drops repeats, and uncategorised products show as their own line.
- **Residual risk:** Harm today is low, build risk is high. Whether the 37 are deliberate is unknown.

### F-07: Rows pointing at records that do not exist - Severity: Low

- **What it is:** No foreign keys. 210 orders name a missing customer (numbers 999007 to 999997), 692 items a missing order, 120 log rows a missing product.
- **How I detected it:** `01_broken_links.sql`, Checks 1 to 3.
- **Scale:** 665,181 on the orders (0.14% of order money) and 826,328 on the items.
- **Effect on the client's number:** Reports joining orders to customers drop those 210 orders silently.
- **What I did about it:** Source data unchanged. Planned: reports state how many rows they leave out.
- **Residual risk:** I do not know what the 999000 customers are.

### F-08: Dates in the future - Severity: Low

- **What it is:** Nothing checks dates. 16 orders and 33 stock sales are dated ahead.
- **How I detected it:** `02_wrong_numbers.sql`, Checks 5 and 6.
- **Scale:** 2 to 269 days ahead. 11 of the orders are "completed" (about 35,506).
- **Effect on the client's number:** Daily and monthly figures can land in months that have not arrived.
- **What I did about it:** Source data unchanged. Planned: monthly figures show these separately.
- **Residual risk:** A completed order cannot be in the future. The rest are unverified.

### F-09: Items with a missing or zero price - Severity: Low

- **What it is:** Nothing checks price. 148 items have none and 152 have zero.
- **How I detected it:** `02_wrong_numbers.sql`, Check 7.
- **Scale:** 298 orders, 269 of which also have a wrong total.
- **Effect on the client's number:** Item totals on these orders are understated, so the recorded total may be the right one.
- **What I did about it:** Source data unchanged. Planned: shown separately wherever item totals are used.
- **Residual risk:** A zero price may be a free item.

## Looked wrong, is not wrong

| Apparent problem | Why it looks wrong | Why it is actually fine |
|---|---|---|
| Dates without a time zone | Usually hides errors | No harm found. Future orders are months ahead, not hours. |
| 7 categories with an empty parent | Looks like a missing link | They are the tops of the tree |
| Phones in 4 formats, city spelled 15 ways | Untidy | No requested report uses either |
| 406 product names used by 841 products | Look like duplicates | Prices differ in 390 of the 406 groups |
| Item price differs from product price (1.2%) | Looks like a pricing error | The ratios are scattered, which fits price changes |
| Negative numbers in the stock log | Look wrong | Outward movements are negative by design |
| Orders with no items, bad quantities, orders before registration | Common faults | Checked, 0 cases each |

## Could not verify

- Which order total, and which stock number, is right.
- Whether overselling came from simultaneous orders.
- How Adwoa's report treats status, and what "complete" and "canceled" mean to the business.
- What the 999000 customers are, and whether the repeated customers are the same people.
- Whether the future-dated records are mistakes, and what currency the money is in.