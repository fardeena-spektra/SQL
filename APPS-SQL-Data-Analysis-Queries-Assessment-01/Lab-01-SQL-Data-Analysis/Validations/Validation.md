[CloudLabs Validator](https://spektra-systems.visualstudio.com/CloudLabs-Validator)

Lab Code: SQLDATAANALYSISLAB01

> Validations for this assessment run **in-VM** via the CloudLabs VM Agent (PowerShell HTTP-trigger
> functions) against the SQL node using `sqlcmd`. Each task maps to a script in this folder,
> keyed by its `<validation step="…"/>` UUID. Every validator retries up to 3 times
> (`Start-Sleep -Seconds 10`), always returns HTTP `OK`, and carries the pass/fail in the JSON `Status`
> field (`Succeeded`/`Failed`). The validators only read the candidate's views, so they are safe to re-run.

| Task | Validation step UUID | Script |
|---|---|---|
| Exercise 1 / Task 1 — Sales Trend Analysis (view dbo.vw_SalesTrend) | 5c000001-0001-4a01-8b01-000000000001 | validate-task1-sales-trend.ps1 |
| Exercise 2 / Task 1 — Remove Duplicates with Ranking (view dbo.vw_DedupedCustomers) | 5c000002-0002-4a02-8b02-000000000002 | validate-task2-dedupe-customers.ps1 |
| Exercise 3 / Task 1 — Conditional Aggregation (view dbo.vw_SalesByStatus) | 5c000003-0003-4a03-8b03-000000000003 | validate-task3-conditional-agg.ps1 |
