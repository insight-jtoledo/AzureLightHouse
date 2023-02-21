param(
$TenantID,
$ManagementGroupName,
$Location,
$PolicyDefinitionName="Enable-Azure-Lighthouse"
)

# Login to Azure
Login-AzAccount -Tenant $TenantID

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
$PolicyDefinitionName = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}

# Create a new policy assignment with the policy definition
Write-Host ""
Write-Host "Assigning policy to the specified Management Group.."
New-AzPolicyAssignment -Name $PolicyDefinitionName.ResourceName -Scope $ManagementGroup.Id -PolicyDefinition $PolicyDefinitionName -IdentityType SystemAssigned -Location australiaeast
$PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinitionName.PolicyDefinitionId
$RoleDefinitionId = [GUID]($PolicyDefinitionName.properties.policyRule.then.details.roleDefinitionIds -split "/")[4]
$ObjectID = [GUID]($PolicyAssignment.Identity.principalId)
Start-Sleep 90
New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $ObjectID -RoleDefinitionId $RoleDefinitionId

Write-Host "Policy for Azure Lighthouse has been completed" -ForegroundColor Cyan
