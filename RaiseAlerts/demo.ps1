#
# Demo n°1 : Déclencher la création d'un Storage Account
# OK
[String]$ResourceGroupName = "DemoStorage"
[String]$Region = "WestEurope"
[String]$StorageSKU = "Standard_LRS"
[String]$StorageKind = "StorageV2"
[String]$StorageAccessTier = "Hot"
[string]$StorageAccountName = "st0" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
    -AccountName $StorageAccountName `
    -Location $Region `
    -SkuName $StorageSKU `
    -Kind $StorageKind `
    -AccessTier $StorageAccessTier
#
# Démo n°2 : Déclencher la suppression d'un Storage Account existant
# OK
[String]$ResourceGroupName = "DemoStorage"
$StorageToDelete = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Storage/storageAccounts | select-Object -last 1
Remove-AzStorageAccount -ResourceGroupName $StorageToDelete.ResourceGroupName `
    -Name $StorageToDelete.Name `
    -Force      
#
# Demo n°3 : Déclencher la création d'un KeyVault
# In Progress
[String]$resourceGroupName = "DemoKeyVault"
[string]$KeyVaultName = "key" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
[String]$Region = "WestEurope"
[String]$KeyVaultSKU = "Standard"
New-AzKeyVault -ResourceGroupName $resourceGroupName `
    -Name $KeyVaultName `
    -Location $region `
    -Sku $KeyVaultSKU     

#
# Constater le Job pour Handle-Alert
# Lister les jobs
Get-AzAutomationJob -ResourceGroupname LabAutomation -AutomationAccount LabAutomation -RunbookName Handle-Alert -Status Queued
