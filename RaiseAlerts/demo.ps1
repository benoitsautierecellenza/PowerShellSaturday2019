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
# Constater les jobs
#
Get-AzAutomationJob -ResourceGroupname LabAutomation -AutomationAccount LabAutomation -RunbookName Handle-Alert -Status Queued
Get-AzAutomationJob -ResourceGroupname LabAutomation -AutomationAccount LabAutomation  -Status Running
#
# Démo n°2 : Déclencher la suppression d'un Storage Account existant
# OK
[String]$ResourceGroupName = "DemoStorage"
$StorageToDelete = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Storage/storageAccounts | select-Object -last 1
Remove-AzStorageAccount -ResourceGroupName $StorageToDelete.ResourceGroupName `
    -Name $StorageToDelete.Name `
    -Force      
#
# Constater les jobs
#
Get-AzAutomationJob -ResourceGroupname LabAutomation -AutomationAccount LabAutomation -RunbookName Handle-Alert -Status Queued
Get-AzAutomationJob -ResourceGroupname LabAutomation -AutomationAccount LabAutomation  -Status Running
#
# Demo n°3 : Déclencher la création d'un KeyVault
# Inutile car idem suivante
#[String]$resourceGroupName = "DemoKeyVault"
#[string]$KeyVaultName = "key" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
#[String]$Region = "WestEurope"
#[String]$KeyVaultSKU = "Standard"
#New-AzKeyVault -ResourceGroupName $resourceGroupName `
#    -Name $KeyVaultName `
#    -Location $region `
#    -Sku $KeyVaultSKU     
#
# Demo KeyVault With Policy en Powershell (pour montrer l'échec)
# OK
[String]$resourceGroupName = "DemoKeyVaultWIthPolicy"
[String]$KeyVaultName = "key" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
[String]$Region = "WestEurope"
[String]$KeyVaultSKU = "Standard"
New-AzKeyVault -ResourceGroupName $resourceGroupName `
    -Name $KeyVaultName `
    -Location $region `
    -Sku $KeyVaultSKU    
#
# Demo KeyVault compliant with policy (avec template ARM dans RG dédié policy)
# OK
[String]$Subscriptionid = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$ResourceGroupName = "DemoKeyVaultWIthPolicy"
[String]$KeyVaultName = "key" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
[String]$KeyVaultSKU = "Standard"
Set-AzContext -SubscriptionId $Subscriptionid
$DeploymentName = (new-guid).guid
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/RaiseAlerts/CreateKeyVault.json"
New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri $TemplateFileURI `
    -KeyVaultName $KeyVaultName `
    -sku $KeyVaultSKU  `
    -enabledForDeployment $true `
    -enabledForTemplateDeployment $true `
    -enabledForDiskEncryption $true 

#
# Demo KeyVault compliant with policy (avec template ARM dans RG standard)
# OK
[String]$Subscriptionid = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$ResourceGroupName = "DemoKeyVault"
[String]$KeyVaultName = "key" + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})
[String]$KeyVaultSKU = "Standard"
Set-AzContext -SubscriptionId $Subscriptionid
$DeploymentName = (new-guid).guid
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/RaiseAlerts/CreateKeyVault.json"
New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri $TemplateFileURI `
    -KeyVaultName $KeyVaultName `
    -sku $KeyVaultSKU  `
    -enabledForDeployment $true `
    -enabledForTemplateDeployment $true `
    -enabledForDiskEncryption $true 
