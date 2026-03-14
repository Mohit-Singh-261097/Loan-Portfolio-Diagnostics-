import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta
import os

np.random.seed(42)
random.seed(42)

# ── CONFIG ────────────────────────────────────────────────────────────────────
N_CUSTOMERS  = 8000
N_LOANS      = 10000
N_BRANCHES   = 40
START_DATE   = datetime(2021, 1, 1)
END_DATE     = datetime(2023, 12, 31)
TODAY        = datetime(2024, 3, 31)

# ── HELPERS ───────────────────────────────────────────────────────────────────
def random_date(start, end):
    return start + timedelta(days=random.randint(0, (end - start).days))

def maybe_null(val, prob=0.05):
    return None if random.random() < prob else val

# ── 1. BRANCHES ───────────────────────────────────────────────────────────────
cities_by_region = {
    "North": ["Delhi", "Lucknow", "Jaipur", "Chandigarh", "Agra", "Meerut", "Varanasi", "Kanpur", "Amritsar", "Ludhiana"],
    "South": ["Bangalore", "Chennai", "Hyderabad", "Kochi", "Coimbatore", "Mysore", "Vizag", "Madurai", "Mangalore", "Tirupati"],
    "East":  ["Kolkata", "Bhubaneswar", "Patna", "Guwahati", "Ranchi", "Jamshedpur", "Cuttack", "Siliguri", "Asansol", "Dhanbad"],
    "West":  ["Mumbai", "Pune", "Ahmedabad", "Surat", "Nagpur", "Nashik", "Vadodara", "Rajkot", "Aurangabad", "Indore"],
}
state_map = {
    "Delhi": "Delhi", "Lucknow": "Uttar Pradesh", "Jaipur": "Rajasthan",
    "Chandigarh": "Punjab", "Agra": "Uttar Pradesh", "Meerut": "Uttar Pradesh",
    "Varanasi": "Uttar Pradesh", "Kanpur": "Uttar Pradesh", "Amritsar": "Punjab",
    "Ludhiana": "Punjab", "Bangalore": "Karnataka", "Chennai": "Tamil Nadu",
    "Hyderabad": "Telangana", "Kochi": "Kerala", "Coimbatore": "Tamil Nadu",
    "Mysore": "Karnataka", "Vizag": "Andhra Pradesh", "Madurai": "Tamil Nadu",
    "Mangalore": "Karnataka", "Tirupati": "Andhra Pradesh", "Kolkata": "West Bengal",
    "Bhubaneswar": "Odisha", "Patna": "Bihar", "Guwahati": "Assam",
    "Ranchi": "Jharkhand", "Jamshedpur": "Jharkhand", "Cuttack": "Odisha",
    "Siliguri": "West Bengal", "Asansol": "West Bengal", "Dhanbad": "Jharkhand",
    "Mumbai": "Maharashtra", "Pune": "Maharashtra", "Ahmedabad": "Gujarat",
    "Surat": "Gujarat", "Nagpur": "Maharashtra", "Nashik": "Maharashtra",
    "Vadodara": "Gujarat", "Rajkot": "Gujarat", "Aurangabad": "Maharashtra",
    "Indore": "Madhya Pradesh",
}

branches = []
branch_id = 1
for region, cities in cities_by_region.items():
    for city in cities[:N_BRANCHES // 4]:
        branches.append({
            "branch_id":   f"BR{branch_id:03d}",
            "branch_name": f"FinServe {city} Branch",
            "city":        city,
            "state":       state_map[city],
            "region":      region,
        })
        branch_id += 1

df_branches = pd.DataFrame(branches)

# ── 2. CUSTOMERS ──────────────────────────────────────────────────────────────
# Dirty: inconsistent gender, city name casing, nulls, illogical age/income
first_names = ["Amit","Priya","Rahul","Sneha","Vikram","Pooja","Suresh","Anjali",
               "Ravi","Kavya","Arjun","Divya","Manoj","Sunita","Deepak","Meera",
               "Rajesh","Nisha","Arun","Swati","Kiran","Sonia","Naveen","Rekha"]
last_names  = ["Sharma","Patel","Singh","Kumar","Gupta","Verma","Joshi","Mehta",
               "Reddy","Nair","Iyer","Shah","Mishra","Rao","Agarwal","Pandey"]

gender_variants = ["Male","Female","M","F","male","female","MALE","FEMALE","M","M","Male","Male","Female","Female"]

all_cities = [c for cities in cities_by_region.values() for c in cities]
# Dirty city name variants
city_dirty = {c: random.choice([c, c.upper(), c.lower(), c + " ", " " + c]) for c in all_cities}

employment_types = ["Salaried","Self-Employed","salaried","SALARIED","Self-employed","self-employed"]

customers = []
for i in range(1, N_CUSTOMERS + 1):
    age    = random.randint(21, 58)
    income = round(random.gauss(45000, 20000), 2)

    # Dirty: ~2% age < 18, ~1% negative income
    if random.random() < 0.02:
        age = random.randint(14, 17)
    if random.random() < 0.01:
        income = -abs(income)

    city   = random.choice(all_cities)
    gender = random.choice(gender_variants)
    emp    = random.choice(employment_types)

    credit_score = maybe_null(random.randint(300, 900), prob=0.06)
    monthly_income = maybe_null(income, prob=0.05)

    customers.append({
        "customer_id":      f"CUST{i:05d}",
        "first_name":       random.choice(first_names),
        "last_name":        random.choice(last_names),
        "age":              age,
        "gender":           gender,
        "city":             city_dirty[city] if random.random() < 0.3 else city,
        "state":            state_map[city],
        "credit_score":     credit_score,
        "employment_type":  emp,
        "monthly_income":   monthly_income,
    })

df_customers = pd.DataFrame(customers)

# ── 3. LOANS ──────────────────────────────────────────────────────────────────
loan_types   = ["Personal Loan","Consumer Durable","Two-Wheeler Loan","Personal Loan","Personal Loan"]
loan_status_pool = ["Active","Closed","Written-Off","Active","Active","Active","Closed","Closed"]

loans = []
for i in range(1, N_LOANS + 1):
    cust_id   = f"CUST{random.randint(1, N_CUSTOMERS):05d}"
    branch_id = random.choice(df_branches["branch_id"].tolist())
    ltype     = random.choice(loan_types)
    tenure    = random.choice([12, 18, 24, 36, 48, 60])
    amount    = round(random.choice([
        random.randint(25000,  100000),   # small
        random.randint(100000, 500000),   # medium
        random.randint(500000, 1500000),  # large
    ]), -3)
    rate       = round(random.uniform(10.5, 24.0), 2)
    disb_date  = random_date(START_DATE, END_DATE)
    status     = random.choice(loan_status_pool)

    loans.append({
        "loan_id":           f"LN{i:06d}",
        "customer_id":       cust_id,
        "branch_id":         branch_id,
        "loan_type":         ltype,
        "loan_amount":       amount,
        "tenure_months":     tenure,
        "interest_rate":     rate,
        "disbursement_date": disb_date.strftime("%Y-%m-%d"),
        "loan_status":       status,
    })

df_loans = pd.DataFrame(loans)

# Dirty: inject ~1.5% duplicate loan rows
n_dupes = int(N_LOANS * 0.015)
dupe_rows = df_loans.sample(n_dupes, replace=True)
df_loans = pd.concat([df_loans, dupe_rows], ignore_index=True)

# ── 4. REPAYMENTS ─────────────────────────────────────────────────────────────
# Target ~50K rows total
repayments = []
rep_id = 1

# Loans to skip entirely (missing repayment rows dirty issue)
skip_loans = set(random.sample(df_loans["loan_id"].unique().tolist(), k=int(N_LOANS * 0.02)))

for _, loan in df_loans.drop_duplicates("loan_id").iterrows():
    if loan["loan_id"] in skip_loans:
        continue

    disb    = datetime.strptime(loan["disbursement_date"], "%Y-%m-%d")
    tenure  = int(loan["tenure_months"])
    amount  = float(loan["loan_amount"])
    rate    = float(loan["interest_rate"]) / 100 / 12
    emi     = round(amount * rate * (1 + rate)**tenure / ((1 + rate)**tenure - 1), 2)

    # Determine borrower risk profile
    risk = random.choices(["good","moderate","bad"], weights=[0.55, 0.30, 0.15])[0]

    for month in range(1, tenure + 1):
        due_date = disb + timedelta(days=30 * month)
        if due_date > TODAY:
            break

        # Determine payment behaviour based on risk
        if risk == "good":
            pay_status = random.choices(["Paid","Partially Paid","Missed"], weights=[0.92, 0.05, 0.03])[0]
        elif risk == "moderate":
            pay_status = random.choices(["Paid","Partially Paid","Missed"], weights=[0.70, 0.18, 0.12])[0]
        else:
            pay_status = random.choices(["Paid","Partially Paid","Missed"], weights=[0.40, 0.25, 0.35])[0]

        if pay_status == "Paid":
            paid_amount = emi
            days_late   = random.choices([0, random.randint(1,5)], weights=[0.85, 0.15])[0]
            paid_date   = due_date + timedelta(days=days_late)
        elif pay_status == "Partially Paid":
            paid_amount = round(emi * random.uniform(0.3, 0.9), 2)
            days_late   = random.randint(1, 45)
            paid_date   = due_date + timedelta(days=days_late)
        else:  # Missed
            paid_amount = 0.0
            days_late   = random.randint(30, 120)
            paid_date   = None

        dpd = days_late if pay_status != "Paid" or days_late > 0 else 0

        # Dirty: ~3% paid_amount > emi (data entry error)
        if random.random() < 0.03:
            paid_amount = round(emi * random.uniform(1.05, 1.5), 2)

        # Dirty: ~2% future paid_dates
        if paid_date and random.random() < 0.02:
            paid_date = TODAY + timedelta(days=random.randint(1, 60))

        # Dirty: ~5% null paid_date even when status = Paid
        if pay_status == "Paid" and random.random() < 0.05:
            paid_date = None

        repayments.append({
            "repayment_id":  f"REP{rep_id:07d}",
            "loan_id":       loan["loan_id"],
            "due_date":      due_date.strftime("%Y-%m-%d"),
            "paid_date":     paid_date.strftime("%Y-%m-%d") if paid_date else None,
            "emi_amount":    emi,
            "paid_amount":   paid_amount,
            "days_past_due": dpd,
            "payment_status": pay_status,
        })
        rep_id += 1

df_repayments = pd.DataFrame(repayments)

# ── SAVE ──────────────────────────────────────────────────────────────────────
os.makedirs("/home/claude/loan_data", exist_ok=True)

df_branches.to_csv("/home/claude/loan_data/branches.csv", index=False)
df_customers.to_csv("/home/claude/loan_data/customers.csv", index=False)
df_loans.to_csv("/home/claude/loan_data/loans.csv", index=False)
df_repayments.to_csv("/home/claude/loan_data/repayments.csv", index=False)

print("─── Data Generation Summary ───")
print(f"branches.csv    : {len(df_branches):>7,} rows")
print(f"customers.csv   : {len(df_customers):>7,} rows")
print(f"loans.csv       : {len(df_loans):>7,} rows  (includes ~{n_dupes} duplicates)")
print(f"repayments.csv  : {len(df_repayments):>7,} rows")
print()
print("─── Dirty Data Injected ───")
print(f"Null credit_score       : {df_customers['credit_score'].isna().sum()}")
print(f"Null monthly_income     : {df_customers['monthly_income'].isna().sum()}")
print(f"Age < 18                : {(df_customers['age'] < 18).sum()}")
print(f"Negative income         : {(df_customers['monthly_income'].dropna() < 0).sum()}")
print(f"Duplicate loan rows     : {n_dupes}")
print(f"Loans missing repayments: {len(skip_loans)}")
print(f"Null paid_date          : {df_repayments['paid_date'].isna().sum()}")
print(f"Future paid_dates       : {len(df_repayments[df_repayments['paid_date'] > TODAY.strftime('%Y-%m-%d')].dropna())}")
print(f"paid_amount > emi       : {(df_repayments['paid_amount'] > df_repayments['emi_amount']).sum()}")
print(f"Inconsistent gender     : {df_customers['gender'].value_counts().to_dict()}")
