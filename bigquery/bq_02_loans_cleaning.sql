-- ============================================================
-- Loans Cleaning — BigQuery Variant
-- Original: Loans_cleaning.sql (PostgreSQL)
--
-- Key BQ adaptations:
--   • FILTER (WHERE ...) → COUNTIF(condition)
--   • ctid (PostgreSQL internal row ID) → _row_number via ROW_NUMBER()
--   • DELETE with CTE → MERGE or DELETE with subquery
--   • ALTER COLUMN TYPE → BigQuery does not support ALTER COLUMN TYPE;
--     recreate the table with correct type instead
--   • Regex ~ operator → REGEXP_CONTAINS()
--   • BEGIN / COMMIT → not needed (BQ DML auto-commits)
-- ============================================================


-- ============================================================
-- SECTION 1: DUPLICATE DETECTION
-- ============================================================

-- Find duplicate loan_ids
SELECT
    loan_id,
    COUNT(*) AS occurrences
FROM `your_project.your_dataset.loans`
GROUP BY loan_id
HAVING COUNT(*) > 1
ORDER BY loan_id;

-- Check if duplicates are truly identical rows or partial duplicates
SELECT
    loan_id,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM `your_project.your_dataset.loans`
GROUP BY loan_id
HAVING COUNT(*) > 1
ORDER BY unique_customers DESC;

-- ============================================================
-- SECTION 2: REMOVE EXACT DUPLICATES
-- ============================================================

-- BigQuery does not have ctid. Use ROW_NUMBER() to tag duplicates,
-- then overwrite the table keeping only row_num = 1 per loan_id.

CREATE OR REPLACE TABLE `your_project.your_dataset.loans` AS
SELECT * EXCEPT(row_num)
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY loan_id) AS row_num
    FROM `your_project.your_dataset.loans`
)
WHERE row_num = 1;


-- ============================================================
-- SECTION 3: COLUMN TYPE INSPECTION
-- ============================================================

-- Check data type of disbursement_date
-- BigQuery equivalent of information_schema.columns
SELECT
    column_name,
    data_type
FROM `your_project.your_dataset`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'loans'
  AND column_name = 'disbursement_date';

-- Detect date format (if stored as STRING)
-- PostgreSQL used ~ regex operator → BigQuery uses REGEXP_CONTAINS()
SELECT DISTINCT
    disbursement_date,
    CASE
        WHEN REGEXP_CONTAINS(disbursement_date, r'^\d{4}-\d{2}-\d{2}$') THEN 'YYYY-MM-DD'
        WHEN REGEXP_CONTAINS(disbursement_date, r'^\d{2}-\d{2}-\d{4}$') THEN 'DD-MM-YYYY'
        ELSE 'UNKNOWN'
    END AS detected_format
FROM `your_project.your_dataset.loans`
ORDER BY detected_format;


-- ============================================================
-- SECTION 4: CONVERT disbursement_date TO DATE TYPE
-- ============================================================

-- BigQuery does NOT support ALTER COLUMN TYPE.
-- Instead, recreate the table with the correct type using CAST.

CREATE OR REPLACE TABLE `your_project.your_dataset.loans` AS
SELECT
    loan_id,
    customer_id,
    branch_id,
    loan_type,
    loan_amount,
    interest_rate,
    tenure_months,
    CAST(disbursement_date AS DATE) AS disbursement_date,  -- string → DATE
    loan_status
FROM `your_project.your_dataset.loans`;

-- Quick sanity check
SELECT * FROM `your_project.your_dataset.loans` LIMIT 5;


-- ============================================================
-- SECTION 5: LOAN AMOUNT DISTRIBUTION
-- ============================================================

-- Distribution stats including quartiles
-- PERCENTILE_CONT in BQ is a window function — use OVER()
SELECT
    MIN(loan_amount)  AS minimum,
    MAX(loan_amount)  AS maximum,
    AVG(loan_amount)  AS average,
    COUNTIF(loan_amount < 25000) AS below_25k_count
FROM `your_project.your_dataset.loans`;

-- Quartiles via window function (BigQuery approach)
SELECT DISTINCT
    PERCENTILE_CONT(loan_amount, 0.25) OVER () AS q1,
    PERCENTILE_CONT(loan_amount, 0.50) OVER () AS median,
    PERCENTILE_CONT(loan_amount, 0.75) OVER () AS q3
FROM `your_project.your_dataset.loans`
LIMIT 1;


-- ============================================================
-- SECTION 6: NULL CHECK ACROSS ALL COLUMNS
-- ============================================================

SELECT
    COUNTIF(loan_id           IS NULL) AS loan_id_nulls,
    COUNTIF(customer_id       IS NULL) AS customer_id_nulls,
    COUNTIF(branch_id         IS NULL) AS branch_id_nulls,
    COUNTIF(loan_type         IS NULL) AS loan_type_nulls,
    COUNTIF(loan_amount       IS NULL) AS loan_amount_nulls,
    COUNTIF(tenure_months     IS NULL) AS tenure_nulls,
    COUNTIF(interest_rate     IS NULL) AS interest_rate_nulls,
    COUNTIF(disbursement_date IS NULL) AS disbursement_nulls,
    COUNTIF(loan_status       IS NULL) AS loan_status_nulls
FROM `your_project.your_dataset.loans`;
