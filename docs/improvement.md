# Improvement beyond the brief: One-command Monday report files

## The problem it solves

Adwoa's Monday report took about 40 minutes and sometimes did not finish. Even with the report now fast, someone still has to open the database and type a query to get the figures out, and Adwoa was still keeping the running totals by hand. Nana wanted her to run nothing by hand again.

## What I built

One script, `05_report_pack.sql`, that reads the finished Monday report and writes it out as four ready-to-open spreadsheet files:

| File | What is in it | Rows |
|---|---|---|
| `monday_top_100.csv` | The 100 biggest-spending customers | 100 |
| `monday_customer_summary.csv` | Every customer: total spent, order count, rank | 40,420 |
| `monday_monthly_running_total.csv` | Monthly spend for the last 12 months and the running total, per customer | 485,040 |
| `monday_notes.csv` | What the report leaves out, and when it was written | 1 |

Adwoa runs one command and gets all four files. I ran it on Kloud Kart's own database and it finished in 4.2 seconds, including starting up. The row counts match the report exactly: 40,420 customers, and 485,040 is 40,420 customers times 12 months. The first row of the top 100 is customer 116661 with 258,975.35, as in the checks.

The notes file travels with the other three. It shows the orders the report leaves out: 210 with no customer on file, 15 dated in the future, 19,176 cancelled or refunded, 2,111 counted orders whose total disagrees with their items, and 1,068 customer rows that share an email.

## What it is worth to Adwoa

- The running totals she tracked by hand now come ready-made, for every customer, every Monday.
- The wait goes from about 40 minutes (the figure in the brief) to about 4 seconds.
- The notes file stops anyone trusting the figures blindly.

## What it cost

- It only reads the existing report. It changes no data and adds nothing that slows down sales.
- It is a one-command run, not a schedule. Running it on its own every Monday needs the company's server scheduling, which I have not seen, so I recommend it in the memo and did not build it. Whoever looks after the company's server would set it up, and Adwoa would confirm the day and time she needs the files.
- The files are a snapshot of the moment they were written. They contain customer names and emails, so they should be shared with care.
- The figures carry the same open questions as the report: which order totals are right, and whether pending and shipped orders should count.