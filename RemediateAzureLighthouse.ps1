param(
$PolicyDefinitionName="Enable-Azure-Lighthouse"
)

# Start Remediation Task
Write-Host ""
Write-Host "Getting all non-compliant resources.."
$NonCompliantPolicies = Get-AzPolicyState `
| Where-Object{$_.ComplianceState -eq 'NonCompliant' `
-and $_.PolicyDefinitionAction -eq 'deployifnotexists' `
-and $_.PolicyAssignmentName -eq $PolicyDefinitionName}

Write-Host ""
Write-Host "Remediating existing resources that are not compliant.."
$nonCompliantPolicies | ForEach-Object{
    $name = ("rem." + $_.PolicyDefinitionName)
    Start-AzPolicyRemediation -Name $name `
    -PolicyAssignmentId $_.PolicyAssignmentId `
    -Scope $managementGroup.Id
    Write-Host "Remediation started for $SubscriptionID" -ForegroundColor Cyan
    }
