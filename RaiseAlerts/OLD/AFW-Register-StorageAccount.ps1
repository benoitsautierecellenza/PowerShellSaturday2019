[OutputType("String")]
Param(
    [Parameter (Mandatory=$False)]
    [String]$ResourceName = "teseaeqtn9hd"
)
#
# Contants
#
[bool]$DebugMode = $true
[String]$ResourceGroupName = "DemoazureFirewall"	
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
        try
        {
             $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName                    
             Write-output "Logging in to Azure..."
            Connect-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
        }
        catch {
            if (!$servicePrincipalConnection)
            {
                $ErrorMessage = "Connection $connectionName not found."
                throw $ErrorMessage
            } else{
                Write-Error -Message $_.Exception
                throw $_.Exception
            }
        }
        Write-output "Successfully authenticated to Azure."
}
#
# Parse all VNETS address space to build the source Address for Firewall Rule
# OK
$SourceAddress = @()
$ListVNETS = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName                                              
$AddressSpaces = $ListVNETS.AddressSpace.AddressPrefixes
Foreach($AddressSpace in $AddressSpaces)
{
    $SourceAddress +=$AddressSpace
}
#
# Build Rule for the Storage Accounts
# OK
$Rules = @{
	ApplicationRuleCollection = @{
	    GROUP = @{
	        CollectionName      = "StorageAccountRules"
	        Priority            = 1400
	        ActionType          = "Allow"
	    }
	    STORAGE = @{
	        name                = "Storage_$ResourceName"
	        Protocol            = "https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "$ResourceName.blob.core.windows.net", "$ResourceName.queue.core.windows.net", "$ResourceName.table.core.windows.net","$ResourceName.file.core.windows.net"
	        Description         = "Required for Blob storage service."
	    }
    }
    NetworkRuleCollection = @{        
	    GROUP = @{
	        CollectionName      = "StorageAccountRules"
	        Priority            = 1400
	        ActionType          = "Allow"
	    }
	    KMS = @{
	        name                = "Storage_$ResourceName"
	        description         = "KMS for Windows Licencing purpose"
	        protocol            = "TCP"
	        SourceAddress       = $SourceAddress
	        DestinationAddress  = '23.102.135.246'
	        DestinationPort     = 1688
	    }
    }
}
$ApplicationRuleCollectionRules = @{}
$NetworkRuleCollectionRules = @{}
#
# Build Azure Firewall collections for the new object to declare in Azure Firewall Configuration
# OK
try {
    Write-Output "[AzureFirewall] - Building new Rule From JSON definition."
    foreach($collection in $rules.GetEnumerator()) {
        switch($collection.Name) {
	        "ApplicationRuleCollection" {
	            #
	            # JSON contain a Application Rule Collection
	            # OK
	            ForEach ($ApplicationRule in $collection.Value.GetEnumerator()) {
	                If ($($ApplicationRule.Name) -like "GROUP") { 	                
                        Write-Output "[AzureFirewall] - Process Azure Firewall group creation : $($ApplicationRule.Value.CollectionName)."
	                    $ApplicationGroupRuleName = ($ApplicationRule.Value.CollectionName)
	                    $ApplicationGroupRulePriority = $ApplicationRule.Value.Priority
	                    $ApplicationGroupRuleAction  = $ApplicationRule.Value.ActionType
	                }
	                else {
	                    Write-Output "[AzureFirewall] - Process Azure Firewall Application rule $($ApplicationRule.Name)."
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
	        "NetworkRuleCollection" {
	            #
	            # JSON contain a Network Rule Collection
	            # OK
	            ForEach ($NetworkRule in $collection.value.GetEnumerator()) {
	                If ($($NetworkRule.Name) -like "GROUP") { 
	                    Write-Output "[AzureFirewall] - Process Azure Network group creation : $($NetworkRule.value.CollectionName)."
	                    $NetworkGroupRuleName = ($NetworkRule.Value.CollectionName)
	                    $NetworkGroupRulePriority = $NetworkRule.Value.Priority
	                    $NetworkGroupRuleAction  = $NetworkRule.Value.ActionType
	                }
	                else {                    
	                    Write-Output "[AzureFirewall] - Process Azure Firewall Network rule $($NetworkRule.Name)." 
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
    #
    # Build new Azure Firewall configuration
    # OK
    $AzureFirewallList = Get-AzFirewall | select-Object resourcegroupname, name  
    ForEach ($AzureFirewall in $AzureFirewallList) {
        #
        # Process Each Azure Firewall instance found 
        # OK
        $ExistingApplicationRuleCollectionRules = @{}
        Write-Output "[AzureFirewall] - Processing Azure Firewall $($AzureFirewall.name)"
        $AzureFirewallConfig = Get-AzFirewall -ResourceGroupName $($AzureFirewall.resourcegroupname) -Name $($AzureFirewall.name)
        #
        # Process existing Application Collection rule
        # OK
        $listApplicationCollectionrulesname = $AzureFirewallConfig.ApplicationRuleCollections.name
        $testrulecollectionname = $listApplicationCollectionrulesname -contains $ApplicationGroupRuleName
        If($testrulecollectionname -eq $true)
        {
            Write-Output "[AzureFirewall] - Existing Application rule collection named $ApplicationGroupRuleName. Will be rebuilded with existing rules."
            $ExistingApplicationRules =  $AzureFirewallConfig.GetApplicationRuleCollectionByName($ApplicationGroupRuleName).rules
            ForEach($ExistingApplicationRule in $ExistingApplicationRules)
            {
                #
                # Process each Application rule
                #
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
                $ExistingApplicationRuleCollectionRules.Add($ExistingApplicationRule.Name,$ApplicationRuleCollectionRule )
            }
        }
        else {
            Write-Output "[AzureFirewall] - Application rule collection $ApplicationGroupRuleName not yet already exists. Will be created."
        }
        #
        # Process existing network rule collections
        #
        $ExistingNetworkRuleCollectionRules = @{}
        $listNetworkCollectionrulesname = $AzureFirewallConfig.ApplicationRuleCollections.name
        $testrulecollectionname = $listNetworkCollectionrulesname -contains $NetworkGroupRuleName
        If($testrulecollectionname -eq $true)
        {
            Write-Output "[AzureFirewall] - Existing Network rule collection named $NetworkGroupRuleName. Will be rebuilded with existing rules."
            $ExistingNetworkRules =  $AzureFirewallConfig.GetNetworkRuleCollectionByName($NetworkGroupRuleName).rules
            ForEach($ExistingNetworkRule in $ExistingNetworkRules)
            {
                #
                # Process Each network rule
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
                $ExistingNetworkRuleCollectionRules.Add($ExistingNetworkRule.Name,$NetworkRuleCollectionRule )
            }   
        }
        else {
            Write-Output "[AzureFirewall] - Network rule collection $NetworkGroupRuleName not yet already exists. Will be created."
        }
        #
        # Search for existing Application Collection Rule and delete if exists
        #
        if (($AzureFirewallConfig.ApplicationRuleCollections.name) -contains $ApplicationGroupRuleName) {
            Write-Output "[AzureFirewall] - Azure Firewall Application Collection Rule named $ApplicationGroupRuleName, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveApplicationRuleCollectionByName($ApplicationGroupRuleName)
        }
        else {
	        Write-Output "[AzureFirewall] - No existing Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
        }
        #
        # Search for existing Network Collection Rule and delete if exists
        #
        if (($AzureFirewallConfig.NetworkRuleCollections.name) -contains $NetworkGroupRulename) {
            Write-Output "[AzureFirewall] - Azure Firewall Network Collection Rule named $NetworkGroupRulename, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveNetworkRuleCollectionByName($NetworkGroupRulename)
        }
        else {
	        Write-Output "[AzureFirewall] - No existing Azure Firewall Network Collection Rule named $NetworkGroupRulename."
        }
        #
        # Merge existing and new Application Collection rule into a new collection
        # OK
        Write-Output "[AzureFirewall] - Merge existing Application rules collection with new rules."
        $NewApplicationRuleCollectionRule = @{}
        ForEach ($collection in $ApplicationRuleCollectionRules.GetEnumerator())
        {
            $NewApplicationRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        foreach($collection in $ExistingApplicationRuleCollectionRules.GetEnumerator())
        {
            $NewApplicationRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        #
        # Merge existing and new Network collection rule into a new collection
        # OK
        Write-Output "[AzureFirewall] - Merge existing Network rules collection with new rules."
        $NewNetworkRuleCollectionRule = @{}
        ForEach ($collection in $NetworkRuleCollectionRules.GetEnumerator())
        {
            $NewNetworkRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        foreach($collection in $ExistingNetworkRuleCollectionRules.GetEnumerator())
        {
            $NewNetworkRuleCollectionRule.Add($collection.Name, $collection.value)
        }
        #
        # Create new Azure Firewall Application Collection Rule
        # OK
        Write-Output "[AzureFirewall] - Creating Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
        $NewAzFwApplicationRuleCollection = New-AzFirewallApplicationRuleCollection `
            -Name $ApplicationGroupRuleName `
            -Priority $ApplicationGroupRulePriority `
            -Rule @($NewApplicationRuleCollectionRule.values) `
            -ActionType $ApplicationGroupRuleAction
        $AzureFirewallConfig.ApplicationRuleCollections += $NewAzFwApplicationRuleCollection
        #
        # Create new Azure Firewall Network Collection Rule
        #
        Write-Output "[AzureFirewall] - Creating Azure Firewall Network Rule named $NetworkGroupRuleName."
        $NewAZFirewallNetworkRuleCollection = New-AzFirewallNetworkRuleCollection `
            -Name $NetworkGroupRuleName `
            -Priority $NetworkGroupRulePriority `
            -Rule @($NewNetworkRuleCollectionRule.values) `
            -ActionType $NetworkGroupRuleAction
        $AzureFirewallConfig.NetworkRuleCollections += $NewAZFirewallNetworkRuleCollection
        Write-Output "[AzureFirewall] - Updating Azure Firewall $($AzureFirewall.name)"
        $AzureFirewallConfig | Set-AzFirewall | Out-Null
        Write-Output "[AzureFirewall] - Updated Azure Firewall $($AzureFirewall.name)"  
    }
    $ScriptProcessingTime= $((new-timespan -Start $StartDate -End (get-date)).TotalSeconds).ToString("N2")
    Write-output "[AzureFirewall] - All Azure Firewall updated in $ScriptProcessingTime seconds."
    Write-output "[OK]"   
}
catch {
    Write-Output "[ERROR] - $($_.Exception)"
}