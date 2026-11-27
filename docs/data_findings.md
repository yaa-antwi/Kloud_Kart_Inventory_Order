# Data findings — Kloud Kart Ltd.

## Summary

The checks found errors affecting stock, order totals, customer records and business reports. Some could lead to incorrect stock decisions or misleading spending figures. The findings are ranked by risk, based on their scale and likely business impact. Where nobody can say what the right figure is, I did not overwrite the old records. I stopped new damage and made the reports show what they cannot vouch for.

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
| Future-dated orders | 16 on the day of diagnosis; 15 on 27 November 2026 | — | Dates after the day the check was run. One order's date has passed since. |
| Missing/zero item prices | 300 rows | 298 orders | Missing or zero prices |
| Shared customer emails | 533 groups | 535 extra rows | Possible duplicate customers |

## Findings, ranked by risk

### F-01: Negative stock — Severity: High

- **What it is:** 14 products have stock below zero.
- **How I detected it:** Checked stock quantities below zero.
- **Scale:** -27 units in total; worst balance is -4.
- **Effect on the client's number:** Stock availability may be wrong; associated value is approximately 20,628.
- **What I did about it:** Built the order step so two buyers cannot take the same last unit, and added a rule that refuses any new stock change below zero. The race test passed three times on my machine, with exactly 50 of 400 buyers served. The 14 existing records are left unchanged until someone counts them.
- **Residual risk:** The cause of the original overselling is unconfirmed (the data cannot show whether it was two simultaneous orders). The 14 need a physical count. A stock number typed in by hand still skips the order step. Who decides: Nana's warehouse team (shelf count).

### F-02: Completed orders missed by reports — Severity: High

- **What it is:** Completed orders use different spellings of `complete` and `completed`.
- **How I detected it:** Compared exact status filtering with both spellings grouped together.
- **Scale:** 89,260 orders, or 80.2%, are missed by an exact `completed` filter.
- **Effect on the client's number:** The missed orders have recorded value of 273,128,670.
- **What I did about it:** The Monday report ignores capital letters and stray spaces in the status, and I left the original data unchanged.
- **Residual risk:** The business must confirm that both statuses mean the same thing, and what pending and shipped orders should count as. Who decides: Nana, with Adwoa for her report.

### F-03: Order totals do not match items — Severity: High

- **What it is:** Recorded order totals differ from calculated item totals.
- **How I detected it:** Compared recorded totals with quantities multiplied by item prices.
- **Scale:** 2,398 orders; 1,342 lower and 1,056 higher.
- **Effect on the client's number:** Spending reports may be wrong. The net difference across all orders is -3,477,551.62.
- **What I did about it:** New orders now take their total from their items, so new orders cannot disagree. The Monday report uses the recorded total and shows how many counted orders disagree (2,111 today), instead of hiding it.
- **Residual risk:** The cause is unknown and nobody has said which total is right. Who decides: Nana or finance.

### F-04: Stock does not match stock history — Severity: Medium

- **What it is:** Current stock differs from recorded stock movements.
- **How I detected it:** Compared current stock with stock calculated from movement records.
- **Scale:** 144 products; 2,553 absolute units difference.
- **Effect on the client's number:** Stock reporting may be unreliable; associated value is 3,865,699.
- **What I did about it:** New sales, restocks and corrections now each write their own history row. The check identifies 144 products whose current stock differs from their movement history. It also finds 262,088 old sale movements without a linked order, so those movements cannot be fully traced back to individual orders.
- **Residual risk:** The correct stock balance has not been confirmed. The history may itself be incomplete, so a shelf count is the only way to settle it. Who decides: Nana's warehouse team.

### F-05: Possible duplicate customers — Severity: Medium

- **What it is:** Customer records share the same cleaned email and name.
- **How I detected it:** Grouped records by cleaned email and compared names.
- **Scale:** 533 groups involving 1,068 records.
- **Effect on the client's number:** Customer counts and spending rankings may be overstated or split.
- **What I did about it:** The Monday report flags every customer record that shares an email, and does not merge them.
- **Residual risk:** Shared details do not prove that records belong to the same person. Who decides: someone who reviews the pairs of records.

### F-06: Products missing from category reports — Severity: Medium

- **What it is:** Some products cannot be included in category reporting.
- **How I detected it:** Checked missing categories and broken category links.
- **Scale:** 37 uncategorised and 6 unreachable products.
- **Effect on the client's number:** 43 products are excluded from category reporting.
- **What I did about it:** The low-stock report shows these products on their own lines ("Uncategorised" and "Unreachable"), so the top-level lines add up to all 4,023 products.
- **Residual risk:** Correct category assignments need confirmation. Two categories point at each other and one names a parent that does not exist. Who decides: Nana, with marketing.

### F-07: Missing record links — Severity: Low

- **What it is:** Orders and stock records refer to customers, orders or products that cannot be found.
- **How I detected it:** Checked whether referenced records exist.
- **Scale:** 210 orders, 692 items and 120 inventory records affected.
- **Effect on the client's number:** 665,181 in order value and 826,328 in item value are affected.
- **What I did about it:** The Monday report leaves out the 210 orders with no customer and states the number in its notes. The stock history check counts the 120 records. Nothing was deleted.
- **Residual risk:** The missing records need investigation before correction or deletion. Who decides: Nana.

### F-08: Future-dated orders — Severity: Low

- **What it is:** Orders have dates after the investigation date.
- **How I detected it:** Checked for future order dates.
- **Scale:** 16 orders on the day of diagnosis, 15 on 27 November 2026, dated up to August 2027. The count falls as dates pass.
- **Effect on the client's number:** They may distort historical sales reports.
- **What I did about it:** The Monday report leaves future-dated orders out and states the number in its notes.
- **Residual risk:** The dates need confirmation. I have not re-run the money total for the 15, so I left the earlier amount out. Who decides: Nana.

### F-09: Missing and zero prices — Severity: Low

- **What it is:** Some items have missing or zero prices.
- **How I detected it:** Checked item prices for missing and zero values.
- **Scale:** 300 item rows across 298 orders.
- **Effect on the client's number:** Calculated order totals may be wrong; 269 affected orders also have mismatched totals.
- **What I did about it:** Left the old records unchanged. None of the 4,023 products has a missing or zero price, so new orders take a real price.
- **Residual risk:** The reason for missing and zero prices is unknown. A product added later with no price would produce an order with no total; I did not add a check for that. Who decides: Nana.

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

| Open question | Who can answer it |
|---|---|
| The cause of negative stock and stock differences, and whether the overselling came from simultaneous orders | Nana |
| What the true stock count is for the 14 negative products and the 144 mismatches | Nana's warehouse team (shelf count) |
| Whether `complete` and `completed` mean the same thing, and whether pending and shipped should count as spend | Nana, with Adwoa for her report |
| Which order totals are correct | Nana or finance |
| Whether shared customer records belong to the same person | Someone who reviews the pairs of records |
| Whether future dates are mistakes | Nana |
| Whether zero prices are intentional | Nana |
| Whether missing customer, order and product records can be recovered | Nana |
| The correct category for the 43 excluded products | Marketing, with Nana |
| Which clock the dates were recorded in (the dates carry no time zone) | Whoever looks after the company's server |
| What the website shows the customer when a product is out of stock | Whoever looks after the website |
| Whether anything other than the three stock functions changes stock | Whoever looks after the website and other systems |
| Adwoa's real report, so her 40 minutes is untested | Adwoa |