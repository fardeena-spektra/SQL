# Exercise 1: Sales Trend Analysis

### Estimated Duration: 30 Minutes

## Lab Overview

The business wants to see how revenue moves **over time**. The **`dbo.Sales`** table in **`SalesDB`** holds 2,100 sales transactions dated across the first half of 2026, each with an `Amount`, `Region`, `Category`, and `Status`. Your job is to aggregate revenue **by month** and publish the result as a reusable view so reporting tools can read a clean, one-row-per-period trend.

This is an **assessment**: the task gives you the **required outcome** and the **exact view contract** the validator checks — not the steps. Write the T-SQL yourself, then press **Validate** to score it.

> **Note:** Connect to the SQL node over SSH and use `sqlcmd` with the **SA** login (password in `/home/labuser/README.txt`), e.g. `/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'NedSQL@1234!' -d SalesDB`.

## Task 1: Build the monthly sales-trend view

**Goal:** Aggregate `dbo.Sales` so there is exactly **one row per calendar month**, with the total revenue for that month, and expose it as a view the reporting layer can query.

**Required outcome — create the view `dbo.vw_SalesTrend` with these columns:**

| Column | Meaning |
|---|---|
| `SalesPeriod` | The period identifier — one distinct value per month (e.g. `'2026-01'`, or the month-start date). |
| `TotalAmount` | The **`SUM(Amount)`** of all sales in that period. |

The view must return **one row per month present in the data** (group by the year-and-month of `SaleDate`). Across all rows, **`SUM(TotalAmount)` must equal the grand total of `dbo.Sales`** — i.e. summing the view reproduces the full revenue with nothing double-counted or dropped.

Use `GROUP BY` over a month expression derived from `SaleDate` (for example `FORMAT(SaleDate, 'yyyy-MM')`, or `YEAR(SaleDate), MONTH(SaleDate)`, or `DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)`). Order is not graded, but the **column names `SalesPeriod` and `TotalAmount` are required**.

> **Congratulations** on completing the task! Now, it's time to validate it. Here are the steps:
> - Hit the Validate button for the corresponding task. If you receive a success message, you can proceed to the next task.
> - If not, carefully read the error message and retry the step, following the instructions in the lab guide.
> - If you need any assistance, please contact us at labs-support@spektrasystems.com. We are available 24/7 to help you out.

<validation step="1057d158-eec2-4943-a1bf-edd8b59872c9" />
