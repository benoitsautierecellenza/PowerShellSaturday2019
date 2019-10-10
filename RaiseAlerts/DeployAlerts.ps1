[String]$ResourceGroupName = "LabAutomation"
[String]$Subscriptionid = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$ResourceGroupName = "LabAutomation"
[String]$AlertName = "DemoRaiseAlert4Storage"
[String]$ActionGroupName = "DemoAlert"
[String]$RunbookName = "AFW-ProcessServiceRules"
Set-AzContext -SubscriptionId $Subscriptionid
$DeploymentName = (new-guid).guid
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/RaiseAlerts/RaiseAlert4Storage.JSON"
New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri $TemplateFileURI `
    -ActivityLogAlertName $AlertName `
    -actionGroupName $ActionGroupName `
    -RunbookName $RunbookName

[String]$ResourceGroupName = "LabAutomation"
[String]$Subscriptionid = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$ResourceGroupName = "LabAutomation"
[String]$AlertName = "DemoRaiseAlert4KeyVault"
[String]$ActionGroupName = "DemoAlert"
[String]$RunbookName = "AFW-ProcessServiceRules"
Set-AzContext -SubscriptionId $Subscriptionid
$DeploymentName = (new-guid).guid
$TemplateFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/RaiseAlerts/RaiseAlert4KeyVault.JSON"
New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri $TemplateFileURI `
    -ActivityLogAlertName $AlertName `
    -actionGroupName $ActionGroupName `
    -RunbookName $RunbookName
