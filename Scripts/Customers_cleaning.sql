
begin;
--null check
select
	count(*) filter(where c.customer_id is null),
	count(*) filter(where c.first_name is null),
	count(*) filter(where c.last_name is null),
	count(*) filter(where c.age is null),
	count(*) filter(where c.gender is null),
	count(*) filter(where c.city is null),
	count(*) filter(where c.state is null),
	count(*) filter(where c.credit_score is null)
	from customers c;

--
select
	count(*) filter(where c.customer_id in ('', ' ')),
	count(*) filter(where c.first_name in ('', ' ')),
	count(*) filter(where c.last_name in ('', ' ')),
	count(*) filter(where c.gender in ('', ' ')),
	count(*) filter(where c.city in ('', ' ')),
	count(*) filter(where c.state in ('', ' ')),
	count(*) filter(where c.employment_type in ('',' '))
from customers c;




--age
select --consitency check of 'age'
	age,
	count(*)
from 
	customers 
group by age 
order by age;


SELECT --youngest is 14 which seems suspicious
    MIN(age) AS youngest,
    MAX(age) AS oldest,
    AVG(age)::INT AS average_age,
    COUNT(*) FILTER (WHERE age < 18) AS underage_count
FROM customers; 

select 
	distinct c.age
from 
	customers c
where 
	age<18; --14,15,16,17 are minors probably typo.
	
	

update customers
set age= case
	when age = 14 then 41
	when age = 15 then 51
	when age = 16 then 61
	when age = 17 then 71	
end
where age < 18;

SELECT --recheck
    MIN(age) AS youngest,
    MAX(age) AS oldest,
    AVG(age)::INT AS average_age,
    COUNT(*) FILTER (WHERE age < 18) AS underage_count
FROM customers; 

--gender
select 
	gender, 
	count(*)
from 
	customers
group by gender
order by gender; --inconsitent strings	

--all stings to lowercase
update customers
set gender = lower(gender);

-- labelling 'female'
update customers
set gender = 'f'
where gender = 'female';

--labelling 'male'
update customers
set gender = 'm'
where gender = 'male';

--constitent labelling
update customers
set gender = upper(gender);

-- updated 'gender'
select 
	gender, 
	count(*)
from 
	customers
group by gender
order by gender;

--updating string consistency
UPDATE customers SET
    first_name      = INITCAP(first_name),
    last_name       = INITCAP(last_name),
    city            = INITCAP(city),
    state           = INITCAP(state),
    employment_type = INITCAP(employment_type);

--'monthly_income' consistency check
SELECT 
    MIN(monthly_income)     AS lowest,
    MAX(monthly_income)     AS highest,
    AVG(monthly_income)     AS average,
    COUNT(*) FILTER (WHERE monthly_income < 0) AS negative_count,
    COUNT(*) FILTER (WHERE monthly_income = 0) AS zero_count
FROM customers
WHERE employment_type = 'Salaried';

--recitfying Data entry error
update customers set monthly_income = ABS(monthly_income ) where monthly_income < 0;



select 
	employment_type, 
	monthly_income ,
	credit_score 
from customers 
where credit_score is not null
group by employment_type , monthly_income, credit_score
order by monthly_income;

--Monthly income for each categories seems unrealistically.

-- To check how many suspiciously low incomes?
SELECT 
    employment_type,
    COUNT(*) FILTER (WHERE monthly_income < 1000)  AS under_1k,
    COUNT(*) FILTER (WHERE monthly_income < 10000)  AS under_10k,
    COUNT(*) FILTER (WHERE monthly_income < 18000) AS under_18k
FROM customers
GROUP BY employment_type;

-- the minimum pay in India is 18,000 INR. So anything below it is not good enough to get loan. 
--Since significant values are under 18K, it is not reccomded to drop data values.
--it's better to assign 1k and below as NULL and replace null with median


-- Only fix the definitely wrong values
UPDATE customers
SET monthly_income = NULL
WHERE monthly_income < 1000;

-- Add context in to analysis queries instead
SELECT 
    employment_type,
    CASE 
        WHEN monthly_income < 1000  THEN 'Invalid'
        WHEN monthly_income < 18000 THEN 'Low Income'
        WHEN monthly_income < 50000 THEN 'Middle Income'
        ELSE 'High Income'
    END AS income_bracket,
    COUNT(*) AS customer_count
FROM customers
GROUP BY employment_type, income_bracket
ORDER BY employment_type, income_bracket;

-- Check current NULL count
SELECT COUNT(*) FROM customers WHERE monthly_income IS NULL;


SELECT 
    CASE 
        WHEN credit_score < 500 THEN 'Poor (300-499)'
        WHEN credit_score < 650 THEN 'Fair (500-649)'
        WHEN credit_score < 750 THEN 'Good (650-749)'
        ELSE                         'Excellent (750+)'
    END AS credit_band,
    employment_type,
    ROUND(AVG(monthly_income)::numeric, 0)                               AS avg_income,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monthly_income)::numeric AS median_income,
    COUNT(*) AS customer_count
FROM customers
WHERE monthly_income IS NOT NULL
GROUP BY credit_band, employment_type
ORDER BY credit_band, employment_type;

UPDATE customers c
SET monthly_income = sub.median_income
FROM (
    SELECT 
        employment_type,
        PERCENTILE_CONT(0.5) WITHIN GROUP 
        (ORDER BY monthly_income) AS median_income
    FROM customers
    WHERE monthly_income IS NOT NULL
    GROUP BY employment_type
) sub
WHERE c.monthly_income IS NULL
AND c.employment_type = sub.employment_type;

UPDATE customers c
SET credit_score = sub.median_credit
FROM (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP 
        (ORDER BY credit_score) AS median_credit
    FROM customers
    WHERE credit_score  IS NOT NULL
    GROUP BY employment_type
) sub
WHERE c.credit_score IS NULL;

select * from customers c 
where c.credit_score is null or c.monthly_income is null;

commit;