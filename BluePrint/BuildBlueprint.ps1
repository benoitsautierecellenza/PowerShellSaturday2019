[String]$ManagementGroupname = "MGMT01"
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
[String]$ArtifactFolder = "artifacts"
[String]$RolesFolder = "Roles"
[String]$VersionFileName = "version.txt"
[String]$AlertFolderName = "Alerts"
[String]$CustommetricsFolderName = "CustomMetrics"
[String]$RunbookFolderName = "Runbooks"
[String]$DependenciesFolderName = "Dependencies"
[String]$ScriptsFolderName = "Scripts"
[String]$PostAssignScriptFolderName = "POSTASSIGN"
[String]$PostDeployScriptFolderName = "POSTDEPLOY"
[String]$PreAssignScriptFolderName = "PREASSIGN"
[String]$PreDeployScriptFolderName = "PREDEPLOY"
[String]$CleanupScriptFolderName = "CLEANUP"

[String]$RolesRootFolder = (get-location).path
[Int]$MissingRootFolder_ErrorCode = -1
[Int]$MissionVersionFile_ErrorCode = -2
[Int]$DeployBluePrintImportArtefact_ErrorCode = -3
[Int]$DeployBluePrintPublish_ErrorCode = -5
[Int]$DeployBluePrintAlreadyExists_ReturnCode = 1

[Int]$ProcessedRoles = 0

#
# Begin functions
#
Function LogMessage(
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]    
    $Message,
    [ValidateSet("Information","Warning","Error")]
    [Parameter(Mandatory=$True)]
    $Level
    )
{
    $ProcessingTime = $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    Switch($Level)
    {
        "Information" {
            Write-Output ($ProcessingTime + " - " + $Message)
        }
        "Warning" {
            Write-Warning ($ProcessingTime + " - " + $Message)

        }
        "Error" {
            Write-Error ($ProcessingTime + " - " + $Message)
        }
    }
}
Function Deploy-BluePrint(
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]
    [String]$BlueprintRootPath,
    
    [Parameter(Mandatory=$False)]
    [String]$ManagementGroupID
)
{
    [Bool]$FullArtifactImportSuccess_Flag = $True
    Logmessage -Message "[Deploy-BluePrint] - Begin $BlueprintRootPath." -Level Information
    $CheckVersionFile =[System.IO.File]::Exists($($BlueprintRootPath + "\$VersionFileName")) 
    If ($CheckVersionFile -eq $True)
    {
        Logmessage -Message "[Deploy-BluePrint] - $VersionFileName file found at root of $BlueprintRootPath." -Level Information 
        [String]$BluePrintName = (get-item -Path $BlueprintRootPath).Name
        [String]$BluePrintVersion = get-content $($BlueprintRootPath + "\$VersionFileName")
        #
        # Only import if version of Blueprint file does not match blueprints already inside
        #
        $checkExistingBluePrint = Get-AzBlueprint -ManagementGroupId $ManagementGroupID -Name $BluePrintName -ErrorAction SilentlyContinue
        If(([string]::IsNullOrEmpty($checkExistingBluePrint))) {
            LogMessage -message "[Deploy-BluePrint] - BluePrint named $BluePrintName does not exist yet at scope $ManagementGroupID." -Level Information
        }
        else {
            LogMessage -Message "[Deploy-BluePrint] - BluePrint named $BluePrintName already exists at scope $ManagementGroupID." -Level Information
            If (($checkExistingBluePrint.versions) -match $BluePrintVersion) {
                #
                # No need to deploy BluePrint version to scope because already at this level
                # OK
                LogMessage -message "[Deploy-BluePrint] - BluePrint named $BluePrintName with version $BluePrintVersion already deployed at scope $ManagementGroupID" -Level Information
                Return $DeployBluePrintAlreadyExists_ReturnCode
            }
            else {
                #
                # BluePrint version can be published
                # OK
                Logmessage -message "[Deploy-BluePrint] - BluePrint named $BluePrintName already exist at scope $ManagementGroupID, but not for version $BluePrintVersion." -Level Information
            }
        }
        #
        # Create the Blueprint Object
        # OK
        try {
            LogMessage -Message "[Deploy-BluePrint] - Create Blueprint $BluePrintName." -Level Information
            Import-AzBlueprintWithArtifact -Name $BluePrintName -ManagementGroupId $ManagementGroupID -InputPath $BlueprintRootPath -force
            $BluePrintObject = Get-AzBlueprint -ManagementGroupId $ManagementGroupID -Name $BluePrintName                 
            LogMessage -Message "[Deploy-BluePrint] - BluePrint $BluePrintName created as Draft." -Level Information
        }
        catch {
            Logmessage -Message "[Deploy-BluePrint] - BluePrint $BluePrintName not created. Error : $($_.Exception.Message)." -Level Error
            return $DeployBluePrintImportArtefact_ErrorCode           
        }
        #
        # Parse all artefacts object composing the Blueprint (except the BluePrint definition File)
        # OK
        Foreach ($file in (Get-ChildItem "$BlueprintRootPath\$ArtifactFolder")) {
            LogMessage -Message "[Deploy-BluePrint] - Processing BluePrint artefact $($file.name) for Blueprint $BluePrintName." -Level Information
            try {
                New-AzBlueprintArtifact -Name $($file.name) -Blueprint $BluePrintObject -ArtifactFile ($file.FullName)   | Out-Null              
            }
            catch {
                Logmessage -Message "[Deploy-BluePrint] - Unable to import BluePrint artefact $($file.name) for Blueprint $BluePrintName. Error : $($_.Exception.Message)." -Level Error
                $FullArtifactImportSuccess_Flag = $False # To avoid blueprint publishing
                return $DeployBluePrintImportArtefact_ErrorCode
            }
            LogMessage -message "[Deploy-BluePrint] - BluePrint artefact $($file.name) processed successfully for BluePrint $BluePrintName." -level Information
        }
        If ($FullArtifactImportSuccess_Flag -eq $true)
        {
            #
            # All Blueprint artefacts imported successfully, publish the Blueprint with version
            #
            try {
                Logmessage -message "[Deploy-BluePrint] - Publishing BluePrint $BluePrintName version $BluePrintVersion." -Level Information
                $BluePrintObject = Get-AzBlueprint -Name $BluePrintName -ManagementGroupId $ManagementGroupID
                Publish-AzBlueprint -Blueprint $BluePrintObject -Version $BluePrintVersion
                LogMessage -message "[Deploy-BluePrint] - BluePrint $BluePrintName succesfully published with version $BluePrintVersion." -Level Information
                return $true
            }
            catch {
                LogMessage -message "Error while publishing Blueprint $BluePrintName. Error : $($_.Exception.Message)" -Level Error
                Return $DeployBluePrintPublish_ErrorCode
            }
        }
    }
    else {
       Logmessage -message "[Deploy-BluePrint] -  $VersionFileName file not found at root of $BlueprintRootPath." -Level Error
       Return $MissionVersionFile_ErrorCode
    }
    Logmessage -Message "[Deploy-BluePrint] - End $BlueprintRootPath." -Level Information
}

Function Deploy-RoleDependencies (
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]
    [String]$RoleName,
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]
    [String]$FolderName
)
{
    $SaveLocation = Get-Location
    Set-Location -Path $FolderName
    $DependenciesFolders = Get-ChildItem -Directory
    If ($DependenciesFolders.Count -Gt 0)
    {
        Foreach($DependenciesFolder in $DependenciesFolders) {
            $DependencyFolderName = $($DependenciesFolder.name).tolower()
            Switch($DependencyFolderName)
            {
                $AlertFolderName  {
                    LogMessage -message "[Deploy-RoleDependencies] - Folder $AlertFolderName found. Alerts will be processed." -Level Information
                }      
                $CustommetricsFolderName {
                    LogMessage -message "[Deploy-RoleDependencies] - Folder $CustommetricsFolderName found. CustomMetrics will be processed." -Level Information
                }
                $RunbookFolderName {
                    LogMessage -message "[Deploy-RoleDependencies] - Folder $RunbookFolderName found. Automation Runbooks will be imported." -Level Information
                }
            }
            Write-Output "Processing $($DependenciesFolder.name)"
        } 
    }
    else {
        LogMessage -Message "[Deploy-RoleDependencies] - No dependencies to process for Role $RoleName." -Level Information
    }
    Set-location -Path $savelocation
}

Function Deploy-RoleScripts
(
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]
    [String]$RoleName,
    [ValidateNotnullorEmpty()]
    [Parameter(Mandatory=$True)]
    [String]$FolderName
)
{
    $SaveLocation = Get-Location
    Set-Location -Path $FolderName
    $DependenciesFolders = Get-ChildItem -Directory
    If ($DependenciesFolders.Count -Gt 0)
    {
        Foreach($DependenciesFolder in $DependenciesFolders) {
            $DependencyFolderName = $($DependenciesFolder.name).tolower()
            Switch($DependencyFolderName)
            {
                $PreDeployScriptFolderName  {
                    LogMessage -message "[Deploy-RoleScripts] - Folder $PreDeployScriptFolderName found. Pre-Deploy scripts will be processed." -Level Information
                }      
                $PostDeployScriptFolderName {
                    LogMessage -message "[Deploy-RoleDependencies] - Folder $PostDeployScriptFolderName found. Post-Deploy scripts will be processed." -Level Information
                }
            }
            Write-Output "Processing $($DependenciesFolder.name)"
        } 
    }
    else {
        LogMessage -Message "[Deploy-RoleDependencies] - No dependencies to process for Role $RoleName." -Level Information
    }
    Set-location -Path $savelocation
}

Function CleanBluePrint()
{
    #
    # https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/azure-policy-limits.md Purger les Blueprints non assignés sur un management group (et en dessous)
    #
}

Function Deploy()
{
    LogMessage -Message "[Main] - Begin."  -level "Information"
#
# Check for ROLES subfolder
# OK
$TestRolesRootFolder = Get-ChildItem $RolesRootFolder -Directory 
if((($TestRolesRootFolder.name) -contains $RolesFolder) -eq $False) {
    #
    # Roles ub-folder does not exists
    # OK
    Logmessage -Message "[Main] - Unable to locate sub-folder $RolesFolder in $RolesRootFolder." -Level "Error"
    return $MissingRootFolder_ErrorCode
    Exit
}
Else
{
    #
    # Roles Sub-Folder found
    # OK
    LogMessage -Message "[Main] - Sub-folder $RolesFolder found in $RolesRootFolder." -Level "Information"
}
#
# Première passe : Identifier les scripts et dépendances à traiter avant déploiement pour alimenter des listes
# TODO
$FoldersList = Get-ChildItem -Path ".\$RolesFolder" -Recurse -Directory
$FoldersList.FullName -like "*\$PreDeployScriptFolderName"
$FoldersList.FullName -like "*\$PostDeployScriptFolderName"
#
# Processing each sub-folder as a role
#
$SaveSubscription = Get-Azcontext # Save to restore at the end
Set-AzContext -SubscriptionID $SubscriptionID
$Savelocation = Get-Location    
[String]$RolesRootFolder = (get-location).path + "\$RolesFolder\"
$ProcessedFolders = Get-ChildItem $RolesRootFolder -Directory
foreach($RoleRootFolder in $ProcessedFolders) {
    #
    # Process each role $PreDeployScriptFolderName 
    #
    $ProcessedRoles +=1
    Set-location $RoleRootFolder
    $ProcessedRoleName = (Get-Item $RoleRootFolder).name
    Logmessage -Message "[Main] - Processing Role $ProcessedRoleName." -Level "Information"
#
# Intégrer ici le processing des PREDEPLOY scripts
#
    $FoldersInRole = Get-ChildItem -Directory
    #
    # Process each subfolders in each role, filtering specific names
    # 
    [Int]$Count_ProcessedBluePrintsInRole = 0
    [Int]$Count_SuccessBluePrintsInRole = 0
    [Int]$Count_FailedBluePrintsInRole = 0
    ForEach ($folder in $FoldersInRole) {

        Switch(($folder.name).tolower()) {
            $DependenciesFolderName {
                # Revoir, il faut une première passe pour identifier les répertoires contenant les dependances
                Deploy-RoleDependencies -Rolename $ProcessedRoleName -folderName  $folder.fullname            
            }
            $ScriptsFolderName {
                # Revoir, il faut une première passe pour identifier les répertoires contenant les dependances
                Deploy-RoleScripts -Rolename $ProcessedRoleName -folderName  $folder.fullname           
            }
            default {
                $Count_ProcessedBluePrintsInRole += 1
                $retour = Deploy-BluePrint $folder.FullName -ManagementGroupID $ManagementGroupname # Later import au niveau souscription?
                switch ($retour) {
                    $true {
                        $Count_SuccessBluePrintsInRole += 1
                    }
                    $DeployBluePrintAlreadyExists_ReturnCode {
                        $Count_SuccessBluePrintsInRole +=1
                    }
                    default {
                        $Count_FailedBluePrintsInRole +=1
                    }
                }
                    
            }
        }
        #Traitement des POSTDEPLOY
    }
    Logmessage -Message "[Main] - Role $ProcessedRoleName processed." -Level "Information"
    #
    # Intégrer ic le traitement des postDEPLOY
    #
}
Logmessage -Message "[Main] - Processed roles $ProcessedRoles." -Level Information
Set-AzContext -SubscriptionId $SaveSubscription.Subscription.id
Set-location $Savelocation
LogMessage -Message "[Main] - End." -Level "Information"
}
Function Assign()
{
    # Assignation selon des 

    #
# Reprocess de chaque répertoire pour parner le ASSIGN.JSON
#
# Intégrer la prise en charge de variables?

# format à imposer dans le JSON à charger dans le ASSIGN.JSON
$parameters = @{ 
    resourceNamePrefix = "DemoBluePrint"
    addressSpaceForVnet ="192.168.0.0/16" 
    addressSpaceForSubnet ="192.168.0.1/24" 
}
$rgArray = @{ SingleRG = $rgHash }
$AssignedBluePrintName = $BluePrintName
$TestBluePrintAssignment = New-AzBlueprintAssignment -Blueprint $PublishedBluePrintObject -Location WestEurope -SubscriptionId $SubscriptionID -ResourceGroupParameter $rgArray -Parameter $parameters -Name $AssignedBluePrintName -Lock AllResourcesDoNotDelete


}
#
# end functions
#
Deploy
