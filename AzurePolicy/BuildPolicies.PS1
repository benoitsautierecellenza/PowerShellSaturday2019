#
# Update existing policy assignments 
#

Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$Build,
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$ManagementGroupName

)
[String]$SubscriptionID = "5be15500-7328-4beb-871a-1498cd4b4536"
Set-AzContext -SubscriptionId $SubscriptionID

$TestManagementGroup = Get-AzManagementGroup -GroupName $ManagementGroupName
If ([string]::IsNullOrEmpty($TestManagementGroup) -eq $True)
{
    Throw "Management group named $ManagementGroupName does not exists."
}
else {
    Write-Output "Management group named $ManagementGroupName  exists."
}
[String]$SubscriptionID = (Get-AzContext).Subscription.id
[String]$Scope = "/subscriptions/$SubscriptionID/"
$Policies = @{
	PolicyDefinitions = @{
	    POLICY1 = @{
            PolicyName              = "DefautltValue4UpdatePolicy"
	        PolicyDefinitionFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-DEFAULTTAG-01/AZ-DEFAULTTAG-01-RULE.json"
            PolicyParameterFileURI  = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-DEFAULTTAG-01/AZ-DEFAULTTAG-01-PARAMETERS.json"
            ManagementGroupName     = $ManagementGroupName
            Description             = "Enforce Default value for a Tag."
	    }
	    POLICY2 = @{
            PolicyName              = "AllowedTagValues4UpdatePolicy"
	        PolicyDefinitionFileURI = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-ALLOWEDTAGVALUES-02/AZ-ALLOWEDTAGVALUES-02-RULE.json"
            PolicyParameterFileURI  = "https://raw.githubusercontent.com/Benoitsautierecellenza/PowerShellSaturday2019/master/AzurePolicy/AZ-ALLOWEDTAGVALUES-02/AZ-ALLOWEDTAGVALUES-02-PARAMETERS.json"	        
            ManagementGroupName     = $ManagementGroupName
            Description             = "Enfoce allowed values for a Tag."
	    }
	}
	Assignments = @{        
	    ASSIGN1 = @{
            PolicyName          = "DefautltValue4UpdatePolicy"
            ManagementGroupName = $ManagementGroupName
            Scope = "/subscriptions/5be15500-7328-4beb-871a-1498cd4b4536/"
            Parameters = @{
                UpdatePolicyTagName = "UpdatePolicy"       
                DefaultTagValue = "AlwaysReboot"
            }
        }
        ASSIGN2 = @{
            PolicyName = "AllowedTagValues4UpdatePolicy"
	        ManagementGroupName = $ManagementGroupName
            Scope = "/subscriptions/5be15500-7328-4beb-871a-1498cd4b4536/"
            Parameters = @{
                UpdatePolicyTagName = "UpdatePolicy"
                UpdatePolicyTagAllowedValues = @("AlwaysReboot", "RebootIfRequired", "OnlyReboot", "NeverReboot")
            }
        }
    }
}
#
# Remove existing assignments
#
Write-Output "Removing exiting Azure Policy Assignments."
$TestPolicy = Get-AzPolicyAssignment -Scope $Scope
If ([string]::IsNullOrEmpty($TestPolicy) -eq $False) {Get-AzPolicyAssignment -Scope $Scope | Remove-AzPolicyAssignment -Scope $scope | Out-Null }
#
# Processing JSON policy definition file for import
#
foreach($Policy in $Policies.PolicyDefinitions.GetEnumerator()) {
    #
    # Processing each node
    #
    Write-Output "Importing Policy $($policy.name) at Management group level $($Policy.Value.ManagementGroupName)."
    New-AzPolicyDefinition -Name $($policy.Value.PolicyName) `
        -DisplayName $policy.Value.PolicyName `
        -Policy $($policy.Value.PolicyDefinitionFileURI) `
        -Parameter $($policy.Value.PolicyParameterFileURI) `
        -ManagementGroupName $($policy.Value.ManagementGroupName) `
        -Description $($policy.Value.description) `
        -Mode All 
}
#
# Processing JSON Policy definition for Policy Assignment
#
foreach($Assignment in $policies.Assignments.GetEnumerator()) {
    Write-Output "Processing Assignment $($Assignment.Name)."
    $($Assignment.Value.ManagementGroupName)
    $($Assignment.Value.PolicyName)
    $PolicyDefinition = Get-AzPolicyDefinition -ManagementGroupName $($Assignment.Value.ManagementGroupName) -Custom | Where-Object {$_.name -eq $($Assignment.Value.PolicyName)}
    #
    # Check if Azure Policy Exists
    #
    If ([string]::IsNullOrEmpty($PolicyDefinition) -eq $false)
    {
        Write-Output "Azure Policy $($Assignment.Value.PolicyName) exists at Management group $($Assignment.Value.ManagementGroupName) level."
    }
    else {
        Throw "Azure Policy $($Assignment.Value.PolicyName) does not exists at Management group $($Assignment.Value.ManagementGroupName) level."
    }
    #
    # Prepare Policy Assignment
    #
    [String]$PolicyAssignname = $($Assignment.Name)  + "_" + $Build    
    $AssignParameters = @{
    }
    ForEach ($Parameter in $Assignment.Value.Parameters.GetEnumerator())
    {
        $AssignParameters.Add($Parameter.name, $Parameter.Value)

    }
    #
    # Perform Policy Assignments
    #
# Tester ici si l'assignation fonctionne réellement pour la seconde policy
    New-AzPolicyAssignment -Name $PolicyAssignname `
        -PolicyDefinition $PolicyDefinition `
        -Scope $Assignment.Value.Scope `
        -PolicyParameterObject $AssignParameters
}



exit


#
# Assign AZ-ALLOWEDTAGVALUES Policy
#
Write-Output "Assign AZ-ALLOWEDTAGVALUES Policy"
$PolicyName = "AllowedTagValues4UpdatePolicy"
[String]$PolicyAssignname = "MGMT01-VM-P2"  + "_" + $Build
$UpdatePolicyTagName = "UpdatePolicy"
$AllowedValues = @("AlwaysReboot", "RebootIfRequired", "OnlyReboot", "NeverReboot")
$PolicyDefinition = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupName -Custom | Where-Object {$_.name -eq $PolicyName}
$AssignParameters = @{
    'UpdatePolicyTagName' = $UpdatePolicyTagName;
    'UpdatePolicyTagAllowedValues' = ($AllowedValues)
}
New-AzPolicyAssignment -Name $PolicyAssignname `
    -PolicyDefinition $PolicyDefinition `
    -Scope $Scope `
    -PolicyParameterObject $AssignParameters