# Memo to Nana

**From:** Data Engineering Consultant  
**Date:** 27 November 2026  
**Subject:** Overselling fixed, Monday report now takes seconds

## What I found

Overselling happens when two orders arrive at the same moment and both see the last unit. A bigger machine would not stop that. The Monday report was slow because it looked up each customer one at a time, not because the machine is too small.

The records also have problems: 14 products show stock below zero, 144 have stock that disagrees with their history, 2,398 orders have a total that disagrees with their items, and 210 orders belong to customers who are not on file.

## What I built

| What you asked for | Status | Evidence |
|---|---|---|
| No overselling | Done and tested | 400 buyers competing for 50 units: exactly 50 sold and 350 told "Out of stock", with no errors, in all three test runs. |
| Fast Monday report | Done and tested | The summary covers all 40,420 customers. The 12-month history, including running totals, takes about 1 second to calculate. The top 100 is also available. |
| Low stock through the categories | Done and tested | Works at any depth (4 levels today) and covers all 4,023 products: 591 out of stock and 833 low (fewer than 5). |
| A trail of stock movements | Done for new movements | New sales, restocks and corrections made through the new steps are recorded. However, 262,088 old sale movements have no link to an order. |
| Extra: report files for Adwoa | Done and tested | One command writes four report files. |

## What I recommend

| Action | Who |
|---|---|
| Arrange physical counts for the 14 negative-stock products first, then the 144 whose stock disagrees with history | Nana, with the staff responsible for counting stock |
| Confirm what each order status means and agree which orders should count towards customer spending in the Monday report | Nana and Adwoa |
| Make sure stock is only changed through the three new steps (sell, restock, correct) | Nana, with whoever looks after the website |
| Arrange for the Monday report files to be written automatically each week | Nana, with whoever looks after the company's server |
| Lower the low-stock cut-off from 5 to 2 if the list of 1,424 is too long | Nana to decide; I can make the change |

## What I could not stand behind

- Whether the old overselling really came from simultaneous orders. The records cannot show it. Only you can confirm what happened.
- Which historical order totals and stock figures are correct. Nana and Adwoa need to agree on the reporting rules; the staff responsible for stock counts need to confirm physical stock. I did not overwrite the disputed records.
- Whether pending and shipped orders should count as customer spending. I used both, but Nana and Adwoa should confirm that this matches the business rules.
- Adwoa's real report. I never saw it, so the claim that it takes 40 minutes remains unverified.
- What your website shows a customer who is told "Out of stock", and whether anything else changes stock. Whoever looks after the website needs to confirm this.
- A few checks were run only on a practice copy of an older version of the database, not on the final database version.