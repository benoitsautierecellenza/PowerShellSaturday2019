#
# Dequeue messages
#
[String]$QueueStorageAccountName = "demoazurequeue"
[String]$QueueResourceGroupName = "DemoAzureFirewall"
[String]$QueueToProcess = "storagefirewalleun"
[Int]$invisibleTimeout = 60
#
# Create context to the Azure Storage Account
# OK
$StorageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $QueueResourceGroupName -Name $QueueStorageAccountName
$StorageContext = New-AzStorageContext -StorageAccountName $QueueStorageAccountName -StorageAccountKey $StorageAccountKeys[0].Value
#
# Test Azure Queue
# OK
$AzureQueue = Get-AzStorageQueue -Context $StorageContext -Name $QueueToProcess -ErrorAction SilentlyContinue
IF([string]::IsNullOrEmpty($AzureQueue)) {
    Write-Output "Azure Queue $QueueToProcess does not exists yet. Create it. No message to dequeue at this stage."
    $AzureQueue = New-AzStorageQueue -Context $StorageContext -Name $QueueToProcess
    exit
}
else {
    Write-Output "Azure Queue $QueueToProcess already exists. Processing Queue messages"
}
#
# Process
#
$ProcessedMessages = @()
If (($AzureQueue.ApproximateMessageCount) -GT 0)
{
    Write-Output "Found $($AzureQueue.ApproximateMessageCount) messages to dequeue from queue $QueueToProcess."
    $DequeueMessage = $AzureQueue.CloudQueue.GetMessageAsync($invisibleTimeout,$null,$null)     
    While($DequeueMessage.Result -ne $Null)
    {
        #
        # Process Message
        #
        Write-Host "Processing Message $($DequeueMessage.Result.ID)"
        $ProcessedMessages +=  $DequeueMessage.Result.ID
        $DequeueMessage.Result
        $DequeueMessage = $AzureQueue.CloudQueue.GetMessageAsync($invisibleTimeout,$null,$null)     

        # $queue.CloudQueue.DeleteMessageAsync($queueMessage.Result.Id,$queueMessage.Result.popReceipt)pour la suppression de la queue
    }
    "done"
    exit
}
else {
    Write-Output "No message to dequeue from queue $QueueToProcess."
}


exit
$invisibleTimeout = [System.TimeSpan]::FromSeconds(10)

Get-AzureStorageQueueInfo -StorageAccountName $QueueStorageAccountName -StorageAccountKey $StorageAccountKeys[0].Value -Name $QueueToProcess 

# Read the message from the queue, then show the contents of the message. Read the other two messages, too.
$DequeueMessage = $AzureQueue.CloudQueue.GetMessageAsync($invisibleTimeout,$null,$null)
$DequeueMessage.Result

