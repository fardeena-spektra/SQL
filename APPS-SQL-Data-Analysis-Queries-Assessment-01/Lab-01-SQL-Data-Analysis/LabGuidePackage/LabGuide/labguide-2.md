# Exercise 2: Remove Duplicates with Ranking

### Estimated Duration: 30 Minutes

## Lab Overview

A nightly load appended customer records to **`dbo.CustomerStaging`** in `SalesDB` without de-duplicating, so the **same `CustomerId` now appears several times**, each copy carrying a different `LoadDate` (and sometimes a different `Tier`). Downstream reports double-count these customers. You must produce a clean list that keeps **only the most recent row per customer**, using a **ranking function**, and publish it as a view.

This is an **assessment**: the task gives you the **required outcome** and the **exact view contract** the validator checks — not the steps. Write the T-SQL yourself, then press **Validate** to score it.

> **Note:** Connect to the SQL node over SSH and use `sqlcmd` with the **SA** login. The staging table columns are `StagingId, CustomerId, CustomerName, Region, Tier, LoadDate`.

## Task 1: Build the de-duplicated customer view

**Goal:** Collapse the duplicate rows in `dbo.CustomerStaging` so that **each `CustomerId` appears exactly once**, keeping the **latest load** (the row with the most recent `LoadDate`) for that customer.

**Required outcome — create the view `dbo.vw_DedupedCustomers`:**

- It returns **one row per distinct `CustomerId`** — no duplicates remain.
- For each customer, the surviving row is the one with the **maximum `LoadDate`** (the latest load).
- The view must expose at least the **`CustomerId`** column (carry `CustomerName`, `Region`, `Tier`, and `LoadDate` through as well so the result is a usable customer master).

Use a **ranking window function** — `ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY LoadDate DESC)` (or `RANK()`) — in a CTE or subquery, then keep only the rows ranked `1`. The validator confirms the view's row count equals the number of **distinct** customers in the staging table (proving every duplicate was removed) and that **no `CustomerId` repeats** in the view.

> **Congratulations** on completing the task! Now, it's time to validate it. Here are the steps:
> - Hit the Validate button for the corresponding task. If you receive a success message, you can proceed to the next task.
> - If not, carefully read the error message and retry the step, following the instructions in the lab guide.
> - If you need any assistance, please contact us at labs-support@spektrasystems.com. We are available 24/7 to help you out.

<validation step="e743fde9-f4a2-45b5-943b-7e8be60b1eda" />
