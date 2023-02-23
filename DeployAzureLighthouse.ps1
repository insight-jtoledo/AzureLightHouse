param(
[parameter(mandatory)][string]$ManagementGroupName,
[parameter(mandatory)][string]$Location,
[parameter(mandatory)][string]$ResourceGroupName
)

$ManagementGroup = Get-AzManagementGroup | Where-Object{$_.DisplayName -eq $ManagementGroupName}

$Subscriptions = Search-AzGraph -Query "ResourceContainers `
   | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $managementGroup.Name

$Subscriptions | ForEach-Object{
    Write-Host "Deploying Azure Lighthouse to"$_.Name -ForegroundColor Cyan
    $context = Set-AzContext -Subscription $_.subscriptionId
    New-AzSubscriptionDeployment -Location $Location -TemplateFile .\subscription.template.json
    }
Write-Host "Deployed Azure Lighthouse to subscription/s under"$managementGroup.DisplayName -ForegroundColor Cyan

Write-Host "Deploying Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan

$deploymentOptions = @{}
Write-Host "Getting Azure subscriptions (filtering out unsupported ones)..." -ForegroundColor Green

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.SubscriptionPolicies.QuotaId -notlike "Internal*" -and $_.SubscriptionPolicies.QuotaId -notlike "AAD*" }

if ($subscriptions.Count -gt 1) {

    $selectedSubscription = -1
    for ($i = 0; $i -lt $subscriptions.Count; $i++)
    {
        if (-not($deploymentOptions["SubscriptionId"]))
        {
            Write-Output "[$i] $($subscriptions[$i].Name)"    
        }
        else
        {
            if ($subscriptions[$i].Id -eq $deploymentOptions["SubscriptionId"])
            {
                $selectedSubscription = $i
                break
            }
        }
    }
    if (-not($deploymentOptions["SubscriptionId"]))
    {
        $lastSubscriptionIndex = $subscriptions.Count - 1
        while ($selectedSubscription -lt 0 -or $selectedSubscription -gt $lastSubscriptionIndex) {
            Write-Output "---"
            $selectedSubscription = [int] (Read-Host "Please, select the target subscription for this deployment [0..$lastSubscriptionIndex]")
        }    
    }
    if ($selectedSubscription -eq -1)
    {
        throw "The selected subscription does not exist. Check if you are logged in with the right Azure AD account."        
    }
}
else
{
    if ($subscriptions.Count -ne 0)
    {
        $selectedSubscription = 0
    }
    else
    {
        throw "No valid subscriptions found. Azure AD or Internal subscriptions are currently not supported."
    }
}

if ($subscriptions.Count -eq 0) {
    throw "No subscriptions found. Check if you are logged in with the right Azure AD account."
}

$subscriptionId = $subscriptions[$selectedSubscription].Id

if (-not($deploymentOptions["SubscriptionId"]))
{
    $deploymentOptions["SubscriptionId"] = $subscriptionId
}

if ($ctx.Subscription.Id -ne $subscriptionId) {
    $ctx = Select-AzSubscription -SubscriptionId $subscriptionId
}

# Deploying Azure Lighthouse delegation for Azure Guardian Resource Group
New-AzSubscriptionDeployment -Name "RGDeployment" -Location $Location -TemplateFile .\resourcegroup.template.json -rgName $ResourceGroupName
Write-Host "Deployed Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan

