# VERSION 1.6.6

param(
    [Parameter (Mandatory=$false)][object[]] $WebhookData,
    [Parameter (Mandatory=$false)][int] $Severity
)
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

import-module Az.Resources
import-module Az.Network

Write-Verbose "Retrieving credentials and variables from Azure Automation"
$credentials = Get-AutomationPSCredential -Name "tnc-automation"
$subscriptionId = Get-AutomationVariable -Name "subscriptionId"
$tenantId = Get-AutomationVariable -Name "tenantId"

Write-Verbose "Connecting to the subscription '$subscriptionId'"
Add-AzAccount -Credential $credentials -TenantId $tenantId -ServicePrincipal -SubscriptionId $subscriptionId | Out-Null

$SubscriptionName = (Get-AzContext).Subscription.Name
$latestitem = ($SubscriptionName.Split('-')[-1]).ToLower()  

if ((Get-AzContext).Tenant.Id -eq "XXXXX-XXXXX-XXXX-XXXXX-XXXXX") {$latestitem = "XXXXX"}

# Return the env variable and the coretechservice subscription where is locate the storage account for the storage message queue

switch ($latestitem) {

    "bld" {
                $SubscriptionIDCoreTech = "XXXXX-XXXX-XXX-XXX-XXX"   
                $env                    = "bld"
                $resourceGroup          = "XX-$env"+"XXX-rg"
                $storageAccountName     = "updatefqdntagazfw$env"    
    }

$SourceAddress = @()

foreach ($item in (Get-AzVirtualNetwork).AddressSpaceText | ConvertFrom-Json) {
    
    #$SourceAddress += """" + $item.AddressPrefixes + """"   
    $SourceAddress += $item.AddressPrefixes  
    }
$IPsSource = $SourceAddress -Join "," 

$ServiceAzureEndpoint = @"
    $WebhookData
"@ | ConvertFrom-Json

$ServiceAzureEndpoint.rawAlert.RequestBody.data.context.activityLog.resourceId | % { $ServiceAzureEndpointFound = $_.split("/") } 
$AuthorizationAction = $ServiceAzureEndpoint.rawAlert.RequestBody.data.context.activityLog.authorization.action
$ActionType = $AuthorizationAction.Split('/')[2]
$resourceId = $ServiceAzureEndpoint.rawAlert.RequestBody.data.context.activityLog.resourceId
$submissionTimestamp = $ServiceAzureEndpoint.rawAlert.RequestBody.data.context.activityLog.submissionTimestamp

$TypeOfServiceAzure = $ServiceAzureEndpointFound[7]
$ServiceAzure = $ServiceAzureEndpointFound[8]

Write-Output $ServiceAzureEndpoint

switch ($TypeOfServiceAzure) {

    "storageAccounts" {
        $SKUStorageAccount = (Get-AzStorageAccount -ResourceGroupName $resourceId.Split("/")[4] -Name $resourceId.Split("/")[-1]).Sku.Name
        $AzureManagedService = "Azure Storage Account"  
        if (($SKUStorageAccount -like "*LRS*") -or ($SKUStorageAccount -like "*GRS*") -or ($SKUStorageAccount -like "*ZRS*")){
            
        $FQDNTag      = "'$ServiceAzure.blob.core.windows.net','$ServiceAzure.file.core.windows.net','$ServiceAzure.table.core.windows.net','$ServiceAzure.queue.core.windows.net','$ServiceAzure.dfs.core.windows.net','$ServiceAzure.z16.web.core.windows.net'"

        } else {
        
        $FQDNTag      = "'$ServiceAzure.blob.core.windows.net','$ServiceAzure.file.core.windows.net','$ServiceAzure.table.core.windows.net','$ServiceAzure.queue.core.windows.net','$ServiceAzure.dfs.core.windows.net','$ServiceAzure.z16.web.core.windows.net',"
        $FQDNTag      += "'$ServiceAzure-secondary.blob.core.windows.net','$ServiceAzure-secondary.file.core.windows.net','$ServiceAzure-secondary.table.core.windows.net','$ServiceAzure-secondary.queue.core.windows.net','$ServiceAzure-secondary.dfs.core.windows.net','$ServiceAzure-secondary.z16.web.core.windows.net'"
           
        }       
      
   }

    "databaseAccounts" {
        $AzureManagedService = "Azure CosmosDB"  
        $FQDNTag      = "'$ServiceAzure.documents.azure.com'"    
    }

    "vaults" {
        $AzureManagedService = "Azure Key Vault"  
        $FQDNTag      = "'$ServiceAzure.vault.azure.net'"    
    }

    "servers" {
        switch ($ServiceAzureEndpointFound[6]) {
            "Microsoft.DBforPostgreSQL" {
                $AzureManagedService = "Azure Database for PostgreSQL"
                $FQDNTag = "'$ServiceAzure.postgre.database.azure.net'"       
            }
        }
           
    }

    "workspaces" {
        $AzureManagedService = "Azure Log Analytics"

        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ServiceAzureEndpoint.rawAlert.RequestBody.data.context.activityLog.resourceGroupName -Name $ServiceAzure
        $customerId = $workspace.CustomerId
        $FQDNTag = "'$customerId.ods.opinsights.azure.com','$customerId.oms.opinsights.azure.com'"
    }

    "accounts" {
        switch ($ServiceAzureEndpointFound[6]) {
            "Microsoft.CognitiveServices" {
                $AzureManagedService = "Cognitive Services"  
                $FQDNTag      = ""       
            }
        }
    }

}

$MessageToQueue = @"
{
    "ServiceAzure" : "$AzureManagedService",
    "ActionType" : "$ActionType",
    "resourceId" : "$resourceId",
    "Action" : "$AuthorizationAction",
    "subscriptionId" : "$subscriptionId",
    "tenantId" : "$tenantId",
    "FQDNTag" : "$FQDNTag",
    "AddressSpace" : "$IPsSource",
    "submissionTimestamp" : "$submissionTimestamp"
}
"@

if (($ActionType -Match "delete") -or ($ActionType -Match "write")) {

Connect-AzAccount -Credential $credentials -Tenant $tenantId -ServicePrincipal -Subscription $SubscriptionIDCoreTech 
$keyStorageQueueAccount = (Get-AzStorageAccountKey -ResourceGroupName "$resourceGroup" -AccountName "$storageAccountName").Value[0]
$IStorageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $keyStorageQueueAccount 

$queue = Get-AzStorageQueue -Context $IStorageContext -Name $queueNameUpdateAZFW 

$invisibleTimeout = [System.TimeSpan]::FromSeconds(3)

# Create a new message using a constructor of the CloudQueueMessage class
$queueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage -ArgumentList "$MessageToQueue"
# Add a new message to the queue
$queue.CloudQueue.AddMessageAsync($queueMessage)

# Read the message from the queue, then show the contents of the message. Read the other two messages, too.
$queueMessage = $queue.CloudQueue.GetMessageAsync($invisibleTimeout,$null,$null)
$MessageToProcessed = ($queueMessage.Result).AsString

Write-Output "Add new message to the Queue :"
Write-Output $MessageToQueue

} else {
    "The json message is malformed !" 
    exit 0
}  
