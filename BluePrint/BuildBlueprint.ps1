#
#
#
[String]$ManagementGroupname = "MGMT01"
[String]$BluePrintName = "VNET"
[String]$Build = "1.0"
[String]$AssignmentName = $BluePrintName +  $Build
[String]$SubscriptionID = (Get-AzContext).Subscription.id
$BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupname
#
# Montrer les paramètres
#
$resourceNamePrefix = "TESTBP01"
$addressSpaceForVnet = "192.168.0.0/16"
$addressSpaceForSubnet = "192.168.1.0/254"
$AssignParameters = @{
    'resourceNamePrefix' = $resourceNamePrefix
    'addressSpaceForVnet'= $addressSpaceForVnet
    'addressSpaceForSubnet' = $addressSpaceForSubnet
    'Location' = "WestEurope"
}
#
# Corriger l'assignation des paramètres
#
New-AzBlueprintAssignment -Name "VNET" `
    -Blueprint $BluePrintObject `
    -SubscriptionId $SubscriptionID `
    -Location "West Europe" `
    -Parameter $AssignParameters `
    -Lock AllResourcesReadOnly
