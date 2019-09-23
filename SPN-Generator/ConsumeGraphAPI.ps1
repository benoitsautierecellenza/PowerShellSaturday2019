$AppId = "03d501b6-5d7d-4935-ade1-94f24e183a5c"
$Secret = "hKC4yCMiuE35YRB+luA6cron/uptEUtPmaJ4Koor0OA="
$TenantID = "fa6e8394-fa69-4f72-b838-00319a91d080"


$WorkspaceID = '/subscriptions/{0}/resourcegroups/{1}/microsoft.operationalInsights/Workspaces/{2}' -f $SubscriptionID, $ResourceGroupname, "$SubscriptionID-LA"
$graphUri = "https://management.core.windows.net"
$Authority = "https://login.microsoftonline.com/{0}" -f $TenantID
$AADModule = Get-module "AzureAD.Standard.Preview" -ListAvailable | Sort-Object verion -Descending | Select-Object -First 1
$adal = Join-Path $AADModule.modulebase "Microsoft.IdentityModel.Clients.ActiveDirectory.Dll"
[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
$authcontext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext $Authority
# Créer un crédential


$PWord = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppId, $PWord

$clientcreds = new-object Microsoft.IdentityModel.Clients.ActiveDirectory.ClientAssertion $Credential
$Authresult = $authcontext.AcquireTokenAsync($graphUri,$clientcreds)
$Authresult.wait()
"New version en dessous"
exit
"SPN2"
$AppID = "7a7987d9-9af1-4413-aa54-779b59b7db5b"
$Secret = "p4aoYe216NiBWqMFy4vb3IaWPHD2qm3jxT3haeZOMC4="
$TenantID = "fa6e8394-fa69-4f72-b838-00319a91d080"

exit
#$AppId = "03d501b6-5d7d-4935-ade1-94f24e183a5c"
#$Secret = "hKC4yCMiuE35YRB+luA6cron/uptEUtPmaJ4Koor0OA="
#$TenantID = "fa6e8394-fa69-4f72-b838-00319a91d080"

$PWord = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AppId, $PWord
Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantID
$Context = Get-AzContext
$cacheItems = $context.TokenCache.ReadItems()

$Workspacename = (get-azcontext).subscription.id + "-LA"
$token = $cacheItems.AccessToken
$uri = 'https://management.azure.com/providers/microsoft.aadiam/diagnosticssettings/{0}?api-version=2017-04-01-Preview' -f $Workspacename
#    id = "/providers/microsoft.aadiam/microsoft.insights/diagnosticSettings/logAnalytics"

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

$uri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ruleName
$body = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$ruleName",
    "type": null,
    "name": "Log Analytics",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "storageAccountId": null,
      "serviceBusRuleId": null,
      "workspaceId": "$workspaceId",
      "eventHubAuthorizationRuleId": null,
      "eventHubName": null,
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
