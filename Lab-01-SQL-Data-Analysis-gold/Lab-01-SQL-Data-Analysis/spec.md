This Package Includes

Deliverables Included in the Package

• Lab Guide
• Master Document
• Inline Validations
• ARM Deployment + Custom Script Extension
• Solution Guide (facilitator-only)
• Instructor Brief (facilitator-only)

Inline Validations

Pre-configured inline validations enabled (3 task validations, in-VM via CloudLabs VM Agent — PowerShell, executed against the SQL node with sqlcmd). Each task maps to a validation script keyed by a validation-step UUID; see Validations/Validation.md.

Inline Assessment Questions

Not included in this package (knowledge-check questions are out of scope for this assessment).

Lab Environment Setup & Deployment

Lab provisioning and setup include one or more of the following components:

• ARM template deployment — ONE CloudLabs Linux JumpVM (Ubuntu Server 22.04 LTS, Standard_D2s_v3) running SQL Server 2022 for Linux: labvm-<DeploymentID> (10.0.0.4), on a VNet/subnet
• Custom Script Extension (CSE / Bash) — installs mssql-server + mssql-tools and seeds the SalesDB analytics database deterministically: dbo.Sales (2,100 rows, Jan–Jun 2026, a clean monthly trend and fixed per-status totals) and dbo.CustomerStaging (1,500 rows with deliberate duplicate CustomerId values over 500 distinct customers)
• NSG allows SSH (22) from anywhere and SQL (1433) within the VNet
• Supporting deployment configurations as required

Assessment Profile

• Domain: SQL / Data Analysis
• Level: Intermediate
• Target duration: 120 minutes (120 minutes provisioned)
• Hosting tier: A (native — Azure Linux VM running SQL Server on Linux, single node, Standard_D2s_v3)

Scenario & Validation Summary

• Exercise 1 / Task 1 — Sales Trend Analysis: build view dbo.vw_SalesTrend (one row per month, total per period) → validate-task1-sales-trend.ps1
• Exercise 2 / Task 1 — Remove Duplicates with Ranking: build view dbo.vw_DedupedCustomers (latest row per CustomerId) → validate-task2-dedupe-customers.ps1
• Exercise 3 / Task 1 — Complex Query with Conditional Aggregation: build view dbo.vw_SalesByStatus (SUM(CASE WHEN Status …) pivot) → validate-task3-conditional-agg.ps1

ASSESSMENT MODEL (deterministic, auto-gradable)

The candidate publishes three named views over the seeded data so the validators can check results deterministically. The seed is engineered so each query has a single known answer: the sales-trend view returns 6 period rows summing to 21000; the dedup view returns exactly 500 distinct customers (from 1500 staged rows); and the conditional-aggregation view returns OpenAmount = 10500, ShippedAmount = 6300, ClosedAmount = 4200. The required view names and columns are stated in each lab guide.

Note: SQL Server package installation requires internet access at deploy time; the bootstrap guards every install step so the CSE never hard-fails.

Exclusions

This package does not include:

• Scoring or grading mechanisms beyond pass/fail inline validations
• Inline assessment questions
• Any multi-node / high-availability configuration (single-node query-analysis lab)
