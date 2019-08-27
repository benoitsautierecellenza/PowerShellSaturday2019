#
# Queue messages (for Handle-Alert)
#
[String]$QueueResourceGroupName = "DemoAzureFirewall"
[String]$QueueStorageAccountName = "demoazurequeue"
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
[string]$ServiceType = "Storage"
[String]$OperationName = "Create"
$Rnd = Get-random -Minimum 1 -Maximum 9999
[String]$ResourceName = "testst0$Rnd"

#
# Generate Source Address list from VNET definition in Subscription
# OK
[String]$VNETResourceGroupName = "DemoAzureFirewall"
$SourceAddress = @()
$ListVNETS = Get-AzVirtualNetwork -ResourceGroupName $VNETResourceGroupName                                              
$AddressSpaces = $ListVNETS.AddressSpace.AddressPrefixes
Foreach($AddressSpace in $AddressSpaces)
{
    $SourceAddress +=$AddressSpace
}
Switch ($ServiceType)
{
    "Storage" {
        [String]$StorageQueueName1 = "storagefirewalleun"
        [String]$StorageQueueName2 = "storagefirewalleuw"
        $MessageToQueue = @"
        {
            "ServiceType" : "$ServiceType",
            "ActionType" : "$OperationName",
            "ResourceName" : "$ResourceName",
            "SubscriptionID": "$subscriptionID"
            "SourceAddress" : "$SourceAddress"
        }
"@
    }
    "KeyVault" {
        [String]$StorageQueueName1 = "keyvaultfirewalleun"
        [String]$StorageQueueName2 = "keyvaultfirewalleuw"
        $MessageToQueue = @"
        {
            "ServiceType" : $ServiceType,
            "ActionType" : $OperationName,
            "resourceId" : $resourceId,
            "SubscriptionID": $subscriptionID
            "SourceAddress" : $SourceAddress
        }
"@
    }
    default
    {
        Write-Error "$ServiceType Service not managed for Azure Firewall."
        Exit
    }
}
$StorageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $QueueResourceGroupName -Name $QueueStorageAccountName
$StorageContext = New-AzStorageContext -StorageAccountName $QueueStorageAccountName -StorageAccountKey $StorageAccountKeys[0].Value
#
# Test Azure Queue. Create if required
# OK
$AzureQueue1 = Get-AzStorageQueue -Context $StorageContext -Name $StorageQueueName1 -ErrorAction SilentlyContinue
IF([string]::IsNullOrEmpty($AzureQueue1)) {
    Write-Output "Azure Queue $StorageQueueName1 does not exists yet. Create it"
    $AzureQueue1 = New-AzStorageQueue -Context $StorageContext -Name $StorageQueueName1
}
else {
    Write-Output "Azure Queue $StorageQueueName1 already exists."
}
$AzureQueue2 = Get-AzStorageQueue -Context $StorageContext -Name $StorageQueueName2 -ErrorAction SilentlyContinue
IF([string]::IsNullOrEmpty($AzureQueue2)) {
    Write-Output "Azure Queue $StorageQueueName2 does not exists yet. Create it"
    $AzureQueue1 = New-AzStorageQueue -Context $StorageContext -Name $StorageQueueName2
}
else {
    Write-Output "Azure Queue $StorageQueueName2 already exists."
}
#
# Queue Message on Both Queues
#
$queueMessage = New-Object -TypeName "Microsoft.Azure.Storage.Queue.CloudQueueMessage,$($AzureQueue1.CloudQueue.GetType().Assembly.FullName)" -ArgumentList $MessageToQueue
$AzureQueue1.CloudQueue.AddMessageAsync($QueueMessage)

$queueMessage = New-Object -TypeName "Microsoft.Azure.Storage.Queue.CloudQueueMessage,$($AzureQueue1.CloudQueue.GetType().Assembly.FullName)" -ArgumentList $MessageToQueue
$AzureQueue2.CloudQueue.AddMessageAsync($QueueMessage)


