function Get-AzCachedAccessToken()
{
    #
    # Get Current token for connected user
    #
    # https://www.codeisahighway.com/how-to-easily-and-silently-obtain-accesstoken-bearer-from-an-existing-azure-powershell-session/
    $ErrorActionPreference = 'Stop'
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
$token =  Get-AzCachedAccessToken 
$Subscriptionid = (Get-AzContext).Subscription.id
$headers = @{"authorization"="bearer $token"} 
$Result = Invoke-WebRequest -Uri https://management.azure.com/subscriptions/$Subscriptionid/resourcegroups?api-version=2016-09-01 -Method GET -Headers $headers
$result.Headers["x-ms-ratelimit-remaining-subscription-reads"]
