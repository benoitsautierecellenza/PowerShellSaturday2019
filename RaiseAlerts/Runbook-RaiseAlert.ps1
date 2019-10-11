#
# Todo : Close related alert
#
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
[String]$AutomationAccountName = "LabAutomation" 
[String]$AutomationAccountResourceGroupName = "LabAutomation"
[String]$RunbookJobCheckPeriod = 10
[Int]$FirewallRunbookMaximumProcessionTime = 400
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
#Write-Output "DEBUG"
#Write-output "azureMonitorCommonAlertSchema"
#Write-output $WebhookBody
#Write-output "Essentials $($WebhookBody.Data.essentials)"
#Write-output "AlertID $($WebhookBody.Data.essentials.alertid)"
#Write-output "AlertRule $($WebhookBody.Data.essentials.alertrule)"
#Write-output "Severity $($WebhookBody.Data.essentials.severity)"
#Write-output "Signal Type $($WebhookBody.Data.essentials.SignalType)"
#Write-output "Monitor Condition : $($WebhookBody.Data.essentials.MonitorCondition)"
#Write-output "Monitoring Service : $($WebhookBody.Data.essentials.MonitoringService)"
#Write-output "Origin Alert ID : $($WebhookBody.Data.essentials.OriginAlertId)"
#Write-output "Alert Context : $($WebhookBody.Data.AlertContext)"
#Write-output "Action : $($WebhookBody.Data.AlertContext.authorization.Action)"
#Write-output "Action Scope : $($WebhookBody.Data.AlertContext.authorization.Scope)"
#Write-output "operationName : $($WebhookBody.Data.AlertContext.operationName)"
#Write-output "APPID : $($WebhookBody.Data.AlertContext.caller)" 
#Write-Output "DEBUG"

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
        # Checking Webhook Context (If Caller is Automation, do not create infinite loop)
        #
        $AlertCallerID = $($WebhookBody.Data.AlertContext.caller)
        $CurrentContext = (Get-AzContext).account.id
        Write-Output "AlertCallerID : $AlertCallerID"
        Write-Output "CurrentContext : $CurrentContext"
        If ($AlertCallerID -eq $CurrentContext) {
            Write-Output "SAME CONTEXT, AVOID LOOP"
            Exit
        }
        else {
            Write-Output "Not same context, process"
        }
        #
        # Prepare AFW-ProcessServiceRules runbook parameters based on ResourceType
        #
        Switch($ResourceType)
        {
            "Microsoft.Storage/storageAccounts"
            {
                Write-output "This is a Storage Account event"
                If ($($WebhookBody.Data.essentials.MonitorCondition) -eq "Fired")
                {
                    Switch ($($WebhookBody.Data.AlertContext.operationName))
                    {
                        "Microsoft.Storage/storageAccounts/write"
                        {
                            # Process only new alerts, not closed or acknwoledged
                            $Parameters = @{
                                "ResourceName" = $ResourceName
                                "ServiceType" = "Storage"
                                "OperationName" = "Create"
                            }            
                        }
                        "Microsoft.Storage/storageAccounts/delete"
                        {
                            $Parameters = @{
                                "ResourceName" = $ResourceName
                                "ServiceType" = "Storage"
                                "OperationName" = "Delete"
                            }            
                        } 
                        default {
                            Write-output "Operation ($($WebhookBody.Data.AlertContext.operationName)) not managed by Runbook."
                        }                                       
                    } 
                }
            }
            "Microsoft.Keyvault/Vaults" {
                Write-Output "This a KeyVault related Event."
                If ($($WebhookBody.Data.essentials.MonitorCondition) -eq "Fired")
                {
                    Switch ($($WebhookBody.Data.AlertContext.operationName))
                    {
                        "Microsoft.KeyVault/vaults/write"
                        {
                            # Process only new alerts, not closed or acknwoledged
                            $Parameters = @{
                                "ResourceName" = $ResourceName
                                "ServiceType" = "KeyVault"
                                "OperationName" = "Create"
                            }  
                            #
                            # Intégrer le call du Runbook de remédiation ici
                            #          
                        }
                        "Microsoft.KeyVault/vaults/delete"
                        {
                            $Parameters = @{
                                "ResourceName" = $ResourceName
                                "ServiceType" = "KeyVault"
                                "OperationName" = "Delete"
                            }            
                        }
                        default {
                            Write-output "Operation ($($WebhookBody.Data.AlertContext.operationName)) not managed by Runbook."
                        }                    
                    } 
                }
            }
            default {
                Write-Output "Resource $ResourceType is not managed by Runbook"
                $Parameters = $Null
            }
        }
        #
        # Call Runbook
        # OK
        If ($Parameters -ne $null) {
            $Job = Start-AzAutomationRunbook -ResourceGroupName $AutomationAccountResourceGroupName `
                -AutomationAccountName $AutomationAccountName  `
                -Name "AFW-ProcessServiceRules" `
                -Parameters $Parameters 
            #
            # Wait for Azure Automation Job processing
            # OK
            [Bool]$ExitJobLoop_Flag = $false
            [DateTime]$StartDate = $JobStatus.CreationTime.UtcDateTime
            While ($ExitJobLoop_Flag -eq $False) {
                #
                # Get-Job Status
                #
                $JobStatus = Get-AzAutomationJob -ResourceGroupName $AutomationAccountResourceGroupName `
                    -AutomationAccountName $AutomationAccountName  `
                    -Id $job.JobId.guid
                #
                # Only cases to interrupt Runbook job loop
                #
                Write-Output "Processing Firewall rule for resource $ResourceName. Status : $(($JobStatus.Status))."
                If ((($JobStatus.Status) -eq "Completed") -or (($JobStatus.Status) -eq "Failed") -or (($JobStatus.Status) -eq "Stopped") ) {
                    #
                    # Runbook completed or failed, no need to parse more
                    #
                    $ExitJobLoop_Flag = $True
                }
                else {
                    #
                    # Runbook did not completed
                    #
                    $TimeSpan  = New-TimeSpan -Start $StartDate -End (Get-date)
                    Write-Output "Checking Runbook job processing time : $(($TimeSpan.TotalMinutes))."
                    If (($TimeSpan.TotalMinutes) -gt $FirewallRunbookMaximumProcessionTime) {
                        #
                        # Exit also if Runbook execution time is too long
                        #
                        $ExitJobLoop_Flag = $True
                        Write-Warning "Runbook AFW-ProcessServiceRules execution time is above $FirewallRunbookMaximumProcessionTime minutes. Killing job."
                        Stop-AzAutomationJob -ResourceGroupName $AutomationAccountResourceGroupName `
                            -AutomationAccountName $AutomationAccountName `
                            -Id $job.JobId.guid
                    }
                    Start-Sleep -Seconds $RunbookJobCheckPeriod                                    
                }
            } # End of Loop
            Write-output "Exited Runbook Job check loop."
            If (($JobStatus.Status) -eq "Completed") {
                #
                # It's not becasue job status is completed that runbook execution was OK
                #
                $JobOutput = Get-AzAutomationJobOutput  -ResourceGroupName $AutomationAccountResourceGroupName `
                    -AutomationAccountName $AutomationAccountName  `
                    -Id $job.JobId.guid `
                    -Stream Output
                    If ((($JobOutput | select-Object -Last 1).Summary) -eq "[OK]") {
                        Write-Output "Azure Firewall rule successfully implemented for resource $ResourceName."
                }
                #
                # Todo : Close Related Alert
                #
            }
            else {
                $JobOutput = Get-AzAutomationJobOutput  -ResourceGroupName $AutomationAccountResourceGroupName `
                    -AutomationAccountName $AutomationAccountName  `
                    -Id $job.JobId.guid `
                    -Stream Output
                Write-Output "Azure Firewall rule not succesfully implemented for resource $ResourceName. Runbook Error : $(($JobOutput | select-Object -Last 1).Summary)."                                    
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