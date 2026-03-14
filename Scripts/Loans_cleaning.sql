begin;
SELECT * FROM loans
WHERE loan_id IN (
    SELECT loan_id FROM loans
    GROUP BY loan_id
    HAVING COUNT(*) > 1
)
ORDER BY loan_id;


-- Check if duplicates are identical rows
SELECT loan_id, COUNT(DISTINCT customer_id) AS unique_customers
FROM loans
GROUP BY loan_id
HAVING COUNT(*) > 1
ORDER BY unique_customers DESC;

-- Delete exact duplicates, keep one row per loan_id
WITH duplicates AS (
    SELECT customer_id,
           ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY ctid) AS row_num
    FROM loans
)

DELETE FROM loans
WHERE customer_id IN (
    SELECT customer_id FROM duplicates
    WHERE row_num > 1
);


-- Check the actual column type first
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'loans' AND column_name = 'disbursement_date';

SELECT DISTINCT
  disbursement_date,
  CASE 
    WHEN disbursement_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
    WHEN disbursement_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'DD-MM-YYYY'
    ELSE 'UNKNOWN'
  END AS detected_format
FROM loans
ORDER BY detected_format;


ALTER TABLE loans
ALTER COLUMN disbursement_date TYPE DATE
USING disbursement_date::DATE;

select * from loans;

SELECT 
  MIN(loan_amount)        AS minimum,
  MAX(loan_amount)        AS maximum,
  AVG(loan_amount)        AS average,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY loan_amount) AS q1,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY loan_amount) AS median,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY loan_amount) AS q3,
  COUNT(*) FILTER (WHERE loan_amount < 25000) AS below_25k_count
FROM loans;

commit;


SELECT
    COUNT(*) FILTER(WHERE loan_id IS NULL)            AS loan_id_nulls,
    COUNT(*) FILTER(WHERE customer_id IS NULL)        AS customer_id_nulls,
    COUNT(*) FILTER(WHERE branch_id IS NULL)          AS branch_id_nulls,
    COUNT(*) FILTER(WHERE loan_type IS NULL)          AS loan_type_nulls,
    COUNT(*) FILTER(WHERE loan_amount IS NULL)        AS loan_amount_nulls,
    COUNT(*) FILTER(WHERE tenure_months IS NULL)      AS tenure_nulls,
    COUNT(*) FILTER(WHERE interest_rate IS NULL)      AS interest_rate_nulls,
    COUNT(*) FILTER(WHERE disbursement_date IS NULL)  AS disbursement_nulls,
    COUNT(*) FILTER(WHERE loan_status IS NULL)        AS loan_status_nulls
FROM loans;