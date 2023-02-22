param(
[parameter(Mandatory)][string]$ManagementGroupName,
[parameter(Mandatory)][string]$Location,
[parameter(Mandatory)][string]$PolicyDefinitionName,
[parameter(Mandatory)][string]$ResourceGroupName
)

#Get Management Group Details
$ManagementGroup = Get-AzManagementGroup | Where-Object{$_.DisplayName -eq $ManagementGroupName}
if($ManagementGroup -eq $null){
    Write-Host "Please check Management Group Name" -ForegroundColor Yellow
    }else{Write-Host "Verified Management Group Name - $ManagementGroupName" -ForegroundColor Cyan}

#Check if Policy Definition Name exists
$PolicyDefinition = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}
if($PolicyDefinition -eq $null){
        #Deploy Policy
        Write-Host "Deploying Azure Lighthouse Policy.." -ForegroundColor Cyan
        New-AzManagementGroupDeployment -Location $Location `
        -ManagementGroupId $ManagementGroup.Name `
        -TemplateFile '.\deployLighthouseIfNotExistManagementGroup.json' `
        -TemplateParameterFile '.\deployLighthouseIfNotExistsManagementGroup.parameters.json' -verbose

    }else{
        Write-Host "Policy Definition - $PolicyDefinitionName already exist. Please specify a new one.-" -ForegroundColor Yellow
    }

# Get the policy assignment from the management group
do{
    Write-Host "Waiting for Policy Definition to be created.."
    Start-Sleep 10
    $PolicyDefinition = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}
    }until(
        (Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}) -ne $null
            )

# Create a new policy assignment with the policy definition
Write-Host "Assigning policy to the specified Management Group.." -ForegroundColor Cyan
New-AzPolicyAssignment -Name $PolicyDefinitionName `
-Scope $ManagementGroup.Id `
-PolicyDefinition $PolicyDefinition `
-IdentityType SystemAssigned `
-Location australiaeast

$PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId

$RoleDefinitionId = [GUID]($PolicyDefinition.properties.policyRule.then.details.roleDefinitionIds -split "/")[4]

$ObjectID = [GUID]($PolicyAssignment.Identity.principalId)

Start-Sleep 90

New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $ObjectID -RoleDefinitionId $RoleDefinitionId

$Remediate = Read-Host "Remediate Non Compliant Resources? (Y/N)"

if($Remediate -eq 'Y'){

Write-Host ""
Write-Host "Getting all non-compliant resources.."
$NonCompliantPolicies = Get-AzPolicyState `
| Where-Object{$_.ComplianceState -eq 'NonCompliant' `
-and $_.PolicyDefinitionAction -eq 'deployifnotexists' `
-and $_.PolicyAssignmentName -eq $PolicyDefinition.Name}

Write-Host ""
Write-Host "Remediating existing resources that are not compliant.."
$nonCompliantPolicies | ForEach-Object{
    $name = ("rem." + $_.PolicyDefinitionName)
    Start-AzPolicyRemediation -Name $name `
    -PolicyAssignmentId $_.PolicyAssignmentId `
    -Scope $managementGroup.Id
    }

    }else{}

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

Write-Host "Deployment Done" -ForegroundColor Cyan
