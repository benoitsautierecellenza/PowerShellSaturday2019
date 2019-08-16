#
# Start all existing Azure firewall instances located in a single resource group
#
[String]$ResourceGroupName = "DemoAzureFirewall"
$AzureFirewalls= Get-AzFirewall -ResourceGroupName $ResourceGroupName
Foreach($AzureFirewall in $AzureFirewalls)
{

    Write-Output "Processing Azure Firewall instance named : $($AzureFirewall.name)."
    $Vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName | Where-Object {$_.location -eq ($AzureFirewall.location)}
    $PublicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.location -eq ($AzureFirewall.location)}
    $AzureFirewall.Allocate($Vnet, $PublicIP)

    Set-AzFirewall -AzureFirewall $AzureFirewall
}
exit

# Start a firewall

$azfw = Get-AzFirewall -Name "FW Name" -ResourceGroupName "RG Name"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "RG Name" -Name "VNet Name"
$publicip = Get-AzPublicIpAddress -Name "Public IP Name" -ResourceGroupName " RG Name"
$azfw.Allocate($vnet,$publicip)
Set-AzFirewall -AzureFirewall $azfw