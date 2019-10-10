#
# Manage Azure Firewall Rules for Azure Services
#
# Version 1.0 - Initial release - Benoît SAUTIERE
#                               - Storage and KeyVault
#
[OutputType("String")]
Param(
    [Parameter (Mandatory=$True)]
    [String]$ResourceName,

    [Parameter (Mandatory=$True)]
    [ValidateSet("Storage","KeyVault")]
    [String]$ServiceType,

    [Parameter (Mandatory=$True)]
    [ValidateSet("Create","Delete")]
    [String]$OperationName
)
#
# Constants
#
[bool]$DebugMode = $True
[String]$RulePrefix = $ServiceType + "_"
[String]$NetworkResourceGroup = "DemoAzureFirewall"
[Int]$LockWaitPeriod = 10
[String]$LockName = "ProcessServiceRules"
[String]$LockNotes = "Instance Locked by Runbook $LockName."
#
# Variables
#
[DateTime]$StartDate = Get-date
If ($DebugMode -eq $false)
{
    #
    # Authenticating to Azure to generate an answer for this event
    #
    $connectionName = "AzureRunAsConnection"
    try {
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName                    
        Write-output "[AFW-ProcessServiceRules] - Logging in to Azure..."
        Connect-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)   {
            $ErrorMessage = "[AFW-ProcessServiceRules] - Connection $connectionName not found."
            Write-Output "[ERROR]"
            throw $ErrorMessage
        } 
        else {
            Write-Error -Message $_.Exception
            Write-Output "[ERROR]"
            throw $_.Exception
        }
    }
    Write-output "[AFW-ProcessServiceRules] - Successfully authenticated to Azure."
}
#
# Parse les Subnets pour avoir la liste 
#
$SourceAddress = @()
$ListeVNET = Get-AzVirtualNetwork -ResourceGroupName $NetworkResourceGroup
ForEach ($AddressSpace in ($ListeVNET.AddressSpace.Addressprefixes))
{
    $SourceAddress += $AddressSpace
}
#    $SourceAddress.Add($AddressSpace)
switch($ServiceType)
{
    "Storage" {
        $Rules = @{
            ApplicationRuleCollection = @{
                GROUP = @{
                    CollectionName      = "StorageAccountRules"
                        Priority            = 1400
                        ActionType          = "Allow"
                }
                STORAGE = @{
                    name                = $RulePrefix + $ResourceName
                    Protocol            = "https:443"
                    SourceAddress       = $SourceAddress
                    TargetFQDN          = "$ResourceName.blob.core.windows.net", "$ResourceName.queue.core.windows.net", "$ResourceName.table.core.windows.net","$ResourceName.file.core.windows.net"
                    Description         = "Required for Blob storage service."
                }
            }
        }
    }
    "KeyVault" {
        $Rules = @{
            ApplicationRuleCollection = @{
                GROUP = @{
                    CollectionName      = "KeyVaultRules"
                        Priority            = 1401
                        ActionType          = "Allow"
                }
                KEYVAULT = @{
                    name                = $RulePrefix + $ResourceName
                    Protocol            = "https:443"
                    SourceAddress       = $SourceAddress
                    TargetFQDN          = "$ResourceName.vault.azure.net"
                    Description         = "Required for KeyVault Access."
                }
            }
        }
    }
}
Write-Output "[AFW-ProcessServiceRules] - Processing operation $OperationName for resource $ResourceName as $ServiceType resource type."
#
# Build Rule for the Storage Accounts
# OK
$ApplicationRuleCollectionRules = @{}
$NetworkRuleCollectionRules = @{}
Write-Output "[AFW-ProcessServiceRules] - Building new Rule From JSON definition."
foreach($collection in $rules.GetEnumerator()) {
    switch($collection.Name) {
        "ApplicationRuleCollection" {
            #
	        # JSON contain an Application Rule Collection
            # OK
            ForEach ($ApplicationRule in $collection.Value.GetEnumerator()) {
                If ($($ApplicationRule.Name) -like "GROUP") { 	               
                    #
                    # Json definition to create the Collection object
                    # 
                    Write-Output "[AFW-ProcessServiceRules] - Process Azure Firewall group creation : $($ApplicationRule.Value.CollectionName)."
	                $ApplicationGroupRuleName = ($ApplicationRule.Value.CollectionName)
	                $ApplicationGroupRulePriority = $ApplicationRule.Value.Priority
	                $ApplicationGroupRuleAction  = $ApplicationRule.Value.ActionType
	            }
                else {
                If ($OperationName -eq "Create")
                {
                    #
                    # Only process Json definition rule details if operationname is create
                    #
                    Write-Output "[AFW-ProcessServiceRules] - Process Azure Firewall Application rule $($ApplicationRule.Name)."
                    $ApplicationRuleCollectionRule = $Null
                    $ApplicationRuleCollectionRule = New-AzFirewallApplicationRule `
                        -Name $ApplicationRule.Value.name `
                        -Protocol $ApplicationRule.Value.Protocol `
                        -TargetFqdn $ApplicationRule.Value.TargetFQDN `
                        -SourceAddress $ApplicationRule.Value.SourceAddress `
                        -Description $ApplicationRule.Value.Description
                    $ApplicationRuleCollectionRules.add($($ApplicationRule.Name), $ApplicationRuleCollectionRule)
                }
            }
        }            
    }
    "NetworkRuleCollection" {
        #
        # JSON contain a Network Rule Collection
        # OK
        ForEach ($NetworkRule in $collection.value.GetEnumerator()) {
            If ($($NetworkRule.Name) -like "GROUP") { 
                #
                # Json definition to create the Collection object
                # 
                Write-Output "[AFW-ProcessServiceRules] - Process Azure Network group creation : $($NetworkRule.value.CollectionName)."
                $NetworkGroupRuleName = ($NetworkRule.Value.CollectionName)
                $NetworkGroupRulePriority = $NetworkRule.Value.Priority
                $NetworkGroupRuleAction  = $NetworkRule.Value.ActionType
            }
            else {
                If ($OperationName -eq "Create")
                    {
                        #
                        # Only process Json definition rule details if operationname is create
                        #
                        Write-Output "[AFW-ProcessServiceRules] - Process Azure Firewall Network rule $($NetworkRule.Name)." 
                        $networkRuleCollectionRule = $null
                        $networkRuleCollectionRule  = New-AzFirewallNetworkRule `
                            -Name  $networkrule.Value.name `
                            -Description $NetworkRule.value.description `
                            -Protocol $NetworkRule.value.protocol `
                            -SourceAddress $NetworkRule.Value.SourceAddress `
                            -DestinationAddress $NetworkRule.Value.DestinationAddress `
                            -DestinationPort $NetworkRule.Value.DestinationPort
                        $NetworkRuleCollectionRules.add($($NetworkRule.Name), $networkRuleCollectionRule)
                    }                    
                }
            }
	    }            
    }
}
Write-Output "[AFW-ProcessServiceRules] - New Rule created From JSON definition."
#
# Build Azure Firewall collections for the new object to declare in Azure Firewall Configuration
# OK
$FirewallLock = $null
#try {
    #
    # Build new Azure Firewall configuration
    # OK
    $AzureFirewallList = Get-AzFirewall | select-Object resourcegroupname, name  
    ForEach ($AzureFirewall in $AzureFirewallList) {
        #
        # Process Each Azure Firewall instance found 
        # OK
        Write-Output "[AFW-ProcessServiceRules] - Processing Azure Firewall $($AzureFirewall.name)."
        #
        # Check if Azure Firewall instance is locked on Delete or not
        #
        $lock = Get-AzResourceLock -ResourceGroupName $AzureFirewall.resourcegroupname -ResourceName $AzureFirewall.Name -ResourceType Microsoft.Network/azureFirewalls
        If ([string]::IsNullOrEmpty($lock) -eq $False) 
        {
            Write-Output "[AFW-ProcessServiceRules] - Azure Firewall $($AzureFirewall.name) is in locked mode. Wait until unlock."
            [DateTime]$StartLockDate = Get-Date
            [Bool]$LockExit_Flag = $False
            do {
                #
                # Wait until resource is not longer locked
                #
                Start-Sleep -Seconds $LockWaitPeriod
                $TimeSpan = New-TimeSpan $StartLockDate -end (get-date)
                $LockDuration = "{0:N0}" -F ($TimeSpan.TotalSeconds)
                Write-Output "[AFW-ProcessServiceRules] - Waiting for Azure Firewall $($AzureFirewall.name) lock removal since $LockDuration seconds."
                $lock = Get-AzResourceLock -ResourceGroupName $AzureFirewall.resourcegroupname -ResourceName $AzureFirewall.Name -ResourceType Microsoft.Network/azureFirewalls
                If ([string]::IsNullOrEmpty($lock) -eq $True) {
                    $LockExit_Flag= $True
                    Write-Output "[AFW-ProcessServiceRules] Azure Firewall $($AzureFirewall.name) is no longer locked."
                }     
            } Until ($LockExit_Flag -eq $true)
        }
        else {
            #
            # Azure Firewall instance is not locked, ressources can be updated.
            # OK
            Write-Output "[AFW-ProcessServiceRules] - Azure Firewall $($AzureFirewall.name) is not locked."
        }
        #
        # Now we can Set a lock on Azure Firewall to lock any concurrent update
        #
        Write-Output "[AFW-ProcessServiceRules] - Azure Firewall $($AzureFirewall.name) locking for update."
        $FirewallLock = New-AzResourceLock -ResourceGroupName $AzureFirewall.resourcegroupname -ResourceName $AzureFirewall.Name -ResourceType Microsoft.Network/azureFirewalls -LockName $LockName -LockLevel CanNotDelete -LockNotes $LockNotes -Force 
        Write-Output "[AFW-ProcessServiceRules] - Azure Firewall $($AzureFirewall.name) locked for update."
        $ExistingApplicationRuleCollectionRules = @{}
        $AzureFirewallConfig = Get-AzFirewall -ResourceGroupName $($AzureFirewall.resourcegroupname) -Name $($AzureFirewall.name)
        #
        # Process existing Application Collection rule
        # OK
        $listApplicationCollectionrulesname = $AzureFirewallConfig.ApplicationRuleCollections.name
        $testrulecollectionname = $listApplicationCollectionrulesname -contains $ApplicationGroupRuleName
        If($testrulecollectionname -eq $true)
        {
            Write-Output "[AFW-ProcessServiceRules] - Existing Application rule collection named $ApplicationGroupRuleName. Will be rebuilded with existing rules."
            $ExistingApplicationRules =  $AzureFirewallConfig.GetApplicationRuleCollectionByName($ApplicationGroupRuleName).rules
            ForEach($ExistingApplicationRule in $ExistingApplicationRules)
            {
                #
                # Process each Application rule
                #
# Challenge : détecter que le nom est dans la liste des rules à supprimer
                If ($ExistingApplicationRule.Name -ne $($RulePrefix + $ResourceName))
                {
                    # Pas de prise en charge des FQDN Tags
                    $ProtocolList = @()
                    Foreach($Protocol in $ExistingApplicationRule.Protocols)
                    {
                        $ProtocolList += "$($Protocol.ProtocolType):$($Protocol.Port)"
                    }
                    $ApplicationRuleCollectionRule = $null
                    $ApplicationRuleDescription = $ExistingApplicationRule.Description
                    If ([string]::IsNullOrEmpty($ApplicationRuleDescription) -eq $true) 
                    {
                        $ApplicationRuleDescription = "Automatically generated rule"
                    }
                    $ApplicationRuleCollectionRule = New-AzFirewallApplicationRule `
                        -Name $ExistingApplicationRule.Name `
                        -Protocol $ProtocolList `
                        -TargetFqdn ($ExistingApplicationRule.TargetFqdns) `
                        -SourceAddress ($ExistingApplicationRule.SourceAddresses) `
                        -Description $ApplicationRuleDescription                                         
                    $ExistingApplicationRuleCollectionRules.Add($ExistingApplicationRule.Name,$ApplicationRuleCollectionRule)
                }
                else {
                    #
                    # Rule already exists
                    #
                    Switch ($OperationName)
                    {
                        "Create" {
                            Write-Output "[AFW-ProcessServiceRules] - Application Rule named $($RulePrefix + $ResourceName) already exists. No need to add it to rebuild process of Application rule collection $ApplicationGroupRuleName."
                        }
                        "Delete" {
                            #
                            # Delete mode, rule will be excluded at rebuild
                            #
                            Write-Output "[AFW-ProcessServiceRules] - Application Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Application rule collection $ApplicationGroupRuleName."
                        }
                        Default {
                            Write-Output "[ERROR]"
                        }
                    }
                }
            }
        }
        else {
            Write-Output "[AFW-ProcessServiceRules] - Application rule collection $ApplicationGroupRuleName not yet already exists. Will be created."
        }
        #
        # Process existing network rule collections
        #
        $ExistingNetworkRuleCollectionRules = @{}
        $listNetworkCollectionrulesname = $AzureFirewallConfig.ApplicationRuleCollections.name
        $testrulecollectionname = $listNetworkCollectionrulesname -contains $NetworkGroupRuleName
        If($testrulecollectionname -eq $true)
        {
            Write-Output "[AFW-ProcessServiceRules] - Existing Network rule collection named $NetworkGroupRuleName. Will be rebuilded with existing rules."     
            $ExistingNetworkRules =  $AzureFirewallConfig.GetNetworkRuleCollectionByName($NetworkGroupRuleName).rules
            ForEach($ExistingNetworkRule in $ExistingNetworkRules)
            {
                #
                # Process Each network rule
                #
# Challenge : détecter que le nom est dans la liste des rules à supprimer
                If ($ExistingNetworkRule.Name -ne $($RulePrefix + $ResourceName))
                {
                    # Pas de prise en charge des Service Tag, juste des IP rules
                    $NetworkRuleCollectionRule = $Null
                    $NetworkRuleDescription = $ExistingApplicationRule.Description
                    If ([string]::IsNullOrEmpty($NetworkRuleDescription) -eq $true) 
                    {
                        $NetworkRuleDescription = "Automatically generated rule"
                    }
                    $NetworkRuleCollectionRule = New-AzFirewallNetworkRule -name $($ExistingNetworkRule.name) `
                        -SourceAddress $($ExistingNetworkRule.SourceAddresses) `
                        -DestinationAddress $ExistingNetworkRule.DestinationAddresses `
                        -DestinationPort $ExistingNetworkRule.DestinationPorts `
                        -Protocol $ExistingNetworkRule.Protocols `
                        -Description $NetworkRuleDescription                         # A traier pour récupérer le contenu si pas vide
                    $ExistingNetworkRuleCollectionRules.Add($ExistingNetworkRule.Name,$NetworkRuleCollectionRule)
                }
                else {
                    Switch ($OperationName)
                    {
                        "Create" {
                            Write-Output "[AFW-ProcessServiceRules] - Network Rule named $($RulePrefix + $ResourceName) already exists. No need to add it to rebuild process of Network rule collection $NetworkGroupRuleName."
                        }
                        "Delete" {
                            #
                            # Delete mode, rule will be excluded at rebuild
                            #
                            Write-Output "[AFW-ProcessServiceRules] - Network Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Network rule collection $NetworkGroupRuleName."
                        }
                        Default {
                            Write-Output "[ERROR]"
                        }
                    }
                }

            }   
        }
        else {
            Write-Output "[AFW-ProcessServiceRules] - Network rule collection $NetworkGroupRuleName not yet already exists. Will be created."
        }
        if (($AzureFirewallConfig.ApplicationRuleCollections.name) -contains $ApplicationGroupRuleName) {
            #
            # Search for existing Application Collection Rule and delete if exists
            #
            Write-Output "[AFW-ProcessServiceRules] - Azure Firewall Application Collection Rule named $ApplicationGroupRuleName, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveApplicationRuleCollectionByName($ApplicationGroupRuleName)
        }
        else {
	        Write-Output "[AFW-ProcessServiceRules] - No existing Azure Firewall Application Collection Rule found to delete."
        }
        if (($AzureFirewallConfig.NetworkRuleCollections.name) -contains $NetworkGroupRulename) {
            #
            # Search for existing Network Collection Rule and delete if exists
            #
            Write-Output "[AFW-ProcessServiceRules] - Azure Firewall Network Collection Rule named $NetworkGroupRulename, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveNetworkRuleCollectionByName($NetworkGroupRulename)
        }
        else {
	        Write-Output "[AFW-ProcessServiceRules] - No existing Azure Firewall Network Collection Rule found to delete."
        }
        #
        # Merge existing and new Application Collection rule into a new collection
        # OK
        Write-Output "[AFW-ProcessServiceRules] - Merge existing Application rules collection with new rules."
        $NewApplicationRuleCollectionRule = @{}
        If ($OperationName -eq "Create") {
            ForEach ($collection in $ApplicationRuleCollectionRules.GetEnumerator())
            {
                $NewApplicationRuleCollectionRule.Add($collection.Name, $collection.value)
            }
        }        
        foreach($collection in $ExistingApplicationRuleCollectionRules.GetEnumerator())
        {
            $NewApplicationRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        #
        # Merge existing and new Network collection rule into a new collection
        # OK
        Write-Output "[AFW-ProcessServiceRules] - Merge existing Network rules collection with new rules."
        $NewNetworkRuleCollectionRule = @{}
        If ($OperationName -eq "Create") {
            ForEach ($collection in $NetworkRuleCollectionRules.GetEnumerator())
            {
                $NewNetworkRuleCollectionRule.Add($collection.Name, $collection.value)
            }
        }
        foreach($collection in $ExistingNetworkRuleCollectionRules.GetEnumerator())
        {
            $NewNetworkRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        #
        # Create new Azure Firewall Application Collection Rule
        # OK
        If ($NewApplicationRuleCollectionRule.count -GT 0)
        {
            Write-Output "[AFW-ProcessServiceRules] - Creating Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
            $NewAzFwApplicationRuleCollection = New-AzFirewallApplicationRuleCollection `
                -Name $ApplicationGroupRuleName `
                -Priority $ApplicationGroupRulePriority `
                -Rule @($NewApplicationRuleCollectionRule.values) `
                -ActionType $ApplicationGroupRuleAction
            $AzureFirewallConfig.ApplicationRuleCollections += $NewAzFwApplicationRuleCollection
        }
        else {
            Write-Output "[AFW-ProcessServiceRules] - No Azure Application Collection rule to create because no rule inside."
        }

        #
        # Create new Azure Firewall Network Collection Rule
        #
        If ($NewNetworkRuleCollectionRule.count -GT 0)
        {
            Write-Output "[AFW-ProcessServiceRules] - Creating Azure Firewall Network Rule named $NetworkGroupRuleName."
            $NewAZFirewallNetworkRuleCollection = New-AzFirewallNetworkRuleCollection `
                -Name $NetworkGroupRuleName `
                -Priority $NetworkGroupRulePriority `
                -Rule @($NewNetworkRuleCollectionRule.values) `
                -ActionType $NetworkGroupRuleAction
            $AzureFirewallConfig.NetworkRuleCollections += $NewAZFirewallNetworkRuleCollection
        }
        else {
            Write-Output "[AFW-ProcessServiceRules] - No Azure Network Collection rule to create because no rule inside."
        }
        Write-Output "[AFW-ProcessServiceRules] - Updating Azure Firewall $($AzureFirewall.name)"
        $AzureFirewallConfig | Set-AzFirewall | Out-Null
        Write-Output "[AFW-ProcessServiceRules] - Updated Azure Firewall $($AzureFirewall.name)"  

        Write-Output "[AFW-ProcessServiceRules] - Unlocking Azure Firewall $($AzureFirewall.name)." 
        Remove-AzResourceLock -LockId $FirewallLock.LockId -Force | Out-Null
        $FirewallLock = $null
        Write-Output "[AFW-ProcessServiceRules] - Azure Firewall $($AzureFirewall.name) no longer locked."
    }
    $ScriptProcessingTime= $((new-timespan -Start $StartDate -End (get-date)).TotalSeconds).ToString("N2")
    Write-output "[AFW-ProcessServiceRules] - All Azure Firewall updated in $ScriptProcessingTime seconds."
    Write-output "[OK]"   
#}
#catch {
#    If ($FirewallLock -ne $null)
#    {
    #    Remove-AzResourceLock -LockId $FirewallLock.LockId -Force | Out-Null
#    }
#    Write-Output "[ERROR] - $($_.Exception)."
#    Write-Output "[ERROR]"
#}