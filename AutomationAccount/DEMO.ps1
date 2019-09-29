#
# Prerequisites
#
Install-Module -Name 'AzureAD.Standard.Preview' -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber 
import-module azuread.standard.preview
Connect-AzureAd
Connect-AZAccount
$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
Set-AzContext -subscriptionID $SubscriptionID

# Demo n°1
# Find modules with dependencies
#
Find-Module -Name az.Accounts -Repository PSGallery -IncludeDependencies
Find-Module -Name AzureAD -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.Automation -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.Resources -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.Storage -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.KeyVault -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.OperationalInsights -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.Network -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.RecoveryServices -Repository PSGallery -IncludeDependencies
Find-Module -Name Az.Compute -Repository PSGallery -IncludeDependencies
#
# Demo n°2 : Déploiement Azure Automation Account
#
$ResourceGroupName = "DemoPowerShellSaturdayV2"
[String]$Environment = "PROD"
[String]$AzureRegion = "WestEurope"
$DeploymentName = $Environment + (new-guid).guid 
$AutomationAccountName = "Automation$Environment"
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AutomationAccount/AutomationAccount.JSON"
New-AzResourceGroup $ResourceGroupName -Location WestEurope
New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri $TemplateFileURI `
    -automationAccountName $AutomationAccountName `
    -automationAccountRegion $AzureRegion `
    -EnvironmentTag $Environment
#
# Demo n°3 :Créating KeyVault
#
$LowerCaseLetterCodes = (97..122) # Source : https://dev.to/omiossec/powershell-files-and-azure-storage-account-blobs-5g8
$KeyVaultName = -join ((Get-Random -InputObject $LowercaseLetterCodes -Count 24) | Foreach-Object {[char]$_} )
New-AzKeyVault -ResourceGroupName $ResourceGroupName `
    -Name $KeyVaultName `
    -Location $AzureRegion `
    -Sku Standard `
    -Tag @{Name="Environment"; Value=$Environment}
#
# Creating Azure AD Application
#
$Mode = "Create" 
. .\SPN-GENERATOR.PS1 -SolutionResourceGroupName $ResourceGroupName `
    -SolutionKeyVaultName $KeyVaultName `
    -SolutionSubscriptionID $SubscriptionID `
    -AzureADApplicationName $AutomationAccountName `
    -AutomationCertificateLifetimePolicy 12 `
    -AuthenticationMethod Certificate `
    -mode $Mode
#
# Configuring Azure automation Credentials and Secrets in Azure Automation
#
. .\Configure-AutomationAccountSecurity.PS1 -SolutionResourceGroupName $ResourceGroupName `
    -SolutionKeyVaultName $KeyVaultName `
    -SolutionSubscriptionID $SubscriptionID `
    -SolutionAutomationAccountName $AutomationAccountName `
    -AutomationAzureADApplicationName $AutomationAccountName 
#
# Demo : Launch Runbook
#