--null check
SELECT 
    count(*) FILTER(WHERE r.repayment_id IS NULL),
    count(*) FILTER(WHERE r.loan_id IS NULL),
    count(*) FILTER(WHERE r.due_date IS NULL),
    count(*) FILTER(WHERE r.paid_date IS NULL),
    count(*) FILTER(WHERE r.emi_amount IS NULL),
    count(*) FILTER(WHERE r.paid_amount IS NULL),
    count(*) FILTER(WHERE r.days_past_due IS NULL),
    count(*) FILTER(WHERE r.payment_status IS null)
FROM repayments r;

--empty string check
SELECT 
    count(*) FILTER(WHERE r.repayment_id in ('', ' ')),
    count(*) FILTER(WHERE r.loan_id in ('', ' ')),
    count(*) FILTER(WHERE r.due_date in ('', ' ')),
    count(*) FILTER(WHERE r.paid_date in ('', ' ')),
    count(*) FILTER(WHERE r.payment_status in ('', ' '))
FROM repayments r;

--'paid_date' is filled with a lot of empty strings so they will be replaced by null values for now
update repayments
set paid_date = null
where paid_date in ('',' ');

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'repayments' AND column_name in ('due_date','paid_date');

--changing date format to date data type from string
alter table repayments 
alter column due_date type date
using due_date::date,
alter column paid_date type date
using paid_date::date;

SELECT 
    payment_status,
    CASE 
        WHEN days_past_due = 0  THEN 'Zero'
        WHEN days_past_due > 0  THEN 'Positive'
        WHEN days_past_due < 0  THEN 'Negative'
        WHEN days_past_due IS NULL THEN 'NULL'
    END AS days_category,
    COUNT(*) AS count
FROM repayments
GROUP BY payment_status, days_category
ORDER BY payment_status, days_category;

BEGIN;

-- Paid on time
UPDATE repayments
SET paid_date = due_date
WHERE paid_date IS NULL
AND payment_status = 'Paid'
AND days_past_due = 0;

-- Paid late
UPDATE repayments
SET paid_date = (due_date + days_past_due)::date
WHERE paid_date IS NULL
AND payment_status = 'Paid'
AND days_past_due > 0;

-- Partially Paid
UPDATE repayments
SET paid_date = (due_date + days_past_due)::date
WHERE paid_date IS NULL
AND payment_status = 'Partially Paid';

COMMIT;

-- Verify
SELECT 
    payment_status,
    COUNT(*) FILTER(WHERE paid_date IS NULL) AS null_paid_date
FROM repayments
GROUP BY payment_status;


SELECT 
    payment_status,
    COUNT(*) FILTER(WHERE paid_date IS NULL) AS null_paid_date
FROM repayments
GROUP BY payment_status;	

SELECT 
    MIN(emi_amount)                    AS min_emi,
    MAX(emi_amount)                    AS max_emi,
    AVG(emi_amount)                    AS avg_emi,
    COUNT(*) FILTER(WHERE emi_amount <= 0) AS zero_or_negative,
    MIN(paid_amount)                   AS min_paid,
    MAX(paid_amount)                   AS max_paid,
    COUNT(*) FILTER(WHERE paid_amount < 0) AS negative_paid
FROM repayments;

SELECT 
    payment_status,
    COUNT(*) AS count
FROM repayments
WHERE paid_amount = 0
GROUP BY payment_status;

'''
Missed + paid_amount = 0(never paid anything) 
No Paid or Partially Paid records with zero amount 

Missed total:           18,135
Missed with 0 paid:     17,555
Difference:                580  <- these missed payments have paid_amount > 0?
'''

-- What are the 580 missed payments that have some paid amount?
SELECT 
    payment_status,
    paid_amount,
    emi_amount,
    days_past_due
FROM repayments
WHERE payment_status = 'Missed'
AND paid_amount > 0
LIMIT 20;

'''
paid_amount > emi_amount + Missed status
-> Customer paid MORE than EMI
-> But still marked as Missed
'''

-- Flag these as status inconsistency
-- Don't change payment_status — too risky without business confirmation

SELECT 
    COUNT(*),
    AVG(paid_amount - emi_amount) AS avg_overpayment
FROM repayments
WHERE payment_status = 'Missed'
AND paid_amount > 0;