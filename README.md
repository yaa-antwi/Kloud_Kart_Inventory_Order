
# Kloud Kart Inventory and Order Management

This project addresses two problems at Kloud Kart:

- The company sold the same last unit to two customers.
- The Monday customer-spending report takes too long to produce.

It also provides a low-stock view, a record of stock movements, and one additional improvement. The solution uses Kloud Kart's existing PostgreSQL database and does not require new software tools.

## The project in plain words

1. **Investigated the data.** Identified nine data problems and ranked them by severity. See `docs/data_findings.md`.
2. **Prevented overselling.** Added a `place_order` function that controls access to stock. When two customers compete for the last unit, one order succeeds and the other is refused with an out-of-stock message.
3. **Improved the Monday report.** Changed the report calculation so customer spending is calculated in one pass. The new report takes about one second in the measured test.
4. **Added a low-stock view.** The view follows the product category structure, including categories nested at different levels.
5. **Added a stock movement trail.** New sales, restocks and corrections can leave records showing how stock changed.
6. **Added a report export.** One command produces four CSV files for Adwoa's Monday report.
7. **Documented the decisions.** Added five decision records, a one-page memo to Nana, and an improvement note.

## Project structure

```text
Kloud_Kart_Inventory_Order/
├── README.md
├── .env.example                         # Local database connection settings
├── .gitignore
├── requirements.txt                     # Pinned Python test dependency
├── run_build.ps1
├── run_tests.ps1
├── run_everything.ps1                   # Destructive fresh-load workflow
├── run_monday_report.ps1
├── M03_Resources/
│   ├── data/                    # Six source CSV files
│   ├── load.sql
│   ├── race_test.py              # Supplied concurrency test
│   └── schema.sql
├── docs/
│   ├── decisions/                # ADR-001 through ADR-005
│   ├── client_memo.md
│   ├── data_findings.md
│   └── improvement.md
├── logs/                         # Captured command and test reports
├── report_pack/                  # Four generated Monday report CSV files
├── tests/
│   └── 99_checks.sql              # SQL validation checks
└── sql/
    ├── build/
    │   ├── 01_place_order.sql
    │   ├── 02_low_stock.sql
    │   ├── 03_monday_report.sql
    │   ├── 04_stock_trail.sql
    │   ├── 05_report_pack.sql
    │   └── run_all.sql
    ├── build_outputs/             # Generated build and check results
    ├── diagnosis/                 # SQL used to investigate source data
    ├── diagnosis_outputs/         # Results from diagnosis queries
    └── report/
        └── 01_before_after.sql
```

For the investigation methods, ranked findings and limitations, see [`docs/data_findings.md`](docs/data_findings.md).

The SQL validation checks are in `tests/99_checks.sql`. The single supplied concurrency test is `M03_Resources/race_test.py`; do not edit it. Automated race-test evidence is written to `logs/`. Generated files under `logs/`, `sql/build_outputs/`, `sql/diagnosis_outputs/` and `report_pack/` are local outputs and are ignored by Git.

## What each build file does

| File | Purpose |
|---|---|
| `01_place_order.sql` | Creates the order-placement function, automatic order numbering and protection against new negative stock. |
| `02_low_stock.sql` | Builds the category hierarchy and low-stock view. |
| `03_monday_report.sql` | Creates the Monday report views: customer summary, top 100 customers, 12-month spending with a running total, and report notes. |
| `04_stock_trail.sql` | Adds restock and correction functions, the stock movement trail and its check. |
| `05_report_pack.sql` | Exports the four report files. |
| `run_all.sql` | Runs build files 01 to 04 in order and writes a build summary. |

## Test files

| File | Purpose |
|---|---|
| `tests/99_checks.sql` | Runs 13 SQL checks and writes `sql/build_outputs/02_checks.md`. |
| `M03_Resources/race_test.py` | Tests order placement when many buyers attempt to purchase stock at the same time. |

## How to run the project

### Before you start

1. Install Docker Desktop and Python.
2. Clone the GitHub repository or download and extract its ZIP file.
3. Open the project folder.
4. Open PowerShell inside that folder. In Windows File Explorer, open the project folder, click the address bar, type `powershell`, and press Enter.
5. Make sure Docker Desktop is running.

Run the commands below from the project root, one step at a time.

### Step 1: Set up the database container

**First-time setup**

If you do not already have a PostgreSQL container named `kloudkart`, create one:

```powershell
docker run -d --name kloudkart -e POSTGRES_PASSWORD=your_local_password -p 5432:5432 -v "${PWD}:/lab" postgres@sha256:a47637053e65dc7112aeb7353feb8b87954982ad5fd4524908c284d90d71b5e3 -c max_connections=500
```

Replace `your_local_password` with the local password you intend to use. Use the same password in your `.env` file.

The image is pinned to the digest used by the local test container. The password and container command are for a disposable local lab only; do not reuse them in a shared or production environment. The container is configured for up to 500 database connections because the concurrency test opens 400 connections.

**If the container already exists**

Start it instead:

```powershell
docker start kloudkart
```

Check its status:

```powershell
docker ps -a
```

The container should show `Up`.

The password used when the container was first created remains its database password. Changing the value in `.env` does not change the password inside an existing container.

### Step 2: Create the `.env` file

Create a file named `.env` in the project root, alongside `README.md`.

Add these two settings:

```dotenv
DATABASE_URL=postgresql://postgres:your_local_password@localhost:5432/postgres
POSTGRES_PASSWORD=your_local_password
```

Replace `your_local_password` with the password used when the database container was created.

- `DATABASE_URL` tells the Python concurrency test how to connect to PostgreSQL.
- `POSTGRES_PASSWORD` records the password used for the initial container setup.
- A `DATABASE_URL` set in the PowerShell process takes precedence over the `.env` value.

Keep `.env` out of Git. The `.gitignore` file should contain:

```gitignore
# Local credentials
.env

# Generated outputs
logs/
sql/build_outputs/
sql/diagnosis_outputs/
report_pack/

# Python
__pycache__/
*.pyc
```


### Step 3: Load a fresh copy of the data

The following commands reset the database schema and reload the supplied data.

**Warning:** The first command deletes everything currently stored in the `public` schema. Use it only when you intend to reset the project database.

```powershell
docker exec -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

Load the schema:

```powershell
docker exec -w /lab/M03_Resources -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f schema.sql
```

Load the CSV data:

```powershell
docker exec -w /lab/M03_Resources -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f load.sql
```

Expect these six row counts, in this order:

| Table | Expected rows |
|---|---:|
| Categories | 94 |
| Products | 4,023 |
| Customers | 40,420 |
| Orders | 159,384 |
| Order items | 336,559 |
| Inventory log | 282,352 |

### Step 4: Create the output folders

```powershell
New-Item -ItemType Directory -Force sql\build_outputs, sql\diagnosis_outputs, sql\report, report_pack, logs | Out-Null
```

### Step 5: Build the SQL solution

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql
```

The build should complete without errors. Notices about existing objects being skipped are expected where the scripts use that behaviour.

The build writes:

`sql/build_outputs/01_build_summary.md`

### Step 6: Run the SQL checks

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f tests/99_checks.sql
```

This runs the 13 SQL validation checks and writes:

`sql/build_outputs/02_checks.md`

Every check that reports a true/false result should show `t` for true. Checks 4 and 5 are informational and do not gate the test run. Check 13 verifies the exact function signatures, the existing `NOT VALID` stock constraint, and that negative inserts and direct stock updates are rejected.

### Step 7: Run the concurrency test

Install the pinned Python package required to connect to PostgreSQL:

```powershell
pip install -r requirements.txt
```

Set `DATABASE_URL` in the process environment or in `.env`; the test scripts preserve a process-level value when one is already set.

To run the SQL checks and concurrency test three times, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

The script saves a detailed test report in `logs/`.

The concurrency test checks whether the database can safely handle competing purchase attempts.

For the 400-buyer test, the expected result is:

- **50 sold:** 50 orders succeed because only 50 units are available.
- **350 refused:** The remaining attempts are rejected because stock is no longer available.
- **0 errored:** No unexpected errors occur.
- **Within 10 seconds:** The test completes within the required time limit.

The test also checks repeated attempts to buy the last unit, insufficient-stock requests and stock movement records.

The supplied test removes its fixtures before and after each run. The automation treats a reported cleanup failure as a failed run. Do not edit `M03_Resources/race_test.py`.

### Step 8: Run the before-and-after speed comparison

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/report/01_before_after.sql
```

This comparison takes about 20 seconds in the measured run. It writes:

`sql/build_outputs/04_before_after.md`

It is designed to leave no test data behind.

### Step 9: Generate the four report files

```powershell
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql
```

The expected output includes:

```text
COPY 100
COPY 40420
COPY 485040
COPY 1
```

The four CSV files are written to `report_pack/`.

## Automated scripts

Run these commands from PowerShell in the project root.

| Script | Command | What it does | Output |
|---|---|---|---|
| `run_build.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_build.ps1` | Runs the SQL build against the existing database. It does not reset or reload data or run tests. | Saves a command report in `logs/` and a build summary in `sql/build_outputs/`. |
| `run_tests.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1` | Runs the 13 SQL checks and the concurrency test three times. It does not reset or reload data. | Saves detailed results in `logs/`. |
| `run_monday_report.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_monday_report.ps1` | Generates the four Monday report CSV files. | Writes the CSV files to `report_pack/` and records the run in `logs/monday_report_log.md`. |
| `run_everything.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\run_everything.ps1` | Drops and reloads the `public` schema, builds the project, checks it, runs the race test three times, and generates reports. **Destructive: use only with a disposable project database.** | Writes run details to `logs/` and build outputs to `sql/build_outputs/`. |

The automated scripts use the existing database. If you need a clean starting point, follow Step 3 to reload the data before running them.

## Trying a single order manually

The following command places a real order:

```powershell
docker exec -i kloudkart psql -U postgres -c "SELECT * FROM place_order(100001, 5001, 1);"
```

It uses customer `100001`, product `5001` and a quantity of one.

This changes the database. To return to the original supplied data, follow Step 3 and reload the database.

## Notes on the test evidence

Older saved build/check reports may predate two orders (`665625` and `665626`) created while testing the five-second lock-wait limit. Treat those archived outputs as historical, not as a snapshot of the current database. For fresh evidence from the supplied data, use `run_everything.ps1` only with a disposable database; it resets the schema and reloads all source files.

The five-second lock-wait limit and the response to a lock timeout are implemented in the `place_order` function in:

`sql/build/01_place_order.sql`

Review that file to see how the limit is enforced.
