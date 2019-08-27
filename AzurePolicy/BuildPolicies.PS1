#
# Update existing policy assignments 
#
Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$Build
)
[String]$SubscriptionID = (Get-AzContext).Subscription.id
[String]$Scope = "/subscriptions/$SubscriptionID/"
Write-Output "Removing exiting Azure Policy Assignments."
$TestPolicy = Get-AzPolicyAssignment -Scope $Scope
If ([string]::IsNullOrEmpty($TestPolicy) -eq $False) {Get-AzPolicyAssignment -Scope $Scope | Remove-AzPolicyAssignment -Scope $scope | Out-Null }
#
# Import AZ-DEFAULTTAG-01-RULE Policy
#
Write-Output "Import AZ-DEFAULTTAG-01-RULE Policy"
[String]$ManagementGroupName = "MGMT01"
[String]$PolicyDefinitionFileURI ="https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-DEFAULTTAG-01/AZ-DEFAULTTAG-01-RULE.json"
[String]$PolicyParameterFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-DEFAULTTAG-01/AZ-DEFAULTTAG-01-PARAMETERS.json"
[String]$PolicyName = "DefautltValue4UpdatePolicy"
[String]$PolicyDisplayName = $PolicyName + "_" + $Build
New-AzPolicyDefinition -Name $PolicyName `
    -DisplayName $PolicyDisplayName `
    -Policy $PolicyDefinitionFileURI `
    -Parameter $PolicyParameterFileURI `
    -ManagementGroupName $ManagementGroupName `
    -Mode All
#
# Import AZ-ALLOWEDTAGVALUES Policy
#
Write-Output "Import AZ-ALLOWEDTAGVALUES Policy"
[String]$PolicyDefinitionFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-ALLOWEDTAGVALUES-02/AZ-ALLOWEDTAGVALUES-02-RULE.json"
[String]$PolicyParameterFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-ALLOWEDTAGVALUES-02/AZ-ALLOWEDTAGVALUES-02-PARAMETERS.json"
[String]$PolicyName = "AllowedTagValues4UpdatePolicy"
[String]$PolicyDisplayName = $PolicyName + "_" + $Build
New-AzPolicyDefinition -Name $PolicyName `
    -DisplayName $PolicyDisplayName `
    -Policy $PolicyDefinitionFileURI `
    -Parameter $PolicyParameterFileURI `
    -ManagementGroupName $ManagementGroupName `
    -Mode All
#
# Assign AZ-DEFAULTTAG-01-RULE Policy
#
Write-Output "Assign AZ-DEFAULTTAG-01-RULE Policy"
[String]$PolicyName = "DefautltValue4UpdatePolicy"
[String]$SubscriptionID = (Get-AzContext).Subscription.id
[String]$UpdatePolicyTagName = "UpdatePolicy"
[String]$DefaultTagValue = "AlwaysReboot"
[String]$PolicyAssignname = "MGMT01-VM-P1"  + "_" + $Build
[String]$Scope = "/subscriptions/$SubscriptionID/"
$PolicyDefinition = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupName -Custom | Where-Object {$_.name -eq $PolicyName}
$AssignParameters = @{
    'UpdatePolicyTagName' = $UpdatePolicyTagName;
    'DefaultTagValue'= $DefaultTagValue
}
New-AzPolicyAssignment -Name $PolicyAssignname `
    -PolicyDefinition $PolicyDefinition `
    -Scope $Scope `
    -PolicyParameterObject $AssignParameters
#
# Assign AZ-ALLOWEDTAGVALUES Policy
#
Write-Output "Assign AZ-ALLOWEDTAGVALUES Policy"
$PolicyName = "AllowedTagValues4UpdatePolicy"
[String]$PolicyAssignname = "MGMT01-VM-P2"  + "_" + $Build
$UpdatePolicyTagName = "UpdatePolicy"
$AllowedValues = @("AlwaysReboot", "RebootIfRequired", "OnlyReboot", "NeverReboot")
$PolicyDefinition = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupName -Custom | Where-Object {$_.name -eq $PolicyName}
$AssignParameters = @{
    'UpdatePolicyTagName' = $UpdatePolicyTagName;
    'UpdatePolicyTagAllowedValues' = ($AllowedValues)
}
New-AzPolicyAssignment -Name $PolicyAssignname `
    -PolicyDefinition $PolicyDefinition `
    -Scope $Scope `
    -PolicyParameterObject $AssignParameters