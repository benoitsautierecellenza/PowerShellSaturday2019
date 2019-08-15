Connect-AzAccount
Get-Azsubscription
Set-AzContext -subscriptionID 5be15500-7328-4beb-871a-1498cd4b4536
$ResourceGroupName = "DemoPowerShellSaturday"
$DeploymentName = "DEV" + (new-guid).guid 
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AutomationAccount/AutomationAccount.JSON"
$ParameterFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AutomationAccount/parameters.json"
New-AzResourceGroup $ResourceGroupName -Location WestEurope
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileURI -TemplateParameterUri $ParameterFileURI -automationAccountName LAB 

