[OutputType("String")]
Param(
    [Parameter (Mandatory=$False)]
    [String]$ResourceName = "teseaeqtn9hd"
)
#
# Contants
#
[bool]$DebugMode = $true
[String]$RulePrefix = "Storage_"
[String]$ApplicationGroupRuleName = "StorageAccountRules"
[String]$NetworkGroupRuleName = "StorageAccountRules"
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

$ApplicationRuleCollectionRules = @{}
$NetworkRuleCollectionRules = @{}
#
# Build Azure Firewall collections for the new object to declare in Azure Firewall Configuration
# OK
try {
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
            Write-Output "[AzureFirewall] - Existing Application rule collection named $ApplicationGroupRuleName. Will be rebuilded to remove rule for $ResourceName."
            $ExistingApplicationRules =  $AzureFirewallConfig.GetApplicationRuleCollectionByName($ApplicationGroupRuleName).rules
            ForEach($ExistingApplicationRule in $ExistingApplicationRules)
            {
                #
                # Process each Application rule
                #
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
                    $ExistingApplicationRuleCollectionRules.Add($ExistingApplicationRule.Name,$ApplicationRuleCollectionRule )
                }
                else {
                    Write-Output "[AzureFirewall] - Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Application rule collection $ApplicationGroupRuleName."
                }
            }
        }
        else {
            Write-Output "[AzureFirewall] - Application rule collection $ApplicationGroupRuleName not yet already exists. No rule to delete."
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
                #
                If ($ExistingApplicationRule.Name -ne $($RulePrefix + $ResourceName))
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
                    $ExistingNetworkRuleCollectionRules.Add($ExistingNetworkRule.Name,$NetworkRuleCollectionRule )
                }
                else {
                    Write-Output "[AzureFirewall] - Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Application rule collection $NetworkGroupRuleName."                    
                }
            }   
        }
        else {
            Write-Output "[AzureFirewall] - Network rule collection $NetworkGroupRuleName not yet already exists. No rule to delete."
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


