$Enddate = Get-date
$StartDate = (Get-date).AddDays(-2)
Get-AzAlertHistory -StartTime $StartDate  -EndTime $Enddate


 Get-AzAlertHistory -StartTime 2019-08-01T11:00:00 -EndTime 2019-08-20T12:00:00 -DetailedOutput  
 Get-AzAlertHistory -StartTime 2019-08-01T11:00:00 -EndTime 2019-08-20T12:00:00 -DetailedOutput  
 Get-AzAlertHistory -StartTime 2019-08-01T11:00:00 

 Get-AzAlertHistory -StartTime 2019-08-15T13:00:00

# pour mettre à jour une alerte existante
# Set-AzActivityLogAlert
Set-AzActivityLogAlert 

Get-AzAlertHistory -ResourceId /subscriptions/s1/resourceGroups/rg1/providers/microsoft.insights/alertrules/myalert -StartTime 2016-03-1 -Status Activated

Get-AzAlertHistory


Get-AzResource -ResourceGroupName LabAutomation -ResourceType microsoft.insights/metricAlerts 

$names = (Get-AzResource -ResourceType microsoft.insights/metricAlerts).Name
foreach($name in $names){
    Get-AzResource  -Name $name -ResourceType microsoft.insights/metricAlerts | ConvertTo-Json
}

Get-AzAlertHistory -StartTime 2019-08-15 -EndTime 2019-08-17 -DetailedOutput -ResourceId $AlertResourceID

new-azstorageaccount -ResourceGroupName "testkeyvaultcreate" -Name teststorage9866 

New-AzStorageAccount -ResourceGroupName "testkeyvaultcreate" -AccountName testmysrorage864 -Location westeurope -SkuName Standard_LRS -Kind BlobStorageV2 -AccessTier Hot