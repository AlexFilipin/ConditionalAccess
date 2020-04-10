<#
.NAME
    Create-CARuleSet.ps1
    
.SYNOPSIS
    None

.DESCRIPTION
    None
    
.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Alexander Filipin
    Creation Date:  2020-04-09
  
.EXAMPLE
    None
#>
Param(
    [Parameter(Mandatory=$True)]
    [System.String]$Prefix
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$ClientId
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$TenantName
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$TemplateFolder
    ,
    [Parameter(Mandatory=$False)]
    [System.Boolean]$RiskPolicies
    ,
    [Parameter(Mandatory=$False)]
    [ValidateSet("All","Targeted")]
    [System.String]$RiskScope
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$RiskGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$SynchronizationServiceAccountsGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$EmergencyAccessAccountsGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$ExlusionReviewersGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.Boolean]$DenyAccessReviewCreation
)

#region parameters
if(-not $RiskScope){$RiskScope = "All"}
if(-not $RiskGroup){$RiskGroup = "Conditional_Access_AADP2"}
if(-not $SynchronizationServiceAccountsGroup){$SynchronizationServiceAccountsGroup = "Conditional_Access_Exclusion_SynchronizationServiceAccounts"}
if(-not $EmergencyAccessAccountsGroup){$EmergencyAccessAccountsGroup = "Conditional_Access_Exclusion_EmergencyAccessAccounts"}
if(-not $RiskPolicies){$RiskPolicies = $True}
#endregion

#region development

$Prefix = "ZT"
$ClientId = "a4a0356b-69a5-4b85-9545-f64459010333"
$TenantName = "filipinlabs.onmicrosoft.com"
$TemplateFolder = "C:\AF\Repos\KB\AAD\CAPolicies\Template"
$RiskPolicies = $True
$RiskScope = "Targeted"
$SynchronizationServiceAccountsGroup = "Conditional_Access_Exclusion_SynchronizationServiceAccounts"
$EmergencyAccessAccountsGroup = "Conditional_Access_Exclusion_EmergencyAccessAccounts"

<#
To be implemented
    RiskScope
    Update exising policies
    app enforced restrictions
    create access review
#>

Write-Host "Prefix: $Prefix"
Write-Host "ClientId: $ClientId"
Write-Host "TenantName: $TenantName"
Write-Host "TemplateFolder: $TemplateFolder"
Write-Host "RiskPolicies: $RiskPolicies"
Write-Host "RiskScope: $RiskScope"
Write-Host "SynchronizationServiceAccountsGroup: $SynchronizationServiceAccountsGroup"
Write-Host "EmergencyAccessAccountsGroup: $EmergencyAccessAccountsGroup"
#endregion

#region functions
function New-AFAzureADGroup($Name){
    $Group = Get-AzureADGroup -SearchString $Name
    if(-not $Group){
        New-AzureADGroup -DisplayName $Name -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet" 
    }
}

function New-GraphConditionalAccessPolicy{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $requestBody,
        [Parameter(Mandatory = $true)]
        $accessToken 
    )
    $conditionalAccessURI = "https://graph.microsoft.com/beta/conditionalAccess/policies"
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Post -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"} -Body $requestBody -ContentType "application/json"
    $conditionalAccessPolicyResponse     
}

function Remove-GraphConditionalAccessPolicy{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $Id,
        [Parameter(Mandatory = $true)]
        $accessToken 
    )
    $conditionalAccessURI = "https://graph.microsoft.com/beta/conditionalAccess/policies/{$Id}"
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Delete -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"}
    $conditionalAccessPolicyResponse     
}

function Get-GraphConditionalAccessPolicies{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $accessToken 
    )
    $conditionalAccessURI = "https://graph.microsoft.com/beta/conditionalAccess/policies"
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Get -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"}
    $conditionalAccessPolicyResponse     
}
#endregion

#region connect
#Connect to Graph
$resource = "https://graph.microsoft.com/"
$authUrl = "https://login.microsoftonline.com/$TenantName"

#Using Device Code Flow that support Modern Authentication for Delegated User
$postParams = @{ resource = "$resource"; client_id = "$ClientId" }
$response = Invoke-RestMethod -Method POST -Uri "$authurl/oauth2/devicecode" -Body $postParams
Write-Host $response.message
#HALT: Go to Browser logged in as User with access to Azure AD Conditional Access and tenant and paste in Device Code

$Confirmation = ""
while ($Confirmation -notmatch "[y|n]"){
    $Confirmation = Read-Host "Did you complete the device code flow login? (Y/N)"
}
if ($Confirmation -eq "y"){
    $tokenParams = @{ grant_type = "device_code"; resource = "$resource"; client_id = "$ClientId"; code = "$($response.device_code)" }
    $tokenResponse = $null
    # Provided Successful Authentication, the following should return Access and Refresh Tokens: 
    $tokenResponse = Invoke-RestMethod -Method POST -Uri "$authurl/oauth2/token" -Body $tokenParams
    # Save Access Token and Refresh Token for later use
    $accessToken = $tokenResponse.access_token
    #$refreshToken = $tokenResponse.refresh_token

    #Connect-AzureAD -AadAccessToken $accessToken -AccountId $AdminUPN
}else{
    Write-Host "Script stopped, device code flow login not completed"
    Exit
}

Connect-AzureAD
#endregion

#region create groups
New-AFAzureADGroup -Name $SynchronizationServiceAccountsGroup
New-AFAzureADGroup -Name $EmergencyAccessAccountsGroup
if($RiskPolicies -and ($RiskScope -eq "Targeted")){
    #Create dynamic group if not yet existing
    $Group_AADP2 = Get-AzureADGroup -SearchString $RiskGroup
    if(-not $Group_AADP2){
        $MembershipRule = 'user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled")'
        New-AzureADMSGroup -DisplayName $RiskGroup -MailEnabled $False -MailNickName "NotSet" -SecurityEnabled $True -GroupTypes "DynamicMembership" -MembershipRule $MembershipRule -MembershipRuleProcessingState "On"
    }
}
#endregion

#region get group ObjectIds
$Group_SynchronizationServiceAccounts = Get-AzureADGroup -SearchString $SynchronizationServiceAccountsGroup
$Group_EmergencyAccessAccounts = Get-AzureADGroup -SearchString $EmergencyAccessAccountsGroup
$Group_AADP2 = Get-AzureADGroup -SearchString $RiskGroup

$ObjectID_SynchronizationServiceAccounts = $Group_SynchronizationServiceAccounts.ObjectId
$ObjectID_EmergencyAccessAccounts = $Group_EmergencyAccessAccounts.ObjectID
$ObjectID_AADP2 = $Group_AADP2.ObjectID
#endregion

#region import policy templates
$Templates = Get-ChildItem -Path $TemplateFolder #Change to $PSScriptRoot
$Policies = @()

foreach($Item in $Templates){
    $Policy = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    if($RiskPolicies -eq $False){
        if(-not $Policy.conditions.signInRiskLevels){
            $Policies += $Policy
        }
    }else{
        $Policies += $Policy
    }
}
#endregion

#region create policies
$Counter = 1
foreach($Policy in $Policies){
    $PrefixAndNumber = $Prefix + ("{0:00}" -f $Counter)

    #Create exlusion group
    $DisplayName_Exclusion = "Conditional_Access_Exclusion_" + $PrefixAndNumber
    $Group = Get-AzureADGroup -SearchString $DisplayName_Exclusion
    if(-not $Group){
        New-AzureADGroup -DisplayName $DisplayName_Exclusion -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet" 
    }

    #Get exclusion group ObjectId
    $Group_Exclusion = Get-AzureADGroup -SearchString $DisplayName_Exclusion
    $ObjectID_Exclusion = $Group_Exclusion.ObjectId

    #Add prefix to DisplayName
    $Policy.displayName = $Policy.displayName.Replace("<PREFIX>",$PrefixAndNumber)

    #Shift to targeted risk policies
    if($RiskPolicies -and ($RiskScope -eq "Targeted")){
        if($Policy.conditions.signInRiskLevels){
            if($Policy.conditions.users.includeUsers -eq "All"){
                [System.Collections.ArrayList]$Clear = $Policy.conditions.users.includeUsers
                $Clear.Clear()
                $Policy.conditions.users.includeUsers = $Clear
            }
        }
        #$ObjectID_AADP2
    }

    #Replace Conditional_Access_Exclusion
    $Policy.conditions.users.excludeGroups = $Policy.conditions.users.excludeGroups.Replace("<ExclusionGroup>",$ObjectID_Exclusion)

    #Replace Conditional_Access_Exclusion_SynchronizationServiceAccounts
    $Policy.conditions.users.excludeGroups = $Policy.conditions.users.excludeGroups.Replace("<SynchronizationServiceAccountsGroup>",$ObjectID_SynchronizationServiceAccounts)

    #Replace Conditional_Access_Exclusion_EmergencyAccessAccounts
    $Policy.conditions.users.excludeGroups = $Policy.conditions.users.excludeGroups.Replace("<EmergencyAccessAccountsGroup>",$ObjectID_EmergencyAccessAccounts)

    Write-Host "ExclusionGroup $ObjectID_Exclusion"
    Write-Host "SynchronizationServiceAccountsGroup $ObjectID_SynchronizationServiceAccounts"
    Write-Host "EmergencyAccessAccountsGroup $ObjectID_EmergencyAccessAccounts"

    Write-Host "Policy to be created"
    $Policy

    #Create policy
    New-GraphConditionalAccessPolicy -requestBody ($Policy | ConvertTo-Json -Depth 3) -accessToken $accessToken
    
    $Counter ++
}
#endregion

#region enable app enforced restrictions
<#
# Connect to EXO 
$Session = New-PSSession -ConfigurationName Microsoft.Exchange `
-ConnectionUri https://outlook.office365.com/powershell-liveid/ `
-Credential $cred -Authentication Basic -AllowRedirection 
# Gaaaa!! We are using basic auth for this.
 
# Configure Mailbox CA Policy and remove the session
Import-PSSession $Session -DisableNameChecking
Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -ConditionalAccessPolicy ReadOnly
Remove-PSSession $Session
 
# Connect to SPO and configure CA policy
Connect-SPOService -Url https://M365x436188-admin.sharepoint.com -Credential $cred
Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess
# Note, this will create two CA policies that are enabled for all users!
#>
#Write-Host "Enabling app enforced restrictions not yet implemented, please do it manually"
#endregion

#region create access review
#To be implemented
#Write-Host "Access review creation not yet implemented, please create your access review manually"
#endregion

#region post tasks
    #Fill exlusion groups SynchronizationServiceAccountsGroup and EmergencyAccessAccountsGroup
    #Create your trusted locations
    #enable combined registration preview
    #choose MFA registration story 1 Identity Protection MFA registration policy 2 AAD SSPR registration policy 3 Proactive enduser communication 4 Short term MFA enforcement without exceptions
    #monitor exclusion groups
#endregion