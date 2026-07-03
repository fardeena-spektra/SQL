# Exercise 3: Complex Query with Conditional Aggregation

### Estimated Duration: 30 Minutes

## Lab Overview

Leadership wants a single-glance breakdown of total revenue split by order **status** — how much is `OPEN`, how much has `SHIPPED`, and how much is `CLOSED` — laid out as **columns** rather than rows, so it can drop straight into a dashboard. This is a classic **conditional aggregation** (pivot-style) problem: one pass over `dbo.Sales` with `SUM(CASE WHEN …)` per status. You must publish the result as a view.

This is an **assessment**: the task gives you the **required outcome** and the **exact view contract** the validator checks — not the steps. Write the T-SQL yourself, then press **Validate** to score it.

> **Note:** Connect to the SQL node over SSH and use `sqlcmd` with the **SA** login. The `dbo.Sales` table carries a `Status` column whose values are `OPEN`, `SHIPPED`, and `CLOSED`.

## Task 1: Build the sales-by-status conditional-aggregation view

**Goal:** Produce a **single-row** pivot of total revenue by status, with one column per status, using conditional aggregation over the whole `dbo.Sales` table.

**Required outcome — create the view `dbo.vw_SalesByStatus` with these columns:**

| Column | Definition |
|---|---|
| `OpenAmount` | `SUM(CASE WHEN Status = 'OPEN' THEN Amount ELSE 0 END)` |
| `ShippedAmount` | `SUM(CASE WHEN Status = 'SHIPPED' THEN Amount ELSE 0 END)` |
| `ClosedAmount` | `SUM(CASE WHEN Status = 'CLOSED' THEN Amount ELSE 0 END)` |

The view returns **exactly one row** holding the three status totals as separate columns. The three amounts must add up to the grand total of `dbo.Sales` (every sale falls into exactly one status). The **column names `OpenAmount`, `ShippedAmount`, and `ClosedAmount` are required** — the validator reads each one and compares it to the seeded per-status total.

Build it with a single `SELECT` over `dbo.Sales` using `SUM(CASE WHEN Status = … THEN Amount ELSE 0 END)` for each status (no `GROUP BY` is needed for a single summary row).

> **Congratulations** on completing the task! Now, it's time to validate it. Here are the steps:
> - Hit the Validate button for the corresponding task. If you receive a success message, you can proceed to the next task.
> - If not, carefully read the error message and retry the step, following the instructions in the lab guide.
> - If you need any assistance, please contact us at labs-support@spektrasystems.com. We are available 24/7 to help you out.

<validation step="9b6f6e09-a0f0-47a8-9b82-abd4b39556bc" />
