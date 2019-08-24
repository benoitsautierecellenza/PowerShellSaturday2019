#
# Manage Azure Firewall Rules for Storage Accounts
#
# Version 1.0 - Initial release - Benoît SAUTIERE
# A exécuter avant appel pour créer le paramètre $SourceAddress : [Array]$parameters = @("172.16.0.0/16", "192.168.0.0/16", "10.0.0.0/8")
# -ResourceName "finaltest7" -ServiceType "Storage" -OperationName "Create" -SourceAddress $Parameters
# Rendre le paramètre $SourceAddress obligatoire uniquement si Create
# Intégrer le test du lock pour s'assurer qu'une opération n'est pas en cours
#
[OutputType("String")]
Param(
    [Parameter (Mandatory=$False)]
    [String]$ResourceName = "finaltest6",

    [Parameter (Mandatory=$False)]
    [ValidateSet("Storage","KeyVault")]
    [String]$ServiceType = "Storage",

    [Parameter (Mandatory=$false)]
    [ValidateSet("Create","Delete")]
    [String]$OperationName = "Create",

    [Parameter (Mandatory=$False)]
    [Array]$SourceAddress 
)
#
# Constants
#
[bool]$DebugMode = $true
[String]$RulePrefix = $ServiceType + "_"
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
        Write-output "Logging in to Azure..."
        Connect-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)   {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } 
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    Write-output "Successfully authenticated to Azure."
}
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
Write-Output "[AzureFirewall] - Processing operation $OperationName for resource $ResourceName as $ServiceType resource type."
#
# Build Rule for the Storage Accounts
# OK
$ApplicationRuleCollectionRules = @{}
$NetworkRuleCollectionRules = @{}
Write-Output "[AzureFirewall] - Building new Rule From JSON definition."
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
                    Write-Output "[AzureFirewall] - Process Azure Firewall group creation : $($ApplicationRule.Value.CollectionName)."
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
                Write-Output "[AzureFirewall] - Process Azure Network group creation : $($NetworkRule.value.CollectionName)."
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
}
#
# Build Azure Firewall collections for the new object to declare in Azure Firewall Configuration
# OK
#try {
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
                            Write-Output "[AzureFirewall] - Application Rule named $($RulePrefix + $ResourceName) already exists. No need to add it to rebuild process of Application rule collection $ApplicationGroupRuleName."
                        }
                        "Delete" {
                            #
                            # Delete mode, rule will be excluded at rebuild
                            #
                            Write-Output "[AzureFirewall] - Application Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Application rule collection $ApplicationGroupRuleName."
                        }
                        Default {
                            Write-Output "ERROR"
                        }
                    }
                }
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
                            Write-Output "[AzureFirewall] - Network Rule named $($RulePrefix + $ResourceName) already exists. No need to add it to rebuild process of Network rule collection $NetworkGroupRuleName."
                        }
                        "Delete" {
                            #
                            # Delete mode, rule will be excluded at rebuild
                            #
                            Write-Output "[AzureFirewall] - Network Rule named $($RulePrefix + $ResourceName) found, will be excluded from rebuild process of Network rule collection $NetworkGroupRuleName."
                        }
                        Default {
                            Write-Output "ERROR"
                        }
                    }
                }

            }   
        }
        else {
            Write-Output "[AzureFirewall] - Network rule collection $NetworkGroupRuleName not yet already exists. Will be created."
        }
        if (($AzureFirewallConfig.ApplicationRuleCollections.name) -contains $ApplicationGroupRuleName) {
            #
            # Search for existing Application Collection Rule and delete if exists
            #
            Write-Output "[AzureFirewall] - Azure Firewall Application Collection Rule named $ApplicationGroupRuleName, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveApplicationRuleCollectionByName($ApplicationGroupRuleName)
        }
        else {
	        Write-Output "[AzureFirewall] - No existing Azure Firewall Application Collection Rule found to delete."
        }
        if (($AzureFirewallConfig.NetworkRuleCollections.name) -contains $NetworkGroupRulename) {
            #
            # Search for existing Network Collection Rule and delete if exists
            #
            Write-Output "[AzureFirewall] - Azure Firewall Network Collection Rule named $NetworkGroupRulename, will be deleted to inject new content."
            $AzureFirewallConfig.RemoveNetworkRuleCollectionByName($NetworkGroupRulename)
        }
        else {
	        Write-Output "[AzureFirewall] - No existing Azure Firewall Network Collection Rule found to delete."
        }
        #
        # Merge existing and new Application Collection rule into a new collection
        # OK
        Write-Output "[AzureFirewall] - Merge existing Application rules collection with new rules."
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
        Write-Output "[AzureFirewall] - Merge existing Network rules collection with new rules."
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
            Write-Output "[AzureFirewall] - Creating Azure Firewall Application Collection Rule named $ApplicationGroupRuleName."
            $NewAzFwApplicationRuleCollection = New-AzFirewallApplicationRuleCollection `
                -Name $ApplicationGroupRuleName `
                -Priority $ApplicationGroupRulePriority `
                -Rule @($NewApplicationRuleCollectionRule.values) `
                -ActionType $ApplicationGroupRuleAction
            $AzureFirewallConfig.ApplicationRuleCollections += $NewAzFwApplicationRuleCollection
        }
        else {
            Write-Output "[AzureFirewall] - No Azure Application Collection rule to create because no rule inside."
        }

        #
        # Create new Azure Firewall Network Collection Rule
        #
        If ($NewNetworkRuleCollectionRule.count -GT 0)
        {
            Write-Output "[AzureFirewall] - Creating Azure Firewall Network Rule named $NetworkGroupRuleName."
            $NewAZFirewallNetworkRuleCollection = New-AzFirewallNetworkRuleCollection `
                -Name $NetworkGroupRuleName `
                -Priority $NetworkGroupRulePriority `
                -Rule @($NewNetworkRuleCollectionRule.values) `
                -ActionType $NetworkGroupRuleAction
            $AzureFirewallConfig.NetworkRuleCollections += $NewAZFirewallNetworkRuleCollection
        }
        else {
            Write-Output "[AzureFirewall] - No Azure Network Collection rule to create because no rule inside."
        }
        Write-Output "[AzureFirewall] - Updating Azure Firewall $($AzureFirewall.name)"
        $AzureFirewallConfig | Set-AzFirewall | Out-Null
        Write-Output "[AzureFirewall] - Updated Azure Firewall $($AzureFirewall.name)"  
    }
    $ScriptProcessingTime= $((new-timespan -Start $StartDate -End (get-date)).TotalSeconds).ToString("N2")
    Write-output "[AzureFirewall] - All Azure Firewall updated in $ScriptProcessingTime seconds."
    Write-output "[OK]"   
#}
#catch {
#    Write-Output "[ERROR] - $($_.Exception)"
#}