-- ============================================================
-- POWER BI DATASET QUERIES
-- Retail Loan Portfolio Risk & Collections Analytics
-- ============================================================
 
 
-- ============================================================
-- QUERY 1: MAIN FACT TABLE (for most visuals)
-- Load this as: fact_loan_repayments
-- ============================================================
SELECT
    l.loan_id,
    l.loan_type,
    l.loan_amount,
    l.interest_rate,
    l.tenure_months,
    l.loan_status,
    l.disbursement_date,
    EXTRACT(YEAR FROM l.disbursement_date)  AS vintage_year,
    EXTRACT(MONTH FROM l.disbursement_date) AS disbursement_month,
    c.customer_id,
    c.first_name || ' ' || c.last_name      AS customer_name,
    c.age,
    c.gender,
    c.city                                  AS customer_city,
    c.state                                 AS customer_state,
    c.credit_score,
    CASE
        WHEN c.credit_score < 500 THEN '1. Poor (300-499)'
        WHEN c.credit_score < 650 THEN '2. Fair (500-649)'
        WHEN c.credit_score < 750 THEN '3. Good (650-749)'
        ELSE                           '4. Excellent (750+)'
    END                                     AS credit_band,
    c.employment_type,
    c.monthly_income,
    ROUND((l.loan_amount / NULLIF(c.monthly_income, 0))::numeric, 2) AS lti_ratio,
    CASE
        WHEN (l.loan_amount / NULLIF(c.monthly_income, 0)) > 10 THEN 'High Risk (LTI > 10)'
        WHEN (l.loan_amount / NULLIF(c.monthly_income, 0)) > 7  THEN 'Medium Risk (LTI 7-10)'
        ELSE                                                          'Low Risk (LTI < 7)'
    END                                     AS lti_risk_band,
    b.branch_id,
    b.branch_name,
    b.city                                  AS branch_city,
    b.state                                 AS branch_state,
    b.region,
    r.repayment_id,
    r.due_date,
    r.paid_date,
    r.emi_amount,
    r.paid_amount,
    r.days_past_due,
    r.payment_status,
    CASE
        WHEN r.days_past_due = 0  THEN '1. Current'
        WHEN r.days_past_due <= 30 THEN '2. DPD 1-30'
        WHEN r.days_past_due <= 60 THEN '3. DPD 31-60'
        WHEN r.days_past_due <= 90 THEN '4. DPD 61-90'
        ELSE                            '5. DPD 90+'
    END                                     AS dpd_bucket
FROM loans l
JOIN customers  c ON l.customer_id = c.customer_id
JOIN branches   b ON l.branch_id   = b.branch_id
JOIN repayments r ON l.loan_id     = r.loan_id;
 
 
-- ============================================================
-- QUERY 2: PORTFOLIO SUMMARY KPIs
-- Load this as: kpi_portfolio_summary
-- ============================================================
SELECT
    COUNT(DISTINCT l.loan_id)                        AS total_loans,
    COUNT(DISTINCT l.customer_id)                    AS total_customers,
    SUM(l.loan_amount)                               AS total_portfolio_value,
    ROUND(AVG(l.loan_amount)::numeric, 2)            AS avg_loan_amount,
    ROUND(AVG(l.interest_rate)::numeric, 2)          AS avg_interest_rate,
    ROUND(AVG(l.tenure_months)::numeric, 1)          AS avg_tenure_months,
    COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END)                          AS total_written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END) * 100.0 /
        COUNT(DISTINCT l.loan_id), 2)                AS write_off_rate,
    ROUND(SUM(r.paid_amount)::numeric * 100.0 /
        NULLIF(SUM(r.emi_amount)::numeric, 0), 2)    AS collection_efficiency,
    ROUND(AVG(r.days_past_due)::numeric, 1)          AS avg_days_past_due
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id;
 
 
-- ============================================================
-- QUERY 3: LOAN TYPE ANALYSIS
-- Load this as: dim_loan_type_analysis
-- ============================================================
SELECT
    l.loan_type,
    COUNT(DISTINCT l.loan_id)                        AS total_loans,
    SUM(l.loan_amount)                               AS total_value,
    ROUND(AVG(l.loan_amount)::numeric, 2)            AS avg_loan_amount,
    ROUND(AVG(l.interest_rate)::numeric, 2)          AS avg_interest_rate,
    ROUND(COUNT(DISTINCT l.loan_id) * 100.0 /
        SUM(COUNT(DISTINCT l.loan_id)) OVER(), 2)    AS portfolio_pct,
    COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END)                          AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END) * 100.0 /
        COUNT(DISTINCT l.loan_id), 2)                AS write_off_rate,
    ROUND(SUM(r.paid_amount)::numeric * 100.0 /
        NULLIF(SUM(r.emi_amount)::numeric, 0), 2)    AS collection_efficiency
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id
GROUP BY l.loan_type
ORDER BY total_loans DESC;
 
 
-- ============================================================
-- QUERY 4: GEOGRAPHIC ANALYSIS
-- Load this as: dim_regional_analysis
-- ============================================================
SELECT
    b.region,
    b.state                                          AS branch_state,
    COUNT(DISTINCT l.loan_id)                        AS total_loans,
    SUM(l.loan_amount)                               AS total_value,
    ROUND(AVG(l.loan_amount)::numeric, 2)            AS avg_loan_amount,
    COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END)                          AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END) * 100.0 /
        COUNT(DISTINCT l.loan_id), 2)                AS write_off_rate,
    ROUND(SUM(r.paid_amount)::numeric * 100.0 /
        NULLIF(SUM(r.emi_amount)::numeric, 0), 2)    AS collection_efficiency,
    ROUND(AVG(r.days_past_due)::numeric, 1)          AS avg_dpd
FROM loans l
JOIN branches   b ON l.branch_id = b.branch_id
JOIN repayments r ON l.loan_id   = r.loan_id
GROUP BY b.region, b.state
ORDER BY write_off_rate DESC;
 
 
-- ============================================================
-- QUERY 5: VINTAGE ANALYSIS
-- Load this as: dim_vintage_analysis
-- ============================================================
SELECT
    EXTRACT(YEAR FROM l.disbursement_date)           AS vintage_year,
    COUNT(DISTINCT l.loan_id)                        AS total_loans,
    ROUND(AVG(l.loan_amount)::numeric, 2)            AS avg_loan_amount,
    COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END)                          AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END) * 100.0 /
        COUNT(DISTINCT l.loan_id), 2)                AS write_off_rate,
    ROUND(SUM(r.paid_amount)::numeric * 100.0 /
        NULLIF(SUM(r.emi_amount)::numeric, 0), 2)    AS recovery_rate,
    ROUND(AVG(r.days_past_due)::numeric, 1)          AS avg_dpd,
    COUNT(*) FILTER(WHERE r.payment_status = 'Missed')        AS missed_payments,
    COUNT(*) FILTER(WHERE r.payment_status = 'Paid')          AS paid_payments,
    COUNT(*) FILTER(WHERE r.payment_status = 'Partially Paid') AS partial_payments
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id
GROUP BY vintage_year
ORDER BY vintage_year;
 
 
-- ============================================================
-- QUERY 6: CREDIT RISK SEGMENTATION
-- Load this as: dim_credit_risk
-- ============================================================
SELECT
    CASE
        WHEN c.credit_score < 500 THEN '1. Poor (300-499)'
        WHEN c.credit_score < 650 THEN '2. Fair (500-649)'
        WHEN c.credit_score < 750 THEN '3. Good (650-749)'
        ELSE                           '4. Excellent (750+)'
    END                                              AS credit_band,
    c.employment_type,
    COUNT(DISTINCT l.loan_id)                        AS total_loans,
    ROUND(AVG(c.monthly_income)::numeric, 0)         AS avg_income,
    ROUND(AVG(l.loan_amount)::numeric, 0)            AS avg_loan_amount,
    ROUND((AVG(l.loan_amount) /
        NULLIF(AVG(c.monthly_income), 0))::numeric, 2) AS lti_ratio,
    COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END)                          AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN l.loan_status = 'Written-Off'
        THEN l.loan_id END) * 100.0 /
        COUNT(DISTINCT l.loan_id), 2)                AS write_off_rate
FROM loans l
JOIN customers  c ON l.customer_id = c.customer_id
GROUP BY credit_band, c.employment_type
ORDER BY write_off_rate DESC;
 
 
-- ============================================================
-- QUERY 7: COLLECTIONS FUNNEL
-- Load this as: dim_collections_funnel
-- ============================================================
SELECT
    payment_status,
    COUNT(*)                                         AS total_payments,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER()::numeric, 2)            AS pct,
    SUM(emi_amount)                                  AS total_emi,
    SUM(paid_amount)                                 AS total_paid,
    ROUND(SUM(paid_amount)::numeric * 100.0 /
        NULLIF(SUM(emi_amount)::numeric, 0), 2)      AS recovery_rate
FROM repayments
GROUP BY payment_status
ORDER BY total_payments DESC;
 
 
-- ============================================================
-- QUERY 8: DPD BUCKET ANALYSIS
-- Load this as: dim_dpd_analysis
-- ============================================================
SELECT
    CASE
        WHEN days_past_due = 0   THEN '1. Current (DPD=0)'
        WHEN days_past_due <= 30 THEN '2. Early (DPD 1-30)'
        WHEN days_past_due <= 60 THEN '3. Moderate (DPD 31-60)'
        WHEN days_past_due <= 90 THEN '4. Severe (DPD 61-90)'
        ELSE                          '5. Critical (DPD 90+)'
    END                                              AS dpd_bucket,
    COUNT(*)                                         AS total_records,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER()::numeric, 2)            AS pct,
    ROUND(AVG(paid_amount)::numeric, 2)              AS avg_paid,
    ROUND(AVG(emi_amount)::numeric, 2)               AS avg_emi
FROM repayments
GROUP BY dpd_bucket
ORDER BY dpd_bucket;