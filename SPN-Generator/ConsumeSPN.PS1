#
# Provision Azure AUtomation variables
#
[String]$AutomationAccountName = "tnc-automationaccount9"
[String]$AutomationAccountResourceGroupName = "tnc-automationaccount"
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$BabelSubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"   # Donc à configurer dans le référentiel
[String]$CoreTechlogSubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536" # A extraire du référentiel
[String]$KeyVaultResourceGroupname = "ftpaas-AADeuADSecrets"
[String]$KeyvaultName = "testsecret0456567"                     # Donc à configurer dans le référentiel
[String]$TNCREsourceGroupName = "TnC"
[String]$ApplicationSecretName = "secret"
[String]$ApplicationAppIDName = "AppId"


[String]$AzureADResourceGroupVariableName = "resourceGroupName" 
[String]$AzureADCredentialName = "AADDCredential"
[String]$AzureADTenantVariableName = "TenantID"

$CurrentsubscriptionID = (Get-AzContext).Subscription.Id
#
# Get into Babel subscription to retreive latest version of secret
#
try {
    Write-Output "Switching to the Babel Subscription $BabelSubscriptionID."
    Set-AzContext -Subscriptionid $BabelSubscriptionID    
    Write-Output "Connected to Azure Subscription $BabelSubscriptionID."
}
catch {
    Throw "Error while switcing to "

}
#
# Locate KeyVault instance in Babel subscription
#
try {
    Write-Output "Checking for KeyVault $KeyvaultName in resource group $KeyVaultResourceGroupname."
    $TestRG = Get-AzResourceGroup -Name $KeyVaultResourceGroupname 
    $KeyVault = Get-AzKeyVault -ResourceGroupName $KeyVaultResourceGroupname -VaultName $KeyvaultName   
    Write-Output "KeyVault $KeyvaultName found in resource group $KeyVaultResourceGroupname."
}
catch {
    Throw "Unable to locate Resource in subscription $BabelSubscriptionID  named $KeyVaultResourceGroupname."    
}
#
# Check if KeyVault Secrets exists
#
$ListSecrets  = Get-AzKeyVaultSecret -VaultName $KeyvaultName 
If ([string]::IsNullOrEmpty($ListSecrets) -eq $True) {
    Throw "No Secrets found in KeyVault $KeyvaultName."
}
If (($ListSecrets.Name) -notcontains $ApplicationAppIDName)
{
    Throw "No Secret named $ApplicationAppIDName found in KeyVault $KeyvaultName."
}
If (($ListSecrets.Name) -notcontains $ApplicationSecretName)
{
    Throw "No Secret named $ApplicationSecretName found in KeyVault $KeyvaultName."
}
#
# Get Latest version of secrets
#
$AppIDSecret = Get-AzKeyVaultSecret -VaultName $KeyvaultName -Name $ApplicationAppIDName
$AppSecret = Get-AzKeyVaultSecret -VaultName $KeyvaultName -Name $ApplicationSecretName
#
# Switching to the CoreTech-Log Subscription
#
Set-AzContext -Subscriptionid $CoreTechlogSubscriptionID
#
# Check ResourceGroup and Automation Account in CoreTech-Log subscription
#
try {
    Write-Output "Checking for Automation Account named $AutomationAccountName in resourcegroup $AutomationAccountResourceGroupName."
    $CheckRG = Get-AzResourceGroup $AutomationAccountResourceGroupName 
    $CheckAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $AutomationAccountResourceGroupName -Name $AutomationAccountName
    Write-Output "Automation Account named $AutomationAccountName found in resource group $AutomationAccountResourceGroupName."
}
catch {
    Throw "Unable to locate Resource in CoreTech-Log $CoreTechlogSubscriptionID."        
}
#
# Remove existing Automation variable
#
$TestAutomationVariable = Get-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADResourceGroupVariableName -ErrorAction SilentlyContinue
If ([string]::IsNullOrEmpty($TestAutomationVariable) -eq $False) {
    Write-Output "Removing Automation variable $AzureADResourceGroupVariableName from Automation Account $AutomationAccountName."
    Remove-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADResourceGroupVariableName
}
$TestAutomationVariable = Get-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADTenantVariableName -ErrorAction SilentlyContinue
If ([string]::IsNullOrEmpty($TestAutomationVariable) -eq $False) {
    Write-Output "Removing Automation variable $AzureADTenantVariableName from Automation Account $AutomationAccountName."
    Remove-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADTenantVariableName
}
#
# Remove existing Automation credential
#
$TestAutomationVariable = Get-AzAutomationCredential -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADCredentialName -ErrorAction SilentlyContinue
If ([string]::IsNullOrEmpty($TestAutomationVariable) -eq $False) {
    Write-Output "Removing Automation credential $AzureADCredentialName from Azure Automation Account $AutomationAccountName."
    Remove-AzAutomationCredential  -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADCredentialName
}
#
# Setup required Azure Automation variables and credentials
#
New-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADResourceGroupVariableName -Value $TNCREsourceGroupName -Encrypted $False
New-AzAutomationVariable -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADTenantVariableName -Value ((Get-AzContext).tenant.id) -Encrypted $False


$PWord = ConvertTo-SecureString -String $AppSecret.SecretValueText -AsPlainText -Force
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AppIDSecret.SecretValueText, $PWord
New-AzAutomationCredential -ResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -Name $AzureADCredentialName -Value $Credential

exit
[String]$AzureADResourceGroupVariableName = "resourceGroupName" 
[String]$AzureADCredentialVariableName = "AADDCredential"






"done"
exit

$AppId = "03d501b6-5d7d-4935-ade1-94f24e183a5c"
$Secret = "hKC4yCMiuE35YRB+luA6cron/uptEUtPmaJ4Koor0OA="
$TenantID = "fa6e8394-fa69-4f72-b838-00319a91d080"

$PWord = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AppId, $PWord
Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantID

exit
#
# Revert to previous Azure context
#
Set-AzContext -SubscriptionID $CurrentsubscriptionID