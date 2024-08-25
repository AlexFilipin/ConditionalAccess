<#    
.SYNOPSIS
    Script for automatic creation and update of Conditional Access Policies based on JSON representations

.DESCRIPTION
    Connects to Microsoft Graph

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
    Version:        2.1
    Author:         Alexander Filipin
    Creation date:  2020-04-09
    Last modified:  2021-09-05

    Many thanks to the two Microsoft MVPs whose publications served as a basis for this script:
        Jan Vidar Elven's work https://github.com/JanVidarElven/MicrosoftGraph-ConditionalAccess
        Daniel Chronlund's work https://danielchronlund.com/2019/11/07/automatic-deployment-of-conditional-access-with-powershell-and-microsoft-graph/
  
.EXAMPLE 
    .\Deploy-Policies.ps1 -Prefix "CA" -PoliciesFolder "C:\Repos\ConditionalAccess\Policies" 

.EXAMPLE
    .\Deploy-Policies.ps1 -Prefix "CA" -PoliciesFolder "C:\Repos\ConditionalAccess\Policies" -ExclusionGroupsPrefix "CA_Exclusion_" -AADP2Group "AADP2" -SynchronizationServiceAccountsGroup "SyncAccounts" -EmergencyAccessAccountsGroup "BreakGlassAccounts"
#>
Param(
    [Parameter(Mandatory = $True)]
    [System.String]$Prefix
    ,
    [Parameter(Mandatory = $True)]
    [System.String]$Ring
    ,
    [Parameter(Mandatory = $False)]
    [System.Boolean]$RingTargeted
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$RingGroup
    ,
    [Parameter(Mandatory = $True)]
    [System.String]$PoliciesFolder
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$ExclusionGroupsPrefix
    ,   
    [Parameter(Mandatory = $False)]
    [System.String]$AADP2Group
    ,    
    [Parameter(Mandatory = $False)]
    [System.String]$SynchronizationServiceAccountsGroup
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$EmergencyAccessAccountsGroup
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$AdministratorGroup
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$Endpoint
)
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Beta.Identity.SignIns, Microsoft.Graph.Beta.Groups, Microsoft.Graph.Beta.Identity.Governance

#region connect
Import-Module -Name Microsoft.Graph.Authentication
Import-Module -Name Microsoft.Graph.Beta.Groups
Import-Module -Name Microsoft.Graph.Beta.Identity.SignIns
Import-Module -Name Microsoft.Graph.Beta.Identity.Governance

try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
Connect-MgGraph -Scopes "AdministrativeUnit.ReadWrite.All", "Agreement.Read.All", "Application.Read.All", "Group.ReadWrite.All", "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "RoleManagement.ReadWrite.Directory" -ErrorAction Stop
#endregion

#region parameters
if (-not $ExclusionGroupsPrefix) { $ExclusionGroupsPrefix = $Prefix + "_Exclusion_" }
if (-not $AADP2Group) { $AADP2Group = $Prefix + "_AADP2" }
if (-not $SynchronizationServiceAccountsGroup) { $SynchronizationServiceAccountsGroup = $Prefix + "_Exclusion_SynchronizationServiceAccounts" }
if (-not $RestrictedManagementAdministrativUnit) { $RestrictedManagementAdministrativUnit = $Prefix + "_RestrictedManagementAdministrativUnit" }
if (-not $EmergencyAccessAccountsGroup) { $EmergencyAccessAccountsGroup = $Prefix + "_Exclusion_EmergencyAccessAccounts" }
if (-not $RingTargeted) { $RingTargeted = $False }
if (-not $RingGroup) { $RingGroup = $Prefix + "_" + $Ring }
if (-not $AdministratorGroup) { $AdministratorGroup = $Prefix + "_Administrator" }
#endregion

#region functions

#region function to generate or receive Entra ID Group
function New-AFAzureADGroup {
    [CmdletBinding()]
    param (
        $Name,
        $RoleAssignable = $false
    )
    $Group = Get-MgBetaGroup -Filter "DisplayName eq '$Name'"
    if (-not $Group) {
        Write-Host "Creating group: $Name"
        $Group = New-MgBetaGroup -DisplayName $Name -SecurityEnabled:$True -MailEnabled:$false -MailNickname "NotSet" -Visibility Private -IsAssignableToRole:$RoleAssignable
    }
    Write-Host "ObjectId for $Name $($Group.Id)" 
    return $Group.Id
}

#region function for generate or receive Restricted Management Administrativ Unit
function New-AFRMAU($Name) {
    # Generate or receive Restricted Management Administrativ Unit
    $RMAU = Get-MgBetaAdministrativeUnit -Filter "DisplayName eq '$Name'"
    if (-not $RMAU) {
        Write-Host "Creating RMAU: $Name"
        $RMAU = New-MgBetaAdministrativeUnit -DisplayName $Name -Description "RMAU for Conditional Access Policies" -IsMemberManagementRestricted:$True
    }
    Write-Host "ObjectId for $Name $($RMAU.Id)" 
    return $RMAU.Id
}
#endregion 

#region Add Member to RMAU
function Add-AFMembertoRMAU {
    [CmdletBinding()]
    param (
        $RMAUID,
        $GroupID
    )
    Write-Host "Check if group $GroupID is already member of RMAU $RMAUID"
    $RMAUMemberAssign = Get-MgBetaAdministrativeUnitMember -AdministrativeUnitId $RMAUID -Filter "id eq '$GroupID'" -ErrorAction SilentlyContinue

    if (-not $RMAUMemberAssign) {
        Write-Host "Adding group $GroupID to RMAU $RMAUID"
        $params = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/groups/{$GroupID}" 
        }
        New-MGBetaAdministrativeUnitMemberbyRef -AdministrativeUnitId $OBjectID_RMAU -BodyParameter $params
    }
}
#endregion

#region function for Add New Admin Assignment for RMAU
function Add-AFAdminAssignmenttoRMAU {
    [CmdletBinding()]
    param (
        $RMAUID,
        $RoleAssignmentID = 'db004403-d48a-49c3-a098-088c45470d56',
        $AdminID
    )
    
    Write-Host "Check if Admin $AdminID is already member of RMAU $RMAUID"
    $RMAUAdminAssign = Get-MgBetaAdministrativeUnitScopedRoleMember -AdministrativeUnitId $RMAUID | select -ExpandProperty RoleMemberInfo | where { $_.Id -eq $AdminID } -ErrorAction SilentlyContinue

    if (-not $RMAUAdminAssign) {
        $params = @{
            roleId         = $RoleAssignmentID
            roleMemberInfo = @{
                id = $AdminID
            }
        }
        Write-Host "Adding Admin $AdminID to RMAU $RMAUID"
        New-MgBetaAdministrativeUnitScopedRoleMember -AdministrativeUnitId $RMAUID -BodyParameter $params | Out-Null
    }
}
#endregion

#region create restricted Management Administrativ Unit
# RMAU create or receive
Write-Host " Create or receive restricted Management Administrativ Unit $RMAU"
$OBjectID_RMAU = New-AFRMAU -Name $RestrictedManagementAdministrativUnit
#endregion

#region create groups
Write-Host "Creating or receiving group: $AdministratorGroup" 
$ObjectID_AdministratorGroup = New-AFAzureADGroup -Name $AdministratorGroup -RoleAssignable $True
#Add CA Admin to RMAU Group Admin
Add-AFAdminAssignmenttoRMAU -RMAUID $OBjectID_RMAU -AdminID $ObjectID_AdministratorGroup

Write-Host "Creating or receiving group: $SynchronizationServiceAccountsGroup" 
$ObjectID_SynchronizationServiceAccounts = New-AFAzureADGroup -Name $SynchronizationServiceAccountsGroup
Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $ObjectID_SynchronizationServiceAccounts

Write-Host "Creating or receiving group: $EmergencyAccessAccountsGroup" 
$ObjectID_EmergencyAccessAccounts = New-AFAzureADGroup -Name $EmergencyAccessAccountsGroup
Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $ObjectID_EmergencyAccessAccounts

if ($RingTargeted) {
    Write-Host "Creating or receiving group: $RingGroup" 
    $ObjectID_RingGroup = New-AFAzureADGroup -Name $RingGroup
    Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $ObjectID_RingGroup

}

#create dynamic group if not yet existing
Write-Host "Creating or receiving group: $AADP2Group" 
$Group_AADP2 = Get-MgBetaGroup -Filter "DisplayName eq '$AADP2Group'"
if (-not $Group_AADP2) {
    Write-Host "Creating group: $AADP2Group"
    $MembershipRule = 'user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled")'
    $Group_AADP2 = New-MgBetaGroup -DisplayName $AADP2Group -MailEnabled:$False -MailNickname "NotSet" -SecurityEnabled:$True -GroupTypes "DynamicMembership" -MembershipRule $MembershipRule -MembershipRuleProcessingState "On" #TODO:  Remove Param SecuityEnabled
    Write-Host "ObjectId for $AADP2Group $($Group_AADP2.Id)" 
    #Add to RMAU 
    Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $($Group_AADP2.Id)
    $ObjectID_AADP2 = $Group_AADP2.Id
    }
else {
    Write-Host "ObjectId for $AADP2Group $($Group_AADP2.Id)" 
    $ObjectID_AADP2 = $Group_AADP2.Id
}
#endregion

#region import policy templates
Write-Host "Importing policy templates"
$Templates = Get-ChildItem -Path $PoliciesFolder
$Policies = foreach ($Item in $Templates) {
    $Policy = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    $Policy
}
#endregion

#region create or update policies
foreach ($Policy in $Policies) {
    Write-Host "Working on policy: $($Policy.displayName)" 
    $PolicyNumber = $Policy.displayName.Substring(0, 3)

    #Create temp exlusion group
    Write-Host "Creating or receiving temp exclusion group"
    $DisplayName_Temp_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Temp"
    $ObjectID_Temp_Exclusion = New-AFAzureADGroup -Name $DisplayName_Temp_Exclusion
    Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $ObjectID_Temp_Exclusion


    #Create perm exlusion group
    Write-Host "Creating or receiving perm exclusion group" 
    $DisplayName_Perm_Exclusion = $ExclusionGroupsPrefix + $PolicyNumber + "_" + $Ring + "_Perm"
    $ObjectID_Perm_Exclusion = New-AFAzureADGroup -Name $DisplayName_Perm_Exclusion
    Add-AFMembertoRMAU -RMAUID $OBjectID_RMAU -GroupID $ObjectID_Perm_Exclusion

    #REPLACEMENTS
    Write-Host "Working on replacements"
    #Add prefix to DisplayName
    $Policy.displayName = $Policy.displayName.Replace("<RING>", $Ring)

    if ($RingTargeted) {
        #Adjust scope to ring group
        if ($Policy.conditions.users.includeUsers.Contains("All")) {

            #Remove all user scope
            [System.Collections.ArrayList]$includeUsers = $Policy.conditions.users.includeUsers
            $includeUsers.Remove("All") > $null
            $Policy.conditions.users.includeUsers = $includeUsers

            #Add ring group
            [System.Collections.ArrayList]$includeGroups = $Policy.conditions.users.includeGroups
            $includeGroups.Add($ObjectID_RingGroup) > $null
            $Policy.conditions.users.includeGroups = $includeGroups

        }
    }

    if ($Policy.conditions.users.includeGroups) {
        [System.Collections.ArrayList]$includeGroups = $Policy.conditions.users.includeGroups

        #Replace Conditional_Access_AADP2
        if ($includeGroups.Contains("<AADP2Group>")) {
            $includeGroups.Add($ObjectID_AADP2) > $null
            $includeGroups.Remove("<AADP2Group>") > $null
        }

        #Replace AdministratorGroup
        if ($includeGroups.Contains("<AdministratorGroup>")) {
            $includeGroups.Add($ObjectID_AdministratorGroup) > $null
            $includeGroups.Remove("<AdministratorGroup>") > $null
        }

        $Policy.conditions.users.includeGroups = $includeGroups
    }

    if ($Policy.conditions.users.excludeGroups) {
        [System.Collections.ArrayList]$excludeGroups = $Policy.conditions.users.excludeGroups

        #Replace Conditional_Access_Temp_Exclusion
        if ($excludeGroups.Contains("<ExclusionTempGroup>")) {
            $excludeGroups.Add($ObjectID_Temp_Exclusion) > $null
            $excludeGroups.Remove("<ExclusionTempGroup>") > $null
        }
        #Replace Conditional_Access_Perm_Exclusion
        if ($excludeGroups.Contains("<ExclusionPermGroup>")) {
            $excludeGroups.Add($ObjectID_Perm_Exclusion) > $null
            $excludeGroups.Remove("<ExclusionPermGroup>") > $null
        }
        #Replace Conditional_Access_Exclusion_SynchronizationServiceAccounts
        if ($excludeGroups.Contains("<SynchronizationServiceAccountsGroup>")) {
            $excludeGroups.Add($ObjectID_SynchronizationServiceAccounts) > $null
            $excludeGroups.Remove("<SynchronizationServiceAccountsGroup>") > $null
        }
        #Replace Conditional_Access_Exclusion_EmergencyAccessAccounts
        if ($excludeGroups.Contains("<EmergencyAccessAccountsGroup>")) {
            $excludeGroups.Add($ObjectID_EmergencyAccessAccounts) > $null
            $excludeGroups.Remove("<EmergencyAccessAccountsGroup>") > $null
        }

        $Policy.conditions.users.excludeGroups = $excludeGroups
    }

    # Authentication Strengh
    
    [System.Collections.ArrayList]$AuthStrengh = $Policy.GrantControls.authenticationStrength

    $AuthMethod = Get-MgBetaPolicyAuthenticationStrengthPolicy -AuthenticationStrengthPolicyId 00000000-0000-0000-0000-000000000004

    if ($AuthStrengh -ne $null) {
        if ($AuthStrengh.Contains("Phising-resistent Auth")) {
            $AuthStrengh.Add("$($AuthMethod.Id)") > $null
            $AuthStrengh.Remove("Phising-resistent Auth") > $null


            $Policy.GrantControls.authenticationStrength = $AuthStrengh
        }
    }


    #TermsofUse

    [System.Collections.ArrayList]$TermsofUse = $Policy.GrantControls.termsOfUse

    $ToU = Get-MgBetaIdentityGovernanceTermsOfUseAgreement -Top 1
    if ($TermsofUse -ne $null) {
        if ($TermsofUse.Contains("ToU")) {
            $TermsofUse.Add("$($ToU.Id)") > $null
            $TermsofUse.Remove("ToU") > $null

            $Policy.GrantControls.TermsofUse = $TermsofUse
        }
    }

    #Create or update

    $requestBody = $Policy | ConvertTo-Json -Depth 4

    if ($Policy.id) {
        Write-Host "Template includes policy id - trying to update existing policy $($Policy.id)" -ForegroundColor Magenta
        $Result = Get-MgBetaIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $Policy.id -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        if ($Result) {
            Write-Host "Updating existing policy $($Policy.id)" -ForegroundColor Green
            Update-MgBetaIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $Policy.id -BodyParameter $requestBody
        }
        else {
            Write-Host "No existing policy found - abort cannot update" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Template does not include policy id - creating new policy" -ForegroundColor Green
        New-MgBetaIdentityConditionalAccessPolicy -BodyParameter $requestBody
    }

    Start-Sleep -Seconds 2

}
#endregion

#region disconnect
try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
#endregion
