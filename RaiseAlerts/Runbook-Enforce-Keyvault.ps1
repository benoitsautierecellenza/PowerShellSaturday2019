#
# Todo : Ne réaliser les mises à jour que si elles ne sont pas déjà présentes
#
[OutputType("String")]
Param(
    [Parameter (Mandatory=$True)]
    [String]$resourceGroupName,
    [Parameter (Mandatory=$True)]
    [String]$ResourceName
)
[bool]$DebugMode = $True
If ($DebugMode -eq $false) {
    #
    # Authenticating to Azure to generate an answer for this event
    #
    $connectionName = "AzureRunAsConnection"
    try {
        Write-output "[Runbook-Enforce-Keyvault] - Logging in to Azure..."
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName                    
        Connect-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
        Write-output "[Runbook-Enforce-Keyvault] - Logged in to Azure..."
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } 
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    Write-output "[Runbook-Enforce-Keyvault] - Successfully authenticated to Azure."
}
try {
    [String]$VNETResourceGroupName = "DemoAzureFirewall"
    [String]$SecurityAuditResourceGroupname = "LabAutomation"
    [String]$SecurityAuditSTorageAcoccountName = "automationartifact"
    [String]$SecurityLogName = "Security"
    [Int]$SecurityRetentionPeriod = 90    
    [String]$SecurityOfficerGroupID = "475e2970-9490-44fc-9741-f79366587719"
    $SecurityOfficersPermissionsToCertificates = @('get','list','delete','create','import','update','managecontacts','getissuers','listissuers','setissuers','deleteissuers','manageissuers', 'recover','backup','restore', 'purge')
    $SecurityOfficersPermissionsToSecrets = @('get','list','set','delete','recover','backup','restore', 'purge')
    $SecurityOfficersPermissionsToKeys = @('get','list','update','create','import','delete','recover','backup','restore', 'decrypt', 'encrypt', 'unwrapkey', 'wrapkey', 'verify', 'sign', 'purge')
    #
    # Build list of Subnets named AzureFirewallSubnet for VNET integration
    # OK
    $ListVNETS = Get-AzVirtualNetwork -ResourceGroupName $VNETResourceGroupName 
    $AzureFirewallSubnets = $ListVNETS.subnets | Where-Object {$_.name -eq "AzureFirewallSubnet"}   # AzureFirewall subnets on witch KeyVault endpoints are activated
    #
    # Build list of public IP Adrdresses used for ServiceHub service purpose (Tag service configured with Hub value)
    # OK
    $publiciplist = Get-AzResource -ResourceType "Microsoft.Network/publicIPAddresses" -Tag @{Service="Hub"}
    $IPRange = @()
    Foreach ($PublicIP in $publiciplist)
    {
        $PublicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $PublicIP.ResourceGroupName -Name $PublicIP.name).IPAddress
        $IpRange += ($PublicIpAddress + "/32")
    }
    #
    # Build list of local network public ip addresses
    # OK
    $LocalNetworkGatewayList = get-azresource -ResourceType Microsoft.Network/localNetworkGateways -Tag @{Service="Hub"}
    ForEach ($LocalNetworkgateway in $LocalNetworkGatewayList)
    {
        $PublicIpAddress = (Get-AzLocalNetworkGateway -ResourceGroupName $LocalNetworkgateway.ResourceGroupName -Name $LocalNetworkgateway.Name).gatewayipaddress
        $IpRange += ($PublicIpAddress + "/32")
    }
    $IpRange = $IpRange -split ","
    #
    # Get Key Vault current configuration
    #
    #$keyvault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $ResourceName                                                                                                                               
    #$CurrentIpRange = $keyvault.NetworkAcls.IpAddressRanges
    Write-output "[Runbook-Enforce-Keyvault] - Updating Key Vault Network Rules."
    Update-AzKeyVaultNetworkRuleSet -VaultName $ResourceName `
        -ResourceGroupName $resourceGroupName `
        -Bypass AzureServices `
        -IpAddressRange $IpRange `
        -VirtualNetworkResourceId $AzureFirewallSubnets.id `
        -DefaultAction Deny | Out-Null
    #
    # Configure Access Key for Security Officers
    # OK
    Write-output "[Runbook-Enforce-Keyvault] - Updating Key Vault access policies."
    Set-AzKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName `
        -VaultName $ResourceName `
        -ObjectId $SecurityOfficerGroupID `
        -PermissionsToCertificates $SecurityOfficersPermissionsToCertificates `
        -PermissionsToSecrets $SecurityOfficersPermissionsToSecrets `
        -PermissionsToKeys $SecurityOfficersPermissionsToKeys | Out-Null

    # bonus a trouver : identifier les utilisateurs externes avec des permissions pour les supprimer.
    #
    # Configure Diagnostics Settings
    # OK
    $KeyVaultObject = Get-AzKeyVault -VaultName $ResourceName -ResourceGroupName $resourceGroupName 
    $StorageAccountObject = Get-AzStorageAccount -ResourceGroupName $SecurityAuditResourceGroupname -Name $SecurityAuditSTorageAcoccountName
    Write-output "[Runbook-Enforce-Keyvault] - Enforce Key Vault diagnostics settings."
    Set-AzDiagnosticSetting -ResourceId $KeyVaultObject.ResourceId `
        -StorageAccountId $StorageAccountObject.id `
        -Enabled $True `
        -Name $SecurityLogName `
        -Category AuditEvent `
        -RetentionEnabled $true `
        -RetentionInDays $SecurityRetentionPeriod `
        -MetricCategory AllMetrics | Out-Null
    Write-output "[OK]"   
}
catch {
    Write-Output "[ERROR] - $($_.Exception)"
}


