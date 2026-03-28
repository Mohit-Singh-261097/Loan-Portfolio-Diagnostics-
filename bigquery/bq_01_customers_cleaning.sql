-- ============================================================
-- Customers Cleaning — BigQuery Variant
-- Original: Customers_cleaning.sql (PostgreSQL)
--
-- Key BQ adaptations:
--   • FILTER (WHERE ...) → COUNTIF(condition)
--   • ::INT / ::numeric casting → CAST(x AS INT64 / NUMERIC)
--   • INITCAP() → not native in BQ → use CONCAT + UPPER + LOWER + SUBSTR
--   • PERCENTILE_CONT ... WITHIN GROUP → PERCENTILE_CONT(col, 0.5) OVER()
--   • UPDATE with FROM subquery → MERGE statement in BQ
--   • BEGIN / COMMIT → not needed in BQ (DML is auto-committed)
--   • PostgreSQL single quotes for empty string checks → same in BQ
-- ============================================================


-- ============================================================
-- SECTION 1: NULL CHECKS
-- ============================================================

-- Null check across all key columns
SELECT
    COUNTIF(customer_id      IS NULL) AS null_customer_id,
    COUNTIF(first_name       IS NULL) AS null_first_name,
    COUNTIF(last_name        IS NULL) AS null_last_name,
    COUNTIF(age              IS NULL) AS null_age,
    COUNTIF(gender           IS NULL) AS null_gender,
    COUNTIF(city             IS NULL) AS null_city,
    COUNTIF(state            IS NULL) AS null_state,
    COUNTIF(credit_score     IS NULL) AS null_credit_score
FROM `your_project.your_dataset.customers`;

-- Empty string check
SELECT
    COUNTIF(customer_id      IN ('', ' ')) AS empty_customer_id,
    COUNTIF(first_name       IN ('', ' ')) AS empty_first_name,
    COUNTIF(last_name        IN ('', ' ')) AS empty_last_name,
    COUNTIF(gender           IN ('', ' ')) AS empty_gender,
    COUNTIF(city             IN ('', ' ')) AS empty_city,
    COUNTIF(state            IN ('', ' ')) AS empty_state,
    COUNTIF(employment_type  IN ('', ' ')) AS empty_employment_type
FROM `your_project.your_dataset.customers`;


-- ============================================================
-- SECTION 2: AGE VALIDATION & FIX
-- ============================================================

-- Consistency check on age distribution
SELECT
    age,
    COUNT(*) AS count
FROM `your_project.your_dataset.customers`
GROUP BY age
ORDER BY age;

-- Range check — identify underage customers (data entry errors)
SELECT
    MIN(age)                    AS youngest,
    MAX(age)                    AS oldest,
    CAST(AVG(age) AS INT64)     AS average_age,
    COUNTIF(age < 18)           AS underage_count
FROM `your_project.your_dataset.customers`;

-- See which underage ages exist
SELECT DISTINCT age
FROM `your_project.your_dataset.customers`
WHERE age < 18
ORDER BY age;

-- Fix: likely digit-transposition typos (14→41, 15→51, 16→61, 17→71)
-- BigQuery DML UPDATE
UPDATE `your_project.your_dataset.customers`
SET age = CASE
    WHEN age = 14 THEN 41
    WHEN age = 15 THEN 51
    WHEN age = 16 THEN 61
    WHEN age = 17 THEN 71
END
WHERE age < 18;

-- Recheck after fix
SELECT
    MIN(age)                    AS youngest,
    MAX(age)                    AS oldest,
    CAST(AVG(age) AS INT64)     AS average_age,
    COUNTIF(age < 18)           AS underage_count
FROM `your_project.your_dataset.customers`;


-- ============================================================
-- SECTION 3: GENDER STANDARDISATION
-- ============================================================

-- Check current distribution
SELECT
    gender,
    COUNT(*) AS count
FROM `your_project.your_dataset.customers`
GROUP BY gender
ORDER BY gender;

-- Standardise all gender values to 'M' / 'F' in one pass
-- BQ does not support multi-step UPDATE chaining like PostgreSQL
-- Consolidate into a single CASE expression
UPDATE `your_project.your_dataset.customers`
SET gender = CASE
    WHEN LOWER(gender) IN ('female', 'f') THEN 'F'
    WHEN LOWER(gender) IN ('male',   'm') THEN 'M'
    ELSE UPPER(gender)                         -- preserve any other values
END
WHERE gender IS NOT NULL;

-- Verify
SELECT
    gender,
    COUNT(*) AS count
FROM `your_project.your_dataset.customers`
GROUP BY gender
ORDER BY gender;


-- ============================================================
-- SECTION 4: STRING CONSISTENCY (INITCAP EQUIVALENT)
-- ============================================================

-- PostgreSQL INITCAP() is not a native BigQuery function.
-- BQ equivalent: INITCAP() is available in BigQuery as of 2022 via
-- INITCAP(string) — supported in Standard SQL on BigQuery.
-- If on an older version, use the manual approach below.

-- Option A: Use INITCAP (available in modern BigQuery)
UPDATE `your_project.your_dataset.customers`
SET
    first_name      = INITCAP(first_name),
    last_name       = INITCAP(last_name),
    city            = INITCAP(city),
    state           = INITCAP(state),
    employment_type = INITCAP(employment_type)
WHERE TRUE;  -- BQ requires a WHERE clause on UPDATE; WHERE TRUE updates all rows

-- Option B: Manual INITCAP if INITCAP() is unavailable
-- CONCAT(UPPER(SUBSTR(first_name, 1, 1)), LOWER(SUBSTR(first_name, 2)))
-- Use Option A unless you hit a "function not found" error.


-- ============================================================
-- SECTION 5: MONTHLY INCOME VALIDATION & IMPUTATION
-- ============================================================

-- Range check for salaried customers
SELECT
    MIN(monthly_income)                         AS lowest,
    MAX(monthly_income)                         AS highest,
    AVG(monthly_income)                         AS average,
    COUNTIF(monthly_income < 0)                 AS negative_count,
    COUNTIF(monthly_income = 0)                 AS zero_count
FROM `your_project.your_dataset.customers`
WHERE employment_type = 'Salaried';

-- Fix negative incomes (data entry sign errors)
UPDATE `your_project.your_dataset.customers`
SET monthly_income = ABS(monthly_income)
WHERE monthly_income < 0;

-- Income bracket analysis
SELECT
    employment_type,
    COUNTIF(monthly_income < 1000)  AS under_1k,
    COUNTIF(monthly_income < 10000) AS under_10k,
    COUNTIF(monthly_income < 18000) AS under_18k
FROM `your_project.your_dataset.customers`
GROUP BY employment_type;

-- Null out definitively invalid values (below ₹1,000)
UPDATE `your_project.your_dataset.customers`
SET monthly_income = NULL
WHERE monthly_income < 1000;

-- Income bracket context for analysis
SELECT
    employment_type,
    CASE
        WHEN monthly_income < 1000  THEN 'Invalid'
        WHEN monthly_income < 18000 THEN 'Low Income'
        WHEN monthly_income < 50000 THEN 'Middle Income'
        ELSE                             'High Income'
    END AS income_bracket,
    COUNT(*) AS customer_count
FROM `your_project.your_dataset.customers`
GROUP BY employment_type, income_bracket
ORDER BY employment_type, income_bracket;

-- NULL count after update
SELECT COUNTIF(monthly_income IS NULL) AS null_income_count
FROM `your_project.your_dataset.customers`;

-- Credit band × income analysis (before imputation)
SELECT
    CASE
        WHEN credit_score < 500 THEN 'Poor (300-499)'
        WHEN credit_score < 650 THEN 'Fair (500-649)'
        WHEN credit_score < 750 THEN 'Good (650-749)'
        ELSE                         'Excellent (750+)'
    END AS credit_band,
    employment_type,
    ROUND(AVG(monthly_income), 0)                                                 AS avg_income,
    PERCENTILE_CONT(monthly_income, 0.5) OVER (PARTITION BY employment_type)      AS median_income,
    COUNT(*) AS customer_count
FROM `your_project.your_dataset.customers`
WHERE monthly_income IS NOT NULL
GROUP BY credit_band, employment_type, monthly_income  -- monthly_income needed for window fn
ORDER BY credit_band, employment_type;

-- NOTE: PERCENTILE_CONT in BigQuery is a window function, not an aggregate.
-- To get a single median per group for imputation, use a subquery:

-- Compute median income per employment_type
CREATE OR REPLACE TEMP TABLE median_income_by_type AS
SELECT
    employment_type,
    PERCENTILE_CONT(monthly_income, 0.5) OVER (PARTITION BY employment_type) AS median_income
FROM `your_project.your_dataset.customers`
WHERE monthly_income IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY employment_type ORDER BY monthly_income) = 1;

-- Impute NULL monthly_income with median per employment_type
MERGE `your_project.your_dataset.customers` AS target
USING median_income_by_type AS source
ON target.employment_type = source.employment_type
   AND target.monthly_income IS NULL
WHEN MATCHED THEN
    UPDATE SET monthly_income = source.median_income;


-- ============================================================
-- SECTION 6: CREDIT SCORE IMPUTATION
-- ============================================================

-- Compute global median credit score (no group in original)
CREATE OR REPLACE TEMP TABLE median_credit AS
SELECT
    PERCENTILE_CONT(credit_score, 0.5) OVER () AS median_credit
FROM `your_project.your_dataset.customers`
WHERE credit_score IS NOT NULL
LIMIT 1;

-- Impute NULL credit scores with global median
MERGE `your_project.your_dataset.customers` AS target
USING median_credit AS source
ON target.credit_score IS NULL
WHEN MATCHED THEN
    UPDATE SET credit_score = source.median_credit;

-- Final verification — should return 0 rows
SELECT *
FROM `your_project.your_dataset.customers`
WHERE credit_score IS NULL OR monthly_income IS NULL;
