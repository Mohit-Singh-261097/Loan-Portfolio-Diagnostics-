-- ============================================================
-- Repayments Cleaning — BigQuery Variant
-- Original: repayments_cleaning.sql (PostgreSQL)
--
-- Key BQ adaptations:
--   • FILTER (WHERE ...) → COUNTIF(condition)
--   • ALTER COLUMN TYPE → Recreate table with CAST (BQ does not support ALTER TYPE)
--   • UPDATE paid_date using (due_date + days_past_due)::date
--     → DATE_ADD(due_date, INTERVAL days_past_due DAY)
--   • BEGIN / COMMIT → not needed (BQ DML auto-commits)
--   • Python triple-quote comments (''') → standard SQL comments (--)
-- ============================================================


-- ============================================================
-- SECTION 1: NULL CHECKS
-- ============================================================

SELECT
    COUNTIF(repayment_id   IS NULL) AS null_repayment_id,
    COUNTIF(loan_id        IS NULL) AS null_loan_id,
    COUNTIF(due_date       IS NULL) AS null_due_date,
    COUNTIF(paid_date      IS NULL) AS null_paid_date,
    COUNTIF(emi_amount     IS NULL) AS null_emi_amount,
    COUNTIF(paid_amount    IS NULL) AS null_paid_amount,
    COUNTIF(days_past_due  IS NULL) AS null_days_past_due,
    COUNTIF(payment_status IS NULL) AS null_payment_status
FROM `your_project.your_dataset.repayments`;


-- ============================================================
-- SECTION 2: EMPTY STRING CHECKS
-- ============================================================

SELECT
    COUNTIF(repayment_id   IN ('', ' ')) AS empty_repayment_id,
    COUNTIF(loan_id        IN ('', ' ')) AS empty_loan_id,
    COUNTIF(due_date       IN ('', ' ')) AS empty_due_date,
    COUNTIF(paid_date      IN ('', ' ')) AS empty_paid_date,
    COUNTIF(payment_status IN ('', ' ')) AS empty_payment_status
FROM `your_project.your_dataset.repayments`;

-- Replace empty strings in paid_date with NULL
UPDATE `your_project.your_dataset.repayments`
SET paid_date = NULL
WHERE paid_date IN ('', ' ');


-- ============================================================
-- SECTION 3: CONVERT DATE COLUMNS TO DATE TYPE
-- ============================================================

-- Check current data types
SELECT
    column_name,
    data_type
FROM `your_project.your_dataset`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'repayments'
  AND column_name IN ('due_date', 'paid_date');

-- BigQuery does NOT support ALTER COLUMN TYPE.
-- Recreate the table with correct DATE casting.
-- paid_date may be NULL — use SAFE.CAST to avoid errors on NULLs.

CREATE OR REPLACE TABLE `your_project.your_dataset.repayments` AS
SELECT
    repayment_id,
    loan_id,
    CAST(due_date AS DATE)          AS due_date,
    SAFE_CAST(paid_date AS DATE)    AS paid_date,  -- SAFE_CAST returns NULL on failure
    emi_amount,
    paid_amount,
    days_past_due,
    payment_status
FROM `your_project.your_dataset.repayments`;


-- ============================================================
-- SECTION 4: DPD vs PAYMENT STATUS CROSS-CHECK
-- ============================================================

SELECT
    payment_status,
    CASE
        WHEN days_past_due = 0   THEN 'Zero'
        WHEN days_past_due > 0   THEN 'Positive'
        WHEN days_past_due < 0   THEN 'Negative'
        WHEN days_past_due IS NULL THEN 'NULL'
    END AS days_category,
    COUNT(*) AS count
FROM `your_project.your_dataset.repayments`
GROUP BY payment_status, days_category
ORDER BY payment_status, days_category;


-- ============================================================
-- SECTION 5: IMPUTE NULL paid_date VALUES
-- ============================================================

-- Paid on time (DPD = 0) → paid_date = due_date
UPDATE `your_project.your_dataset.repayments`
SET paid_date = due_date
WHERE paid_date IS NULL
  AND payment_status = 'Paid'
  AND days_past_due = 0;

-- Paid late → paid_date = due_date + days_past_due
-- PostgreSQL: (due_date + days_past_due)::date
-- BigQuery:   DATE_ADD(due_date, INTERVAL days_past_due DAY)
UPDATE `your_project.your_dataset.repayments`
SET paid_date = DATE_ADD(due_date, INTERVAL days_past_due DAY)
WHERE paid_date IS NULL
  AND payment_status = 'Paid'
  AND days_past_due > 0;

-- Partially paid → same logic as late payment
UPDATE `your_project.your_dataset.repayments`
SET paid_date = DATE_ADD(due_date, INTERVAL days_past_due DAY)
WHERE paid_date IS NULL
  AND payment_status = 'Partially Paid';

-- Verify: remaining NULLs per payment_status (Missed is expected to still have NULLs)
SELECT
    payment_status,
    COUNTIF(paid_date IS NULL) AS null_paid_date
FROM `your_project.your_dataset.repayments`
GROUP BY payment_status;


-- ============================================================
-- SECTION 6: EMI & PAID AMOUNT VALIDATION
-- ============================================================

SELECT
    MIN(emi_amount)              AS min_emi,
    MAX(emi_amount)              AS max_emi,
    AVG(emi_amount)              AS avg_emi,
    COUNTIF(emi_amount  <= 0)    AS zero_or_negative_emi,
    MIN(paid_amount)             AS min_paid,
    MAX(paid_amount)             AS max_paid,
    COUNTIF(paid_amount  < 0)    AS negative_paid
FROM `your_project.your_dataset.repayments`;

-- Zero paid_amount breakdown by payment_status
SELECT
    payment_status,
    COUNT(*) AS count
FROM `your_project.your_dataset.repayments`
WHERE paid_amount = 0
GROUP BY payment_status;

-- Investigate: Missed payments that somehow have paid_amount > 0
-- (580 records in original analysis — data inconsistency flag)
SELECT
    payment_status,
    paid_amount,
    emi_amount,
    days_past_due
FROM `your_project.your_dataset.repayments`
WHERE payment_status = 'Missed'
  AND paid_amount > 0
LIMIT 20;

-- Quantify the inconsistency: paid MORE than EMI but still marked Missed
-- Flag only — do not update payment_status without business confirmation
SELECT
    COUNT(*)                            AS flagged_records,
    AVG(paid_amount - emi_amount)       AS avg_overpayment
FROM `your_project.your_dataset.repayments`
WHERE payment_status = 'Missed'
  AND paid_amount > 0;
