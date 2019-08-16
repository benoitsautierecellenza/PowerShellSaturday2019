[String]$subscriptionName = "Microsoft Azure Sponsorship"
[String]$ResourceGroupName = "DemoazureFirewall"	 
[String]$SourceAddress = "10.6.0.0/16"
[String]$Subscriptionname = (Get-AzContext).Subscription.name
[String]$Version = "1.0"
#
# Get Log Analytics OMS Workspace ID (required in OMS Agent firewall rules)
#
$WorkspaceInstance = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
$OMSWorkspaceID = $WorkspaceInstance.CustomerId.guid
#
# Rule definition for Virtual machines
#
$Rules = @{
	ApplicationRuleCollection = @{
	    GROUP = @{
	        CollectionName      = "VMS"
	        Priority            = 1300
	        ActionType          = "Allow"
	    }
	    OMS_GEN1 = @{
	        name                = "OMS_GEN1"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "$OMSWorkspaceID.ods.opinsights.azure.com"
	        Description         = "Required for OMS Log Analytics."
	    }
	    OMS_GEN2 = @{
	        name                = "OMS_GEN2"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "$OMSWorkspaceID.oms.opinsights.azure.com"
	        Description         = "Required for OMS Log Analytics."
	    }
	    OMS_GEN3 = @{
	        name                = "OMS_GEN3"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "opinsightsweuomssa.blob.core.windows.net"
	        Description         = "Required for OMS Log Analytics."
	    }
	    OMS_GEN4 = @{
	        name                = "OMS_GEN4"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "scadvisorcontent.blob.core.windows.net"
	        Description         = "Required for OMS Log Analytics."
	    }
	    OMS_GEN5 = @{
	        name                = "OMS_GEN5"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "*.monitoring.azure.com"
	        Description         = "Required for OMS Log Analytics."
	    }
	    OMS_GEN6 = @{
	        name                = "OMS_GEN6"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "client.wns.windows.com"
	        Description         = "Required for OMS Log Analytics."
        }
	    OMS_LINUX1 = @{
	        name                = "OMS_LINUX1"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "packages.microsoft.com"
	        Description         = "Required for OMS Log Analytics for Linux Virtual machines."
	    }        
	    OMS_LINUX2 = @{
	        name                = "OMS_LINUX2"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "*.ubuntu.com"
	        Description         = "Required for OMS Log Analytics for Linux Virtual machines."
	    }
	    OMS_LINUX3 = @{
	        name                = "OMS_LINUX3"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "download.opensuse.org"
	        Description         = "Required for OMS Log Analytics for Linux Virtual machines."
	    }
	    OMS_LINUX4 = @{
	        name                = "OMS_LINUX4"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "api.snapcraft.io"
	        Description         = "Required for OMS Log Analytics for Linux Virtual machines."
	    }
	    OMS_WINDOWS1 = @{
	        name                = "OMS_WINDOWS1"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "tsfe.trafficshaping.dsp.mp.microsoft.com"
	        Description         = "Required for OMS Log Analytics for Windows Virtual machines."
	    }
	    OMS_WINDOWS2 = @{
	        name                = "OMS_WINDOWS2"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "adl.windows.com"
	        Description         = "Required for OMS Log Analytics for Windows Virtual machines."
	    }
	    AUTOMATION_AGENT1 = @{
	        name                = "AUTOMATION_AGENT1"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "agentserviceapi.azure-automation.net"
	        Description         = "Required for Azure Automation Update Management"
	    }
	    AUTOMATION_AGENT2 = @{
	        name                = "AUTOMATION_AGENT2"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "we-agentservice-prod-1.azure-automation.net"
	        Description         = "Required for Azure Automation Update Management"
	    }
	    AUTOMATION_AGENT3 = @{
	        name                = "AUTOMATION_AGENT3"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "we-jobruntimedata-prod-su1.azure-automation.net"
	        Description         = "Required for Azure Automation Update Management"
	    }
	    AUTOMATION_AGENT4 = @{
	        name                = "AUTOMATION_AGENT4"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "$OMSWorkspaceID.agentsvc.azure-automation.net"
	        Description         = "Required for Azure Automation Update Management"
	    }
	    AZUREINGUEST_POLICY1 = @{
	        name                = "AZUREINGUEST_POLICY1"
	        Protocol            = "http:80","https:443"
	        SourceAddress       = $SourceAddress
	        TargetFQDN          = "oaasguestconfigwes1.blob.core.windows.net"
	        Description         = "Required for Azure Policy in-Guest for Virtual machines."
	    }
	}
	NetworkRuleCollection = @{        
	    GROUP = @{
	        CollectionName      = "VMS"
	        Priority            = 1300
	        ActionType          = "Allow"
	    }
	    KMS = @{
	        name                = "KMS"
	        description         = "KMS for Windows Licencing purpose"
	        protocol            = "TCP"
	        SourceAddress       = $SourceAddress
	        DestinationAddress  = '23.102.135.246'
	        DestinationPort     = 1688
	    }
    }
}
#
# Process RuleS Hashtable to replace parameters
#
$ApplicationRuleCollectionRules = @{}
$NetworkRuleCollectionRules = @{}
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
	                $ApplicationGroupRuleName = ($ApplicationRule.Value.CollectionName + "-" + $Version)
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
	            $NetworkGroupRuleName = ($NetworkRule.Value.CollectionName + "-" + $Version)
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
$ApplicationRuleCollectionRules.OMS_GEN2
#
# Process each Firewall instances
#
$AzureFirewallList = Get-AzFirewall | select-Object resourcegroupname, name    
ForeAch ($AzureFirewall in $AzureFirewallList) {
    #
    # Process Each Azure Firewall instance found 
	#
	Write-Output "Processing Azure Firewall rules for $($AzureFirewall.name) located in $($AzureFirewall.resourcegroupname)"
	$AzureFirewallConfig = Get-AzFirewall -ResourceGroupName $($AzureFirewall.resourcegroupname) -Name $($AzureFirewall.name)
	#
	# Delete existing Application Rule collection
	#
	if (($AzureFirewallConfig.ApplicationRuleCollections.name) -contains $ApplicationGroupRuleName) {
	    Write-Output "Deleting existing Azure Firewall application collection rule : $ApplicationGroupRuleName."
	    $AzureFirewallConfig.RemoveApplicationRuleCollectionByName($ApplicationGroupRuleName)
	}
	else {
	    Write-Output "No existing Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
	}
	#
	# Delete existing Application Rule collection
	#
	if (($AzureFirewallConfig.NetworkRuleCollections.name) -contains $NetworkGroupRuleName) {
	    Write-Output "Deleting existing Azure Firewall application collection rule : $NetworkGroupRuleName."
	    $AzureFirewallConfig.RemoveNetworkRuleCollectionByName($ApplicationGroupRuleName)
	}
	else {
	    Write-Output "No existing Azure Firewall Application Collection Rule named $NetworkGroupRuleName."
	}   
	#
	# Create the required Application group rule with Firewall rules
	#
	if ($ApplicationRuleCollectionRules.Count -Gt 0) {
	    #
	    # Create Azure Firewall Application group with rules
	    #
	    Write-Output "Creating Azure Firewall Application Rule named $ApplicationGroupRuleName."
	    $NewAzFwApplicationRuleCollection = New-AzFirewallApplicationRuleCollection `
	        -Name $ApplicationGroupRuleName `
	        -Priority $ApplicationGroupRulePriority `
	        -Rule @($ApplicationRuleCollectionRules.values) `
	        -ActionType $ApplicationGroupRuleAction
	    $AzureFirewallConfig.ApplicationRuleCollections += $NewAzFwApplicationRuleCollection
	}
	else {
	    $NewAzFwApplicationRuleCollection = $null
	}
	#
	# Create the required Network group rule with Firewall rules
	#
	If( $NetworkRuleCollectionRules.count -Gt 0) {
	    Write-Output "Creating Azure Firewall Network Rule named $NetworkGroupRuleName."
	    $NewAZFirewallNetworkRuleCollection = New-AzFirewallNetworkRuleCollection `
	        -Name $NetworkGroupRuleName `
	        -Priority $NetworkGroupRulePriority `
	        -Rule @($NetworkRuleCollectionRules.values) `
	        -ActionType $NetworkGroupRuleAction
	    $AzureFirewallConfig.NetworkRuleCollections += $NewAZFirewallNetworkRuleCollection
    }
	else {
	    $NewAZFirewallNetworkRuleCollection = $Null
	}
	#
	#
	#
	Write-output  "Updating Azure Firewall configuration $($AzureFirewall.name) located in $($AzureFirewall.resourcegroupname)"
	$AzureFirewallConfig | Set-AzFirewall | Out-Null
}
