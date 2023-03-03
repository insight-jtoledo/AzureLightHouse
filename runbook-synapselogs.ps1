param
(
	[object]$WebHookData
)

##Place Values in Variables##
$PipelineName = $WebHookData.PipelineName
$PipelineRunId = $WebHookData.PipelineRunId
$ActivityName = $WebHookData.ActivityName
$ActivityRunId = $WebHookData.ActivityRunId
$ActivityType = $WebHookData.ActivityType
$WorkspaceName = (($WebHookData._ResourceId).split('/'))[8]
$TimeGenerated = $WebHookData.TimeGenerated

##Connect and Select Subscription##
#$DisableAzureContextAutoSave = Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

##Get Pipeline Run Details##
$DateTime = Get-Date $TimeGenerated
$PipelineDetails = Get-AzSynapsePipelineRun -WorkspaceName $WorkSpaceName -PipelineRunId $PipelineRunID


#Create Table to Prepare Data for Submission#
$table = @()
$data = "" | Select WorkspaceName,PipelineName,PipelineRunID,ActivityName,ActivityRunID,TimeGenerated,Status,Message
$data.WorkspaceName = $WorkSpaceName
$data.PipelineName = $PipelineName
$data.PipelineRunID = $PipelineRunID
$data.ActivityName = $ActivityName
$data.ActivityRunID = $ActivityRunId
$data.TimeGenerated = $DateTime
$data.Status = $PipelineDetails.Status
$data.Message = $PipelineDetails.Message
$table += $data
$data | ConvertTo-Json