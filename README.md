# Kloud Kart Inventory and Order Management

This project fixes two problems for Kloud Kart's operations manager, Nana. The company sold the same last unit twice, and the Monday customer-spending report is slow. It also adds a low-stock view, a stock movement trail, and one improvement beyond the brief. Everything runs on the existing database with no new tools.

## The project in plain words

1. **Looked at the data first.** Found nine problems and ranked them by danger (`docs/data_findings.md`).
2. **Stopped the overselling.** A new "place an order" step makes buyers take turns on a product. Two buyers racing for the last unit: one gets it, the other hears "Out of stock".
3. **Made the Monday report fast.** The report is now worked out for every customer in one pass, in about a second.
4. **Built the low-stock view.** It follows the category tree to any depth.
5. **Built the stock trail.** Every new sale, restock and correction leaves a record.
6. **Added one extra.** One command writes Adwoa's report as four spreadsheet files.
7. **Wrote it up.** Five decision records, a one-page memo to Nana, and the improvement note.

## What is in the folder

| Where | What |
|---|---|
| `docs/data_findings.md` | The data problems, ranked by risk |
| `decisions/` | Five decision records (ADR-001 to ADR-005) |
| `client_memo.md` | One-page memo to Nana |
| `improvement.md` | The improvement beyond the brief |
| `sql/build/` | The code that builds everything: files 01 to 05, `run_all.sql`, `99_checks.sql` |
| `sql/build_outputs/` | Saved results: build summary, checks, three race test runs, before and after, report pack proof |
| `sql/report/` | The before-and-after speed comparison script |
| `sql/report_pack/` | The four report files written by the improvement |
| `sql/diagnosis/` and `sql/diagnosis_outputs/` | The checks behind the data findings, and their results |
| `M03_Resources/` | The files supplied with the brief. **Not changed.** |

## What each build file does

| File | Does |
|---|---|
| `01_place_order.sql` | The order step, the automatic numbering, and the rule against new negative stock |
| `02_low_stock.sql` | The category tree and the low-stock view |
| `03_monday_report.sql` | The Monday report views (summary, top 100, 12 months with running total, notes) |
| `04_stock_trail.sql` | Restock and correction steps, and the stock movement trail and check |
| `05_report_pack.sql` | Writes the four report files (the improvement) |
| `run_all.sql` | Runs files 01 to 04 in order and writes the build summary |
| `99_checks.sql` | 13 checks, one row each, written to `02_checks.md` |

## How to run it

Run each line on its own in PowerShell. The commands assume Windows, Docker Desktop and Python. Docker Desktop must say "Engine running" first.

**Step 1: Start the database (first time only)**

```powershell
cd C:\Users\YaaAntwi\Documents\Kloud_Kart_Inventory_Order
```

```powershell
docker run -d --name kloudkart -e POSTGRES_PASSWORD=kloudkart -p 5432:5432 -v "${PWD}:/lab" postgres:18 -c max_connections=500
```

The 500 connections matter, because the test opens 400 at once. If the container already exists, use `docker start kloudkart` instead, then `docker ps -a` and check the status says "Up".

**Step 2: Load a fresh copy of the data**

```powershell
docker exec -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

```powershell
docker exec -w /lab/M03_Resources -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f schema.sql
```

```powershell
docker exec -w /lab/M03_Resources -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f load.sql
```

Expect six row counts at the end: 94, 4023, 40420, 159384, 336559 and 282352 (in that table order: categories, products, customers, orders, order items, inventory log). The first command deletes everything in the database, so it is also the reset button.

**Step 3: Make the output folders**

```powershell
New-Item -ItemType Directory -Force sql\build_outputs, sql\report, sql\report_pack | Out-Null
```

**Step 4: Build everything**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql
```

Expect only notices (lines saying "skipping"). A line starting with `ERROR` is a problem. This writes `sql\build_outputs\01_build_summary.md`.

**Step 5: Run the 13 checks**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/99_checks.sql
```

This writes `02_checks.md`. Every row with a result should say `t`.

**Step 6: Run the race test three times**

```powershell
pip install psycopg2-binary
```

```powershell
$env:DATABASE_URL="postgresql://postgres:kloudkart@localhost:5432/postgres"
```

```powershell
$env:PYTHONIOENCODING="utf-8"
```

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

```powershell
1..3 | ForEach-Object { $run = $_; $lines = python M03_Resources\race_test.py --verbose 2>&1 | ForEach-Object { "$_" }; Set-Content -Encoding utf8 -Path "sql\build_outputs\03_race_test_run$run.md" -Value (@("# Race test, run $run", "", "Written: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "", '```text') + $lines + '```') }
```

Each of the three files should end with a line starting `PASSED`, and Test 2 should show `50 sold, 350 refused, 0 errored`. The test cleans up after itself. Do not edit `race_test.py`.

**Step 7: Run the before-and-after speed comparison**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/report/01_before_after.sql
```

About 20 seconds. It writes `04_before_after.md` and leaves no data behind.

**Step 8: Write the four report files (the improvement)**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql
```

Expect `COPY 100`, `COPY 40420`, `COPY 485040` and `COPY 1`. The files appear in `sql\report_pack`.

**To try a single order by hand**

```powershell
docker exec -i kloudkart psql -U postgres -c "SELECT * FROM place_order(100001, 5001, 1);"
```

This makes a real sale. Run Step 2 again afterwards to get back to a clean load.

## Decisions, in one line each

| Record | Decision | Main alternative rejected |
|---|---|---|
| ADR-001 | Reserve the product record so buyers take turns, with a 5-second wait limit | A strict database setting that cancels the second buyer with an error |
| ADR-002 | A trigger or a bigger server would not have fixed overselling | Relying on a trigger, or buying hardware |
| ADR-003 | The order, restock and correction steps write the stock history | A trigger that logs every change |
| ADR-004 | The Monday report is built in one pass, with no new index | A bigger server, an index, or a stored copy |
| ADR-005 | Low stock follows the category tree to any depth, with a cut-off of 5 | A fixed number of joins, or a sales-speed cut-off |

## Open decisions and who owns them

| Decision or question | Why it matters | Who decides | What happens next |
|---|---|---|---|
| True stock for the 14 negative products and 144 mismatches | Stock numbers cannot be trusted until counted | Nana's warehouse team | Shelf count, then use the correction step |
| What each order status means; whether pending and shipped count as spend | Changes every spending figure | Nana, with Adwoa | Update the report rules |
| Which order totals are right (2,398 disagree) | Decides whether old totals are rewritten | Nana or finance | Fix old records, with before and after counts |
| Duplicate customers (1,068 records) | Splits rankings and counts | Someone who reviews the pairs | Merge only the confirmed pairs |
| Orphan records, future dates, missing prices | Left out of the report, not deleted | Nana | Recover, correct or delete |
| Correct categories for 43 products | They are missing from category totals | Marketing, with Nana | Reassign, then the loop and gaps close |
| Low-stock cut-off (now 5) | A list of 1,424 may be too long | Nana | One command to change it |
| Wait limit (now 5 seconds) | Too short could turn buyers away | Nana, with whoever looks after the website | One number in three steps |
| Stock changed only through the three steps | Hand-typed changes leave no record | Nana, with whoever looks after the website | Remove direct edit rights, or add a trigger |
| Weekly automatic Monday files | Adwoa still types one command | Whoever looks after the server, with Adwoa | Set up a weekly schedule |
| Which clock the dates use | Month boundaries could shift | Whoever looks after the server | Confirm and document |

## What the project does not do

- A stock number typed in by hand skips the order step and leaves no history row.
- The 14 negative stock counts and the 144 stock-history differences are not corrected. Only a shelf count can settle them.
- The report pack is a one-command run. It is not scheduled.
- I never saw Adwoa's real report, so her 40 minutes is untested. The slow "before" is a rebuild of the likely shape.
- What the website shows a customer, and which clock the dates use, are unverified.
- Some checks (the strict-setting test, the 120-level category chain) ran only on a practice copy of an older database version.

## Note on the evidence files

Two test sales (orders 665625 and 665626) were made after the evidence files were written, while testing the wait limit. They do not change the counts in the checks.