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
Write-Host "Deploying Azure Lighthouse Policy.."
New-AzManagementGroupDeployment -Name $PolicyDefinitionName -Location $Location `
-ManagementGroupId $ManagementGroup.Name `
-TemplateFile '.\deployLighthouseIfNotExistManagementGroup.json' `
-TemplateParameterFile '.\deployLighthouseIfNotExistsManagementGroup.parameters.json' -verbose

# Get the policy assignment from the management group
$PolicyDefinition = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}

# Create a new policy assignment with the policy definition
Write-Host ""
Write-Host "Assigning policy to the specified Management Group.."
New-AzPolicyAssignment -Name $PolicyDefinition.ResourceName -Scope $ManagementGroup.Id -PolicyDefinition $PolicyDefinition -IdentityType SystemAssigned -Location australiaeast
$PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId
$RoleDefinitionId = [GUID]($PolicyDefinition.properties.policyRule.then.details.roleDefinitionIds -split "/")[4]
$ObjectID = [GUID]($PolicyAssignment.Identity.principalId)
Start-Sleep 90
New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $ObjectID -RoleDefinitionId $RoleDefinitionId

Write-Host "Policy for Azure Lighthouse has been completed" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deploying Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan
# Deploying Azure Lighthouse delegation for Azure Guardian Resource Group
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name ("$ResourceGroupName" + "-$PolicyDefinitionName") `
-TemplateFile .\resourcegroup.template.json -rgName $ResourceGroupName -Verbose
