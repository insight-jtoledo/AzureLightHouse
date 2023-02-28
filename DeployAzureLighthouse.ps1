param (
    [parameter(mandatory)][string]$ManagementGroupName,
    [parameter(mandatory)][string]$Location,
    [parameter(mandatory)][string]$ResourceGroupName,
    [parameter(mandatory)][string]$Country
)

#Check Modules
$azGraph = Get-Module az.resourcegraph -ErrorAction silentlycontinue
if ($azGraph -eq $null) {
    Install-Module Az.ResourceGraph -Force -Confirm:$false
}
$az = Get-Module -Name Az -ErrorAction SilentlyContinue
if($az -eq $null){
    Install-Module Az -Force -Confirm:$false -ErrorAction SilentlyContinue
}

#Validate Resource Group Name
$ResourceGroup = Get-AzResourceGroup -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($ResourceGroup -eq $null) {
    Write-Host "$ResourceGroupName does not exist" -ForegroundColor Yellow
    do {
        $ResourceGroupName = Read-Host "Enter name of Resource Group"
    }until((Get-AzResourceGroup -ResourceGroupName $ResourceGroupName) -ne $null)
}
else { Write-Host "Validated Resource Group Name -ForegroundColor Cyan" }

# Deploying Azure Lighthouse delegate
Write-Host "Deploying Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan
New-AzSubscriptionDeployment -Name "RGDeployment" -Location $Location -TemplateFile .\resourcegroup.template.json -rgName $ResourceGroupName
Write-Host "Deployed Azure Lighthouse to $ResourceGroupName" -ForegroundColor Cyan

# Validate Management Group Name
$ManagementGroup = Get-AzManagementGroup | Where-Object { $_.displayName -eq $ManagementGroupName }
if ($ManagementGroup -eq $null) {
    Write-Host "$ManagementGroupName does not exist" -ForegroundColor Yellow
    do {
        $ManagementGroupName = Read-Host "Enter name of Management Group"  
    }until((Get-AzManagementGroup | Where-Object { $_.displayName -eq $ManagementGroupName }) -ne $null)
}
else { Write-Host "Validated Management Group Name" -ForegroundColor Cyan }

$ManagementGroup = Get-AzManagementGroup | Where-Object { $_.displayName -eq $ManagementGroupName }
$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $ManagementGroup.Name

# Update Authorization based on country specified
if ($Country -eq 'AU') {
    $authorization = '[{"principalId":"d58f3234-5da6-4c0e-a54d-91b943062ae9","roleDefinitionId":"b24988ac-6180-42a0-ab88-20f7382dd24c","principalIdDisplayName":"Insight-MS-APAC-Guardian-Consultant"},{"principalId":"31ea58d9-8dff-47e7-9bfd-6d31677047fe","roleDefinitionId":"91c1777a-f3dc-4fae-b103-61d183457e46","principalIdDisplayName":"Insight-MS-APAC-Guardian-ArchitectOwner"}]'
}
elseif($Country -eq 'NZ') {
    $authorization = '[{"principalId":"d58f3234-5da6-4c0e-a54d-91b943062ae9","roleDefinitionId":"b24988ac-6180-42a0-ab88-20f7382dd24c","principalIdDisplayName":"Insight-MS-APAC-Guardian-Consultant"},{"principalId":"31ea58d9-8dff-47e7-9bfd-6d31677047fe","roleDefinitionId":"91c1777a-f3dc-4fae-b103-61d183457e46","principalIdDisplayName":"Insight-MS-APAC-Guardian-ArchitectOwner"}]'
    }else{}

$enrollmentstatus = @()
ForEach ($subscription in $subscriptions) {
    try {
        Write-Host "Deploying Azure Lighthouse to"$subscription.Name -ForegroundColor Cyan
        Set-AzContext -Subscription $subscription.subscriptionId
        New-AzSubscriptionDeployment -Location $Location -TemplateFile .\subscription.template.json -authorizations $authorization
        $data = "" | Select-Object SubscriptionName, SubscriptionID, Status
        $data.SubscriptionName = $subscription.Name
        $data.SubscriptionID = $subscription.subscriptionId
        $data.Status = 'Enrolled'
        $enrollmentstatus += $data
    }
    catch {
        $data = "" | Select-Object SubscriptionName, SubscriptionID, Status
        $data.SubscriptionName = $subscription.Name
        $data.SubscriptionID = $subscription.subscriptionId
        $data.Status = 'NotEnrolled'
        $enrollmentstatus += $data
    }
}

Write-Host "Deployed Azure Lighthouse to subscription/s under" $managementGroup.DisplayName -ForegroundColor Cyan
Write-Host "Enrollment Status for each subscription"
$enrollmentstatus
