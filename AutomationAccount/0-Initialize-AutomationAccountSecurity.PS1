


#. .\0-Initialize-AutomationAccountSecurity.PS1 -SolutionResourceGroupName "LabAutomation" -SolutionKeyVaultName "LabAutomation" -SolutionSubscriptionID "5be15500-7328-4beb-871a-1498cd4b4536" -SolutionAutomationAccountName "LabAutomation" -AutomationCertificateLifetimePolicy 365 -AutomationAzureADApplicationName LABAUTOMATION 

# TODO : Mise en place de permission sur secrets pour stocker le mot de passe associé au PFX

#
# Benoît SAUTIERE - Version 1.0 - Initial version
#
Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$SolutionResourceGroupName,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$SolutionKeyVaultName,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$SolutionSubscriptionID,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$AutomationAzureADApplicationName,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$SolutionAutomationAccountName,

    [Parameter(Mandatory=$False)]
    [ValidateRange(20,720)]
    [Int]$AutomationCertificateLifetimePolicy = 365
)
#
# Import required modules
#
import-module randompasswordgenerator
$module = Get-Module 'AzureAD.Standard.Preview' -ListAvailable -ErrorAction SilentlyContinue
if (!$module) 
{
    Write-Output "Azure AD module AzureAD.Standard.Preview is not installed."
    $module = Install-Module -Name 'AzureAD.Standard.Preview' -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber 
    Write-Host "AzureAD.Standard.Preview Module now installed"
}
else {
    Write-Output "Azure AD module AzureAD.Standard.Preview is already installed."
}
try {
    import-module $module.RootModule    
}
catch {
    Write-Error "[ERROR] - Unable to load AzureAD.Standard.Preview module : $($_.Exception.Message)." 
    exit   
}
#
# Constants
#
$PasswordLenght = 16                                        # Password Lenght for PFX certificate export
$PercentLowerCaseLetters = 0.25
$PercentUpperCaseLetters = 0.25
$PercentNumbers = 0.25
$PercentCharacters = 0.25
$AssignedRole = "Owner"
$PfxCertPathForRunAsAccount = "C:\TEMP\CERTIFICATE.PFX"
$AutomationcertSubjectName = "cn=$($SolutionAutomationAccountName.ToLower())"
#
# Check if already connected to an Azure Subscription
# OK
$CheckAzureContext = Get-AzContext
If ([string]::IsNullOrEmpty($CheckAzureContext) -eq $True) {
    #
    # No current context => Not connected to an Azure Subscription
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] : Not connected to Azure."
    Exit
}
#
# Select subscription on witch solution will be deployed
# OK
$Listsubscriptions = Get-AzSubscription -ErrorAction SilentlyContinue
If ([string]::IsNullOrEmpty($Listsubscriptions) -eq $True) {
    #
    # Unable to retreive list of Azure subscriptions
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Unable to list available Azure Subscription."
    Exit
}
If (($Listsubscriptions.count) -gt 0) {
    If ([string]::IsNullOrEmpty($Listsubscriptions.id -match $solutionsubscriptionID) -eq $True) {
        #
        # Subscription not found
        # OK
        Write-Error "[Initialize-AutomationAccountSecurity] - Subscription ID $solutionsubscriptionID not visible in current context."
        Exit
    }
    else {
        #
        # Subscription found
        # OK
        Write-output "[Initialize-AutomationAccountSecurity] - Subscription $solutionsubscriptionID visible in current context."
        Set-AzContext -SubscriptionId $solutionsubscriptionID | Out-Null
    }
}
Else {
    #
    # Required Subscription is not reachable
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Subscription ID $solutionsubscriptionID not visible in current context."
    Exit
}
Try {
    #
    # Check if connected to Azure AD
    # OK
    Get-AzureADTenantDetail -ErrorAction SilentlyContinue  | Out-Null
    Write-Host "[Initialize-AutomationAccountSecurity] - Connected to Azure AD."
}
Catch {
    #
    # Not connected to an Azure AD Tenant
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Not connected to Azure AD. Please connect to Azure AD Tenant $((Get-AzContext).tenant.id) and relaunch the script."
    exit
}
#
# Check if solution Resource Group exists
# OK
$CheckResourceGroup = Get-AzResourceGroup -Name $SolutionResourceGroupname -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckResourceGroup)) {
    #
    # Resource Group does not exists
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Resource Group $SolutionResourceGroupname does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # Resource Group exists in subscription
    # OK
    Write-output "[Initialize-AutomationAccountSecurity] - Resource Group $SolutionResourceGroupname exists in subscription $((Get-AzContext).Subscription.id)."
}
#
# Check if solution Keyvault exists
# OK
$checkKeyVault = Get-AzKeyVault -Name $SolutionKeyVaultName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckKeyVault)) {
    #
    # Solution Key Vault does not exists
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Required KeyVault $SolutionKeyVaultName does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # KeyVault Exists in subscription
    # OK
    Write-Output "[Initialize-AutomationAccountSecurity] - Required KeyVault $SolutionKeyVaultName does exists in subscription $((Get-AzContext).Subscription.id)."
}
#
# Check if Azure Automation Account exists
# OK
$checkautomationaccount = Get-AzResource `
    -ResourceGroupName $SolutionResourceGroupName `
    -ResourceType 'Microsoft.Automation/automationAccounts' `
    -Name $SolutionAutomationAccountName `
    -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($checkautomationaccount)) {
    #
    # Azure Automation Account does not exists in solution resource group
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Required Azure Automation Account $SolutionAutomationAccountName does not exists in resource group $SolutionResourceGroupName."
    Exit
}
else {
    #
    # Azure Automation Account exists
    # OK
    Write-output "[Initialize-AutomationAccountSecurity] - Required Azure Automation Account $SolutionAutomationAccountName found in resource group $SolutionResourceGroupName."
}
#
# Enforce permissions on secrets
# OK
try {
    Write-Output "[Initialize-AutomationAccountSecurity] - Set Permisions to Secrets on Key Vault $SolutionKeyVaultName for $((Get-AzContext).Account.id)."
    $AzureADUSer = Get-AzureADUser -filter ("userprincipalname eq '" + $((Get-AzureADCurrentSessionInfo).account.id) + "'")
    Set-AzKeyVaultAccessPolicy `
        -ResourceGroupName $SolutionResourceGroupName `
        -VaultName $SolutionKeyVaultName `
        -ObjectId $AzureADUSer.ObjectID `
        -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge 
    Write-Output "[Initialize-AutomationAccountSecurity] - Permisions to Secrets on Key Vault $SolutionKeyVaultName sucessfully configured for  $((Get-AzContext).Account.id)."        
}
catch {
    #
    # Unable to set access policy on Key Vault
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Unable set access policies on KeyVault $SolutionKeyVaultName : $($_.Exception.Message)."    
    exit
}
#
# Check Azure AD Application
# OK
$testAzureAdApplication = Get-AzureADApplication -All $true | where-Object {$_.displayname -like $AutomationAzureADApplicationName}
If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True)
{
    #
    # Azure AD application not yet exists, check if another application is not using the same CustomKeyIdentifier
    # OK
    $message = "[Initialize-AutomationAccountSecurity] - Azure AD Application $AutomationAzureADApplicationName does not already exists in your Azure AD tenant."
    Write-Host $message
}
else 
{
    If ($testAzureAdApplication.count -eq 1)
    {
        #
        # Azure AD Application already exists in Azure AD, will be deleted and reconfigured
        # OK
        $Message = "[Initialize-AutomationAccountSecurity] - Azure AD Application $AutomationAzureADApplicationName already exists in Azure AD. Will be deleted"
        Write-Warning $message
        Get-AzureADApplication -ObjectId $testAzureAdApplication.ObjectId | Remove-AzureADApplication       
            
    }
    else {
        #
        # Corner case, multiple Azure AD application withe the same displayname
        # OK
        Write-Error "[Initialize-AutomationAccountSecurity] - Too many application with  the same name. Unable to configure application."
        Exit
    }
}
#
# Check if certificate exists (if yes delete)
# OK
$testcertificate = Get-AzKeyVaultCertificate `
    -VaultName $SolutionKeyVaultName `
    -Name $AutomationAzureADApplicationName `
    -ErrorAction SilentlyContinue
If ($testcertificate.count -eq 0)
{
    #
    # certificate with this name does not existe un KeyVault
    # OK
    Write-Output "[Initialize-AutomationAccountSecurity] - Certificate named $AutomationAzureADApplicationName does not exists yet in solution Key Vault $SolutionKeyVaultName."     
}
else 
{
    #
    # Certificate with this name already exists in solution key vault, will be deleted
    # OK 
    Write-Output "[Initialize-AutomationAccountSecurity] - Certificate named $AutomationAzureADApplicationName already exists in solution Key Vault $SolutionKeyVaultName. Delete certificate."
    Remove-AzKeyVaultCertificate `
        -VaultName $SolutionKeyVaultName `
        -Name $AutomationAzureADApplicationName `
        -Force
}
#
# Generating new Self-signed certificate
# OK
Write-output "[Initialize-AutomationAccountSecurity] - Creating auto-signed certificate in KeyVault $SolutionKeyVaultName"
$Policy = New-AzKeyVaultCertificatePolicy `
    -SecretContentType "application/x-pkcs12" `
    -SubjectName $AutomationcertSubjectName `
    -IssuerName "Self" `
    -ValidityInMonths $AutomationCertificateLifetimePolicy `
    -ReuseKeyOnRenewal
$AddAzureKeyVaultCertificateStatus = Add-AzKeyVaultCertificate `
    -VaultName $SolutionKeyVaultName `
    -Name $AutomationAzureADApplicationName `
    -CertificatePolicy $Policy   
While ($AddAzureKeyVaultCertificateStatus.Status -eq "inProgress") 
{
    #
    # Wait for certificate generation
    # OK
    Start-Sleep -Seconds 10
    $AddAzureKeyVaultCertificateStatus = Get-AzKeyVaultCertificateOperation -VaultName $SolutionKeyVaultName -Name $AutomationAzureADApplicationName     
}
If ($AddAzureKeyVaultCertificateStatus.Status -ne "Completed")
{
    #
    # Error during certificate generation
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Error while creating certificate in Keyvault $SolutionKeyVaultName : $($AddAzureKeyVaultCertificateStatus.Status)."
    exit
}
Else 
{
    #
    # Certificate sucessfully generated in KeyVault
    # OK
    Write-output  "[Initialize-AutomationAccountSecurity] - Successfully created auto-signed certificate in KeyVault $SolutionKeyVaultName."
}
#
# Export certificate from solution Key Vault
# OK
try {
    $PfxCertPlainPasswordForRunAsAccount = (Get-RandomPassword -PasswordLength $PasswordLenght -PercentLowerCaseLetters $PercentLowerCaseLetters -PercentUpperCaseLetters $PercentUpperCaseLetters -PercentNumbers $PercentNumbers -PercentCharacters $PercentCharacters).PasswordValue
    Write-Output "[Initialize-AutomationAccountSecurity] - Exporting certificate from KeyVault $SolutionKeyVaultName."
    $secretRetrieved = Get-AzKeyVaultSecret `
        -VaultName $SolutionKeyVaultName `
        -Name $AutomationAzureADApplicationName
    $pfxBytes = [System.Convert]::FromBase64String($secretRetrieved.SecretValueText)
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $certCollection.Import($pfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)   
    $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12,$PfxCertPlainPasswordForRunAsAccount )
    [System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $protectedCertificateBytes)
    Write-Output "[Initialize-AutomationAccountSecurity] - Certificate successfully exported from solution key vault $SolutionKeyVaultName."
}
catch  {
    #
    # Export certificate in PFX
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - One or more error while exporting certificates : $($_.Exception.Message)."
    exit
}
#
# Create Azure AD Application
# OK
try {
    Write-Output "[Initialize-AutomationAccountSecurity] - Creating Azure AD Application $AutomationAzureADApplicationName."
    #
    # Create Azure AD Application
    # OK
    $NewAzureADApplication = New-AzureADApplication `
        -DisplayName $AutomationAzureADApplicationName `
        -HomePage ("http://" + $AutomationAzureADApplicationName) # -IdentifierUris $CustomKeyIdentifier
    #
    # Create Service princpal linked to Azure AD Application
    # OK
    $NewAzureADServicePrincipal = New-AzureADServicePrincipal -AppId $NewAzureADApplication.AppId 
    $KeyVaultCertificate = Get-AzKeyVaultCertificate `
        -VaultName $SolutionKeyVaultName `
        -Name $AutomationAzureADApplicationName
    #
    # Générate Key Credential for Azure AD Application
    # OK
    $KeyVaultCertRawData = $KeyVaultCertificate.Certificate.RawData
    $base64Value = [System.Convert]::ToBase64String($KeyVaultCertRawData) 
    $thumbprint=$KeyVaultCertificate.Certificate.GetCertHash() 
    $base64Thumbprint = [System.Convert]::ToBase64String($thumbprint) 
    New-AzureADApplicationKeyCredential `
        -ObjectId $NewAzureADApplication.ObjectId `
        -CustomKeyIdentifier $base64Thumbprint `
        -Type AsymmetricX509Cert `
        -Usage Verify `
        -Value $base64Value
    Write-output "[Initialize-AutomationAccountSecurity] - Azure AD Application $AutomationAzureADApplicationName created successfully in Azure AD tenant with Service Principal ID $($AutomationServicePrincipalID.ApplicationId.guid)."
}
catch {
    #
    # Error while generation Azure AD Application
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Error while creating Azure AD Application $AutomationAzureADApplicationName : $($_.Exception.Message)."
    remove-item -Path $PfxCertPathForRunAsAccount -Force | Out-Null
    Exit
}
#
# Insérer ici la mise en place des permissions
#

#
# Perform owner role assignation at subscription level
# OK
$NewRole = $null
$Retries = 0
Write-Output "[Initialize-AutomationAccountSecurity] - Assigning Service Principal Owner role at subscription $((Get-AzContext).Subscription.id) level."
While ($NewRole -eq $null -and $Retries -le 6) 
{
    #
    # Loop While role assignment not completed
    # OK
    Start-Sleep -Seconds 10 # Required because Azure AD Identity may not be visible from Azure just after created
    New-AzRoleAssignment -RoleDefinitionName $AssignedRole -ApplicationId $NewAzureADServicePrincipal.AppId -scope ("/subscriptions/" + $((Get-AzContext).Subscription.id)) -ErrorAction SilentlyContinue
    Write-Output "[Initialize-AutomationAccountSecurity] - Checking role Assignment."
    $NewRole = Get-AzRoleAssignment -ServicePrincipalName  $NewAzureADServicePrincipal.AppId -ErrorAction SilentlyContinue        
    $Retries++;
}
If ($NewRole -ne $null -and $Retries -le 6) 
{
    #
    # Role assignment sucessfully configured
    # OK
    Write-Output "[Initialize-AutomationAccountSecurity] - Owner Role sucessfully assigned to Service Principal $($Application.ApplicationId) at $((Get-AzContext).Subscription.id) level."
}
else 
{
    #
    # Error during role assignment.
    # OK
    Write-Error "[Initialize-AutomationAccountSecurity] - Error while assigning Owner role at $((Get-AzContext).Subscription.id)) : $($_.Exception.Message)."
    Remove-item -Path $PfxCertPathForRunAsAccount -Force | Out-Null
    Remove-AzureADApplication -ObjectId $Application.ObjectId
    exit
}