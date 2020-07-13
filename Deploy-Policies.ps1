<#    
.SYNOPSIS
    Script for automatic creation and update of Conditoinal Access Policies based on JSON representations

.DESCRIPTION
    Connects to Microsoft Graph via device code flow
    Connects to Azure AD via AzureAD module, normal user login
    Creates AAD group for AADC synchronization service accounts
    Creates AAD group for AAD emergency access accounts
    Creates dynamic AAD group for AADP2 user
    Creates AAD group for administrative accounts that should be targeted in the M365 admin protection
    Creates AAD group for the RING if RingTargeted was set to TRUE
    Imports JSON representations of conditional access policies from a policy folder
    Creates two AAD group for each conditional access policy which will be used for exclusions
    Either creates a new conditional access policy for each JSON representation or updates an existing policy. Updating / matching existing policies requires the policy id in the JSON file.

.PARAMETER Prefix
    The prefix will be used as a prefix for all groups that are created if no explicit group name is provided

.PARAMETER Ring
    The ring will be used to replace the <RING> placeholder which is part of the displayName in the JSON representation
    Additionally, it is part of the exclusion group names
    Additionally, it is part of the ring group name if no explicit group name is provided

.PARAMETER RingTargeted
    If set to true policies target to "All users" will instead be targeted on a ring group

.PARAMETER RingGroup
    Name of the group for a 'RingTargeted' deployment
    If no value is provided: $Prefix + "_" + $Ring
    If a group with that name already exists, it will be used

.PARAMETER ClientId
    The Application (client) ID of the created app registration 

.PARAMETER TenantName
    The .onmicrosoft.com tenant name e.g. company.onmicrosoft.com

.PARAMETER PoliciesFolder
    Path of the folder where the templates are located e.g. C:\Repos\ConditionalAccess\Policies

.PARAMETER ExclusionGroupsPrefix
    Prefix of the exclusion groups that are created for each policy, if no value is specified, the prefix value is used
    If no value is provided: 
        $DisplayName_Temp_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Temp"
        $DisplayName_Perm_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Perm"

.PARAMETER AADP2Group
    Name of the dynamic group of users licensed with Azure AD Premium P2
    If no value is provided: $Prefix + "_AADP2", e.g. CA_AADP2
    If a group with that name already exists, it will be used

.PARAMETER SynchronizationServiceAccountsGroup
    Name of the group for the Azure AD Connect service accounts which are excluded from policies. (On-Premises Directory Synchronization Service Account)
    If no value is provided: $Prefix + "_Exclusion_SynchronizationServiceAccounts", e.g. CA_Exclusion_SynchronizationServiceAccounts
    If a group with that name already exists, it will be used

.PARAMETER EmergencyAccessAccountsGroup
    Name of the group for the emergency access accounts which are excluded from policies
    If no value is provided: $Prefix + "_Exclusion_EmergencyAccessAccounts", e.g. CA_Exclusion_EmergencyAccessAccounts
    If a group with that name already exists, it will be used

.PARAMETER AdministratorGroup
    Name of the group for administrative accounts that should be targeted in the M365 admin protection 
    If no value is provided: $Prefix + "_Administrator", e.g. CA_Administrator
    If a group with that name already exists, it will be used

.PARAMETER Endpoint
    Allows you to specify the Graph endpoint (Beta or Canary), if not specified it will default to Beta

.NOTES
    Version:        1.3
    Author:         Alexander Filipin
    Creation date:  2020-04-09
    Last modified:  2020-06-25

    Many thanks to the two Microsoft MVPs whose publications served as a basis for this script:
        Jan Vidar Elven's work https://github.com/JanVidarElven/MicrosoftGraph-ConditionalAccess
        Daniel Chronlund's work https://danielchronlund.com/2019/11/07/automatic-deployment-of-conditional-access-with-powershell-and-microsoft-graph/
  
.EXAMPLE 
    .\Deploy-Policies.ps1 -Prefix "CA" -ClientId "a4a0356b-69a5-4b85-9545-f64459010333" -TenantName "company.onmicrosoft.com" -PoliciesFolder "C:\Repos\ConditionalAccess\Policies" 

.EXAMPLE
    .\Deploy-Policies.ps1 -Prefix "CA" -ClientId "a4a0356b-69a5-4b85-9545-f64459010333" -TenantName "company.onmicrosoft.com" -PoliciesFolder "C:\Repos\ConditionalAccess\Policies" -ExclusionGroupsPrefix "CA_Exclusion_" -AADP2Group "AADP2" -SynchronizationServiceAccountsGroup "SyncAccounts" -EmergencyAccessAccountsGroup "BreakGlassAccounts"
#>
Param(
    [Parameter(Mandatory=$True)]
    [System.String]$Prefix
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$Ring
    ,
    [Parameter(Mandatory=$False)]
    [System.Boolean]$RingTargeted
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$RingGroup
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$ClientId
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$TenantName
    ,
    [Parameter(Mandatory=$True)]
    [System.String]$PoliciesFolder
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$ExclusionGroupsPrefix
    ,   
    [Parameter(Mandatory=$False)]
    [System.String]$AADP2Group
    ,    
    [Parameter(Mandatory=$False)]
    [System.String]$SynchronizationServiceAccountsGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$EmergencyAccessAccountsGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$AdministratorGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$Endpoint
)

#region development
<#
$DebugMode = $True
$Prefix = "CA"
$Ring = "TEST"
$RingTargeted = $False
$ClientId = "a4a0356b-69a5-4b85-9545-f64459010333"
$TenantName = "filipinlabs.onmicrosoft.com"
$PoliciesFolder = "C:\Users\filip\Downloads\tmp4"
#>
#endregion

#region parameters
if(-not $ExclusionGroupsPrefix){$ExclusionGroupsPrefix = $Prefix + "_Exclusion_"}
if(-not $AADP2Group){$AADP2Group = $Prefix + "_AADP2"}
if(-not $SynchronizationServiceAccountsGroup){$SynchronizationServiceAccountsGroup = $Prefix + "_Exclusion_SynchronizationServiceAccounts"}
if(-not $EmergencyAccessAccountsGroup){$EmergencyAccessAccountsGroup = $Prefix + "_Exclusion_EmergencyAccessAccounts"}
if(-not $RingTargeted){$RingTargeted = $False}
if(-not $RingGroup){$RingGroup = $Prefix + "_" + $Ring}
if(-not $AdministratorGroup){$AdministratorGroup = $Prefix + "_Administrator"}
if($Endpoint -eq "Beta"){
    $CAURI = "https://graph.microsoft.com/beta/identity/conditionalAccess/policies"
}elseif($Endpoint -eq "Canary"){
    $CAURI = "TBD"
}elseif($Endpoint -eq "V1"){
    $CAURI = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
}else{
    $CAURI = "https://graph.microsoft.com/beta/identity/conditionalAccess/policies"
}
#endregion

#region functions
function New-AFAzureADGroup($Name){
    $Group = Get-AzureADGroup -SearchString $Name
    if(-not $Group){
        Write-Host "Creating group:" $Name -ForegroundColor Green
        $Group = New-AzureADGroup -DisplayName $Name -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet" 
    }
    Write-Host "ObjectId for" $Name $Group.ObjectId -ForegroundColor Green
    return $Group.ObjectId
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
    $conditionalAccessURI = $CAURI
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
    $conditionalAccessURI = $CAURI + "/{$Id}"
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Delete -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"}
    $conditionalAccessPolicyResponse     
}

function Get-GraphConditionalAccessPolicy{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $accessToken,
        [Parameter(Mandatory = $false)]
        $All, 
        [Parameter(Mandatory = $false)]
        $DisplayName,
        [Parameter(Mandatory = $false)]
        $Id 
    )
    if($DisplayName){
        $conditionalAccessURI = $CAURI + "?`$filter=endswith(displayName, '$DisplayName')"
    }
    if($Id){
        $conditionalAccessURI = $CAURI + "/{$Id}"
    }
    if($All -eq $true){
        $conditionalAccessURI = $CAURI
    }
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Get -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"}
    $conditionalAccessPolicyResponse     
}

function Set-GraphConditionalAccessPolicy{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $requestBody,
        [Parameter(Mandatory = $true)]
        $accessToken,
        [Parameter(Mandatory = $false)]
        $Id
    )
    $conditionalAccessURI = $CAURI + "/{$Id}"
    $conditionalAccessPolicyResponse = Invoke-RestMethod -Method Patch -Uri $conditionalAccessURI -Headers @{"Authorization"="Bearer $accessToken"} -Body $requestBody -ContentType "application/json"
    $conditionalAccessPolicyResponse     
}
#endregion

#region connect
if(-not $DebugMode){
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
}
#endregion

#region create groups
Write-Host "Creating or receiving group:" $SynchronizationServiceAccountsGroup -ForegroundColor Green
$ObjectID_SynchronizationServiceAccounts = New-AFAzureADGroup -Name $SynchronizationServiceAccountsGroup

Write-Host "Creating or receiving group:" $EmergencyAccessAccountsGroup -ForegroundColor Green
$ObjectID_EmergencyAccessAccounts = New-AFAzureADGroup -Name $EmergencyAccessAccountsGroup

Write-Host "Creating or receiving group:" $AdministratorGroup -ForegroundColor Green
$ObjectID_AdministratorGroup = New-AFAzureADGroup -Name $AdministratorGroup

if($RingTargeted){
    Write-Host "Creating or receiving group:" $RingGroup -ForegroundColor Green
    $ObjectID_RingGroup = New-AFAzureADGroup -Name $RingGroup
}

#create dynamic group if not yet existing
Write-Host "Creating or receiving group:" $AADP2Group -ForegroundColor Green
$Group_AADP2 = Get-AzureADGroup -SearchString $AADP2Group
if(-not $Group_AADP2){
    Write-Host "Creating group:" $AADP2Group -ForegroundColor Green
    $MembershipRule = 'user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled")'
    $Group_AADP2 = New-AzureADMSGroup -DisplayName $AADP2Group -MailEnabled $False -MailNickName "NotSet" -SecurityEnabled $True -GroupTypes "DynamicMembership" -MembershipRule $MembershipRule -MembershipRuleProcessingState "On"
    
    Write-Host "ObjectId for" $AADP2Group $Group_AADP2.Id -ForegroundColor Green
    $ObjectID_AADP2 = $Group_AADP2.Id

}else{
    Write-Host "ObjectId for" $AADP2Group $Group_AADP2.ObjectId -ForegroundColor Green
    $ObjectID_AADP2 = $Group_AADP2.ObjectId
}
#endregion

#region import policy templates
Write-Host "Importing policy templates" -ForegroundColor Green
$Templates = Get-ChildItem -Path $PoliciesFolder
$Policies = foreach($Item in $Templates){
    $Policy = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    $Policy
}
#endregion

#region create or update policies
foreach($Policy in $Policies){
    Write-Host "Working on policy:" $Policy.displayName -ForegroundColor Green
    $PolicyNumber = $Policy.displayName.Substring(0, 3)

    #Create temp exlusion group
    Write-Host "Creating or receiving temp exclusion group" -ForegroundColor Green
    $DisplayName_Temp_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Temp"
    $ObjectID_Temp_Exclusion = New-AFAzureADGroup -Name $DisplayName_Temp_Exclusion

    #Create perm exlusion group
    Write-Host "Creating or receiving perm exclusion group" -ForegroundColor Green
    $DisplayName_Perm_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Perm"
    $ObjectID_Perm_Exclusion = New-AFAzureADGroup -Name $DisplayName_Perm_Exclusion

    #REPLACEMENTS
    Write-Host "Working on replacements" -ForegroundColor Green
    #Add prefix to DisplayName
    $Policy.displayName = $Policy.displayName.Replace("<RING>",$Ring)

    if($RingTargeted){
        #Adjust scope to ring group
        if($Policy.conditions.users.includeUsers.Contains("All")){

            #Remove all user scope
            [System.Collections.ArrayList]$includeUsers = $Policy.conditions.users.includeUsers
            $includeUsers.Remove("All")
            $Policy.conditions.users.includeUsers = $includeUsers

            #Add ring group
            [System.Collections.ArrayList]$includeGroups = $Policy.conditions.users.includeGroups
            $includeGroups.Add($ObjectID_RingGroup)
            $Policy.conditions.users.includeGroups = $includeGroups

        }
    }

    if($Policy.conditions.users.includeGroups){
        [System.Collections.ArrayList]$includeGroups = $Policy.conditions.users.includeGroups

        #Replace Conditional_Access_AADP2
        if($includeGroups.Contains("<AADP2Group>")){
            $includeGroups.Add($ObjectID_AADP2)
            $includeGroups.Remove("<AADP2Group>")
        }

        #Replace AdministratorGroup
        if($includeGroups.Contains("<AdministratorGroup>")){
            $includeGroups.Add($ObjectID_AdministratorGroup)
            $includeGroups.Remove("<AdministratorGroup>")
        }

        $Policy.conditions.users.includeGroups = $includeGroups
    }

    if($Policy.conditions.users.excludeGroups){
        [System.Collections.ArrayList]$excludeGroups = $Policy.conditions.users.excludeGroups

        #Replace Conditional_Access_Temp_Exclusion
        if($excludeGroups.Contains("<ExclusionTempGroup>")){
            $excludeGroups.Add($ObjectID_Temp_Exclusion)
            $excludeGroups.Remove("<ExclusionTempGroup>")
        }
        #Replace Conditional_Access_Perm_Exclusion
        if($excludeGroups.Contains("<ExclusionPermGroup>")){
            $excludeGroups.Add($ObjectID_Perm_Exclusion)
            $excludeGroups.Remove("<ExclusionPermGroup>")
        }
        #Replace Conditional_Access_Exclusion_SynchronizationServiceAccounts
        if($excludeGroups.Contains("<SynchronizationServiceAccountsGroup>")){
            $excludeGroups.Add($ObjectID_SynchronizationServiceAccounts)
            $excludeGroups.Remove("<SynchronizationServiceAccountsGroup>")
        }
        #Replace Conditional_Access_Exclusion_EmergencyAccessAccounts
        if($excludeGroups.Contains("<EmergencyAccessAccountsGroup>")){
            $excludeGroups.Add($ObjectID_EmergencyAccessAccounts)
            $excludeGroups.Remove("<EmergencyAccessAccountsGroup>")
        }

        $Policy.conditions.users.excludeGroups = $excludeGroups
    }

    #Create or update

    $requestBody = $Policy | ConvertTo-Json -Depth 3

    if($Policy.id){
        Write-Host "Template includes policy id - trying to update existing policy" $Policy.id -ForegroundColor Green  
        $Result = Get-GraphConditionalAccessPolicy -Id $Policy.id -accessToken $accessToken -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        if($Result){
            Write-Host "Updating existing policy" $Policy.id -ForegroundColor Yellow 
            Set-GraphConditionalAccessPolicy -requestBody $requestBody -accessToken $accessToken -Id $Policy.id
        }else{
            Write-Host "No existing policy found - abort cannot update" -ForegroundColor Red
        }
    }else{
        Write-Host "Template does not include policy id - creating new policy" -ForegroundColor Green
        New-GraphConditionalAccessPolicy -requestBody $requestBody -accessToken $accessToken        
    }

    Start-Sleep -Seconds 3
}
#endregion