#. .\SPN-GENERATOR.PS1 -SolutionResourceGroupName "DemoSPN" -SolutionKeyVaultName "DemoSPN2" -SolutionSubscriptionID "5be15500-7328-4beb-871a-1498cd4b4536"  -AutomationCertificateLifetimePolicy 12 -AzureADApplicationName testspn4 -AuthenticationMethod Key -mode Create

# TODO
# -Ajouter une option pour assigner le SPN à un Rôle Azure AD si précisé
# -Ajouter une option pour assigner la souscription en optionnel
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
    [String]$AzureADApplicationName,

    [Parameter(Mandatory=$False)]
    [ValidateRange(1,720)]
    [Int]$AutomationCertificateLifetimePolicy = 12,

    [Parameter(Mandatory=$True)]
    [Validateset("Key", "Certificate", "Both")]
    [String]$AuthenticationMethod = "Both",

    [Parameter(Mandatory=$True)]
    [Validateset("Create", "Update")]
    [String]$Mode = "Create"
    
)
#
# Import required modules
#
$module = Get-Module 'AzureAD.Standard.Preview' -ListAvailable -ErrorAction SilentlyContinue
if (!$module) 
{
    Write-Output "[SPN-Generator] - Azure AD module AzureAD.Standard.Preview is not installed."
    $module = Install-Module -Name 'AzureAD.Standard.Preview' -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber 
    Write-Host "[SPN-Generator] - AzureAD.Standard.Preview Module now installed"
}
else {
    Write-Output "[SPN-Generator] - Azure AD module AzureAD.Standard.Preview is already installed."
}
try {
    import-module $module.RootModule    
}
catch {
    Write-Error "[SPN-Generator] - Unable to load AzureAD.Standard.Preview module : $($_.Exception.Message)." 
    exit   
}
$module = Get-Module 'randompasswordgenerator' -ListAvailable -ErrorAction SilentlyContinue
if (!$module) 
{
    Write-Output "[SPN-Generator] - Module randompasswordgenerator is not installed."
    $module = Install-Module -Name 'randompasswordgenerator' -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber 
    Write-Host "[SPN-Generator] - Module randompasswordgenerator now installed"
}
else {
    Write-Output "[SPN-Generator] - Module randompasswordgenerator is already installed."
}
try {
    import-module randompasswordgenerator 
}
catch {
    Write-Error "[SPN-Generator] - Unable to load AzureAD.Standard.Preview module : $($_.Exception.Message)." 
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
$AzureADAPplicationSubjectName = "cn=$AzureADApplicationName"

[String]$ApplicationSecretName = "secret"
[String]$ApplicationAppIDName = "AppId"
[String]$ObjectIdName ="ObjectId" 
#
# Check if already connected to an Azure Subscription
# OK
$CheckAzureContext = Get-AzContext
If ([string]::IsNullOrEmpty($CheckAzureContext) -eq $True) {
    #
    # No current context => Not connected to an Azure Subscription
    # OK
    Write-Error "[SPN-Generator] : Not connected to Azure."
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
    Write-Error "[SPN-Generator] - Unable to list available Azure Subscription."
    Exit
}
If (($Listsubscriptions.count) -gt 0) {
    If ([string]::IsNullOrEmpty($Listsubscriptions.id -match $solutionsubscriptionID) -eq $True) {
        #
        # Subscription not found
        # OK
        Write-Error "[SPN-Generator] - Subscription ID $solutionsubscriptionID not visible in current context."
        Exit
    }
    else {
        #
        # Subscription found
        # OK
        Write-output "[SPN-Generator] - Subscription $solutionsubscriptionID visible in current context."
        Set-AzContext -SubscriptionId $solutionsubscriptionID | Out-Null
    }
}
Else {
    #
    # Required Subscription is not reachable
    # OK
    Write-Error "[SPN-Generator] - Subscription ID $solutionsubscriptionID not visible in current context."
    Exit
}
Try {
    #
    # Check if connected to Azure AD
    # OK
    Get-AzureADTenantDetail -ErrorAction SilentlyContinue  | Out-Null
    Write-Host "[SPN-Generator] - Connected to Azure AD."
}
Catch {
    #
    # Not connected to an Azure AD Tenant
    # OK
    Write-Error "[SPN-Generator] - Not connected to Azure AD. Please connect to Azure AD Tenant $((Get-AzContext).tenant.id) and relaunch the script."
    exit
}
#
# Check if connected user is member of the Company Administrator role
# OK
#$CurrentAzureADUser = (Get-AzureADCurrentSessionInfo).Account.id
#$CurrentAzureADObject = Get-AzureADUser -All $true -Filter "UserPrincipalName eq '$CurrentAzureADUser'"
#Write-Host "[SPN-Generator] - Check if user $((Get-AzureADCurrentSessionInfo).Account.ID) is member of the Company Administrator Azure AD Role."
#$AzureADRole = Get-AzureADDirectoryRole | Where-Object {$_.displayname -eq "Company Administrator"}
#$ListAzureADRolemembers = Get-AzureADDirectoryRoleMember -ObjectId $AzureADRole.ObjectId
#If (($ListAzureADRolemembers | Where-Object {$_.objectid -eq $CurrentAzureADObject.ObjectID}) -ne $Null)
#{
#    Write-Host "[SPN-Generator] - User $((Get-AzureADCurrentSessionInfo).Account.ID) is member of the Company Azure AD Role"
#}
#Else
#{
#    Write-Warning "[SPN-Generator] - User $((Get-AzureADCurrentSessionInfo).Account.ID) is not member of the Company Azure AD Role"
#}    
#
# Check if solution Resource Group exists
# OK
$CheckResourceGroup = Get-AzResourceGroup -Name $SolutionResourceGroupname -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckResourceGroup)) {
    #
    # Resource Group does not exists
    # OK
    Write-Error "[SPN-Generator] - Resource Group $SolutionResourceGroupname does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # Resource Group exists in subscription
    # OK
    Write-output "[SPN-Generator] - Resource Group $SolutionResourceGroupname exists in subscription $((Get-AzContext).Subscription.id)."
}
#
# Check if solution Keyvault exists
# OK
$checkKeyVault = Get-AzKeyVault -Name $SolutionKeyVaultName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckKeyVault)) {
    #
    # Solution Key Vault does not exists
    # OK
    Write-Error "[SPN-Generator] - Required KeyVault $SolutionKeyVaultName does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # KeyVault Exists in subscription
    # OK
    Write-Output "[SPN-Generator] - Required KeyVault $SolutionKeyVaultName does exists in subscription $((Get-AzContext).Subscription.id)."
}
#
# Enforce permissions on secrets
# OK
try {
    Write-Output "[SPN-Generator] - Set Permisions to Secrets on Key Vault $SolutionKeyVaultName for $((Get-AzContext).Account.id)."
    $AzureADUSer = Get-AzureADUser -filter ("userprincipalname eq '" + $((Get-AzureADCurrentSessionInfo).account.id) + "'")
    Set-AzKeyVaultAccessPolicy `
        -ResourceGroupName $SolutionResourceGroupName `
        -VaultName $SolutionKeyVaultName `
        -ObjectId $AzureADUSer.ObjectID `
        -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge 
    Write-Output "[SPN-Generator] - Permisions to Secrets on Key Vault $SolutionKeyVaultName sucessfully configured for  $((Get-AzContext).Account.id)."        
}
catch {
    #
    # Unable to set access policy on Key Vault
    # OK
    Write-Error "[SPN-Generator] - Unable set access policies on KeyVault $SolutionKeyVaultName : $($_.Exception.Message)."    
    exit
}
#
# Check Azure AD Application
# OK
# section à traiter uniquement si mode Create et pas update
Switch($Mode)
{
    "Create" {
        #
        # Create mode, will delete if Azure AD Application already exists
        #
        $testAzureAdApplication = Get-AzureADApplication -All $true | where-Object {$_.displayname -like $AzureADApplicationName}
        If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True)
        {
            #
            # Azure AD application not yet exists, check if another application is not using the same CustomKeyIdentifier
            # OK
            $message = "[SPN-Generator] - Azure AD Application $AzureADApplicationName does not already exists in your Azure AD tenant."
            Write-Host $message
        }
        else 
        {
            If ($testAzureAdApplication.count -eq 1)
            {
                #
                # Azure AD Application already exists in Azure AD, will be deleted and reconfigured
                # OK
                $Message = "[SPN-Generator] - Azure AD Application $AzureADApplicationName already exists in Azure AD. Will be deleted."
                Write-Warning $message
                Start-Sleep -Seconds 60 # Time out to avoid issue
                Get-AzureADApplication -ObjectId $testAzureAdApplication.ObjectId | Remove-AzureADApplication                   
            }
            else {
                #
                # Corner case, multiple Azure AD application withe the same displayname
                # OK
                Write-Error "[SPN-Generator] - Too many application with  the same name. Unable to configure application."
                Exit
            }
        }
    }
    "Update" {
        #
        # Update mode, will only check if Azure AD APplication exists
        #
        $testAzureAdApplication = Get-AzureADApplication -All $true | where-Object {$_.displayname -like $AzureADApplicationName}
        If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True)
        {
            #
            # Azure AD application not yet exists, check if another application is not using the same CustomKeyIdentifier
            # OK
            $message = "[SPN-Generator] - Azure AD Application $AzureADApplicationName does not already exists in your Azure AD tenant."
            Write-Error $message
            exit
        }
        else {
            $message = "[SPN-Generator] - Azure AD Application $AzureADApplicationName exists in your Azure AD tenant."
            Write-Output $Message
        }
    }
}
If ($AuthenticationMethod -ne "Key")
{
    #
    # Check if certificate exists (if yes delete)
    # OK
    $testcertificate = Get-AzKeyVaultCertificate `
        -VaultName $SolutionKeyVaultName `
        -Name $AzureADApplicationName `
        -ErrorAction SilentlyContinue
    If ($testcertificate.count -eq 0)
    {
        #
        # Certificate with this name does not existe un KeyVault
        # OK
        Write-Output "[SPN-Generator] - Certificate named $AzureADApplicationName does not exists yet in solution Key Vault $SolutionKeyVaultName."     
    }
    else 
    {
        #
        # Certificate with this name already exists in solution key vault, will be deleted
        # OK 
        Write-Output "[SPN-Generator] - Certificate named $AzureADApplicationName already exists in solution Key Vault $SolutionKeyVaultName. Delete certificate."
        Remove-AzKeyVaultCertificate `
            -VaultName $SolutionKeyVaultName `
            -Name $AzureADApplicationName `
            -Force
    }
    #
    # Generating new Self-signed certificate
    # OK
    Write-output "[SPN-Generator] - Creating auto-signed certificate in KeyVault $SolutionKeyVaultName"
    $Policy = New-AzKeyVaultCertificatePolicy `
        -SecretContentType "application/x-pkcs12" `
        -SubjectName $AzureADAPplicationSubjectName `
        -IssuerName "Self" `
        -ValidityInMonths $AutomationCertificateLifetimePolicy `
        -ReuseKeyOnRenewal
    $AddAzureKeyVaultCertificateStatus = Add-AzKeyVaultCertificate `
        -VaultName $SolutionKeyVaultName `
        -Name $AzureADApplicationName `
        -CertificatePolicy $Policy   
    While ($AddAzureKeyVaultCertificateStatus.Status -eq "inProgress") 
    {
        #
        # Wait for certificate generation
        # OK
        Start-Sleep -Seconds 10
        $AddAzureKeyVaultCertificateStatus = Get-AzKeyVaultCertificateOperation -VaultName $SolutionKeyVaultName -Name $AzureADApplicationName     
    }
    If ($AddAzureKeyVaultCertificateStatus.Status -ne "Completed")
    {
        #
        # Error during certificate generation
        # OK
        Write-Error "[SPN-Generator] - Error while creating certificate in Keyvault $SolutionKeyVaultName : $($AddAzureKeyVaultCertificateStatus.Status)."
        exit
    }
    Else 
    {
        #
        # Certificate sucessfully generated in KeyVault
        # OK
        Write-output  "[SPN-Generator] - Successfully created auto-signed certificate in KeyVault $SolutionKeyVaultName."
    }
    #
    # Export certificate from solution Key Vault
    # OK
    try {
        $PfxCertPlainPasswordForRunAsAccount = (Get-RandomPassword -PasswordLength $PasswordLenght -PercentLowerCaseLetters $PercentLowerCaseLetters -PercentUpperCaseLetters $PercentUpperCaseLetters -PercentNumbers $PercentNumbers -PercentCharacters $PercentCharacters).PasswordValue
        Write-Output "[SPN-Generator] - Exporting certificate from KeyVault $SolutionKeyVaultName."
        $secretRetrieved = Get-AzKeyVaultSecret `
            -VaultName $SolutionKeyVaultName `
            -Name $AzureADApplicationName
        $pfxBytes = [System.Convert]::FromBase64String($secretRetrieved.SecretValueText)
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.Import($pfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)   
        $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12,$PfxCertPlainPasswordForRunAsAccount )
        [System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $protectedCertificateBytes)
        Write-Output "[SPN-Generator] - Certificate successfully exported from solution key vault $SolutionKeyVaultName."
    }
    catch  {
        #
        # Export certificate in PFX
        # OK
        Write-Error "[SPN-Generator] - One or more error while exporting certificates : $($_.Exception.Message)."
        exit
    }
}
#
# Create Azure AD Application
# OK
#try {

    #
    # Create Azure AD Application
    # OK
    Switch($mode)
    {
        "Create" {
            Write-Output "[SPN-Generator] - Creating Azure AD Application $AzureADApplicationName."
            $NewAzureADApplication = New-AzureADApplication `
                -DisplayName $AzureADApplicationName `
                -HomePage ("http://" + $AzureADApplicationName) `
                -IdentifierUris $CustomKeyIdentifier `
                -ReplyUrls ("http://" + $AzureADApplicationName)
            #
            # Create Service princpal linked to Azure AD Application
            # OK
            $NewAzureADServicePrincipal = New-AzureADServicePrincipal -AppId $NewAzureADApplication.AppId 
        }
        "Update" {
            Write-Output "[SPN-Generator] - Updating Azure AD Application $AzureADApplicationName."
            $NewAzureADApplication = Get-AzureADApplication -All $true | where-Object {$_.displayname -like $AzureADApplicationName}
        }
    }       
    If ($AuthenticationMethod -ne "Key")
    {
        $KeyVaultCertificate = Get-AzKeyVaultCertificate `
            -VaultName $SolutionKeyVaultName `
            -Name $AzureADApplicationName
        #
        # Generate Key Credential for Azure AD Application
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
            -Value $base64Value `
            -startdate $KeyVaultCertificate.NotBefore `
            -EndDate $KeyVaultCertificate.Expires| Out-Null
    }
    If ($AuthenticationMethod -ne "Certificate")
    {
        [DateTime]$StartDate = Get-Date
        [DateTime]$EndDate = $StartDate.AddMonths($AutomationCertificateLifetimePolicy)
        $credential = New-AzureADApplicationPasswordCredential -ObjectId $NewAzureADApplication.ObjectId `
            -startdate $StartDate `
            -EndDate $EndDate
        $secretvalue = ConvertTo-SecureString $($credential.Value) -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $SolutionKeyVaultName -Name $ApplicationSecretName -SecretValue $secretvalue | Out-Null
        $credential = $Null
        $secretvalue = $Null
    }
    #
    # Generate a Secret for Azure AD application
    # OK
    $secretvalue = ConvertTo-SecureString $($NewAzureADApplication.AppId) -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $SolutionKeyVaultName -Name $ApplicationAppIDName -SecretValue $secretvalue | Out-Null
    $secretvalue = ConvertTo-SecureString $(  $NewAzureADApplication.ObjectID) -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $SolutionKeyVaultName -Name $ObjectIdName -SecretValue $secretvalue | Out-Null  
    #
    # Assign Owner to newly created Azure AD Application
    #
  # TODO
  #  Add-AzureADApplicationOwner -ObjectId $NewAzureADApplication.ObjectId -RefObjectId $CurrentAzureADObject.objectid

    $credential = $null
    Write-output "[SPN-Generator] - Azure AD Application $AzureADApplicationName created successfully in Azure AD tenant with Service Principal ID $($NewAzureADApplication.AppId)."
    If ($AuthenticationMethod -ne "Key")
    {
        remove-item -Path $PfxCertPathForRunAsAccount -Force | Out-Null
    }
#}
#catch {
#    #
#    # Error while generation Azure AD Application
#    # OK
#    Write-Error "[SPN-Generator] - Error while creating Azure AD Application $AzureADApplicationName : $($_.Exception.Message)."
#        If ($AuthenticationMethod -ne "Key")
#    {
#        remove-item -Path $PfxCertPathForRunAsAccount -Force | Out-Null
#    }
    #    Remove-AzureADApplication -ObjectId $AzureADApplication.ObjectID -Force -ErrorAction SilentlyContinue
#    Exit
#}
#
# Perform owner role assignation at subscription level
# OK
$NewRole = $null
$Retries = 0
Write-Output "[SPN-Generator] - Assigning Service Principal Owner role at subscription $((Get-AzContext).Subscription.id) level."
While ($NewRole -eq $null -and $Retries -le 6) 
{
    #
    # Loop While role assignment not completed
    # OK
    Start-Sleep -Seconds 10 # Required because Azure AD Identity may not be visible from Azure just after created
    New-AzRoleAssignment -RoleDefinitionName $AssignedRole -ApplicationId $NewAzureADServicePrincipal.AppId -scope ("/subscriptions/" + $((Get-AzContext).Subscription.id)) -ErrorAction SilentlyContinue | Out-Null
    Write-Output "[SPN-Generator] - Checking role Assignment."
    $NewRole = Get-AzRoleAssignment -ServicePrincipalName  $NewAzureADServicePrincipal.AppId -ErrorAction SilentlyContinue        
    $Retries++;
}
If ($NewRole -ne $null -and $Retries -le 6) 
{
    #
    # Role assignment sucessfully configured
    # OK
    Write-Output "[SPN-Generator] - Owner Role sucessfully assigned to Service Principal $($Application.ApplicationId) at $((Get-AzContext).Subscription.id) level."
}
else 
{
    #
    # Error during role assignment.
    # OK
    Write-Error "[SPN-Generator] - Error while assigning Owner role at $((Get-AzContext).Subscription.id)) : $($_.Exception.Message)."
    If ($AuthenticationMethod -ne "Key")
    {
        remove-item -Path $PfxCertPathForRunAsAccount -Force | Out-Null
    }
    Remove-AzureADApplication -ObjectId $Application.ObjectId
    exit
}