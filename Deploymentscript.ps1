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

Start-Sleep 300

# Start Remediation Task
Write-Host ""
Write-Host "Getting all non-compliant resources.."
$NonCompliantPolicies = Get-AzPolicyState `
| Where-Object{$_.ComplianceState -eq 'NonCompliant' `
-and $_.PolicyDefinitionAction -eq 'deployifnotexists' `
-and $_.PolicyAssignmentName -eq $PolicyDefinitionName.Name}

Write-Host ""
Write-Host "Remediating existing resources that are not compliant.."
$nonCompliantPolicies | ForEach-Object{
    $name = ("rem." + $_.PolicyDefinitionName)
    Start-AzPolicyRemediation -Name $name `
    -PolicyAssignmentId $_.PolicyAssignmentId `
    -Scope $managementGroup.Id
    }
