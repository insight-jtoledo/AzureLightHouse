param(
[parameter(Mandatory)][string]$ManagementGroupName,
[parameter(Mandatory)][string]$PolicyDefinitionName
)

#Get Management Group Details
$ManagementGroup = Get-AzManagementGroup | Where-Object{$_.DisplayName -eq $ManagementGroupName}
if($ManagementGroup -eq $null){
    Write-Host "Please check Management Group Name" -ForegroundColor Yellow
    }else{Write-Host "Verified Management Group Name - $ManagementGroupName" -ForegroundColor Cyan}

#Check if Policy Definition Name exists
$PolicyDefinitionName = Get-AzPolicyDefinition | where-object{$_.Name -like $PolicyDefinitionName}
if($PolicyDefinitionName -eq $null){
    Write-Host "Please check $PolicyDefinitionName exists" -ForegroundColor Yellow
    }else{
        # Start Remediation Task
        Write-Host "Getting all non-compliant resources for $PolicyDefinitionName" -ForegroundColor Cyan
        $NonCompliantPolicies = Get-AzPolicyState `
        | Where-Object{$_.ComplianceState -eq 'NonCompliant' `
        -and $_.PolicyDefinitionAction -eq 'deployifnotexists' `
        -and $_.PolicyAssignmentName -eq $PolicyDefinitionName}

        Write-Host "Remediating existing resources that are not compliant.." -ForegroundColor Cyan
        $nonCompliantPolicies | ForEach-Object{
            $name = ("rem." + $_.PolicyDefinitionName)
            $subscriptionID = $_.SubscriptionId
            Start-AzPolicyRemediation -Name $name `
            -PolicyAssignmentId $_.PolicyAssignmentId `
            -Scope $ManagementGroup.Id
            Write-Host "Remediation started for $subscriptionID" -ForegroundColor Cyan
                                }

        
        }
