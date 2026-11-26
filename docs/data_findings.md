
# Data findings — Kloud Kart Ltd.

## Summary

The checks found errors affecting stock, order totals, customer records and business reports. Some could lead to incorrect stock decisions or misleading spending figures. The findings are ranked by risk, based on their scale and likely business impact.

## Reconciliation

| Stage | Rows | Delta | Reason |
|---|---|---|---|
| Orders missing customers | 210 | 665,181 | Missing customer records |
| Items missing orders | 692 | 826,328 | Missing order records |
| Inventory records missing products | 120 | — | Missing product records |
| Products missing from category report | 43 | — | Missing or unreachable categories |
| Order total mismatches | 2,398 | -3,477,551.62 net | Order totals differ from item totals |
| Negative stock | 14 products | -27 units | Stock below zero |
| Stock/history differences | 144 products | 2,553 absolute units | Stock does not match recorded movements |
| Future-dated orders | 16 | — | Dates after investigation date |
| Missing/zero item prices | 300 rows | 298 orders | Missing or zero prices |
| Shared customer emails | 533 groups | 535 extra rows | Possible duplicate customers |

## Findings, ranked by risk

### F-01: Negative stock — Severity: High

- **What it is:** 14 products have stock below zero.
- **How I detected it:** Checked stock quantities below zero.
- **Scale:** -27 units in total; worst balance is -4.
- **Effect on the client's number:** Stock availability may be wrong; associated value is approximately 20,628.
- **What I did about it:** Identified and quantified affected products.
- **Residual risk:** The cause is unknown and stock needs investigation before correction.

### F-02: Completed orders missed by reports — Severity: High

- **What it is:** Completed orders use different spellings of `complete` and `completed`.
- **How I detected it:** Compared exact status filtering with both spellings grouped together.
- **Scale:** 89,260 orders, or 80.2%, are missed by an exact `completed` filter.
- **Effect on the client's number:** The missed orders have recorded value of 273,128,670.
- **What I did about it:** Compared the counts without changing the original data.
- **Residual risk:** The business must confirm that both statuses mean the same thing.

### F-03: Order totals do not match items — Severity: High

- **What it is:** Recorded order totals differ from calculated item totals.
- **How I detected it:** Compared recorded totals with quantities multiplied by item prices.
- **Scale:** 2,398 orders; 1,342 lower and 1,056 higher.
- **Effect on the client's number:** Spending reports may be wrong. The net difference across all orders is -3,477,551.62.
- **What I did about it:** Measured the differences without assuming either figure was correct.
- **Residual risk:** The cause is unknown. The spending comparison also has a calculation discrepancy that needs checking.

### F-04: Stock does not match stock history — Severity: Medium

- **What it is:** Current stock differs from recorded stock movements.
- **How I detected it:** Compared current stock with stock calculated from movement records.
- **Scale:** 144 products; 2,553 absolute units difference.
- **Effect on the client's number:** Stock reporting may be unreliable; associated value is 3,865,699.
- **What I did about it:** Identified and measured the differences.
- **Residual risk:** The correct stock balance has not been confirmed.

### F-05: Possible duplicate customers — Severity: Medium

- **What it is:** Customer records share the same cleaned email and name.
- **How I detected it:** Grouped records by cleaned email and compared names.
- **Scale:** 533 groups involving 1,068 records.
- **Effect on the client's number:** Customer counts and spending rankings may be overstated or split.
- **What I did about it:** Compared individual and grouped customer rankings.
- **Residual risk:** Shared details do not prove that records belong to the same person.

### F-06: Products missing from category reports — Severity: Medium

- **What it is:** Some products cannot be included in category reporting.
- **How I detected it:** Checked missing categories and broken category links.
- **Scale:** 37 uncategorised and 6 unreachable products.
- **Effect on the client's number:** 43 products are excluded from category reporting.
- **What I did about it:** Identified the affected products and two category loops.
- **Residual risk:** Correct category assignments need confirmation.

### F-07: Missing record links — Severity: Low

- **What it is:** Orders and stock records refer to customers, orders or products that cannot be found.
- **How I detected it:** Checked whether referenced records exist.
- **Scale:** 210 orders, 692 items and 120 inventory records affected.
- **Effect on the client's number:** 665,181 in order value and 826,328 in item value are affected.
- **What I did about it:** Counted the missing links and their associated values.
- **Residual risk:** The missing records need investigation before correction or deletion.

### F-08: Future-dated orders — Severity: Low

- **What it is:** Orders have dates after the investigation date.
- **How I detected it:** Checked for future order dates.
- **Scale:** 16 orders, dated up to August 2027.
- **Effect on the client's number:** They may distort historical sales reports.
- **What I did about it:** Identified the orders and their statuses.
- **Residual risk:** The dates need confirmation.

### F-09: Missing and zero prices — Severity: Low

- **What it is:** Some items have missing or zero prices.
- **How I detected it:** Checked item prices for missing and zero values.
- **Scale:** 300 item rows across 298 orders.
- **Effect on the client's number:** Calculated order totals may be wrong; 269 affected orders also have mismatched totals.
- **What I did about it:** Identified and compared the affected orders.
- **Residual risk:** The reason for missing and zero prices is unknown.

## Looked wrong, is not wrong

| Apparent problem | Why it looks wrong | Why it is actually fine |
|---|---|---|
| Different phone formats | Numbers use different formats. | Different formats do not prove invalid numbers. |
| Repeated product names | 406 names appear repeatedly. | 390 groups have different prices, so they are not confirmed duplicates. |
| Negative stock movements | Some records reduce stock. | Sales, damage and corrections can reduce stock. |
| Orders without items | Orders may appear incomplete. | None were found. |
| Incorrect quantities | Quantities may affect totals. | No bad quantities were detected. |
| Orders before registration | Dates may appear inconsistent. | None were found. |
| Different historical prices | Prices differ from current prices. | Prices can change over time. |

## Could not verify

- The cause of negative stock and stock differences.
- Whether `complete` and `completed` mean the same thing.
- Which order totals are correct.
- Whether shared customer records belong to the same person.
- Whether future dates are mistakes.
- Whether zero prices are intentional.
- Whether missing records can be recovered.
- The correct category for excluded products.
- The spending comparison calculation discrepancy.
