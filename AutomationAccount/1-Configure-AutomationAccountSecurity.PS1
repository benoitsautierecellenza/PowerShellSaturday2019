

#. .\1-Configure-AutomationAccountSecurity.PS1 -SolutionResourceGroupName "LabAutomation" -SolutionKeyVaultName "LabAutomation" -SolutionSubscriptionID "5be15500-7328-4beb-871a-1498cd4b4536" -SolutionAutomationAccountName "LabAutomation"  -AutomationAzureADApplicationName LABAUTOMATION 

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
    [String]$SolutionAutomationAccountName

)
#
# Constants
#
$PasswordLenght = 16                                        # Password Lenght for PFX certificate export
$PercentLowerCaseLetters = 0.25
$PercentUpperCaseLetters = 0.25
$PercentNumbers = 0.25
$PercentCharacters = 0.25
$CertifcateAssetName = "AzureRunAsCertificate"
$ConnectionAssetName = "AzureRunAsConnection"
$ConnectionTypeName = "AzureServicePrincipal"
#
# Check if already connected to an Azure Subscription
# OK
$CheckAzureContext = Get-AzContext
If ([string]::IsNullOrEmpty($CheckAzureContext) -eq $True) {
    #
    # No current context => Not connected to an Azure Subscription
    # OK
    Write-Error "[Configure-AutomationSecurity] : Not connected to Azure."
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
    Write-Error "[Configure-AutomationSecurity] - Unable to list available Azure Subscription."
    Exit
}
If (($Listsubscriptions.count) -gt 0) {
    If ([string]::IsNullOrEmpty($Listsubscriptions.id -match $solutionsubscriptionID) -eq $True) {
        #
        # Subscription not found
        # OK
        Write-Error "[Configure-AutomationSecurity] - Subscription ID $solutionsubscriptionID not visible in current context."
        Exit
    }
    else {
        #
        # Subscription found
        # OK
        Write-output "[Configure-AutomationSecurity] - Subscription $solutionsubscriptionID visible in current context."
        Set-AzContext -SubscriptionId $solutionsubscriptionID | Out-Null
    }
}
Else {
    #
    # Required Subscription is not reachable
    # OK
    Write-Error "[Configure-AutomationSecurity] - Subscription ID $solutionsubscriptionID not visible in current context."
    Exit
}
#
# Check if solution Resource Group exists
# OK
$CheckResourceGroup = Get-AzResourceGroup -Name $SolutionResourceGroupname -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckResourceGroup)) {
    #
    # Resource Group does not exists
    # OK
    Write-Error "[Configure-AutomationSecurity] - Resource Group $SolutionResourceGroupname does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # Resource Group exists in subscription
    # OK
    Write-output "[Configure-AutomationSecurity] - Resource Group $SolutionResourceGroupname exists in subscription $((Get-AzContext).Subscription.id)."
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
    Write-Error "[Configure-AutomationSecurity] - Required Azure Automation Account $SolutionAutomationAccountName does not exists in resource group $SolutionResourceGroupName."
    Exit
}
else {
    #
    # Azure Automation Account exists
    # OK
    Write-output "[Configure-AutomationSecurity] - Required Azure Automation Account $SolutionAutomationAccountName found in resource group $SolutionResourceGroupName."
}
#
# Check if solution Keyvault exists
# OK
$checkKeyVault = Get-AzKeyVault -Name $SolutionKeyVaultName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckKeyVault)) {
    #
    # Solution Key Vault does not exists
    # OK
    Write-Error "[Configure-AutomationSecurity] - Required KeyVault $SolutionKeyVaultName does not exists in subscription $((Get-AzContext).Subscription.id)."
    exit
}
else {
    #
    # KeyVault Exists in subscription
    # OK
    Write-Output "[Configure-AutomationSecurity] - Required KeyVault $SolutionKeyVaultName does exists in subscription $((Get-AzContext).Subscription.id)."
}
#
# Check Azure AD Application
# OK
$testAzureAdApplication = Get-AzureADApplication -All $true | where-Object {$_.displayname -like $AutomationAzureADApplicationName}
If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True)
{
    #
    # Azure AD application exists in Azure AD     
    # OK
    $message = "[Configure-AutomationSecurity] - Azure AD Application $AutomationAzureADApplicationName does not already exists in your Azure AD tenant."
    Write-Error $message
    exit
}
else 
{
    If ($testAzureAdApplication.count -eq 1)
    {
        #
        # Azure AD Application already exists in Azure AD
        # OK
        $Message = "[Configure-AutomationSecurity] - Azure AD Application $AutomationAzureADApplicationName already exists in Azure AD."
        Write-Output $message            
    }
    else {
        #
        # Corner case, multiple Azure AD application withe the same displayname
        # OK
        Write-Error "[Configure-AutomationSecurity] - Too many application with  the same name. Unable to configure application."
        Exit
    }
}
################### ecrire test certificat  et secret ###########
#
# Check if Certificate exists in KeyVaut
#
$TestCertificateExists = Get-AzKeyVaultCertificate -VaultName $SolutionKeyVaultName
If([string]::IsNullOrEmpty($TestCertificateExists)) {
    Write-Error "[Configure-AutomationSecurity] - No certificate found in Keyvault $SolutionKeyVaultName."
    exit
}
else {

    $AutomationAzureADApplicationName
}
#
# Fin réécriture tests keyvault
# ################################################
#
# Remove existing assets in Azure Automation account related to authentication
#
$testCertificateAsset = Get-AzAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($testCertificateAsset) -eq $False)        
{
    Write-Output "[Configure-AutomationSecurity] - Removing existing certificate asset $certifcateAssetName from Azure Automation Account $SolutionAutomationAccountName."
    Remove-AzAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName    
    Write-Output "[Configure-AutomationSecurity] - Certificate asset  $certifcateAssetName deleted from Azure Automation Account $SolutionAutomationAccountName."
}
#
# Export certificate from KeyVault (PFX)
#
try {
    $PfxCertPlainPasswordForRunAsAccount = (Get-RandomPassword -PasswordLength $PasswordLenght -PercentLowerCaseLetters $PercentLowerCaseLetters -PercentUpperCaseLetters $PercentUpperCaseLetters -PercentNumbers $PercentNumbers -PercentCharacters $PercentCharacters).PasswordValue
    Write-Output "[Configure-AutomationSecurity] - Exporting certificate from KeyVault $SolutionKeyVaultName."
    $secretRetrieved = Get-AzKeyVaultSecret `
        -VaultName $SolutionKeyVaultName `
        -Name $AutomationAzureADApplicationName
    $pfxBytes = [System.Convert]::FromBase64String($secretRetrieved.SecretValueText)
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $certCollection.Import($pfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)   
    $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12,$PfxCertPlainPasswordForRunAsAccount )
    [System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $protectedCertificateBytes) 
}
catch  {
    #
    # Export certificate in PFX
    # OK
    Write-Error "[Configure-AutomationSecurity] - One or more error while exporting certificates : $($_.Exception.Message)."
    $PfxCertPlainPasswordForRunAsAccount = $null
    exit
}
#
# Import certificate Into Azure Automation Account
#
$CertPassword = ConvertTo-SecureString -String $PfxCertPlainPasswordForRunAsAccount -AsPlainText -Force  
New-AzAutomationCertificate  `
    -ResourceGroupName $SolutionResourceGroupname `
    -automationAccountName $SolutionAutomationAccountName `
    -Path $PfxCertPathForRunAsAccount `
    -Name $certifcateAssetName `
    -Password $CertPassword | Out-Null
#
# Configure Connection asset
#
$testconnectionasset = Get-AzAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($testconnectionasset) -eq $False)        
{
    Write-Output "[Configure-AutomationSecurity] - Removing existing connection asset named $connectionAssetName from Azure Automation Account $SolutionAutomationAccountName."
    Remove-AzAutomationConnection -ResourceGroupName $SolutionResourceGroupname `
        -automationAccountName $SolutionAutomationAccountName `
        -Name $connectionAssetName `
        -Force
    Write-Output "[Configure-AutomationSecurity] - Existing connection asset named $connectionAssetName successfully removed from Azure Automation Account $SolutionAutomationAccountName."
}

$ApplicationId = $testAzureAdApplication.AppId
$KeyVaultCertificate = Get-AzKeyVaultCertificate `
    -VaultName $SolutionKeyVaultName `
    -Name $AutomationAzureADApplicationName
#
# Générate Key Credential for Azure AD Application
# OK
#$KeyVaultCertRawData = $KeyVaultCertificate.Certificate.RawData
#$base64Value = [System.Convert]::ToBase64String($KeyVaultCertRawData) 
#$thumbprint=$KeyVaultCertificate.Certificate.GetCertHash() 
#$base64Thumbprint = [System.Convert]::ToBase64String($thumbprint) 

#
# Pas le bon Thumbprint passé : devrait être 1CE2F328FE9074F74852492D1EC0DEC53A69994E
#
$ConnectionFieldValues = @{
    "ApplicationId" = $ApplicationID; 
    "TenantId" = $((Get-AzContext).tenant.ID); 
    "CertificateThumbprint" = $KeyVaultCertificate.Thumbprint; 
    "SubscriptionId" = $SolutionSubscriptionID
} 
New-AzAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues | Out-Null


$CertPassword = $Null
Get-ChildItem $PfxCertPathForRunAsAccount | Remove-Item | Out-Null






"DONE"
exit
#
# Second partie du script
#
#
# Initializing Azure Automation Certificate and connection assets
# OK
try {    
    Write-Output "[Configure-AutomationSecurity] - Initializing Automation Account $SolutionAutomationAccountName in $SolutionResourceGroupname resource Group."
    #New-AzureRmAutomationAccount -ResourceGroupName $SolutionResourceGroupname -Name $AutomationAccountName -Location $AutomationAccountRegion -Tags $SolutionTags -Plan $AutomationAccountPlan
    $CertPassword = ConvertTo-SecureString -String $PfxCertPlainPasswordForRunAsAccount -AsPlainText -Force
    #
    # Delete certificate Asset in Automation account if already exists
    # OK
    $testCertificateAsset = Get-AzureRmAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName -ErrorAction SilentlyContinue
    If([string]::IsNullOrEmpty($testCertificateAsset) -eq $False)        
    {
        Write-Output "[Configure-AutomationSecurity] - Removing existing certificate asset $certifcateAssetName from Azure Automation Account $SolutionAutomationAccountName."
        Remove-AzureRmAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName
        Write-Output "[Configure-AutomationSecurity] - Certificate asset  $certifcateAssetName deleted from Azure Automation Account $SolutionAutomationAccountName."
    }
    #
    # Create a certificate Asset
    # OK
    Write-Output "[Configure-AutomationSecurity] - Configuring certificate asset $certifcateAssetName in Azure Automation Acccount $SolutionAutomationAccountName."
    New-AzureRmAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Path $PfxCertPathForRunAsAccount -Name $certifcateAssetName -Password $CertPassword | Out-Null
    Write-Output "[Configure-AutomationSecurity] - Certificate asset $certifcateAssetName sucecssfully configured in Azure Automation Acccount $SolutionAutomationAccountName."
    If ($mode -eq "CREATE")
    {
        $ApplicationId = $Application.ApplicationId # cas CREATE
    }
    else 
    {
        $ApplicationID    = $TestAzureADApplication.AppId # Cas REUSE 
    }
    $Thumbprint = $PfxCert.Thumbprint
    $ConnectionFieldValues = @{"ApplicationId" = $ApplicationID; "TenantId" = $((Get-AzContext).tenant.ID); "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SolutionSubscriptionID} 
    #
    # Delete existing connection asset in Azure Automation account if already exists
    # OK
    $testconnectionasset = Get-AzureRmAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -ErrorAction SilentlyContinue
    If([string]::IsNullOrEmpty($testconnectionasset) -eq $False)        
    {
        Write-Output "[Configure-AutomationSecurity] - Removing existing connection asset named $connectionAssetName from Azure Automation Account $SolutionAutomationAccountName."
        Remove-AzureRmAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -Force
        Write-Output "[Configure-AutomationSecurity] - Existing connection asset named $connectionAssetName successfully removed from Azure Automation Account $SolutionAutomationAccountName."
    }

# Initialiser avec les données créées
# Déplacer dans Configure-AutomationSecurity.PS1
#    $testAutomationVariable = Get-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName -ResourceGroupName $SolutionResourceGroupname -Name "RunbookAutomationServicePrincipalID" -ErrorAction SilentlyContinue
#    If([string]::IsNullOrEmpty($testAutomationVariable) -eq $false)          
#    {
#        Remove-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName -ResourceGroupName $SolutionResourceGroupname -Name "RunbookAutomationServicePrincipalID"
#    }
#    New-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName -ResourceGroupName $SolutionResourceGroupname -Name "RunbookAutomationServicePrincipalID" -Value $SolutionApplicationId -Description "Azure Automation Service Principal ID" -Encrypted $true | Out-Null



    Write-Output "[Configure-AutomationSecurity] - Creating a connection asset named $connectionAssetName in Azure Automation Account $SolutionAutomationAccountName."
    New-AzureRmAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues | Out-Null
    Write-Output "[Configure-AutomationSecurity] - Connection asset named $connectionAssetName successfully created in Azure Automation Account $SolutionAutomationAccountName."
#
# intégrer l'appartenance du service principal dans le groupe Azure AD
#
    Get-ChildItem $PfxCertPathForRunAsAccount | Remove-Item | Out-Null

    $CertPassword = $Null
    Get-ChildItem $PfxCertPathForRunAsAccount | Remove-Item | Out-Null

    Write-Output "[Configure-AutomationSecurity] - Azure Automation account $SolutionAutomationAccountName successfully initialized."  
}
catch 
{
    Write-Warning "[ERROR] - Error while creating Azure Automation instance $SolutionAutomationAccountName."
    
    $CertPassword = $Null
    exit
}