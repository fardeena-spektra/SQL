Import-Module Az.Compute
Import-Module Az.Accounts

# Validation step: 5c000002-0002-4a02-8b02-000000000002
# Exercise 2 / Task 1 - Remove Duplicates with Ranking (view dbo.vw_DedupedCustomers: 500 distinct)

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
# Passes when the view dbo.vw_DedupedCustomers exists in SalesDB AND its row
# count equals the seeded DISTINCT customer count (500) AND no CustomerId
# repeats in the view (COUNT(*) = COUNT(DISTINCT CustomerId) = 500), proving the
# duplicate staging rows were removed.
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
"SET NOCOUNT ON; SELECT COUNT(*) FROM sys.views WHERE name='vw_DedupedCustomers';" 2>/dev/null)
view_exists=$(echo "$view_exists" | tr -dc '0-9')

row_count=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.vw_DedupedCustomers;" 2>/dev/null)
row_count=$(echo "$row_count" | tr -dc '0-9')

distinct_count=$("$SQLCMD" $SQLARGS -S localhost -U SA -P "$SA_PASSWORD" -d SalesDB -h -1 -W -Q \
"SET NOCOUNT ON; SELECT COUNT(DISTINCT CustomerId) FROM dbo.vw_DedupedCustomers;" 2>/dev/null)
distinct_count=$(echo "$distinct_count" | tr -dc '0-9')

if [ -n "$view_exists" ] && [ "$view_exists" -ge 1 ] && \
   [ -n "$row_count" ] && [ "$row_count" -eq 500 ] && \
   [ -n "$distinct_count" ] && [ "$distinct_count" -eq 500 ]; then
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
                Message = "View dbo.vw_DedupedCustomers exists on VM '$vmName' and returns exactly 500 rows with 500 distinct CustomerId values, matching the seeded distinct customer count - the 1500 staged duplicate rows were de-duplicated correctly."
            } | ConvertTo-Json
        }
        else {

            $message = @{
                Status  = "Failed"
                Message = "The de-duplicated customer view is not correct on VM '$vmName'. Create view dbo.vw_DedupedCustomers that keeps one row per CustomerId (the latest LoadDate) using ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY LoadDate DESC); it must return 500 rows with no repeated CustomerId."
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
