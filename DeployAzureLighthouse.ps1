param (
    [parameter(mandatory)][string]$ManagementGroupName,
    [parameter(mandatory)][string]$Location,
    [parameter(mandatory)][string]$ResourceGroupName
)

$ManagementGroup = Get-AzManagementGroup | Where-Object { $_.displayName -eq $ManagementGroupName }

$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $managementGroup.Name

ForEach ($subscription in $subscriptions) {
    Write-Host "Deploying Azure Lighthouse to"$subscription.Name -ForegroundColor Cyan
    Set-AzContext -Subscription $subscription.subscriptionId
    New-AzSubscriptionDeployment -Location $Location -TemplateFile .\subscription.template.json
}

Write-Host "Deployed Azure Lighthouse to subscription/s under" $managementGroup.DisplayName -ForegroundColor Cyan

Write-Host "Deploying Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan

# Subscription List
$subList = @()
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } |  ForEach-Object{
    if(($_.SubscriptionPolicies.QuotaId -notlike "Internal*") -and ($_.SubscriptionPolicies.QuotaId -notlike "AAD*")){
        [pscustomobject]@{
            Name=$_.Name
            Id=$_.Id
        }
    }
    $subList += $_ | Select-Object Name, Id
}

# Select Subscription
if ($subList.Count -gt 1) {

    $selectedIndex=0
    for ($i=0; $i -lt $subList.Count; $i++) {
        Write-Output "[$i] $($subList[$i].Name)"    
    }

    $lastSubscriptionIndex = $subscriptions.Count - 1
    while ($selectedIndex -lt 0 -or $selectedIndex -gt $lastSubscriptionIndex+1) {
        Write-Output "---"
        $selectedIndex = [int] (Read-Host "Please, select the target subscription for this deployment [0..$lastSubscriptionIndex]")
    }  

    Write-Host "Getting Azure subscriptions (filtering out unsupported ones)..." -ForegroundColor Green
    $subscriptionId = $subList[$selectedIndex].Id

    if ($ctx.Subscription.Id -ne $subscriptionId) {
        $ctx = Select-AzSubscription -SubscriptionId $subscriptionId
    }
}
else {
    Write-Error "No valid subscriptions found. Azure AD or Internal subscriptions are currently not supported."
}

# Deploying Azure Lighthouse delegate 
New-AzSubscriptionDeployment -Name "RGDeployment" -Location $Location -TemplateFile .\resourcegroup.template.json -rgName $ResourceGroupName
Write-Host "Deployed Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan
