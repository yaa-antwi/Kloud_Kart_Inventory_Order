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

## Project structure

```text
Kloud_Kart_Inventory_Order/
├── README.md
├── M03_Resources/
│   ├── data/                         # Six source CSV files
│   ├── load.sql
│   ├── race_test.py                  # Supplied concurrency test
│   └── schema.sql
├── docs/
│   ├── decisions/                    # ADR-001 through ADR-005
│   ├── client_memo.md
│   ├── data_findings.md
│   └── improvement.md
├── logs/                             # Captured command/test run reports
└── sql/
    ├── build/
    │   ├── 01_place_order.sql
    │   ├── 02_low_stock.sql
    │   ├── 03_monday_report.sql
    │   ├── 04_stock_trail.sql
    │   ├── 05_report_pack.sql
    │   ├── 99_checks.sql             # SQL assertions
    │   └── run_all.sql
    ├── build_outputs/                # Generated build, check and test results
    ├── diagnosis/                    # SQL used to investigate the source data
    ├── diagnosis_outputs/             # Findings from the diagnosis queries
    ├── report/
    │   └── 01_before_after.sql
    └── tests/                        # Historical test reports and duplicate copies
```

For methodology, severity-ranked findings, and caveats, see [`docs/data_findings.md`](docs/data_findings.md).

The canonical test sources are `sql/build/99_checks.sql` and
`M03_Resources/race_test.py`. The files `sql/tests/01_place_order.sql` and
`sql/tests/race_test.py` are exact copies of the build script and supplied test,
respectively; they are not separate tests. The Markdown race-test reports in
`sql/tests/` are earlier run results, while current generated results go in
`sql/build_outputs/` or `logs/`.

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

**Before you start**

1. Install Docker Desktop and Python on your computer.
2. Download the project from GitHub by cloning the repository, or download and extract the repository ZIP file.
3. Open the project folder you downloaded.
4. Open PowerShell inside that folder. To do this in Windows File Explorer, open the project folder, click the address bar, type `powershell`, and press Enter.
5. Make sure Docker Desktop is open and shows that the engine is running.

Run the commands below in PowerShell, one step at a time. You must be inside the project folder when you run them.

**Step 1: Start the database (first time only)**

If you are creating the database container for the first time, run:

```powershell
docker run -d --name kloudkart -e POSTGRES_PASSWORD=kloudkart -p 5432:5432 -v "${PWD}:/lab" postgres:18 -c max_connections=500
```

The 500 connections matter, because the test opens 400 at once.

If the container already exists, use:

```powershell
docker start kloudkart
```

Then run:

```powershell
docker ps -a
```

Check that the status says "Up".

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

Expect six row counts at the end: 94, 4023, 40420, 159384, 336559 and 282352 (in that table order: categories, products, customers, orders, order items, inventory log).

The first command deletes everything in the database, so it is also the reset button.

**Step 3: Make the output folders**

```powershell
New-Item -ItemType Directory -Force sql\build_outputs, sql\report, sql\report_pack | Out-Null
```

**Step 4: Build everything**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql
```

Expect only notices (lines saying "skipping"). A line starting with `ERROR` is a problem.

This writes `sql\build_outputs\01_build_summary.md`.

**Step 5: Run the 13 checks**

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/99_checks.sql
```

This writes `02_checks.md`. Every row with a result should say `t` (true).

**Step 6: Run the race test three times**

Install the Python package needed to connect to the database:

```powershell
pip install psycopg2-binary
```

Set the database connection details:

```powershell
$env:DATABASE_URL="postgresql://postgres:kloudkart@localhost:5432/postgres"
```

This tells Python how to connect to the PostgreSQL database running on your computer. The setting applies to programs started from the current PowerShell session.

Set the text encoding:

```powershell
$env:PYTHONIOENCODING="utf-8"
```

This tells Python to use UTF-8 when reading and writing text through its input and output streams.

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

This tells PowerShell to use UTF-8 when handling text output.

Run the test three times and save each result:

```powershell
1..3 | ForEach-Object { $run = $_; $lines = python M03_Resources\race_test.py --verbose 2>&1 | ForEach-Object { "$_" }; Set-Content -Encoding utf8 -Path "sql\build_outputs\03_race_test_run$run.md" -Value (@("# Race test, run $run", "", "Written: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "", '```text') + $lines + '```') }
```

The test creates competing purchase attempts to check that stock is not oversold.

Each of the three files should end with a line starting `PASSED`, and Test 2 should show `50 sold, 350 refused, 0 errored`.

- `50 sold` means 50 purchase attempts succeeded.
- `350 refused` means 350 attempts were rejected because the available stock was no longer sufficient.
- `0 errored` means no attempts failed with unexpected errors.

The three saved files provide evidence that the test was repeated and that the results were recorded. The test cleans up after itself. Do not edit `race_test.py`.

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

## Automated runs

Run these commands from PowerShell in the project root:

| Script | Command | What it runs | Logs and outputs |
|---|---|---|---|
| `run_build.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_build.ps1` | Runs `sql/build/run_all.sql` against the existing database. It does not reset or reload data, or run tests. | Saves command output to `logs/build_run_<timestamp>.md`; the SQL script also writes `sql/build_outputs/01_build_summary.md`. |
| `run_tests.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1` | Runs the 13 SQL checks and the race-test suite three times. It does not reset or reload data. | Saves detailed results to `logs/test_run_<timestamp>.md`. |
| `run_monday_report.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_monday_report.ps1` | Generates the four Monday report files. | Writes four CSVs to `sql/report_pack/` and records the run in `logs/monday_report_log.md`. |

## To try a single order by hand

```powershell
docker exec -i kloudkart psql -U postgres -c "SELECT * FROM place_order(100001, 5001, 1);"
```

This makes a real sale. Run Step 2 again afterwards to get back to a clean load.

## What the project does not do

- A stock number typed in by hand skips the order step and leaves no history row.
- The 14 negative stock counts and the 144 stock-history differences are not corrected. Only a shelf count can settle them.
- The report pack is a one-command run. It is not scheduled.
- I never saw Adwoa's real report, so her 40 minutes is untested. The slow "before" is a rebuild of the likely shape.
- What the website shows a customer, and which clock the dates use, are unverified.
- Some checks (the strict-setting test, the 120-level category chain) ran only on a practice copy of an older database version.

## Note on the evidence files

Two additional orders (665625 and 665626) were created during testing of the 5-second wait limit. They were created after the saved check results, so they are not included in those earlier results.

The 5-second lock limit and the response to a lock timeout are implemented in `sql/build/01_place_order.sql`, under the `place_order` function. You can review this file to see how the limit is enforced.