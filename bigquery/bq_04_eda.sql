-- ============================================================
-- EDA & Schema Setup — BigQuery Variant
-- Original: EDA.sql (PostgreSQL)
--
-- Key BQ adaptations:
--   • PRIMARY KEY / FOREIGN KEY constraints → not enforced in BQ
--     (declared as UNENFORCED for documentation/Looker compatibility)
--   • CREATE VIEW → syntax identical, just add project/dataset prefix
--   • FILTER (WHERE ...) → COUNTIF(condition)
--   • ::numeric / ::INT casting → CAST(x AS NUMERIC / INT64)
--   • information_schema.table_constraints → BQ INFORMATION_SCHEMA
--   • OVER() window share percentages → identical syntax in BQ
-- ============================================================


-- ============================================================
-- SECTION 1: PRIMARY & FOREIGN KEY DECLARATIONS
-- BigQuery supports UNENFORCED constraints (for documentation
-- and BI tool lineage — Looker, dbt, etc. — they are not enforced
-- at query time but are visible in the schema metadata)
-- ============================================================

ALTER TABLE `your_project.your_dataset.customers`
ADD PRIMARY KEY (customer_id) NOT ENFORCED;

ALTER TABLE `your_project.your_dataset.branches`
ADD PRIMARY KEY (branch_id) NOT ENFORCED;

ALTER TABLE `your_project.your_dataset.loans`
ADD PRIMARY KEY (loan_id) NOT ENFORCED;

ALTER TABLE `your_project.your_dataset.repayments`
ADD PRIMARY KEY (repayment_id) NOT ENFORCED;

-- Foreign keys (UNENFORCED in BigQuery)
ALTER TABLE `your_project.your_dataset.loans`
ADD CONSTRAINT fk_loans_customer
FOREIGN KEY (customer_id) REFERENCES `your_project.your_dataset.customers`(customer_id)
NOT ENFORCED;

ALTER TABLE `your_project.your_dataset.loans`
ADD CONSTRAINT fk_loans_branch
FOREIGN KEY (branch_id) REFERENCES `your_project.your_dataset.branches`(branch_id)
NOT ENFORCED;

ALTER TABLE `your_project.your_dataset.repayments`
ADD CONSTRAINT fk_repayments_loan
FOREIGN KEY (loan_id) REFERENCES `your_project.your_dataset.loans`(loan_id)
NOT ENFORCED;


-- ============================================================
-- SECTION 2: VERIFY CONSTRAINTS VIA INFORMATION_SCHEMA
-- ============================================================

-- BigQuery INFORMATION_SCHEMA equivalent of PostgreSQL constraint queries
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM `your_project.your_dataset`.INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
JOIN `your_project.your_dataset`.INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.table_name;


-- ============================================================
-- SECTION 3: MASTER VIEW
-- ============================================================

-- BigQuery VIEW — syntax is identical to PostgreSQL
-- Replace `public.` schema prefix with `your_project.your_dataset.`
CREATE OR REPLACE VIEW `your_project.your_dataset.loan_master` AS
SELECT
    l.loan_id,
    l.loan_type,
    l.loan_amount,
    l.interest_rate,
    l.tenure_months,
    l.loan_status,
    l.disbursement_date,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.age,
    c.gender,
    c.city            AS customer_city,
    c.state           AS customer_state,
    c.credit_score,
    c.employment_type,
    c.monthly_income,
    b.branch_name,
    b.city            AS branch_city,
    b.region,
    r.repayment_id,
    r.due_date,
    r.paid_date,
    r.emi_amount,
    r.paid_amount,
    r.days_past_due,
    r.payment_status
FROM `your_project.your_dataset.loans` l
JOIN `your_project.your_dataset.customers`  c ON l.customer_id = c.customer_id
JOIN `your_project.your_dataset.branches`   b ON l.branch_id   = b.branch_id
JOIN `your_project.your_dataset.repayments` r ON l.loan_id     = r.loan_id;


-- ============================================================
-- SECTION 4: BASIC EDA ON MASTER VIEW
-- ============================================================

-- Row count
SELECT COUNT(*) AS total_rows FROM `your_project.your_dataset.loan_master`;

-- Quick sample
SELECT * FROM `your_project.your_dataset.loan_master` LIMIT 5;

-- Distinct regions
SELECT DISTINCT region FROM `your_project.your_dataset.loan_master`;

-- Distinct loan types
SELECT DISTINCT loan_type FROM `your_project.your_dataset.loan_master`;


-- ============================================================
-- SECTION 5: PORTFOLIO SUMMARY
-- ============================================================

SELECT
    COUNT(DISTINCT loan_id)                             AS total_loans,
    COUNT(DISTINCT customer_id)                         AS total_customers,
    SUM(loan_amount)                                    AS total_portfolio_value,
    ROUND(AVG(loan_amount), 2)                          AS avg_loan_amount,
    ROUND(AVG(interest_rate), 2)                        AS avg_interest_rate,
    ROUND(AVG(tenure_months), 1)                        AS avg_tenure_months
FROM `your_project.your_dataset.loan_master`;


-- ============================================================
-- SECTION 6: LOAN TYPE BREAKDOWN
-- ============================================================

SELECT
    loan_type,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    SUM(loan_amount)                                    AS total_value,
    ROUND(AVG(loan_amount), 2)                          AS avg_amount,
    ROUND(AVG(interest_rate), 2)                        AS avg_rate,
    ROUND(COUNT(DISTINCT loan_id) * 100.0 /
          SUM(COUNT(DISTINCT loan_id)) OVER(), 2)       AS portfolio_pct
FROM `your_project.your_dataset.loan_master`
GROUP BY loan_type
ORDER BY total_loans DESC;


-- ============================================================
-- SECTION 7: LOAN STATUS BREAKDOWN
-- ============================================================

SELECT
    loan_status,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    ROUND(AVG(loan_amount), 2)                          AS avg_amount,
    ROUND(COUNT(DISTINCT loan_id) * 100.0 /
          SUM(COUNT(DISTINCT loan_id)) OVER(), 2)       AS pct
FROM `your_project.your_dataset.loan_master`
GROUP BY loan_status
ORDER BY total_loans DESC;


-- ============================================================
-- SECTION 8: DELINQUENCY BY LOAN TYPE
-- ============================================================

SELECT
    loan_type,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate
FROM `your_project.your_dataset.loan_master`
GROUP BY loan_type
ORDER BY write_off_rate DESC;


-- ============================================================
-- SECTION 9: DELINQUENCY BY CREDIT BAND
-- ============================================================

SELECT
    CASE
        WHEN credit_score < 500 THEN '1. Poor (300-499)'
        WHEN credit_score < 650 THEN '2. Fair (500-649)'
        WHEN credit_score < 750 THEN '3. Good (650-749)'
        ELSE                         '4. Excellent (750+)'
    END                                                 AS credit_band,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate,
    ROUND(AVG(credit_score), 0)                         AS avg_credit_score
FROM `your_project.your_dataset.loan_master`
GROUP BY credit_band
ORDER BY credit_band;


-- ============================================================
-- SECTION 10: COLLECTION EFFICIENCY BY LOAN TYPE
-- ============================================================

-- PostgreSQL FILTER clause → BigQuery COUNTIF()
SELECT
    loan_type,
    ROUND(SUM(paid_amount) * 100.0 /
          SUM(emi_amount), 2)                           AS collection_efficiency,
    ROUND(AVG(days_past_due), 1)                        AS avg_days_past_due,
    COUNTIF(payment_status = 'Missed')                  AS missed_payments,
    COUNTIF(payment_status = 'Paid')                    AS paid_payments,
    COUNTIF(payment_status = 'Partially Paid')          AS partial_payments
FROM `your_project.your_dataset.loan_master`
GROUP BY loan_type
ORDER BY collection_efficiency DESC;


-- ============================================================
-- SECTION 11: OVERALL PAYMENT HEALTH
-- ============================================================

SELECT
    payment_status,
    COUNT(*)                                            AS count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER(), 2)                      AS pct
FROM `your_project.your_dataset.loan_master`
GROUP BY payment_status
ORDER BY count DESC;


-- ============================================================
-- SECTION 12: GEOGRAPHICAL ANALYSIS
-- ============================================================

SELECT
    region,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    ROUND(SUM(loan_amount), 2)                          AS total_value,
    ROUND(AVG(loan_amount), 2)                          AS avg_loan,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate
FROM `your_project.your_dataset.loan_master`
GROUP BY region
ORDER BY total_loans DESC;


-- ============================================================
-- SECTION 13: VINTAGE (COHORT) ANALYSIS
-- ============================================================

SELECT
    EXTRACT(YEAR FROM disbursement_date)                AS vintage_year,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    ROUND(AVG(loan_amount), 2)                          AS avg_loan,
    COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate
FROM `your_project.your_dataset.loan_master`
GROUP BY vintage_year
ORDER BY vintage_year;

-- Recovery rate by vintage
SELECT
    EXTRACT(YEAR FROM disbursement_date)                AS vintage_year,
    ROUND(SUM(paid_amount) * 100.0 /
          SUM(emi_amount), 2)                           AS recovery_rate,
    ROUND(AVG(days_past_due), 1)                        AS avg_dpd,
    COUNTIF(payment_status = 'Missed')                  AS missed,
    COUNTIF(payment_status = 'Paid')                    AS paid
FROM `your_project.your_dataset.loan_master`
GROUP BY vintage_year
ORDER BY vintage_year;


-- ============================================================
-- SECTION 14: CREDIT × EMPLOYMENT RISK SEGMENTATION
-- ============================================================

SELECT
    CASE
        WHEN credit_score < 500 THEN 'Poor'
        WHEN credit_score < 650 THEN 'Fair'
        WHEN credit_score < 750 THEN 'Good'
        ELSE                         'Excellent'
    END                                                 AS credit_band,
    employment_type,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    ROUND(AVG(monthly_income), 0)                       AS avg_income,
    ROUND(AVG(loan_amount), 0)                          AS avg_loan,
    ROUND(AVG(loan_amount) /
          NULLIF(AVG(monthly_income), 0), 2)            AS loan_to_income_ratio,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate
FROM `your_project.your_dataset.loan_master`
GROUP BY credit_band, employment_type
ORDER BY write_off_rate DESC;


-- ============================================================
-- SECTION 15: LTI RISK BAND SEGMENTATION
-- ============================================================

SELECT
    CASE
        WHEN loan_amount / monthly_income > 10
            THEN 'High Risk (LTI > 10)'
        WHEN loan_amount / monthly_income > 7
            THEN 'Medium Risk (LTI 7-10)'
        ELSE    'Low Risk (LTI < 7)'
    END                                                 AS lti_risk_band,
    COUNT(DISTINCT loan_id)                             AS total_loans,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off' THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                     AS write_off_rate
FROM `your_project.your_dataset.loan_master`
GROUP BY lti_risk_band
ORDER BY write_off_rate DESC;
