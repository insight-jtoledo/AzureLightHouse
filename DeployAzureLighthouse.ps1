param (
    [parameter(mandatory)][string]$ManagementGroupName,
    [parameter(mandatory)][string]$Location,
    [parameter(mandatory)][string]$ResourceGroupName
)

#Check Modules
$azGraph = Get-Module az.resourcegraph -ErrorAction silentlycontinue
if($azGraph -eq $null){
    Install-Module Az.ResourceGraph -Force -Confirm:$false
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

$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $managementGroup.Name

$enrollmentstatus = @()
ForEach ($subscription in $subscriptions) {
    try {
        Write-Host "Deploying Azure Lighthouse to"$subscription.Name -ForegroundColor Cyan
        Set-AzContext -Subscription $subscription.subscriptionId
        New-AzSubscriptionDeployment -Location $Location -TemplateFile .\subscription.template.json
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
