<#
Written by KalashniKorv
#>

# Config of authentication, tags, API, and output
# This configuration is based by running with Client ID and Secret which has cost reader RBAC in the root of the desired subscription or management group.
# Instead of hardcoded client ID and Client Secret, you can fetch these from Azure Key Vault. Just give the Azure Runbook access to the key vault with List and Get rights for secrets.
$TenantId       = "<insert tenant ID>"
$ClientId       = "<insert client ID>"
$ClientSecret   = "<Insert client secret>"
$SubscriptionId = "<Insert Subscription ID>"
$TagName        = "<Insert Tagname>"   # Change to your tag name, Example "Cost Center"
# Below is just used if you want specific dates
#$StartDate      = (Get-Date).ToString("yyyy-MM-dd")
#$EndDate        = (Get-Date).ToString("yyyy-MM-dd")
#Specify which version of Management API version you want
$ApiVersion     = "2023-03-01"
#Name and location of file output
$OutputCsv      = "CostByTag.csv"


# Retrievel of authentication token for management API
$TokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/token"
$Resource      = "https://management.azure.com/"

$Body = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    resource      = $Resource
}

$TokenResponse = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $Body -ContentType "application/x-www-form-urlencoded"
$AccessToken   = $TokenResponse.access_token
Write-Host "Access Token Acquired" -ForegroundColor Green


# Cost API body

$Uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/query?api-version=$ApiVersion"

$Headers = @{
    Authorization = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

$RequestBody = @{
    type      = "Usage"
    timeframe = "MonthToDate"
    <#timePeriod = @{
        from = $StartDate
        to   = $EndDate
    }#>
    dataset = @{
        granularity = "Monthly"
        dimensions = @{
            filter = @{
                }
                 tags = @{
                    key = $TagName
            }
        }
        aggregation = @{
            totalCost = @{
                name     = "Cost"
                function = "Sum"
                tags = "Tags"
            }
        }
        grouping = @(
            @{
                type = "TagKey"
                name = "Key Value1"
            }<#,
            @{ Add or remove if you want several tag values in cost output
                type = "TagKey"
                name = "Keyvalue 2"
            }#>
        )
    }    
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body $RequestBody


# Process the results from API 

$rows = $response.properties.rows

$columns = $response.properties.columns | ForEach-Object { $_.name }


foreach ($row in $response.properties.rows) {
    #Removing commas from output
    $row[0] = [math]::Floor($row[0]) 
}

foreach ($row in $response.properties.rows) {
    #removing extra information from date output
    $row[1] = ([datetime]$row[1]).ToString("MMMM d, yyyy")
}

# creates rows and columns from output
$results = foreach ($row in $rows) {
    $obj = [ordered]@{}
    for ($i = 0; $i -lt $columns.Count; $i++) {
        $obj[$columns[$i]] = $row[$i]
    }
    [PSCustomObject]$obj
}


# Format and display

$results | Sort-Object Cost -Descending | Format-Table -AutoSize



# Export to CSV
$results | Export-Csv -Path $OutputCsv -NoTypeInformation
Write-Host "Results exported to $OutputCsv" -ForegroundColor Cyan