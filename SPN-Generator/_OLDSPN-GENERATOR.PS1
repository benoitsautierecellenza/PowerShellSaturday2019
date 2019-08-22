#
# Create Azure AD Application & Service Principal 
#
# Version 1.1 : Benoît SAUTIERE - Initial Release
#
# .\SPN-GENERATOR -SecretLifeTime 365 -AzureADApplicationDisplayName test

# Cloud application administrator tester avec ce rôle pour le check
# Indiquer que c'est bon a avoir dans une chaine CI/CD pour éviter 
# use case : Par défaut tout le monde a des droits de créer des SPN dans Azure AD
# probleme, on ne peut pas enforcer une politique de nommage ou de configuration, on se retrouve donc avec 10 applications portant le même nom
# En plus cela implique de donner des privilèges Azure AD, même si on peut limiter avec Azure AD Security (retrouver le rôle)
# problème, on va avoir beaucoup de SPN à créer
# solution : il faut l'automatiser
# Solution V1 : ce script powershell
# Solution V2 : Ce script Powershell dans un Pipeline Jenkins ou Azure DevOps (donc instanciable par des consommateurs)
# Solution V3 : transformer cela en Azure Function


Param(
[Parameter(Mandatory=$False)]
[ValidateRange(20,720)]
[Int]$SecretLifetime = 365,

[Parameter(Mandatory=$True)]
[String]$AzureADApplicationDisplayName, 

[Parameter(Mandatory=$false)]
[String]$SubscriptionKeyVaultName
)
#
# Constants
#
$SubscriptionIDSecretName = "RGSubscriptionID"
$ServicePrincipalIDSecretName = "RGServicePrincipalID"
$AzureADTenantIDSecretName = "RGAzureADTenantID"
$SubscriptionStatusSecretName = "RGSubscriptionStatus"
$ServicePrincipalCredentialName = "RGAzureADApplicationPassword"
#
# Parameter validation
# OK

$currentDate = Get-Date
$NotAfter = $currentDate.addDays(($SecretLifetime -1)) 
Try
{
    #
    # Check if connected to Azure AD
    # OK
    Get-AzureADCurrentSessionInfo -ErrorAction Ignore
    $message =  "[ManageServicePrincipals] - User $((Get-AzureADCurrentSessionInfo).Account.ID) connected to Azure AD Tenant $((Get-AzureADTenantDetail).displayname)."
    Write-host -ForegroundColor Green $message
}
Catch
{
    $message = "[ManageServicePrincipals] - Not connected to Azure AD. Please use Connect-AzureAD."
    Write-Warning $message
    Exit
}
"done"
exit
#
# Check is user is connected to an Azure subscription
#
$testAzureContext = Get-AzContext
If ([string]::IsNullOrEmpty($testAzureContext) -eq $True)
{
    #
    # Not connected to Azure
    # OK
    $message = "[ManageServicePrincipals] - Not connected to Azure. Please use Login-AzureRmAccount."
    Write-Warning $message
    exit
}
#
# List available subscriptions
# OK
$Listsubscriptions = Get-AzSubscription -ErrorAction SilentlyContinue
If ([string]::IsNullOrEmpty($Listsubscriptions) -eq $True)
{
    #
    # Unable to retreive list of Azure subscriptions
    # OK
    $message = "[ManageServicePrincipals] - Unable to list available Azure Subscription."
    Write-Warning $message
    Exit
}
If (($Listsubscriptions.count) -gt 1)
{
    Write-Error "BUG ICI en Powershell Core donc virer"
    $message =  "[ManageServicePrincipals] - More than one Azure subscription, please select subscription where Resource Group as A service is deployed."
    Write-host -ForegroundColor Green $message
    $SelectedSubscription = $Listsubscriptions | select-Object Name, SubscriptionID | Out-GridView -PassThru -Title "Select Azure Subscription where Resource Group As a Service was deployed."
}
Else
{
    $SelectedSubscription = $Listsubscriptions
}
If ([string]::IsNullOrEmpty($SelectedSubscription) -eq $True)
{
    #
    # No Azure subscription selected
    # OK
    $message = "[ManageServicePrincipals] - No Azure subscription Selected."
    Write-Warning $message
    Exit
}

Set-AzContext -SubscriptionId $SelectedSubscription.SubscriptionId | Out-Null
$message = "[ManageServicePrincipals] - Connected to Azure subscription $($SelectedSubscription.SubscriptionID)."
Write-host -ForegroundColor Green $message

#
# User must be connected to a subscription
#
If (($Listsubscriptions.count) -Gt 1)
{
    #
    # user have access to more than one subscription so no need to ask witch subscription.
    #
# Buggera ici
"error"
exit
    $assignsubscription = $Listsubscriptions | select-Object Name, SubscriptionID | Out-GridView -PassThru -Title "Select Azure Subscription where role assignment must be performed."
    If ([string]::IsNullOrEmpty($assignsubscription) -eq $True)
    {
        $message = "[ManageServicePrincipals] - No subscription selected. Role assignment must be performed manually."
        Write-Warning $message
        $assignsubscription = $Null
    }
}
Else
{
    #
    # No choice because same as solution
    #
    $assignsubscription = $SelectedSubscription
}
"done"
exit
#
# Check if Azure AD Application exists
# OK
$testAzureAdApplication = Get-AzureADApplication | where-Object {$_.displayname -like $AzureADApplicationDisplayName}
If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True)
{
    #
    # Azure AD application not yet exists, check if another application is not using the same CustomKeyIdentifier
    # OK
    $message = "[ManageServicePrincipals] - Azure AD Application $AzureADApplicationDisplayName does not already exists in your Azure AD tenant."
    Write-Host -ForegroundColor Green $message
    $TestCustomKeyIdentifier = Get-AzureADApplication | select-Object DisplayName, IdentifierUris -ExpandProperty IdentifierUris | where-Object {$_.IdentifierUris -Eq $CustomKeyIdentifier}
    If ([string]::IsNullOrEmpty($TestCustomKeyIdentifier) -eq $True)
    {
        $message = "[ManageServicePrincipals] - Custom Key Identifier $CustomKeyIdentifier is not already used by another Azure AD Application."
        Write-Host -ForegroundColor Green $message
    }
    Else
    {
        $message = "[ManageServicePrincipals] - Custom Key Identifier $CustomKeyIdentifier is already used by another Azure AD Application : $($TestCustomKeyIdentifier.DisplayName)."
        Write-Warning $message
        Exit
    }                              
    Try
    {
        $message = "[ManageServicePrincipals] - Creating a new Azure AD Application named $AzureADApplicationDisplayName with Keyidentifier : $CustomKeyIdentifier."
        Write-Host -ForegroundColor green $message
        $AzureADApplication = New-AzureADApplication -DisplayName $AzureADApplicationDisplayName -IdentifierUris $CustomKeyIdentifier                                 
        New-AzureADApplicationPasswordCredential -ObjectId $AzureADApplication.ObjectId -CustomKeyIdentifier $CustomKeyIdentifier  -StartDate $currentDate -EndDate $endDate -Value $AzureADApplicationPassword
        $NewAzureADServicePrincipal = New-AzureADServicePrincipal -AppId $AzureADApplication.AppId
        $message = "[ManageServicePrincipals] - New Azure AD Application created Successfully."
        Write-Host -ForegroundColor Green $message
    }
    Catch
    {
        $message = "[ManageServicePrincipals] - Error while creating Azure AD Application : : $($_.Exception.Message)."   
        Write-Error $message
        If ([string]::IsNullOrEmpty($AzureADApplication) -eq $False)
        {
            Remove-AzureADApplication -ObjectId $AzureADApplication.ObjectID
        }                          
    }
    Write-host "***************************************************************************"
    Write-host "Service Principal Id: $($NewAzureADServicePrincipal.AppId)"
    Write-host "Service Principal Key: $AzureADApplicationPassword"
    Write-host "Azure AD Tenant ID: $($NewAzureADServicePrincipal.AppOwnerTenantId)"
    Write-host "***************************************************************************"                                                           
    $message =  "[ManageServicePrincipals] - Operation completed successfully."
    Write-Host -ForegroundColor green $message
    #
    # STockage dans le Keyvault
    #
}
Else
{
    #
    # Azure AD Application name already exists in Azure AD
    # OK
    $message = "[ManageServicePrincipals] - Azure AD Application $AzureADApplicationDisplayName already exists in your Azure AD tenant."       
    Write-Warning $message
    Exit
}