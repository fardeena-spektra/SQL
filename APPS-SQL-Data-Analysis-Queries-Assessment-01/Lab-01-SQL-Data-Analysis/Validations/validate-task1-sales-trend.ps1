Import-Module Az.Compute
Import-Module Az.Accounts

# Validation step: 5c000001-0001-4a01-8b01-000000000001
# Exercise 1 / Task 1 - Sales Trend Analysis (view dbo.vw_SalesTrend: 6 periods, total = 21000)

# Variables provided by CloudLabs
$deployment_id     = $deployment_id
$resourceGroupName = $resourceGroupName
$sub_id            = $sub_id
$vmName            = "labvm-$deployment_id"

# Set subscription
Select-AzSubscription -SubscriptionId $sub_id

# Retry logic
$stopRetry = $false
[int]$retryCount = 0
$maxRetries = 3

do {
    try {

        # Script to run inside VM. It must echo the sentinel "Validation Success"
        # ONLY when every check passes; otherwise echo "Validation Failed".
        $script = @'
#!/bin/bash
# Passes when the view dbo.vw_SalesTrend exists in SalesDB AND returns exactly 6
# period rows AND SUM(TotalAmount) equals the seeded grand total (21000).
# If sqlcmd is missing/unreachable, prints "Validation Failed". Always exits 0.
SQLCMD=/opt/mssql-tools/bin/sqlcmd
SQLARGS=""
if [ ! -x "$SQLCMD" ]; then
    if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
        SQLCMD=/opt/mssql-tools18/bin/sqlcmd
        SQLARGS="-C"
    else
        echo "Validation Failed"
        exit 0
    fi
fi

SA_PASSWORD='NedSQL@1234!'

view_exists=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT COUNT(*) FROM sys.views WHERE name='vw_SalesTrend';" 2>/dev/null)
view_exists=$(echo "$view_exists" | tr -dc '0-9')

period_count=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.vw_SalesTrend;" 2>/dev/null)
period_count=$(echo "$period_count" | tr -dc '0-9')

total_amount=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT CAST(SUM(TotalAmount) AS INT) FROM dbo.vw_SalesTrend;" 2>/dev/null)
total_amount=$(echo "$total_amount" | tr -dc '0-9')

if [ -n "$view_exists" ] && [ "$view_exists" -ge 1 ] && \
   [ -n "$period_count" ] && [ "$period_count" -eq 6 ] && \
   [ -n "$total_amount" ] && [ "$total_amount" -eq 21000 ]; then
    echo "Validation Success"
else
    echo "Validation Failed"
fi
exit 0
'@

        # Execute inside VM
        $result = Invoke-AzVMRunCommand `
            -ResourceGroupName $resourceGroupName `
            -VMName $vmName `
            -CommandId "RunShellScript" `
            -ScriptString $script

        $vmOutput = ($result.Value[0].Message | Out-String).Trim()

        if ($vmOutput -match "Validation Success") {

            $message = @{
                Status  = "Succeeded"
                Message = "View dbo.vw_SalesTrend exists on VM '$vmName', returns 6 monthly period rows, and SUM(TotalAmount) = 21000 (matches the seeded grand total of dbo.Sales)."
            } | ConvertTo-Json
        }
        else {

            $message = @{
                Status  = "Failed"
                Message = "The sales-trend view is not correct on VM '$vmName'. Create view dbo.vw_SalesTrend with columns SalesPeriod and TotalAmount, grouping dbo.Sales by month so it returns one row per month (6 rows) and SUM(TotalAmount) equals the grand total (21000)."
            } | ConvertTo-Json
        }

        # Return JSON response
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::OK
            Body       = $message
        })

        $stopRetry = $true
    }
    catch {

        if ($retryCount -ge $maxRetries) {

            $message = @{
                Status  = "Failed"
                Message = "Retry for validation process has been exhausted. Please try after sometime."
            } | ConvertTo-Json

            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [System.Net.HttpStatusCode]::OK
                Body       = $message
            })

            $stopRetry = $true
        }
        else {
            Write-Host "Validation failed. Retrying... ($($retryCount + 1)/$maxRetries)"
            Start-Sleep -Seconds 10
            $retryCount++
        }
    }

} while ($stopRetry -eq $false)
