<#    
.SYNOPSIS
    Script for storing existing Conditional Access Policies in specified folder based on JSON representations

.DESCRIPTION
    Connects to Microsoft Graph

    Imports policies from Azure AD
    Replaces object ID in policies with their display names
    Exports JSON representations of conditional access policies to a specified folder

.PARAMETER PoliciesFolder
    Path of the folder where the templates are located e.g. C:\Repos\ConditionalAccess\Policies

.PARAMETER Endpoint
    Allows you to specify the Graph endpoint (Beta or Canary), if not specified it will default to Beta

.PARAMETER TenantId
    If you use a guest account for signing in you may specify tenant ID to establish session with proper Azure AD tenant

.NOTES
    Version:        0.1
    Author:         Szymon Baranek
    Creation date:  2023-04-11
    Last modified:  2023-04-26

    The script is based on the logic from Deploy-Policies.ps1 script developed by Alexander Filipin. 
  
.EXAMPLE 
    .\Save-Policies.ps1 -PoliciesFolder "C:\Repos\ConditionalAccess\PolicySets\Implemented policies" 

.EXAMPLE
#>
Param(
    [Parameter(Mandatory = $True)]
    [System.String]$PoliciesFolder
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$Endpoint
    ,
    [Parameter(Mandatory = $False)]
    [System.String]$TenantId
)
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement

#region connect
Import-Module -Name Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module -Name Microsoft.Graph.Groups -ErrorAction Stop
Import-Module -Name Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Import-Module -Name Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop

if ($Endpoint -eq "Beta") {
    Select-MgProfile -Name "beta"
}
elseif ($Endpoint -eq "V1") {
    Select-MgProfile -Name "v1.0"
}
else {
    Select-MgProfile -Name "beta"
}
try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}

$mgScopes = @("Application.Read.All", "Group.ReadWrite.All", "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "Directory.Read.All", "RoleManagement.Read.All")

if ($TenantId) {
    Connect-MgGraph -Scopes $mgScopes -TenantId $TenantId -ErrorAction Stop
}
else {
    Connect-MgGraph -Scopes $mgScopes -ErrorAction Stop
}
#endregion

#region retrive policies and resolve object IDs for display names
$Policies = Get-MgIdentityConditionalAccessPolicy -All
$SelectedPolicies = $Policies | Out-GridView -PassThru

foreach ($Policy in $SelectedPolicies) {
    Write-Host "Working on policy: $($Policy.displayName)"

    if ($Policy.conditions.users.includeGroups) {
        [System.Collections.ArrayList]$groupIds = $Policy.conditions.users.includeGroups
        $groupNames = New-Object -TypeName System.Collections.ArrayList
        foreach ($groupId in $groupIds) {
            $groupName = (get-mggroup -GroupId $groupId).DisplayName
            $groupNames.Add($groupName) > $null
        }

        $Policy.conditions.users.includeGroups = $groupNames
    }

    if ($Policy.conditions.users.excludeGroups) {
        [System.Collections.ArrayList]$groupIds = $Policy.conditions.users.excludeGroups
        $groupNames = New-Object -TypeName System.Collections.ArrayList
        foreach ($groupId in $groupIds) {
            $groupName = (get-mggroup -GroupId $groupId).DisplayName
            $groupNames.Add($groupName) > $null
        }

        $Policy.conditions.users.excludeGroups = $groupNames
    }

    if ($Policy.conditions.users.IncludeRoles) {
        $roles = Get-MgDirectoryRoleTemplate -All
        [System.Collections.ArrayList]$roleIds = $Policy.conditions.users.IncludeRoles
        $roleNames = New-Object -TypeName System.Collections.ArrayList
        foreach ($roleId in $roleIds) {
            $roleName = ($roles | where-object { $_.Id -eq $roleId }).DisplayName
            $roleNames.Add($roleName) > $null
        }

        $Policy.conditions.users.IncludeRoles = $roleNames
    }

    # Save policy files

    $requestBody = $Policy | ConvertTo-Json -Depth 3
    $policyFilename = $Policy.displayName.Replace(":", "") + ".json"
    $policyFilePath = $PoliciesFolder + $policyFilename
    Out-File -InputObject $requestBody -FilePath $policyFilePath -Force:$true -Confirm:$false -Encoding utf8
}
#endregion

#region disconnect
try {Disconnect-MgGraph -ErrorAction SilentlyContinue} catch {}
#endregion
