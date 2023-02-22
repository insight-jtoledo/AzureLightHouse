param(
[parameter(Mandatory)][string]$ManagementGroupName,
[parameter(Mandatory)][string]$Location,
[parameter(Mandatory)][string]$PolicyDefinitionName
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
    
# Start Remediation Task
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
Write-Host "Deployment Done" -ForegroundColor Cyan
