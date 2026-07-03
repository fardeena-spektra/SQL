# Instructor Brief — SQL Data Analysis Queries (Lab 01)

**Domain / Level:** SQL / Data Analysis · Intermediate · **Hosting tier A** (native CloudLabs Linux JumpVM running SQL Server 2022 on Linux, Ubuntu Server 22.04 LTS).
**Target time:** ~90 min work · **120 min** provisioned.
**Cloud field:** `azure` · **Level field:** `Intermediate`.

## Scenario

The candidate is a Data Analyst for a sales platform on SQL Server. The `SalesDB` database is pre-seeded with `dbo.Sales` (2,100 transactions, Jan–Jun 2026) and `dbo.CustomerStaging` (1,500 rows that intentionally repeat the same `CustomerId`). The candidate must deliver three analytical results **as named views** so the platform's reporting layer can consume them deterministically: a monthly **sales trend**, a **de-duplicated customer master**, and a **conditional-aggregation** breakdown of revenue by status. There is no Azure portal step — all work is over SSH with `sqlcmd`.

## Environment (seeded by `DeploymentPackage/bootstrap-01.sh`)

- **One SQL Server 2022 on Linux node** (`Standard_D2s_v3`): `labvm-<DeploymentID>` (`10.0.0.4`, hostname `labvm`). The bootstrap installs `mssql-server` + `mssql-tools`, sets the **SA** password to `NedSQL@1234!`, and accepts the EULA (Developer edition).
- The bootstrap seeds **`SalesDB`** deterministically:
  - **`dbo.Sales`** — 2,100 rows, every `Amount = 10.00`, dated 2026-01 … 2026-06; month *m* has `100*m` rows. Columns: `SaleId, SaleDate, Amount, Region, Category, Status`.
  - **`dbo.CustomerStaging`** — 1,500 rows = **500 distinct `CustomerId`** × 3 duplicate loads with different `LoadDate`/`Tier`. Columns: `StagingId, CustomerId, CustomerName, Region, Tier, LoadDate`.

## Seeded ground truth (answer key)

| Result the candidate must produce | Required view | Expected value |
|---|---|---|
| Monthly sales trend | `dbo.vw_SalesTrend` (`SalesPeriod`, `TotalAmount`) | **6 rows**; monthly 1000/2000/3000/4000/5000/6000; `SUM(TotalAmount)` = **21000** |
| De-duplicated customers (latest per id) | `dbo.vw_DedupedCustomers` (incl. `CustomerId`) | **500 rows**, 500 distinct `CustomerId` |
| Sales by status (pivot) | `dbo.vw_SalesByStatus` (`OpenAmount`, `ShippedAmount`, `ClosedAmount`) | **10500 / 6300 / 4200** |

Reference T-SQL for all three views is in `LabGuidePackage/Solution-Guide/solution-guide.md`.

## Scoring rubric (100 pts)

| Item | Pts | Pass criteria (validator) |
|---|---|---|
| Ex1 — `dbo.vw_SalesTrend` (6 periods, total 21000) | 34 | validate-task1-sales-trend.ps1 → Succeeded |
| Ex2 — `dbo.vw_DedupedCustomers` (500 distinct) | 33 | validate-task2-dedupe-customers.ps1 → Succeeded |
| Ex3 — `dbo.vw_SalesByStatus` (10500/6300/4200) | 33 | validate-task3-conditional-agg.ps1 → Succeeded |

Pass ≥ 34 (at least one task fully complete). Intermediate sign-off = 100 with **all three** tasks passing.

## Notes / caveats

- Validators run in-VM via the CloudLabs VM Agent (PowerShell HTTP-trigger functions) against the node with `sqlcmd`; HTTP is always `OK` and pass/fail lives in the JSON `Status` field. They only read the candidate's views and are safe to re-run.
- Each validator `CAST(... AS INT)` before comparing, so a candidate view that returns `21000.00` (decimal) still matches `21000`. The seeded amounts are whole numbers by design.
- The candidate may define the view columns with any logic that yields the required values, but the **column names are required** (`SalesPeriod`/`TotalAmount`, `CustomerId`, `OpenAmount`/`ShippedAmount`/`ClosedAmount`) because the validators read columns by name.
- `sqlcmd` may be at `/opt/mssql-tools/bin/sqlcmd` or `/opt/mssql-tools18/bin/sqlcmd` (the validators try both; the v18 path adds `-C` to trust the self-signed cert). SA password is `NedSQL@1234!`.
- SQL Server package install needs **internet access at deploy time**. The bootstrap guards every install step so the CSE never hard-fails; if install was blocked, `sqlcmd` will be absent and all three validators report `Failed` until SQL Server is present.
- The working user is `labuser` (ARM `trainerUserName` / `adminUsername`); `README.txt` with credentials and the seeded-table summary is written to `/home/labuser`.
