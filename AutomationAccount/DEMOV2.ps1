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
Set-AzContext -subscriptionID 5be15500-7328-4beb-871a-1498cd4b4536
$ResourceGroupName = "DemoPowerShellSaturday"
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
# Monter le déploiement et les ressources
#

#
# Montrer les Runbooks importés
#

#
#
#

#. .\0-Initialize-AutomationAccountSecurity.PS1 -SolutionResourceGroupName "LabAutomation" -SolutionKeyVaultName "LabAutomation" -SolutionSubscriptionID "5be15500-7328-4beb-871a-1498cd4b4536" -SolutionAutomationAccountName "LabAutomation" -AutomationCertificateLifetimePolicy 365 -AutomationAzureADApplicationName LABAUTOMATION 
