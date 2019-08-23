#
# Queue messages (for Handle-Alert)
#
[String]$QueueStorageAccountName = "demoazurequeue"
#[String]$QueueStorageAccountResourceGroupName = "DemoAzureFirewall"
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$QueueAccessKey = "qvtOJaLPnSWdZz87pXt/xrLPaENjZV8DUJVA9RxIm4ixxuc1f2RU75JIMPDzUuLdoKFtAO5XQl0uaPxVwwqoww=="
[String]$StorageQueueName = "productionfirewall"

[String]$ResourceId = "/subscriptions/5be15500-7328-4beb-871a-1498cd4b4536/resourceGroups/DemoAzureFirewall/providers/Microsoft.Storage/storageAccounts/demoazurequeue"
[string]$AzureService = "storageAccounts"
[String]$OperationName = "create"

$StorageContext = New-AzStorageContext -StorageAccountName $QueueStorageAccountName -StorageAccountKey $QueueAccessKey
#
# Test Azure Queue
# OK
$AzureQueue = Get-AzStorageQueue -Context $StorageContext -Name $StorageQueueName -ErrorAction SilentlyContinue
IF([string]::IsNullOrEmpty($AzureQueue)) {
    Write-Output "Azure Queue $StorageQueueName does not exists yet. Create it"
    $AzureQueue = New-AzStorageQueue -Context $StorageContext -Name $StorageQueueName
}
else {
    Write-Output "Azure Queue $StorageQueueName exists."
}
Switch($AzureService)
{
    "storageAccounts" 
    {
        Write-Output "Processing an Azure Storage Account Rule."
        $MessageToQueue = @"
        {
            "ServiceAzure" : $AzureService,
            "ActionType" : $OperationName,
            "resourceId" : $resourceId,
            "SubscriptionID": $subscriptionID
        }
"@

# build message
    }
    "Keyvaults"
    {
        Write-Output "Processing a KeyVault Rule."
        $MessageToQueue = @"
        {
            "ServiceAzure" : $AzureService,
            "ActionType" : $OperationName,
            "resourceId" : $resourceId,
            "SubscriptionID": $subscriptionID
        }
"@
        
    }
    default
    {
        Write-Error "$AzureService Service not managed for Azure Firewall."
    }
}
#
# Queue Message
#
$queueMessage = New-Object -TypeName "Microsoft.Azure.Storage.Queue.CloudQueueMessage,$($AzureQueue.CloudQueue.GetType().Assembly.FullName)" -ArgumentList $MessageToQueue
# Add a new message to the queue
$AzureQueue.CloudQueue.AddMessageAsync($QueueMessage)



