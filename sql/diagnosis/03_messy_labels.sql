-- PHASE 3: MESSY LABELS

-- WHAT THIS CHECKS
--   Text that should be consistent but is not. Example: the same order
--   status spelled several different ways, or one customer stored twice.

-- WHY IT HAPPENS
--   Status and phone are free text with no rules. Email is not unique.

-- WHY IT MATTERS
--   A report that filters on one spelling misses the others. Duplicate
--   customers can inflate customer counts and split one person's spend
--   across two rows, which can change who is in the top 100.

-- NOTE
--   Not every odd-looking value is a problem. A check that finds little
--   is still a finding. Two records sharing an email are a strong sign of
--   a duplicate customer, not proof, and need review before merging.

-- CHECKS IN THIS FILE
--   1   Status spellings, as stored
--   2   Status spellings after removing spaces and ignoring capital letters
--   3   Customers sharing an email (spaces and capital letters ignored)
--   4   Phone number formats
--   5   Emails with stray spaces at the start or end

-- READ-ONLY: this file only counts. It changes no data.
-- RUN: docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/diagnosis/03_messy_labels.sql

-- QUERIES

\set QUIET on
\pset null '(null)'


--- 1. Status spellings (how many rows each)
\echo 'PHASE 3, Check 1: Status spellings, as stored (how many rows each)'

-- the brackets make stray spaces visible
SELECT
    status,
    '[' || status || ']' AS status_with_brackets,
    count(*)             AS rows_with_this_spelling
FROM orders
GROUP BY status
ORDER BY lower(status), status;


--- 2. Status after removing spaces and ignoring capital letters
\echo 'PHASE 3, Check 2: Status spellings after removing spaces and ignoring capital letters'

-- "complete" and "completed", "canceled" and "cancelled" stay separate:
-- they are different spellings, not just different capitals
SELECT
    lower(trim(status))    AS normalised_status,
    count(DISTINCT status) AS spellings_merged,
    count(*)               AS orders
FROM orders
GROUP BY lower(trim(status))
ORDER BY orders DESC;


--- 3. Customers sharing an email (spaces and capital letters ignored)
\echo 'PHASE 3, Check 3: Customers sharing an email (spaces and capital letters ignored)'

WITH shared AS (
    SELECT
        lower(trim(email))                     AS normalised_email,
        count(*)                               AS rows_for_this_email,
        count(DISTINCT lower(trim(full_name))) AS different_names
    FROM customers
    -- customers with no email cannot be matched to each other
    WHERE email IS NOT NULL
      AND trim(email) <> ''
    GROUP BY lower(trim(email))
    HAVING count(*) > 1
)
SELECT
    count(*)                                    AS emails_used_more_than_once,
    SUM(rows_for_this_email)                    AS customer_rows_involved,
    SUM(rows_for_this_email - 1)                AS extra_rows_if_one_person_each,
    count(*) FILTER (WHERE different_names = 1) AS groups_where_the_name_also_matches
FROM shared;


--- 4. Phone number formats
\echo 'PHASE 3, Check 4: Phone number formats'

SELECT
    CASE
        WHEN phone IS NULL      THEN 'no phone'
        WHEN phone LIKE '+233%' THEN 'starts with +233'
        WHEN phone LIKE '233%'  THEN 'starts with 233 (no plus)'
        WHEN phone LIKE '0%'    THEN 'starts with 0 (local)'
        ELSE                         'other'
    END        AS phone_format,
    count(*)   AS customers,
    min(phone) AS example
FROM customers
GROUP BY 1
ORDER BY customers DESC;


;--- 5. Emails with leading or trailing spaces
\echo 'PHASE 3, Check 5: Emails with stray spaces at the start or end'

SELECT count(*) AS emails_with_stray_spaces
FROM customers
WHERE email <> trim(email)