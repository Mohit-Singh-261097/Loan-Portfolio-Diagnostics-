# 🏦 Loan Portfolio Diagnostics

**A diagnostic deep-dive into a synthetic NBFC retail loan portfolio — analysing credit risk, delinquency patterns, collections performance, and geographic concentration risk across 9,800 loans and ₹784 Cr in disbursements.**

---

## 📌 Table of Contents

- [Project Overview](#project-overview)
- [Dashboard](#dashboard)
- [Dataset](#dataset)
- [Tech Stack](#tech-stack)
- [Business Questions Answered](#business-questions-answered)
- [Key Findings & Insights](#key-findings--insights)
- [Recommendations](#recommendations)
- [Data Model](#data-model)
- [SQL Queries](#sql-queries)
- [BigQuery Cloud Setup](#️-bigquery-cloud-setup)
- [How to Run](#how-to-run)
- [Project Structure](#project-structure)

---

## Project Overview

Retail NBFCs operate on thin margins. A 1–2 percentage point swing in write-off rate or collection efficiency can be the difference between a profitable quarter and a stressed book. This project simulates the kind of diagnostic analysis a risk or collections analyst would run to answer the question: **where exactly is the portfolio bleeding, and what should leadership do about it?**

The analysis spans three dimensions:

- **Credit Risk** — who is defaulting and why, and is credit scoring doing its job?
- **Collections Performance** — how much of what's owed is actually being recovered, and at which stage is recovery failing?
- **Geographic Concentration** — which states and regions are structurally higher-risk, and is that risk priced in?

> **Dataset note:** This is a synthetic dataset generated to simulate a realistic NBFC retail loan portfolio. All customer names, IDs, and financials are fabricated. The patterns and distributions are designed to reflect real-world NBFC dynamics.

---

## Dashboard

> *Power BI dashboard — screenshots to be added upon completion.*

The dashboard is structured across **3 pages**:

| Page | Focus | Key Visuals |
|------|-------|-------------|
| **Portfolio Overview** | Executive summary of portfolio health | 6 KPI cards, loan type breakdown, vintage trend, payment status donut |
| **Risk & Credit Analysis** | Delinquency and credit segment deep-dive | DPD bucket bar chart, credit band heatmap, LTI distribution |
| **Collections & Geography** | Recovery performance and regional risk | Collections funnel, India filled map by write-off rate, regional table |

---

## Dataset

| Table | Rows | Description |
|-------|------|-------------|
| `fact_loan_repayments` | 172,881 | Repayment-level grain — one row per EMI |
| `kpi_portfolio_summary` | 1 | Pre-aggregated portfolio KPIs |
| `dim_loan_type_analysis` | 3 | Performance by loan product |
| `dim_vintage_analysis` | 3 | Cohort performance by disbursement year |
| `dim_credit_risk` | 8 | Write-off rates by credit band × employment type |
| `dim_dpd_analysis` | 5 | Delinquency distribution across DPD buckets |
| `dim_collections_funnel` | 3 | Payment status funnel with recovery rates |
| `dim_regional_analysis` | 17 | State-wise portfolio and risk metrics |

**Source tables:** `loans`, `customers`, `branches`, `repayments`
**Available on:** PostgreSQL (local) · BigQuery (cloud — see [setup guide](#️-bigquery-cloud-setup))

---

## Tech Stack

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=googlebigquery&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-Cloud%20Storage-4285F4?style=flat&logo=googlecloud&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![DAX](https://img.shields.io/badge/DAX-Measures-2E75B6?style=flat)
![SQL](https://img.shields.io/badge/SQL-Window%20Functions-336791?style=flat)

---

## Business Questions Answered

This project was structured around six diagnostic questions a risk manager or collections head would ask:

1. **Is the overall portfolio healthy or stressed?**
2. **Which loan product carries the most credit risk?**
3. **Is the credit scoring model actually predicting defaults?**
4. **At what point in the delinquency lifecycle does recovery become impossible?**
5. **Which geographies are concentration risks that need immediate intervention?**
6. **Are underwriting standards getting better or worse over time?**

---

## Key Findings & Insights

### 1. Portfolio is Stable — But the Write-Off Rate Deserves Scrutiny

| Metric | Value | Benchmark (NBFC) | Status |
|--------|-------|-----------------|--------|
| Total Portfolio Value | ₹784 Cr | — | — |
| Collection Efficiency | 86.11% | 85–95% | ✅ Within range |
| Write-Off Rate | 12.88% | 8–12% typical | ⚠️ Slightly elevated |
| Avg Days Past Due | 11.0 days | <15 days | ✅ Healthy |
| Total Written-Off Loans | 1,262 of 9,800 | — | ⚠️ 1 in 8 loans |

Collection efficiency at 86.11% sits within benchmark, but a **12.88% write-off rate** means roughly 1 in every 8 loans is a total loss. This is manageable but trending toward the upper end — and as findings below show, the risk is not evenly distributed.

---

### 2. Personal Loans Dominate Volume and Lead in Write-Offs

Personal Loans make up **60% of the portfolio** (5,886 loans, ₹478 Cr) and carry the highest write-off rate at **13.03%**. Consumer Durable loans follow at 12.95%, while Two-Wheeler loans are the safest product at 12.36%.

| Loan Type | Loans | Portfolio % | Write-Off % | Collection % |
|-----------|-------|-------------|-------------|--------------|
| Personal Loan | 5,886 | 60.1% | 13.03% | 85.88% |
| Consumer Durable | 1,907 | 19.5% | 12.95% | 86.48% |
| Two-Wheeler Loan | 2,007 | 20.5% | 12.36% | 86.47% |

The gap in write-off rates across products is small (~0.7pp), suggesting the risk driver is **borrower-level characteristics** (income, LTI) rather than the loan product itself. The real segmentation story is in the credit and LTI analysis below.

---

### 3. The Credit Scoring Paradox — Good Credit Borrowers Default Most

This is the most counterintuitive and analytically important finding in the entire dataset.

| Credit Band | Employment Type | Write-Off % | LTI Ratio |
|-------------|----------------|-------------|-----------|
| 3. Good (650–749) | Salaried | **14.01%** | 10.20x |
| 2. Fair (500–649) | Self-Employed | 13.63% | 9.69x |
| 1. Poor (300–499) | Salaried | 13.41% | 9.67x |
| 4. Excellent (750+) | Salaried | 12.26% | 9.90x |
| 1. Poor (300–499) | Self-Employed | **11.75%** | 9.75x |

**Good credit + Salaried borrowers have the highest write-off rate in the entire portfolio at 14.01% — higher than even Poor credit borrowers.**

The explanation is in the LTI column: Good credit borrowers are being approved at an average **LTI of 10.20x** (loan amount = 10x monthly income), compared to 9.67x for Poor credit borrowers. The underwriting model appears to be rewarding credit scores with larger loan approvals, overriding what the income-based repayability data is flagging. A borrower with a 680 credit score and a ₹4.7L loan on ₹46K monthly income is not low-risk regardless of their score.

---

### 4. The DPD Cliff — Recovery Drops to Near-Zero After 60 Days

The delinquency data reveals a sharp cliff effect in recovery rates across DPD buckets:

| DPD Bucket | Records | % of Portfolio | Avg Paid (₹) | Avg EMI (₹) | Recovery |
|------------|---------|----------------|-------------|------------|----------|
| Current (DPD=0) | 1,14,084 | 65.99% | 20,168 | 20,009 | ~100% |
| Early (DPD 1–30) | 34,094 | 19.72% | 17,039 | 20,156 | 85% |
| Moderate (DPD 31–60) | 12,742 | 7.37% | 6,953 | 19,759 | 35% |
| Severe (DPD 61–90) | 5,916 | 3.42% | 669 | 20,009 | **3.3%** |
| Critical (DPD 90+) | 6,045 | 3.50% | 739 | 19,736 | **3.7%** |

Two observations stand out:

- **The cliff falls between 30 and 60 DPD.** Recovery drops from 85% in Early DPD to 35% in Moderate DPD — a 50pp collapse in a single bucket. This is the intervention window that matters.
- **Severe and Critical DPD are functionally equivalent.** Recovery at 61–90 DPD (3.3%) is virtually identical to recovery at 90+ DPD (3.7%). Once an account crosses 60 days, it is effectively a write-off regardless of whether it is classified as NPA yet.

The **6.92%** of records in Severe/Critical DPD represent accounts where collections has already failed.

---

### 5. Collections Funnel — ₹50 Cr Left on the Table

| Payment Status | Payments | % | Recovery Rate |
|----------------|----------|---|---------------|
| Paid | 1,34,330 | 77.70% | 100.80% |
| Partially Paid | 20,416 | 11.81% | 61.96% |
| Missed | 18,135 | 10.49% | 3.74% |

Of the total EMI billed:
- **Missed payments**: ₹35.9 Cr billed, only ₹1.3 Cr recovered → **₹34.5 Cr lost**
- **Partial payments**: ₹41.2 Cr billed, ₹25.5 Cr recovered → **₹15.7 Cr shortfall**
- **Total collection gap: ₹50.2 Cr**

The 3.74% recovery on missed EMIs confirms that once a borrower stops paying entirely, the probability of voluntary recovery is near zero. The strategic implication is significant: collections resources should be concentrated on **Partially Paid accounts (61.96% recovery)** rather than chasing Missed accounts — the return on intervention is dramatically higher.

---

### 6. Geographic Concentration — North Region is a Structural Risk

The North region carries an average write-off rate of **14.80%** — 2.66 percentage points higher than any other region.

| Region | Avg Write-Off % | Total Loans | Avg Collection % |
|--------|----------------|-------------|-----------------|
| **North** | **14.80%** | 2,342 | 86.28% |
| West | 12.50% | 2,450 | 86.86% |
| East | 12.18% | 2,418 | 85.80% |
| South | 12.14% | 2,590 | 85.66% |

At the state level, the disparity is stark:

| State | Write-Off % | Collection % | Risk Flag |
|-------|-------------|--------------|-----------|
| Delhi | 16.54% | 85.77% | 🔴 Critical |
| Punjab | 15.25% | 84.83% | 🔴 Critical |
| Telangana | 15.02% | 87.28% | 🔴 High |
| Maharashtra | 15.29% | 86.08% | 🔴 High |
| Gujarat | 10.53% | 86.07% | 🟢 Lowest risk |
| Tamil Nadu | 10.72% | 86.56% | 🟢 Low risk |
| Bihar | 10.70% | 86.18% | 🟢 Low risk |

Delhi's 16.54% write-off rate is **57% higher** than Gujarat's 10.53%. This is not noise — it is a structural pattern pointing to either local economic stress, branch-level underwriting quality issues, or both. Notably, Kerala has the lowest collection efficiency (82.80%) despite a below-average write-off rate, suggesting a different type of payment behaviour — possibly habitually late payments that do eventually settle.

---

### 7. Vintage Analysis — 2022 Was an Anomaly, 2023 Reversed the Improvement

| Vintage | Loans | Write-Off % | Recovery % | Avg DPD |
|---------|-------|-------------|------------|---------|
| 2021 | 3,348 | 13.35% | 86.07% | 11.0 |
| 2022 | 3,216 | **12.06%** | **86.20%** | **10.9** |
| 2023 | 3,236 | 13.20% | 86.04% | 11.0 |

The 2022 cohort is the outlier — write-offs improved by **1.29 percentage points** over 2021, the best performance across all three years. However, 2023 almost entirely reversed this gain (+1.14pp deterioration vs 2022). This V-shaped pattern suggests that whatever underwriting or market conditions drove the 2022 improvement were not sustained or institutionalised.

---

## Recommendations

Based on the analysis above, six actions are recommended in order of urgency:

### 🔴 Immediate Actions

**1. Implement LTI caps for Good-credit borrowers**
The data shows that Good credit + Salaried borrowers are being approved at 10.20x LTI and defaulting at 14.01% — the highest rate in the portfolio. Credit score is functioning as a proxy for trustworthiness, overriding income-based repayability signals. A hard cap of 8–9x LTI regardless of credit score would have the largest single impact on write-off rates.

**2. Redeploy collections resources from Missed to Partial accounts**
The ₹50.2 Cr collection gap analysis shows that chasing Missed accounts yields 3.74% recovery while Partially Paid accounts yield 61.96%. Collections teams should be incentivised and structured to prioritise early-stage delinquency (DPD 1–60) and Partial payers rather than pursuing accounts already in Missed status.

**3. Trigger mandatory legal/recovery escalation at DPD 60 — not DPD 90**
Recovery at DPD 61–90 (3.3%) is statistically identical to DPD 90+ (3.7%). The current industry norm of treating 90 DPD as the NPA trigger is causing a 30-day delay in escalation with no recovery benefit. Internal policy should set DPD 60 as the escalation threshold.

### 🟡 Strategic Actions

**4. Audit North region underwriting — specifically Delhi and Punjab branches**
Delhi (16.54%) and Punjab (15.25%) are 4–6 percentage points above the national average. This warrants a branch-level underwriting audit: are local branch managers approving loans to riskier borrower profiles? Are these branches under volume pressure that is overriding credit standards?

**5. Conduct a 2022 vintage post-mortem and institutionalise those standards**
The 2022 cohort achieved a write-off rate 1.29pp better than 2021 and 1.14pp better than 2023. Something changed in 2022 — tighter approval criteria, a different loan officer cohort, more conservative LTI thresholds, or a favourable macroeconomic period. Identifying and embedding those practices is the most evidence-based lever for portfolio improvement.

**6. Introduce credit score × LTI joint risk pricing**
Currently, the interest rate is flat at ~17.2% across all segments. The data clearly shows that risk varies significantly by the interaction of credit score and LTI — not by either factor alone. A pricing model that charges higher rates for high-LTI borrowers (regardless of credit score) would both price risk appropriately and act as a natural deterrent for over-leveraging.

---

## Data Model

```
loans ──────────────── customers
  │                       │
  │                       │ (customer_id)
  │
  ├── branches  (branch_id)
  │
  └── repayments  (loan_id)
```

**Grain definitions:**
- `loans` → one row per loan
- `repayments` → one row per EMI payment (monthly)
- `fact_loan_repayments` → joined grain: one row per repayment, enriched with loan, customer, and branch attributes

---

## SQL Queries

Eight analytical queries produce the Power BI / BigQuery dataset tables from the source tables:

| Query | Output Table | Purpose |
|-------|-------------|---------|
| Q1 | `fact_loan_repayments` | Full repayment-level fact table with all dimensions joined |
| Q2 | `kpi_portfolio_summary` | Single-row portfolio KPI aggregation |
| Q3 | `dim_loan_type_analysis` | Write-off and collection metrics by loan product |
| Q4 | `dim_regional_analysis` | State and region-level risk metrics |
| Q5 | `dim_vintage_analysis` | Year-of-disbursement cohort analysis |
| Q6 | `dim_credit_risk` | Write-off rates by credit band × employment type |
| Q7 | `dim_collections_funnel` | Payment status funnel with recovery rates |
| Q8 | `dim_dpd_analysis` | Delinquency distribution across DPD buckets |

Key SQL techniques used: `WINDOW FUNCTIONS` (portfolio % share), `CASE` bucketing (DPD, credit band, LTI risk), `NULLIF` for safe division, `EXTRACT` for vintage year, `COUNTIF` / `FILTER` for conditional aggregation.

All queries are available in two dialects:
- **PostgreSQL** → `sql/` folder
- **BigQuery Standard SQL** → `bigquery/` folder

---

## ☁️ BigQuery Cloud Setup

This project includes a complete **BigQuery-compatible SQL variant** for teams running on GCP rather than on-premise PostgreSQL. All 5 SQL scripts have been ported with documented dialect adaptations.

### BigQuery SQL Files

| File | Original | Purpose |
|------|----------|---------|
| `bigquery/bq_01_customers_cleaning.sql` | `Customers_cleaning.sql` | Null checks, age/gender fixes, income imputation via MERGE |
| `bigquery/bq_02_loans_cleaning.sql` | `Loans_cleaning.sql` | Dedup via ROW_NUMBER, date type conversion via CREATE OR REPLACE |
| `bigquery/bq_03_repayments_cleaning.sql` | `repayments_cleaning.sql` | Date casting via SAFE_CAST, paid_date imputation via DATE_ADD |
| `bigquery/bq_04_eda.sql` | `EDA.sql` | UNENFORCED PK/FK constraints, master VIEW, 15 EDA queries |
| `bigquery/bq_05_portfolio_analysis.sql` | `Portfolio_analysis.sql` | All 8 Power BI dataset queries ported to BQ dialect |

### Key PostgreSQL → BigQuery Dialect Adaptations

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

### How to Run on BigQuery (Free Tier)

**Prerequisites:** Google account — no credit card required for sandbox

**Step 1 — Create a GCP Project**

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click **New Project** → name it `loan-portfolio-diagnostics`
3. Enable the **BigQuery API** (usually auto-enabled)

**Step 2 — Create a Dataset**

```bash
# Via bq CLI
bq mk --dataset loan_portfolio_diagnostics.nbfc_loans

# Or via Console: BigQuery → your project → Create Dataset
# Dataset ID: nbfc_loans | Location: asia-south1 (Mumbai) or US
```

**Step 3 — Load CSV Files**

Upload the 8 CSVs from `/data/` to BigQuery tables:

```bash
bq load \
  --autodetect \
  --source_format=CSV \
  --skip_leading_rows=1 \
  loan_portfolio_diagnostics.nbfc_loans.fact_loan_repayments \
  gs://your-bucket/fact_loan_repayments.csv
```

> **Tip:** Use BigQuery's **Auto-detect schema** for all 8 CSVs. Review `disbursement_date` / `due_date` columns — correct to `DATE` type if auto-detected as `STRING`.

**Step 4 — Run BigQuery SQL Scripts in order**

```
1. bq_01_customers_cleaning.sql    ← clean source tables first
2. bq_02_loans_cleaning.sql
3. bq_03_repayments_cleaning.sql
4. bq_04_eda.sql                   ← creates loan_master VIEW
5. bq_05_portfolio_analysis.sql    ← 8 analytical output tables
```

Replace `your_project.your_dataset` with your actual GCP project ID and dataset name.

**Step 5 — Connect Power BI to BigQuery**

1. Power BI Desktop → **Get Data** → **Google BigQuery**
2. Sign in with your Google account
3. Navigate to your project → `nbfc_loans` dataset
4. Load each of the 8 output tables

> **Alternative:** Connect [Looker Studio](https://lookerstudio.google.com) (free) directly to BigQuery for a shareable, browser-based live dashboard — no Power BI Desktop required for viewers.

### PostgreSQL vs BigQuery

| | PostgreSQL (local) | BigQuery (cloud) |
|--|-------------------|-----------------|
| Setup | Local install required | Browser-based, zero install |
| Scale | Limited by local RAM | Petabyte-scale serverless |
| Sharing | Share .sql files only | Share live query results |
| Cost | Free (local) | Free tier: 10 GB storage, 1 TB queries/month |
| BI connect | Direct or CSV export | Native Power BI + Looker Studio connectors |

BigQuery's free sandbox tier comfortably covers this entire project — the dataset is ~50 MB, well within the 10 GB free storage and 1 TB free query limits.

---

## How to Run

### PostgreSQL (Local)

**Prerequisites:** PostgreSQL 13+, Power BI Desktop (free)

**1. Set up the database**
```sql
psql -U your_user -d your_db -f sql/schema.sql
psql -U your_user -d your_db -f sql/seed_data.sql
```

**2. Run cleaning scripts in order**
```bash
psql -U your_user -d your_db -f sql/Customers_cleaning.sql
psql -U your_user -d your_db -f sql/Loans_cleaning.sql
psql -U your_user -d your_db -f sql/repayments_cleaning.sql
psql -U your_user -d your_db -f sql/EDA.sql
psql -U your_user -d your_db -f sql/Portfolio_analysis.sql
```

**3. Load into Power BI**
- Open Power BI Desktop → Get Data → Text/CSV → load all 8 CSV files
- Or: Get Data → PostgreSQL → paste each named query

**4. Open the dashboard**
- Open `powerbi/dashboard.pbix` and refresh data if prompted

### BigQuery (Cloud)

See the [BigQuery Cloud Setup](#️-bigquery-cloud-setup) section above.

---

## Project Structure

```
Loan-Portfolio-Diagnostics/
│
├── README.md
├── sql/                                  # PostgreSQL scripts
│   ├── Customers_cleaning.sql
│   ├── Loans_cleaning.sql
│   ├── repayments_cleaning.sql
│   ├── EDA.sql
│   └── Portfolio_analysis.sql
├── bigquery/                             # BigQuery (GCP) variants
│   ├── bq_01_customers_cleaning.sql
│   ├── bq_02_loans_cleaning.sql
│   ├── bq_03_repayments_cleaning.sql
│   ├── bq_04_eda.sql
│   └── bq_05_portfolio_analysis.sql
├── data/
│   ├── fact_loan_repayments.csv
│   ├── kpi_portfolio_summary.csv
│   ├── dim_loan_type_analysis.csv
│   ├── dim_vintage_analysis.csv
│   ├── dim_credit_risk.csv
│   ├── dim_dpd_analysis.csv
│   ├── dim_collections_funnel.csv
│   └── dim_regional_analysis.csv
├── powerbi/
│   ├── dashboard.pbix
│   └── dashboard_export.pdf
└── screenshots/
    ├── page1_portfolio_overview.png
    ├── page2_risk_analysis.png
    └── page3_collections_geography.png
```

---

*Synthetic dataset · PostgreSQL · BigQuery · GCP · Power BI · DAX · Built as a portfolio project demonstrating NBFC risk analytics*
