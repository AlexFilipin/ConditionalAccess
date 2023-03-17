<#    
.SYNOPSIS
    Script for automatic creation and update of Named Locations for Conditional Access

.DESCRIPTION
    Connects to Microsoft Graph

    Creates Named Location for Conditional Access

.PARAMETER NamedLocationsFolder
    Path of the folder where the csv with the NamedLocations are located e.g. C:\Repos\ConditionalAccess\NamedLocations

.NOTES
    Version:        2.2
    Author:         Alexander Filipin
    Creation date:  2020-04-09
    Last modified:  2023-03-15

    Many thanks to the two Microsoft MVPs whose publications served as a basis for this script:
        Jan Vidar Elven's work https://github.com/JanVidarElven/MicrosoftGraph-ConditionalAccess
        Daniel Chronlund's work https://danielchronlund.com/2019/11/07/automatic-deployment-of-conditional-access-with-powershell-and-microsoft-graph/
    
    This is just a sample based on https://goodworkaround.com/2019/11/09/populating-azure-ad-named-and-trusted-locations-using-graph/

.EXAMPLE 
    .\Deploy-Policies.ps1 -Prefix "CA" -NamedLocationsFolder "C:\Repos\ConditionalAccess\NamedLocations"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)]
    [string]
    $NamedLocationsFolder
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

#region connect
Import-Module -Name Microsoft.Graph.Authentication
Import-Module -Name Microsoft.Graph.Identity.SignIns

if ($Endpoint -eq "Beta") {
    Select-MgProfile -Name "beta"
}
elseif ($Endpoint -eq "V1") {
    Select-MgProfile -Name "v1.0"
}
else {
    Select-MgProfile -Name "beta"
}
try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess" -ErrorAction Stop
#endregion

$Locations = Import-Csv -Path $NamedLocationsFolder -Delimiter ";"

foreach($Location in $Locations){

    #Create body
    $Body = @{
        "@odata.type" = "#microsoft.graph.ipNamedLocation"
        displayName = $Location.Name
        isTrusted = $true

        ipRanges = @($Location.cidrAddress.Foreach{
            if($PSItem -like "*.*") {
                @{
                    "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                    cidrAddress = $PSItem
                }
            } else {
                @{
                    "@odata.type" = "#microsoft.graph.iPv6CidrRange"
                    cidrAddress = $PSItem
                }
            }
        })

    } | ConvertTo-Json -Depth 4

    New-MgIdentityConditionalAccessNamedLocation -BodyParameter $Body
}

#region disconnect
try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
#endregion