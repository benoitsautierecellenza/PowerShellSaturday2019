
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
If ([string]::IsNullOrEmpty($testAzureAdApplication) -eq $True) {
    #
    # Azure AD application exists in Azure AD     
    # OK
    $message = "[Configure-AutomationSecurity] - Azure AD Application $AutomationAzureADApplicationName does not already exists in your Azure AD tenant."
    Write-Error $message
    exit
}
else {
    If ($testAzureAdApplication.count -eq 1) {
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
#
# Check if Certificate exists in KeyVaut
# OK
$TestCertificateExists = Get-AzKeyVaultCertificate -VaultName $SolutionKeyVaultName -Name $AutomationAzureADApplicationName
If ($TestCertificateExists.count -eq 0) {
    Write-Error "[Configure-AutomationSecurity] - No certificate named $AutomationAzureADApplicationName found in Keyvault $SolutionKeyVaultName."
    exit
}
else {
    Write-Output "[Configure-AutomationSecurity] - Certificate named $AutomationAzureADApplicationName found in Keyvault $SolutionKeyVaultName."
}
#
# Remove existing assets in Azure Automation account related to authentication
#
$testCertificateAsset = Get-AzAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($testCertificateAsset) -eq $False)  {
    Write-Output "[Configure-AutomationSecurity] - Removing existing certificate asset $certifcateAssetName from Azure Automation Account $SolutionAutomationAccountName."
    Remove-AzAutomationCertificate -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName   -Name $certifcateAssetName    
    Write-Output "[Configure-AutomationSecurity] - Certificate asset  $certifcateAssetName deleted from Azure Automation Account $SolutionAutomationAccountName."
}
#
# Export certificate from KeyVault (PFX)
# OK
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
    Write-Output "[Configure-AutomationSecurity] - Certificate sucessfully exported from KeyVault $SolutionKeyVaultName."
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
# OK
$CertPassword = ConvertTo-SecureString -String $PfxCertPlainPasswordForRunAsAccount -AsPlainText -Force  
New-AzAutomationCertificate  `
    -ResourceGroupName $SolutionResourceGroupname `
    -automationAccountName $SolutionAutomationAccountName `
    -Path $PfxCertPathForRunAsAccount `
    -Name $certifcateAssetName `
    -Password $CertPassword | Out-Null
#
# Delete existing connection Asset
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

$ConnectionFieldValues = @{
    "ApplicationId" = $ApplicationID; 
    "TenantId" = $((Get-AzContext).tenant.ID); 
    "CertificateThumbprint" = $KeyVaultCertificate.Thumbprint; 
    "SubscriptionId" = $SolutionSubscriptionID
} 
New-AzAutomationConnection -ResourceGroupName $SolutionResourceGroupname -automationAccountName $SolutionAutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues | Out-Null
Get-ChildItem $PfxCertPathForRunAsAccount | Remove-Item | Out-Null
$CertPassword = $Null
Write-Output "[Configure-AutomationSecurity] - Azure Automation account $SolutionAutomationAccountName successfully initialized."  
