# CloudLabs by Spektra Systems | Facilitator Solution Guide (NOT for candidates)

## APPS-SQL-Data-Analysis-Queries-Assessment-01: Answer Key + Walkthrough

This document mirrors the candidate exercise order. Each task lists the objective, the seeded ground truth, the reference T-SQL (run via `sqlcmd` on the single SQL node), the expected result, and the validation expectation. All work is performed over SSH on one Ubuntu node running SQL Server 2022 for Linux. The **SA** password is `NedSQL@1234!`; `sqlcmd` is at `/opt/mssql-tools/bin/sqlcmd` (or `/opt/mssql-tools18/bin/sqlcmd -C`).

```bash
SQLCMD=/opt/mssql-tools/bin/sqlcmd      # or: /opt/mssql-tools18/bin/sqlcmd -C
$SQLCMD -S localhost -U SA -P 'NedSQL@1234!' -d SalesDB -Q "..."
```

---

## Seeded ground truth (facilitator reference)

The bootstrap (`DeploymentPackage/bootstrap-01.sh`) seeds `SalesDB` **deterministically**, so each task has a single correct answer:

- **`dbo.Sales`** — 2,100 rows, every row `Amount = 10.00`, dated across 6 months (2026-01 … 2026-06). Per month *m* there are `100*m` rows, so:
  - **Grand total `SUM(Amount)` = 21000.00**
  - **Distinct trend periods = 6**
  - **Monthly totals:** 2026-01 = 1000, 2026-02 = 2000, 2026-03 = 3000, 2026-04 = 4000, 2026-05 = 5000, 2026-06 = 6000
  - **Per-status totals:** `OPEN` = **10500**, `SHIPPED` = **6300**, `CLOSED` = **4200** (10500 + 6300 + 4200 = 21000)
- **`dbo.CustomerStaging`** — 1,500 rows = **500 distinct `CustomerId`** values, each loaded **3 times** with `LoadDate` of 2026-01-02, 2026-01-03, 2026-01-04 (latest = `Tier = 'Gold'`). After de-dup the unique count is **500**.

| Metric the validators assert | Value |
|---|---|
| `dbo.vw_SalesTrend` row count | **6** |
| `SUM(TotalAmount)` over `dbo.vw_SalesTrend` | **21000** |
| `dbo.vw_DedupedCustomers` row count = distinct customers | **500** |
| `dbo.vw_SalesByStatus.OpenAmount` | **10500** |
| `dbo.vw_SalesByStatus.ShippedAmount` | **6300** |
| `dbo.vw_SalesByStatus.ClosedAmount` | **4200** |

---

## Exercise 1 / Task 1 — Sales Trend Analysis (view `dbo.vw_SalesTrend`)

**Objective:** Aggregate `dbo.Sales` to one row per month (`SalesPeriod`, `TotalAmount`), so the monthly totals form a trend and `SUM(TotalAmount)` reproduces the grand total.

**Diagnosis / explore:**

```sql
-- Confirm the grand total and how many months are present.
SELECT COUNT(*) AS Rows, SUM(Amount) AS GrandTotal, COUNT(DISTINCT FORMAT(SaleDate,'yyyy-MM')) AS Months
FROM dbo.Sales;        -- expect 2100, 21000.00, 6
```

**Fix — create the view:**

```sql
CREATE OR ALTER VIEW dbo.vw_SalesTrend
AS
SELECT
    FORMAT(SaleDate, 'yyyy-MM')      AS SalesPeriod,
    SUM(Amount)                      AS TotalAmount
FROM dbo.Sales
GROUP BY FORMAT(SaleDate, 'yyyy-MM');
GO
```

Equivalent acceptable forms: `GROUP BY YEAR(SaleDate), MONTH(SaleDate)` with a derived `SalesPeriod`, or `GROUP BY DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)`.

**Expected result:**

```sql
SELECT * FROM dbo.vw_SalesTrend ORDER BY SalesPeriod;
-- 2026-01 1000.00 / 2026-02 2000.00 / 2026-03 3000.00 / 2026-04 4000.00 / 2026-05 5000.00 / 2026-06 6000.00
SELECT COUNT(*) AS Periods, SUM(TotalAmount) AS Total FROM dbo.vw_SalesTrend;  -- 6, 21000.00
```

**Validation:** `validate-task1-sales-trend.ps1` runs `sqlcmd` on the node and passes when `dbo.vw_SalesTrend` exists **and** `COUNT(*) = 6` **and** `CAST(SUM(TotalAmount) AS INT) = 21000`.

---

## Exercise 2 / Task 1 — Remove Duplicates with Ranking (view `dbo.vw_DedupedCustomers`)

**Objective:** Keep exactly one row per `CustomerId` — the latest `LoadDate` — using a ranking window function, so the view returns the 500 distinct customers.

**Diagnosis / explore:**

```sql
SELECT COUNT(*) AS StagedRows, COUNT(DISTINCT CustomerId) AS DistinctCustomers
FROM dbo.CustomerStaging;     -- expect 1500, 500
```

**Fix — create the view:**

```sql
CREATE OR ALTER VIEW dbo.vw_DedupedCustomers
AS
WITH ranked AS (
    SELECT
        CustomerId, CustomerName, Region, Tier, LoadDate,
        ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY LoadDate DESC) AS rn
    FROM dbo.CustomerStaging
)
SELECT CustomerId, CustomerName, Region, Tier, LoadDate
FROM ranked
WHERE rn = 1;
GO
```

`RANK()` works too, but if any customer had tied `LoadDate` values `RANK()`/`DENSE_RANK()` could return more than one row per key; `ROW_NUMBER()` guarantees exactly one. In this seed each customer's three `LoadDate`s are distinct, so all three approaches return 500.

**Expected result:**

```sql
SELECT COUNT(*) AS Customers, COUNT(DISTINCT CustomerId) AS Distinct_Ids
FROM dbo.vw_DedupedCustomers;   -- 500, 500  (every surviving row is a unique customer)
```

**Validation:** `validate-task2-dedupe-customers.ps1` runs `sqlcmd` on the node and passes when `dbo.vw_DedupedCustomers` exists **and** `COUNT(*) = 500` **and** `COUNT(DISTINCT CustomerId) = 500` (row count equals the distinct customer count, proving duplicates were removed).

---

## Exercise 3 / Task 1 — Conditional Aggregation (view `dbo.vw_SalesByStatus`)

**Objective:** Produce a one-row pivot of total revenue by status with `SUM(CASE WHEN …)`, exposing `OpenAmount`, `ShippedAmount`, `ClosedAmount`.

**Diagnosis / explore:**

```sql
SELECT Status, SUM(Amount) AS Total FROM dbo.Sales GROUP BY Status;
-- OPEN 10500.00 / SHIPPED 6300.00 / CLOSED 4200.00  (rows; the task asks for these as COLUMNS)
```

**Fix — create the view:**

```sql
CREATE OR ALTER VIEW dbo.vw_SalesByStatus
AS
SELECT
    SUM(CASE WHEN Status = 'OPEN'    THEN Amount ELSE 0 END) AS OpenAmount,
    SUM(CASE WHEN Status = 'SHIPPED' THEN Amount ELSE 0 END) AS ShippedAmount,
    SUM(CASE WHEN Status = 'CLOSED'  THEN Amount ELSE 0 END) AS ClosedAmount
FROM dbo.Sales;
GO
```

**Expected result:**

```sql
SELECT * FROM dbo.vw_SalesByStatus;   -- OpenAmount 10500.00 | ShippedAmount 6300.00 | ClosedAmount 4200.00
```

**Validation:** `validate-task3-conditional-agg.ps1` runs `sqlcmd` on the node and passes when `dbo.vw_SalesByStatus` exists **and** `CAST(OpenAmount AS INT) = 10500` **and** `CAST(ShippedAmount AS INT) = 6300` **and** `CAST(ClosedAmount AS INT) = 4200`.

---

### Facilitator Notes

- All three validators run in-VM via the CloudLabs VM Agent (PowerShell HTTP-trigger functions) against the SQL node with `sqlcmd`; HTTP is always `OK` and pass/fail lives in the JSON `Status` field. They are read-only state checks (they only read the candidate's views) and are safe to re-run.
- Each validator `CAST(... AS INT)` before comparing so the decimal portion (e.g. `21000.00`) does not affect the digit comparison; the seeded amounts are whole numbers by design.
- SQL Server install needs internet access at deploy time; the bootstrap guards every install step so the CSE never hard-fails. If install was blocked, `sqlcmd` is absent and all three validators report `Failed` until SQL Server is present. The SA password is `NedSQL@1234!`.
- The seed is deterministic: re-running the bootstrap drops and recreates `dbo.Sales` and `dbo.CustomerStaging`, restoring the exact ground-truth totals above. Candidate views are not dropped by re-validation.
