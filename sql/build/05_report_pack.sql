-- IMPROVEMENT BEYOND THE BRIEF: THE MONDAY REPORT PACK
-- Writes Adwoa's whole Monday report as four CSV files. She runs one command and types no SQL.
-- The folder report_pack must exist first.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql
--
-- It only READS the existing views from 03_monday_report.sql. It changes no data and adds no index,
-- so it cannot slow down sales.
-- The files are written next to the project folder because the container shares it (the -v mount).
-- Each \copy must stay on ONE line (a psql rule).
-- The notes file must always travel with the other three: it says what the report leaves out.

\copy (SELECT * FROM monday_top_100 ORDER BY spend_rank, customer_id) TO 'report_pack/monday_top_100.csv' WITH (FORMAT csv, HEADER true)

\copy (SELECT * FROM monday_customer_summary ORDER BY spend_rank, customer_id) TO 'report_pack/monday_customer_summary.csv' WITH (FORMAT csv, HEADER true)

\copy (SELECT * FROM monday_monthly_spend ORDER BY 1, 2) TO 'report_pack/monday_monthly_running_total.csv' WITH (FORMAT csv, HEADER true)

\copy (SELECT now()::timestamp(0) AS report_written_at, n.* FROM monday_report_notes AS n) TO 'report_pack/monday_notes.csv' WITH (FORMAT csv, HEADER true)