#
# Stop all existing Azure firewall instances located in a single resource group
#
[String]$ResourceGroupName = "DemoAzureFirewall"
$AzureFirewalls= Get-AzFirewall -ResourceGroupName $ResourceGroupName
Foreach($AzureFirewall in $AzureFirewalls)
{
    Write-Output "Processing Azure Firewall instance named : $($AzureFirewall.name)."
    $AzureFirewall.Deallocate()
    Set-AzFirewall -AzureFirewall $AzureFirewall
}
