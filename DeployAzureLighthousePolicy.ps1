param(
$PolicyDefinitionName="Enable-Azure-Lighthouse"
)

# Get Details
$ManagementGroupName = Read-Host "Enter Management Group Name"
$Location = Read-Host "Enter Location"
$ResourceGroupName = Read-Host "Enter Azure Guardian Resource Group Name"
Write-Host ""

# Get Management Group Details
$ManagementGroup = Get-AzManagementGroup | Where-Object{$_.DisplayName -eq $ManagementGroupName}

# Deploy Policy
Write-Host ""
Write-Host "Deploying Azure Lighthouse Policy.." -ForegroundColor Cyan
New-AzManagementGroupDeployment -Name $PolicyDefinitionName -Location $Location `
-ManagementGroupId $ManagementGroup.Name `
-TemplateFile '.\deployLighthouseIfNotExistManagementGroup.json' `
-TemplateParameterFile '.\deployLighthouseIfNotExistsManagementGroup.parameters.json' -verbose

# Get the policy assignment from the management group
$PolicyDefinition = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}

# Create a new policy assignment with the policy definition
Write-Host ""
Write-Host "Assigning policy to the specified Management Group.." -ForegroundColor Cyan
New-AzPolicyAssignment -Name $PolicyDefinition.ResourceName -Scope $ManagementGroup.Id -PolicyDefinition $PolicyDefinition -IdentityType SystemAssigned -Location australiaeast
$PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId
$RoleDefinitionId = [GUID]($PolicyDefinition.properties.policyRule.then.details.roleDefinitionIds -split "/")[4]
$ObjectID = [GUID]($PolicyAssignment.Identity.principalId)
Start-Sleep 90
New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $ObjectID -RoleDefinitionId $RoleDefinitionId

Write-Host "Policy for Azure Lighthouse has been completed" -ForegroundColor Cyan
Write-Host ""
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
New-AzSubscriptionDeployment -Name "RGDeployment" -Location $Location -TemplateFile .\Downloads\resourcegroup.template.json -rgName $ResourceGroupName -WhatIf
