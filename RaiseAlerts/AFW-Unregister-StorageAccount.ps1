[OutputType("String")]
Param(
    [Parameter (Mandatory=$False)]
    [String]$resourceGroupName= "testKeyvault",
    [Parameter (Mandatory=$False)]
    [String]$ResourceName = "testcreatesto97d"

)
#
# Cette fois, on supprimr une règle existante, donc on conserve le mécanisme de rebuild jusqu'à trouver la règle à ignorer
#
[bool]$DebugMode = $true
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
[String]$ResourceGroupName = "DemoazureFirewall"	
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
#
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
foreach($collection in $rules.GetEnumerator()) {
    switch($collection.Name) {
	    "ApplicationRuleCollection" {
	        #
	        # JSON contain a Application Rule Collection
	        #
	        Write-host "Processing ApplicationRuleCollection"
	        ForEach ($ApplicationRule in $collection.Value.GetEnumerator()) {
	            If ($($ApplicationRule.Name) -like "GROUP") { 	                
                    Write-Output "Process Azure Firewall group creation : $($ApplicationRule.Value.CollectionName)."
	                $ApplicationGroupRuleName = ($ApplicationRule.Value.CollectionName)
	                $ApplicationGroupRulePriority = $ApplicationRule.Value.Priority
	                $ApplicationGroupRuleAction  = $ApplicationRule.Value.ActionType
	            }
	            else {
	                Write-Output "Process Azure Firewall Application rule $($ApplicationRule.Name)."
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
	        #
	        Write-host "Processing NetworkRuleCollection"
	        ForEach ($NetworkRule in $collection.value.GetEnumerator()) {
	            If ($($NetworkRule.Name) -like "GROUP") { 
	                Write-Output "Process Azure Network group creation : $($NetworkRule.value.CollectionName)."
	                $NetworkGroupRuleName = ($NetworkRule.Value.CollectionName)
	                $NetworkGroupRulePriority = $NetworkRule.Value.Priority
	                $NetworkGroupRuleAction  = $NetworkRule.Value.ActionType
	            }
	            else {                    
	                Write-Output "Process Azure Firewall Network rule $($NetworkRule.Name)." 
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
$AzureFirewallList = Get-AzFirewall | select-Object resourcegroupname, name    # filter sur le resourceGroup
ForEach ($AzureFirewall in $AzureFirewallList) {
    #
    # Process Each Azure Firewall instance found 
    #
    $ExistingApplicationRuleCollectionRules = @{}
	Write-Output "Processing Azure Firewall rules for $($AzureFirewall.name) located in $($AzureFirewall.resourcegroupname)"
    $AzureFirewallConfig = Get-AzFirewall -ResourceGroupName $($AzureFirewall.resourcegroupname) -Name $($AzureFirewall.name)
    #
    # Process existing Application Collection rule
    #
# bug ici si la collection n'existe pas préalablement, a traiter
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
            -Description $ApplicationRuleDescription                                         # A traier pour récupérer le contenu si pas vide
        $ExistingApplicationRuleCollectionRules.Add($ExistingApplicationRule.Name,$ApplicationRuleCollectionRule )
    }
    #
    # Process existing network rule collections
    #
    $ExistingNetworkRuleCollectionRules = @{}
# bug ici si la collection n'existe pas préalablement, a traiter
    $ExistingNetworkRules =  $AzureFirewallConfig.GetNetworkRuleCollectionByName($NetworkGroupRuleName).rules
    ForEach($ExistingNetworkRule in $ExistingNetworkRules)
    {
        #
        # Process Each network rule
        # PAs de prise en charge des Service Tag, juste des IP rules
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
    #
    # Search for existing Application Collection Rule and delete if exists
    #
    if (($AzureFirewallConfig.ApplicationRuleCollections.name) -contains $ApplicationGroupRuleName) {
        Write-Output "Azure Firewall Application Collection Rule named $ApplicationGroupRuleName, will be deleted to inject new content."
        $AzureFirewallConfig.RemoveApplicationRuleCollectionByName($ApplicationGroupRuleName)
    }
    else {
	    Write-Output "No existing Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
    }
    #
    # Search for existing Networl COllection Rule and delete if exists
    #
    if (($AzureFirewallConfig.NetworkRuleCollections.name) -contains $NetworkGroupRulename) {
        Write-Output "Azure Firewall Network Collection Rule named $NetworkGroupRulename, will be deleted to inject new content."
        $AzureFirewallConfig.RemoveNetworkRuleCollectionByName($NetworkGroupRulename)
    }
    else {
	    Write-Output "No existing Azure Firewall Network Collection Rule named $NetworkGroupRulename."
    }
    #
    # Merge existing and new Application Collection rule into a new collection
    # OK
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
    #
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
    Write-Output "Creating Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
    $NewAzFwApplicationRuleCollection = New-AzFirewallApplicationRuleCollection `
        -Name $ApplicationGroupRuleName `
        -Priority $ApplicationGroupRulePriority `
        -Rule @($NewApplicationRuleCollectionRule.values) `
        -ActionType $ApplicationGroupRuleAction
    $AzureFirewallConfig.ApplicationRuleCollections += $NewAzFwApplicationRuleCollection
   
    Write-Output "Creating Azure Firewall Network Rule named $NetworkGroupRuleName."
    $NewAZFirewallNetworkRuleCollection = New-AzFirewallNetworkRuleCollection `
        -Name $NetworkGroupRuleName `
        -Priority $NetworkGroupRulePriority `
        -Rule @($NewNetworkRuleCollectionRule.values) `
        -ActionType $NetworkGroupRuleAction
    $AzureFirewallConfig.NetworkRuleCollections += $NewAZFirewallNetworkRuleCollection

    $AzureFirewallConfig | Set-AzFirewall | Out-Null

}

exit
# remettre le try catch a la fin
try {
    [String]$VNETResourceGroupName = "DemoAzureFirewall"
    [String]$SecurityAuditResourceGroupname = "LabAutomation"
    [String]$SecurityAuditSTorageAcoccountName = "automationartifact"
    [String]$SecurityLogName = "Security"
    Write-output "[OK]"   
}
catch {
    Write-Output "[ERROR] - $($_.Exception)"
}


