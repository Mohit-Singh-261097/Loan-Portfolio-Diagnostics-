# ☁️ BigQuery (Cloud) Setup

This project includes a complete **BigQuery-compatible SQL variant** for teams running on GCP 
rather than on-premise PostgreSQL. All 5 SQL scripts have been ported with documented dialect 
adaptations.

---

## Tech Stack (Cloud)

![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=googlebigquery&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-Cloud%20Storage-4285F4?style=flat&logo=googlecloud&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)

---

## BigQuery SQL Files

| File | Original | Purpose |
|------|----------|---------|
| `bigquery/bq_01_customers_cleaning.sql` | `Customers_cleaning.sql` | Null checks, age/gender fixes, income imputation via MERGE |
| `bigquery/bq_02_loans_cleaning.sql` | `Loans_cleaning.sql` | Dedup via ROW_NUMBER, date type conversion via CREATE OR REPLACE |
| `bigquery/bq_03_repayments_cleaning.sql` | `repayments_cleaning.sql` | Date casting via SAFE_CAST, paid_date imputation via DATE_ADD |
| `bigquery/bq_04_eda.sql` | `EDA.sql` | UNENFORCED PK/FK constraints, master VIEW, 15 EDA queries |
| `bigquery/bq_05_portfolio_analysis.sql` | `Portfolio_analysis.sql` | All 8 Power BI dataset queries ported to BQ dialect |

---

## Key PostgreSQL → BigQuery Dialect Adaptations

| Pattern | PostgreSQL | BigQuery |
|---------|-----------|---------|
| Conditional count | `COUNT(*) FILTER (WHERE condition)` | `COUNTIF(condition)` |
| Type casting | `value::numeric` | `CAST(value AS NUMERIC)` |
| String concat | `first_name \|\| ' ' \|\| last_name` | `CONCAT(first_name, ' ', last_name)` |
| Safe casting | `value::date` | `SAFE_CAST(value AS DATE)` |
| Date arithmetic | `(due_date + days_past_due)::date` | `DATE_ADD(due_date, INTERVAL days_past_due DAY)` |
| Median (aggregate) | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY col)` | `PERCENTILE_CONT(col, 0.5) OVER (PARTITION BY ...)` |
| Dedup delete | `DELETE ... WHERE ctid NOT IN (...)` | `CREATE OR REPLACE TABLE AS SELECT ... WHERE row_num = 1` |
| Column type change | `ALTER COLUMN ... TYPE DATE USING ...` | `CREATE OR REPLACE TABLE` with `CAST()` |
| Regex match | `col ~ '^\d{4}...'` | `REGEXP_CONTAINS(col, r'^\d{4}...')` |
| Constraints | Enforced PK/FK | `NOT ENFORCED` PK/FK (metadata only) |
| Update all rows | `UPDATE ... SET` (no WHERE needed) | `UPDATE ... SET ... WHERE TRUE` |
| Schema prefix | `public.table_name` | `` `project.dataset.table_name` `` |

---

## How to Run on BigQuery (Free Tier)

**Prerequisites:** Google account (no credit card required for sandbox)

### Step 1 — Create a GCP Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click **New Project** → name it `loan-portfolio-diagnostics`
3. Enable the **BigQuery API** (usually auto-enabled)

### Step 2 — Create a Dataset

```bash
# Via bq CLI (optional)
bq mk --dataset loan_portfolio_diagnostics.nbfc_loans

# Or via Console: BigQuery → your project → Create Dataset
# Dataset ID: nbfc_loans
# Location: asia-south1 (Mumbai) or US (default)
```

### Step 3 — Load CSV Files

Upload the 8 CSVs from `/data/` to BigQuery tables:

```bash
# Example: load fact table
bq load \
  --autodetect \
  --source_format=CSV \
  --skip_leading_rows=1 \
  loan_portfolio_diagnostics.nbfc_loans.fact_loan_repayments \
  gs://your-bucket/fact_loan_repayments.csv

# Or use the Console: BigQuery → dataset → Create Table → Upload CSV
```

> **Tip:** Use BigQuery's **Auto-detect schema** for all 8 CSVs. Review and correct 
> `disbursement_date` / `due_date` columns to `DATE` type if auto-detected as `STRING`.

### Step 4 — Run BigQuery SQL Scripts

Open the BigQuery console SQL editor and run scripts in this order:

```
1. bq_01_customers_cleaning.sql    ← clean source tables first
2. bq_02_loans_cleaning.sql
3. bq_03_repayments_cleaning.sql
4. bq_04_eda.sql                   ← creates loan_master VIEW
5. bq_05_portfolio_analysis.sql    ← 8 analytical output tables
```

Replace `your_project.your_dataset` with your actual GCP project ID and dataset name.

### Step 5 — Connect Power BI to BigQuery

1. Power BI Desktop → **Get Data** → **Google BigQuery**
2. Sign in with your Google account
3. Navigate to your project → `nbfc_loans` dataset
4. Load each of the 8 output tables

> **Alternative:** Connect [Looker Studio](https://lookerstudio.google.com) (free) directly 
> to BigQuery for a shareable, live dashboard — no Power BI Desktop required for viewers.

---

## Why BigQuery?

| Concern | PostgreSQL (local) | BigQuery (cloud) |
|---------|-------------------|-----------------|
| Setup | Local install required | Browser-based, zero install |
| Scale | Limited by local RAM | Petabyte-scale serverless |
| Sharing | Share .sql files only | Share live query results |
| Cost | Free (local) | Free tier: 10 GB storage, 1 TB queries/month |
| BI connect | Direct or CSV export | Native Power BI + Looker Studio connectors |

BigQuery's free sandbox tier comfortably covers this entire project — the dataset is ~50 MB, 
well within the 10 GB free storage and 1 TB free query limits.
