Import-Module Az.Compute
Import-Module Az.Accounts

# Validation step: 5c000003-0003-4a03-8b03-000000000003
# Exercise 3 / Task 1 - Conditional Aggregation (view dbo.vw_SalesByStatus: 10500 / 6300 / 4200)

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
# Passes when the view dbo.vw_SalesByStatus exists in SalesDB AND its
# conditional-aggregation columns match the seeded per-status totals:
#   OpenAmount = 10500, ShippedAmount = 6300, ClosedAmount = 4200.
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
"SET NOCOUNT ON; SELECT COUNT(*) FROM sys.views WHERE name='vw_SalesByStatus';" 2>/dev/null)
view_exists=$(echo "$view_exists" | tr -dc '0-9')

open_amt=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT CAST(OpenAmount AS INT) FROM dbo.vw_SalesByStatus;" 2>/dev/null)
open_amt=$(echo "$open_amt" | tr -dc '0-9')

shipped_amt=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT CAST(ShippedAmount AS INT) FROM dbo.vw_SalesByStatus;" 2>/dev/null)
shipped_amt=$(echo "$shipped_amt" | tr -dc '0-9')

closed_amt=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT CAST(ClosedAmount AS INT) FROM dbo.vw_SalesByStatus;" 2>/dev/null)
closed_amt=$(echo "$closed_amt" | tr -dc '0-9')

if [ -n "$view_exists" ] && [ "$view_exists" -ge 1 ] && \
   [ -n "$open_amt" ]    && [ "$open_amt" -eq 10500 ] && \
   [ -n "$shipped_amt" ] && [ "$shipped_amt" -eq 6300 ] && \
   [ -n "$closed_amt" ]  && [ "$closed_amt" -eq 4200 ]; then
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
                Message = "View dbo.vw_SalesByStatus exists on VM '$vmName' and its conditional-aggregation columns match the seeded totals: OpenAmount = 10500, ShippedAmount = 6300, ClosedAmount = 4200."
            } | ConvertTo-Json
        }
        else {

            $message = @{
                Status  = "Failed"
                Message = "The conditional-aggregation view is not correct on VM '$vmName'. Create view dbo.vw_SalesByStatus with columns OpenAmount, ShippedAmount, ClosedAmount using SUM(CASE WHEN Status = '<value>' THEN Amount ELSE 0 END); the values must equal 10500, 6300 and 4200 respectively."
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
