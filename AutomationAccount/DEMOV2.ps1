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
$ResourceGroupName = "DemoPowerShellSaturdayV2"
[String]$Environment = "PROD"
[String]$AzureRegion = "WestEurope"
$DeploymentName = $Environment + (new-guid).guid 
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AutomationAccount/AutomationAccount.JSON"
$ParameterFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AutomationAccount/parameters.json"
New-AzResourceGroup $ResourceGroupName -Location WestEurope
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileURI -automationAccountName LAB -automationAccountRegion $AzureRegion -EnvironmentTag $Environment


#-TemplateParameterUri $ParameterFileURI -automationAccountName LAB 
#
# Monter le déploiement et les ressources
#

#
# Montrer les Runbooks importés
#

#
# Créer l'application Azure AD
#

#
# Importer les secrets 
#