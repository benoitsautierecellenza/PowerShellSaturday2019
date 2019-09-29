[String]$ManagementGroupname = "MGMT01"
[String]$BluePrintName = "VNET"
[String]$Build = "1.0"
[String]$AssignmentName = $BluePrintName +  $Build
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
$BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupname -LatestPublished
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
}
#$RG = @{ResourceGroup=@{name='Networking';location='WestEurope'}}
$RG = @{ResourceGroup=@{name='Networking'}}
#
# Corriger l'assignation des paramètres
# BUG A CORRIGER ICI
New-AzBlueprintAssignment -Name "VNET" `
    -Blueprint $BluePrintObject `
    -SubscriptionId $SubscriptionID `
    -Location "West Europe" `
    -Parameter $AssignParameters `
    -ResourceGroupParameter $RG `
    -Lock AllResourcesReadOnly

exit
# https://gertkjerslev.com/powershell-modul-for-azure-blueprint
$blueprintName = “TestBluePrint2”
$subscriptionId = “00000000-1111-0000-1111-000000000000″‘
$AssignmentName = “BP-Assignment”
$myBluerpint = Get-AzBlueprint -Name $blueprintName -LatestPublished
$rg = @{ResourceGroup=@{name=’RG-BP-TEST1′}}

New-AzBlueprintAssignment -Name $AssignmentName -Blueprint $myBluerpint -SubscriptionId $subscriptionId -Location “West US” -ResourceGroupParameter $rg