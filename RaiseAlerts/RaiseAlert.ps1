[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory=$false)]
    [object] $WebhookData
)
# https://docs.microsoft.com/en-us/azure/automation/automation-create-alert-triggered-runbook
#$ErrorActionPreference = "stop"
#
# Constants
#
$AutomationAccountName = "LabAutomation" 
$AutomationAccountResourceGroupName = "LabAutomation"
if ($WebhookData)
{
    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    # Get the info needed to identify the VM (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId
    Write-output "schemaId: $schemaId" -Verbose
    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object] ($WebhookBody.data).essentials
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + "/" + ($alertTargetIdArray)[7]
        $ResourceName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition
#
# Cas de mes alertes nouvelles génération
#
Write-Output "DEBUG"
Write-output "azureMonitorCommonAlertSchema"
Write-output $WebhookBody
Write-output "Essentials $($WebhookBody.Data.essentials)"
Write-output "AlertID $($WebhookBody.Data.essentials.alertid)"
Write-output "AlertRule $($WebhookBody.Data.essentials.alertrule)"
Write-output "Severity $($WebhookBody.Data.essentials.severity)"
Write-output "Signal Type $($WebhookBody.Data.essentials.SignalType)"
Write-output "Monitor Condition : $($WebhookBody.Data.essentials.MonitorCondition)"
Write-output "Monitoring Service : $($WebhookBody.Data.essentials.MonitoringService)"
Write-output "Origin Alert ID : $($WebhookBody.Data.essentials.OriginAlertId)"
Write-output "Alert Context : $($WebhookBody.Data.AlertContext)"
Write-output "Action : $($WebhookBody.Data.AlertContext.authorization.Action)"
Write-output "Action Scope : $($WebhookBody.Data.AlertContext.authorization.Scope)"
Write-output "operationName : $($WebhookBody.Data.AlertContext.operationName)"
Write-output "APPID : $($WebhookBody.Data.AlertContext.caller)" 
Write-Output "DEBUG"

    }
    elseif ($schemaId -eq "AzureMonitorMetricAlert") {
        # This is the near-real-time Metric Alert schema
        $AlertContext = [object] ($WebhookBody.data).context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/activityLogs") {
        # This is the Activity Log Alert schema
        $AlertContext = [object] (($WebhookBody.data).context).activityLog
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split("/"))[-1]
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq $null) {
        # This is the original Metric Alert schema
        $AlertContext = [object] $WebhookBody.context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = $WebhookBody.status
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    Write-Verbose "status: $status" -Verbose
    if (($status -eq "Activated") -or ($status -eq "Fired"))
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
#
# Intégrer ici le type d'opératon
#
Write-Output "DEBUG"
Write-Output "APPID AZACCOUNT $($servicePrincipalConnection.ApplicationId)"
Write-Output "DEBUG"
#
# a22f789d-7f7a-499b-9059-f6a65e45402f filtrer le Caller, ignorer ceux concernant l'identité Automation
#
# e9ab63ba-8fcd-488e-815e-5a9d7c62e425 si on trouve l'appID alors c'est goot

        Switch($ResourceType)
        {
            "Microsoft.Compute/virtualMachines"
            {
                # This is an Resource Manager VM
                Write-output "This is a Virtual machine related Event"

            }
            "Microsoft.Storage/storageAccounts"
            {
                # This is an Resource Manager VM
                Write-output "This is a Storage Account event"
                Write-output "operationName : $($WebhookBody.Data.AlertContext.operationName)"
                Write-Output "resourceType: $ResourceType" 
                Write-Output "resourceName: $ResourceName" 
                Write-Output "resourceGroupName: $ResourceGroupName" 
                Write-Output "subscriptionId: $SubId" 
                If ($($WebhookBody.Data.essentials.MonitorCondition) -eq "Fired")
                {
                    Switch ($($WebhookBody.Data.AlertContext.operationName))
                    {
                        "Microsoft.Storage/storageAccounts/write"
                        {
                            # Process only new alerts, not closed or acknwoledged
                            Write-Output "Start Runbook AFW-ProcessServiceRules"
                            $Parameters = @{
                                "ResourceName" = $ResourceName;
                                "ServiceType" = "Storage";
                                "OperationName" = "Create";
                                "resourceGroupName" = $ResourceGroupName;
                        }
                        "AutomationAccountResourceGroupName $AutomationAccountResourceGroupName"        
                        "AutomationAccountName $AutomationAccountName"
                        "Parameters $parameters"            
                        $Job = Start-AzAutomationRunbook -ResourceGroupName $AutomationAccountResourceGroupName `
                            -AutomationAccountName $AutomationAccountName  `
                            -Name "AFW-ProcessServiceRules" `
                            -Parameters $Parameters `
                            -Wait
                        $Job
                        }
                        "Microsoft.Storage/storageAccounts/delete"
                        {
                            "TO INCLUDE"
                        }                    
                    } 
                }
            }
            "microsoft.keyvault/vaults" {
                Write-Output "This a KeyVault related Event"
                Write-Output "resourceType: $ResourceType" 
                Write-Output "resourceName: $ResourceName" 
                Write-Output "resourceGroupName: $ResourceGroupName" 
                Write-Output "subscriptionId: $SubId" 
                $Parameters = @{
                    "ResourceName"=$ResourceName;
                    "resourceGroupName"=$ResourceGroupName
                }
        # DEBUG MODE
                $Job = Start-AzAutomationRunbook -ResourceGroupName $AutomationAccountResourceGroupName `
                    -AutomationAccountName $AutomationAccountName  `
                    -Name "Process-KeyVault" `
                    -Parameters $Parameters `
                    -Wait
                $Job
        # DEBUG MODE
                    # Process Job At end to close Alert or not
            }
        }         
    }
    else {
        # The alert status was not 'Activated' or 'Fired' so no action taken
        Write-Verbose ("No action taken. Alert status: " + $status) -Verbose
    }
}
else {
    # Error
    Write-Error "This runbook is meant to be started from an Azure alert webhook only."
}