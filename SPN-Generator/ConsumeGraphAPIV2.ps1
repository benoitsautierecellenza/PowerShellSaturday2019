
# https://blog.ctglobalservices.com/powershell/jgs/powershell-setting-azure-active-directory-diagnostics-forwarding/
$AppID = "7a7987d9-9af1-4413-aa54-779b59b7db5b"
$Secret = "p4aoYe216NiBWqMFy4vb3IaWPHD2qm3jxT3haeZOMC4="
$TenantID = "fa6e8394-fa69-4f72-b838-00319a91d080"


$PWord = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AppId, $PWord
Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantID
$Context = Get-AzContext
$cacheItems = $context.TokenCache.ReadItems()

$Workspacename = (get-azcontext).subscription.id + "-LA"
$workspaceId = "a51dafc6-3a7d-472f-be31-051609e5999a" # A extraire Azure
$token = $cacheItems.AccessToken
$uri = 'https://management.azure.com/providers/microsoft.aadiam/diagnosticssettings/{0}?api-version=2017-04-01-Preview' -f $Workspacename
$body = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$Workspacename",
    "type": null,
    "name": "Log Analytics",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "workspaceId": "$workspaceId",
      "metrics": [],
      "logs": [
        {
          "category": "AuditLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "SignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }
      ]
    },
    "identity": null
  }
"@


$body = @{
    name = "logAnalytics"
    id = "/providers/microsoft.aadiam/microsoft.insights/diagnosticSettings/$Workspacename"
    properties = @{
        logs = @(
        @{
            category = "AuditLogs"
            Enabled = $true
            retentionpolicy = @{
                days = 0
                enabled = $False       
            }
        },
        @{
            category = "SignInLogs"
            enabled = $true
            retentionpolicy = @{
                days = 0
                enabled = $False       
            }
        }
    )
    metrics = @()
    workspaceid = $WorkspaceID
    }
}

if ($PSVersionTable.PSVersion.Major -ge 6)
{
    Invoke-WebRequest -uri $uri -Body $(convertto-json $body -Depth 4) -Headers @{Authorization = "Bearer $token"} -Method Put -ContentType 'application/json'
}
else {
    Invoke-WebRequest -UseBasicParsing -uri $uri -Body $(convertto-json $body -Depth 4) -Headers @{Authorization = "Bearer $token"} -Method Put -ContentType 'application/json'    
}

exit

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}


