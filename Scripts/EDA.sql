-- PRIMARY KEY
ALTER TABLE customers
ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);

ALTER TABLE branches
ADD CONSTRAINT pk_branches PRIMARY KEY (branch_id);

ALTER TABLE loans
ADD CONSTRAINT pk_loans PRIMARY KEY (loan_id);

ALTER TABLE repayments
ADD CONSTRAINT pk_repayments PRIMARY KEY (repayment_id);

-- loans references customers and branches
ALTER TABLE loans
ADD CONSTRAINT fk_loans_customer
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE loans
ADD CONSTRAINT fk_loans_branch
FOREIGN KEY (branch_id) REFERENCES branches(branch_id);

-- repayments references loans
ALTER TABLE repayments
ADD CONSTRAINT fk_repayments_loan
FOREIGN KEY (loan_id) REFERENCES loans(loan_id);



--verifying all constraints
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name  AS referenced_table,
    ccu.column_name AS referenced_column,
    tc.constraint_type
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.table_name;


--creating a master view
CREATE VIEW loan_master AS
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
FROM loans l
JOIN customers c  ON l.customer_id = c.customer_id
JOIN branches b   ON l.branch_id   = b.branch_id
JOIN repayments r ON l.loan_id     = r.loan_id;


-- Row count
SELECT COUNT(*) FROM loan_master;

-- Quick sample
SELECT * FROM loan_master LIMIT 5;

-- Check all regions
SELECT DISTINCT region FROM loan_master;

-- Check all loan types
SELECT DISTINCT loan_type FROM loan_master;

--portfolio summary
SELECT
    COUNT(DISTINCT loan_id)              AS total_loans,
    COUNT(DISTINCT customer_id)          AS total_customers,
    SUM(loan_amount)                     AS total_portfolio_value,
    ROUND(AVG(loan_amount)::numeric, 2)  AS avg_loan_amount,
    ROUND(AVG(interest_rate)::numeric, 2) AS avg_interest_rate,
    ROUND(AVG(tenure_months)::numeric, 1) AS avg_tenure_months
FROM loan_master;

--loan type breakdown
SELECT
    loan_type,
    COUNT(DISTINCT loan_id)               AS total_loans,
    SUM(loan_amount)                      AS total_value,
    ROUND(AVG(loan_amount)::numeric, 2)   AS avg_amount,
    ROUND(AVG(interest_rate)::numeric, 2) AS avg_rate,
    ROUND(COUNT(DISTINCT loan_id) * 100.0 / 
          SUM(COUNT(DISTINCT loan_id)) OVER(), 2) AS portfolio_pct
FROM loan_master
GROUP BY loan_type
ORDER BY total_loans DESC;

--loan status breakdown
SELECT
    loan_status,
    COUNT(DISTINCT loan_id)                AS total_loans,
    ROUND(AVG(loan_amount)::numeric, 2)    AS avg_amount,
    ROUND(COUNT(DISTINCT loan_id) * 100.0 /
          SUM(COUNT(DISTINCT loan_id)) OVER(), 2) AS pct
FROM loan_master
GROUP BY loan_status
ORDER BY total_loans DESC;

--Deliquency Analysis
SELECT
    loan_type,
    COUNT(DISTINCT loan_id)                          AS total_loans,
    COUNT(DISTINCT CASE 
        WHEN loan_status = 'Written-Off' 
        THEN loan_id END)                            AS written_off,
    ROUND(COUNT(DISTINCT CASE 
        WHEN loan_status = 'Written-Off' 
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                  AS write_off_rate
FROM loan_master
GROUP BY loan_type
ORDER BY write_off_rate DESC;

--Deliquency by credit score board

SELECT
    CASE
        WHEN credit_score < 500 THEN '1. Poor (300-499)'
        WHEN credit_score < 650 THEN '2. Fair (500-649)'
        WHEN credit_score < 750 THEN '3. Good (650-749)'
        ELSE                         '4. Excellent (750+)'
    END                                              AS credit_band,
    COUNT(DISTINCT loan_id)                          AS total_loans,
    COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END)                            AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                  AS write_off_rate,
    ROUND(AVG(credit_score)::numeric, 0)             AS avg_credit_score
FROM loan_master
GROUP BY credit_band
ORDER BY credit_band;

-- Collection Efficiency Rate
SELECT
    loan_type,
    ROUND(SUM(paid_amount)::numeric * 100.0 / 
          SUM(emi_amount)::numeric, 2)             AS collection_efficiency,
    ROUND(AVG(days_past_due)::numeric, 1)          AS avg_days_past_due,
    COUNT(*) FILTER(WHERE payment_status = 'Missed')        AS missed_payments,
    COUNT(*) FILTER(WHERE payment_status = 'Paid')          AS paid_payments,
    COUNT(*) FILTER(WHERE payment_status = 'Partially Paid') AS partial_payments
FROM loan_master
GROUP BY loan_type
ORDER BY collection_efficiency DESC;

-- Overall payment health
SELECT 
    payment_status,
    COUNT(*)                                    AS count,
    ROUND(COUNT(*) * 100.0 / 
          SUM(COUNT(*)) OVER()::numeric, 2)     AS pct
FROM loan_master
GROUP BY payment_status
ORDER BY count DESC;

--geographical analysis
SELECT
    region,
    COUNT(DISTINCT loan_id)                       AS total_loans,
    ROUND(SUM(loan_amount)::numeric, 2)           AS total_value,
    ROUND(AVG(loan_amount)::numeric, 2)           AS avg_loan,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)               AS write_off_rate
FROM loan_master
GROUP BY region
ORDER BY total_loans DESC;

-- Cohort analysis by disbursement year
SELECT
    EXTRACT(YEAR FROM disbursement_date)          AS vintage_year,
    COUNT(DISTINCT loan_id)                        AS total_loans,
    ROUND(AVG(loan_amount)::numeric, 2)            AS avg_loan,
    COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END)                          AS written_off,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                AS write_off_rate
FROM loan_master
GROUP BY vintage_year
ORDER BY vintage_year;

-- Recovery Rate by vintage
SELECT
    EXTRACT(YEAR FROM disbursement_date)           AS vintage_year,
    ROUND(SUM(paid_amount)::numeric * 100.0 /
          SUM(emi_amount)::numeric, 2)             AS recovery_rate,
    ROUND(AVG(days_past_due)::numeric, 1)          AS avg_dpd,
    COUNT(*) FILTER(WHERE payment_status = 'Missed')  AS missed,
    COUNT(*) FILTER(WHERE payment_status = 'Paid')    AS paid
FROM loan_master
GROUP BY vintage_year
ORDER BY vintage_year;
-- Risk segmentation combining multiple factors
SELECT
    CASE
        WHEN credit_score < 500 THEN 'Poor'
        WHEN credit_score < 650 THEN 'Fair'
        WHEN credit_score < 750 THEN 'Good'
        ELSE 'Excellent'
    END                                            AS credit_band,
    employment_type,
    COUNT(DISTINCT loan_id)                        AS total_loans,
    ROUND(AVG(monthly_income)::numeric, 0)         AS avg_income,
    ROUND(AVG(loan_amount)::numeric, 0)            AS avg_loan,
    ROUND(AVG(loan_amount)::numeric /
          NULLIF(AVG(monthly_income)::numeric, 0)
          , 2)                                     AS loan_to_income_ratio,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2)                AS write_off_rate
FROM loan_master
GROUP BY credit_band, employment_type
ORDER BY write_off_rate DESC;

-- Flag high risk customers by LTI
SELECT
    CASE
        WHEN loan_amount / monthly_income > 10 
        THEN 'High Risk (LTI > 10)'
        WHEN loan_amount / monthly_income > 7  
        THEN 'Medium Risk (LTI 7-10)'
        ELSE 'Low Risk (LTI < 7)'
    END                             AS lti_risk_band,
    COUNT(DISTINCT loan_id)         AS total_loans,
    ROUND(COUNT(DISTINCT CASE
        WHEN loan_status = 'Written-Off'
        THEN loan_id END) * 100.0 /
        COUNT(DISTINCT loan_id), 2) AS write_off_rate
FROM loan_master
GROUP BY lti_risk_band
ORDER BY write_off_rate DESC;