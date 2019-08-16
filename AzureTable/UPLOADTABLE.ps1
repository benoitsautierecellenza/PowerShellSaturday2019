$subscriptionName = "Microsoft Azure Sponsorship"
$resourceGroupName = "DemoAzureTable"
$storageAccountName = "demostablestorage"
$tableName = "NicVendors"


# Log on to Azure and set the active subscription
Connect-AzAccount
Set-AzContext -SubscriptionName $subscriptionName
Import-module AZTable

# Get the storage key for the storage account
#$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
# Get a storage context
#$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
# Get a reference to the table
#$table = Get-AzStorageTable -Name $tableName -Context $ctx 

# https://blog.kloud.com.au/2019/02/05/loading-and-querying-data-in-azure-table-storage-using-powershell/
# https://paulomarquesc.github.io/working-with-azure-storage-tables-from-powershell/



$table = Get-AzTableTable -resourceGroup $resourceGroupName -TableName $tableName -storageAccountName $storageAccountName
[int]$rowCount = 0
foreach ($line in $vendors) { 
Add-AzTableRow -table $table -partitionKey ([guid]::NewGuid().tostring()) -rowKey $Line.base16 -property @{"Vendor"=$Line.Vendor;"hex"=$Line.hex}
$rowCount++
}
# 27000 entrées

$table = Get-AzTableTable -resourceGroup $resourceGroupName -TableName $tableName -storageAccountName $storageAccountName
#
# Simple request
#
Get-AzTableRow -table $table -columnName "Vendor" -value "Microsoft" -operator Equal
#
# Build complex request
#
[string]$filter1 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("Vendor",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"Microsoft")
[string]$filter2 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("Vendor",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"Apple, Inc.")
[string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filter1,"or",$filter2)
Get-AzTableRow -table $table -customFilter $finalFilter
#
# Much more simple
#
Get-AzTableRow -table $table -customFilter "(Vendor eq 'Microsoft') or (Vendor eq 'Apple, Inc.')"

