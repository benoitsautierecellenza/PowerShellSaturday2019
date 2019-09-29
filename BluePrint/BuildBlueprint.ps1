#
# Source : https://github.com/Azure/azure-blueprints
#
[String]$ArtifactFolder = "artifacts"
[String]$BluePrintsRootFolder = "C:\localgit\PowerShellSaturday2019\BluePrint\BluePrints\"


[String]$ManagementGroupname = "MGMT01"
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$BluePrintName = "Boilerplate"
[String]$BluePrintVersion = "1.0"
Set-AzContext -SubscriptionID $SubscriptionID
#
# Process BluePrints folder
#
Foreach ($BluePrintFolder in (Get-Childitem $BluePrintsRootFolder -Directory)) {
    Write-Output "Processing Azure Blueprint $($BluePrintFolder.Name)."
    #
    # Check for version.txt file
    # OK
    $CheckVersionFile =[System.IO.File]::Exists($($BluePrintFolder.FullName + "\version.txt")) 
    If ($CheckVersionFile -eq $True)
    {
        #
        # File version description exists at root of the Blueprint Folder
        #
        [String]$BluePrintName = $BluePrintFolder.Name
        [String]$BluePrintVersion = get-content $($BluePrintFolder.FullName + "\version.txt")
        #
        # Create the Blueprint Object
        #
        Import-AzBlueprintWithArtifact -Name $BluePrintName  `
            -ManagementGroupId $ManagementGroupname `
            -InputPath $BluePrintFolder.FullName `
            -Force  
        $BluePrintObject = Get-AzBlueprint -ManagementGroupId $ManagementGroupname -Name $BluePrintName 
        #
        # Parse all artefacts object composing the Blueprint (except the BluePrint definition File)
        #
        Foreach ($file in (Get-ChildItem "$BluePrintFolder\$ArtifactFolder")) {
            Write-Output "Processing Blueprint artefact $($file.name) for Blueprint $BluePrintName"
            New-AzBlueprintArtifact -Name $($file.name) -Blueprint $BluePrintObject -ArtifactFile ($file.FullName)
        }
        #
        # Publish BluePrint
        # BUG ICI
        $BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupname
        Publish-AzBlueprint -Blueprint $BluePrintObject -Version $BluePrintVersion
    }
    else {
        Write-Error "Unable to process $($BluePrintFolder.Name) dur to missing version.txt file att BluePrint root folder."
    }
}
"DONE"
exit
#
# Reprocess de chaque répertoire pour parner le ASSIGN.JSON
#
# format à imposer dans le JSON à charger dans le ASSIGN.JSON
$parameters = @{ 
    resourceNamePrefix = "DemoBluePrint"
    addressSpaceForVnet ="192.168.0.0/16" 
    addressSpaceForSubnet ="192.168.0.1/24" 
}
$rgArray = @{ SingleRG = $rgHash }
$AssignedBluePrintName = $BluePrintName
$TestBluePrintAssignment = New-AzBlueprintAssignment -Blueprint $PublishedBluePrintObject -Location WestEurope -SubscriptionId $SubscriptionID -ResourceGroupParameter $rgArray -Parameter $parameters -Name $AssignedBluePrintName -Lock AllResourcesDoNotDelete


"DONE"
EXIT

#
# Import Blueprint network
#
# https://github.com/Azure/azure-blueprints/tree/master/samples/001-builtins/networking-vnet
[String]$BluePrintName = "VirtualNetwork"
[String]$BluePrintVersion = "1.0"
[String]$BluePrintRootFolder = "C:\localgit\PowerShellSaturday2019\BluePrint\BluePrints\networking-vnet"
Import-AzBlueprintWithArtifact -Name $BluePrintName -ManagementGroupId $ManagementGroupname -InputPath $BluePrintRootFolder -Force  
$BluePrintObject = Get-AzBlueprint -ManagementGroupId $ManagementGroupname -Name $BluePrintName 
#
# Parse all artefacts object composing the Blueprint (except the BluePrint definition File)
#
Foreach ($file in (Get-ChildItem "$BluePrintRootFolder\artifacts"))    {
        Write-Output "Processing Blueprint artefact $($file.name) for Blueprint $BluePrintName"
        New-AzBlueprintArtifact -Name $($file.name) -Blueprint $BluePrintObject -ArtifactFile ($file.FullName)
}
$BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupname
Publish-AzBlueprint -Blueprint $BluePrintObject -Version $BluePrintVersion


exit
$BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupname
Publish-AzBlueprint -Blueprint $BluePrintObject -Version $BluePrintVersion


[String]$BluePrintName = "PolicyEnforcement"
[String]$BluePrintVersion = "1.0"
Import-AzBlueprintWithArtifact -Name $BluePrintName -ManagementGroupId $ManagementGroupname -InputPath "C:\localgit\azure-blueprints\samples\001-builtins\common-policies\"

C:\localgit\azure-blueprints\samples\001-builtins\common-policies>cd..

#
# Assign BluePrint
#
$PublishedBluePrintObject = Get-AzBlueprint -ManagementGroupId $ManagementGroupname -Name $BluePrintName -Version $BluePrintVersion
#$rgHash = @{ name="DemoBluePrint"; location = "WestEurope" }

$rgHash = @{ location = "WestEurope" } # Resource Group name is defined in BluePrint, do not nooed to add


$parameters = @{ 
    resourceNamePrefix = "DemoBluePrint"
    addressSpaceForVnet ="192.168.0.0/16" 
    addressSpaceForSubnet ="192.168.0.1/24" 
}
$rgArray = @{ SingleRG = $rgHash }
$AssignedBluePrintName = $BluePrintName
$TestBluePrintAssignment = New-AzBlueprintAssignment -Blueprint $PublishedBluePrintObject -Location WestEurope -SubscriptionId $SubscriptionID -ResourceGroupParameter $rgArray -Parameter $parameters -Name $AssignedBluePrintName -Lock AllResourcesDoNotDelete
#
# Check for BluePrint Assignment error at assign stage
#

#
# Test Azure BluePrint Assignment
#
$TestBluePrintAssignment = Get-AzBlueprintAssignment -SubscriptionId $SubscriptionID -Name $AssignedBluePrintName
While ($TestBluePrintAssignment.ProvisioningState -ne "Succeeded") {
    Write-Output "Waiting for BluePrint Assignement $AssignedBluePrintName on subscription $SubscriptionID."
}




#-LatestPublished



"DONE"
exit
#
# Assign
#
$PublishedBluePrintObject = Get-AzBlueprint -ManagementGroupId $ManagementGroupname -Name $BluePrintName -LatestPublished
$rgHash = @{ name="MyBoilerplateRG"; location = "WestEurope" }
# all other (non-rg) parameters are listed in a single hashtable, with a key/value pair for each parameter
$parameters = @{ principalIds="caeebed6-cfa8-45ff-9d8a-03dba4ef9a7d" }

# All of the resource group artifact hashtables are themselves grouped into a parent hashtable
# the 'key' for each item in the table should match the RG placeholder name in the blueprint
$rgArray = @{ SingleRG = $rgHash }

# Assign the new blueprint to the specified subscription (Assignment updates should use Set-AzBlueprintAssignment
$AssignedBluePrintName = "$BluePrintName-$($PublishedBluePrintObject.Version)"
New-AzBlueprintAssignment -Blueprint $PublishedBluePrintObject -Location WestEurope -SubscriptionId $SubscriptionID -ResourceGroupParameter $rgArray -Parameter $parameters -Name $AssignedBluePrintName


exit

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
# $blueprintName = "TestBluePrint2"
# $subscriptionId = "00000000-1111-0000-1111-000000000000"
# $AssignmentName = "BP-Assignment"
# $myBluerpint = Get-AzBlueprint -Name $blueprintName -LatestPublished
# $rg = @{ResourceGroup=@{name=’RG-BP-TEST1′}}
# New-AzBlueprintAssignment -Name $AssignmentName -Blueprint $myBluerpint -SubscriptionId $subscriptionId -Location “West US” -ResourceGroupParameter $rg