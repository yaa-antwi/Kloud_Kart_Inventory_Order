# Memo to Nana

**From:** Data Engineering Consultant
**Date:** 27 November 2026
**Subject:** Overselling fixed, Monday report now takes seconds

## What I found

Overselling happens when two orders arrive at the same moment and both see the last unit. A bigger machine would not stop that. The Monday report was slow because it looked up each customer one at a time, not because the machine is too small. The records also have problems: 14 products show stock below zero, 144 have stock that disagrees with their history, 2,398 orders have a total that disagrees with their items, and 210 orders belong to customers who are not on file.

## What I built

| What you asked for | Status | Evidence |
|---|---|---|
| No overselling | Done and tested | 400 buyers at once for 50 units: exactly 50 sold and 350 told "Out of stock", with no errors, three times out of three. |
| Fast Monday report | Done and tested | All 40,420 customers, with totals, 12 months, running totals and top 100, in about 1 second. |
| Low stock through the categories | Done and tested | Works at any depth (4 levels today) and adds up to all 4,023 products: 591 out of stock, 833 low (fewer than 5). |
| A trail of stock movements | Done for new movements | Every new sale, restock and correction is recorded and linked to its order. 262,088 old sales have no such link. |
| Extra: report files for Adwoa | Done and tested | One command writes four spreadsheet files in about 4 seconds. |

## What I recommend

| Action | Who |
|---|---|
| Count the shelves for the 14 negative products first, then the 144 whose stock disagrees with history | Nana's warehouse team |
| Tell me what each order status means and which totals are right, so old records can be fixed safely | Nana or finance |
| Make sure stock is only changed through the three new steps (sell, restock, correct) | Nana, with whoever looks after the website |
| Have the Monday files written automatically each week | Whoever looks after the company's server |
| Lower the low-stock cut-off from 5 to 2 if the list of 1,424 is too long (one command) | Nana, to decide; I can do it |

## What I could not stand behind

- Whether the old overselling really came from simultaneous orders. The records cannot show it. Only you can say.
- Which order totals and stock figures are right (you or finance for totals, your warehouse team for stock). I did not overwrite any of them.
- Whether pending and shipped orders should count as spend (you and Adwoa). I counted them.
- Adwoa's real report (Adwoa). I never saw it, so her 40 minutes is untested.
- What your website shows a customer who is told "Out of stock", and whether anything else changes stock (whoever looks after the website).
- A few checks were run only on a practice copy, on an older version of the system.