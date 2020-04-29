function Get-GraphNamedLocation{
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
        $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations?`$filter=DisplayName eq '$DisplayName'"
    }
    if($Id){
        $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations/{$Id}"
    }
    if($All -eq $true){
        $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations"
    }
    $Response = Invoke-RestMethod -Method Get -Uri $URI -Headers @{"Authorization"="Bearer $accessToken"}
    $Response  
}

function New-GraphNamedLocation{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $requestBody,
        [Parameter(Mandatory = $true)]
        $accessToken 
    )
    $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations"
    $Response = Invoke-RestMethod -Method Post -Uri $URI -Headers @{"Authorization"="Bearer $accessToken"} -Body $requestBody -ContentType "application/json"
    $Response     
}

function Set-GraphNamedLocation{
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
    $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations/{$Id}"
    $Response = Invoke-RestMethod -Method Patch -Uri $URI -Headers @{"Authorization"="Bearer $accessToken"} -Body $requestBody -ContentType "application/json"
    $Response     
}

function Remove-GraphNamedLocation{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $Id,
        [Parameter(Mandatory = $true)]
        $accessToken 
    )
    $URI = "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations/{$Id}"
    $Response = Invoke-RestMethod -Method Delete -Uri $URI -Headers @{"Authorization"="Bearer $accessToken"}
    $Response     
}

$Locations = Import-Csv -Path "C:\Users\filip\Downloads\NamedLocations.csv" -Delimiter ";"

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

    #Create or patch
    if($NamedLocation.value.Count -eq 1){
        Write-Host "Found existing named location - patching" $Location.Name -ForegroundColor Green  
        Set-GraphNamedLocation -accessToken $accessToken -Id $NamedLocation.value.id -requestBody $Body
    }elseif($NamedLocation.value.Count -gt 1) {
        Write-Host "Found multiple existing named locations with the same name - aborting" $Location.Name -ForegroundColor Red 
    }else {
        Write-Host "Found no existing named location - creating new one" $Location.Name -ForegroundColor Green
        New-GraphNamedLocation -accessToken $accessToken -requestBody $Body 
    }

}


<#

SAMPLE FROM https://goodworkaround.com/2019/11/09/populating-azure-ad-named-and-trusted-locations-using-graph/

$url = Read-Host "Paste Graph Explorer url"
$excelFile = "~\Desktop\LocIP.xlsx"
 
# Extract access token and create header
$accessToken = ($url -split "access_token=" | select -Index 1) -split "&amp;amp;" | select -first 1
$headers = @{"Authorization" = "Bearer $accessToken"}
 
# Get existing named locations
$_namedLocationsAzureAD = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/conditionalAccess/namedLocations" -Headers $headers
$namedLocationsAzureAD = $_namedLocationsAzureAD.value | foreach{[PSCustomObject]@{id = $_.id; displayName=$_.displayName; isTrusted = $_.isTrusted; ipRanges = @($_.ipranges.cidraddress)}}
 
# Get locations form excel
$namedLocationsExcel = @{}
Import-Excel -Path $excelFile | ? Location | Foreach {
    $IP = $_.IP 
    if($IP -notlike "*/*" -and $IP -like "*.*") {
        Write-Verbose "Changed $IP to $IP/32" -Verbose
        $IP = $IP + "/32"
    } elseif($IP -notlike "*/*" -and $IP -like "*:*") {
        Write-Verbose "Changed $IP to $IP/128" -Verbose
        $IP = $IP + "/128"
    }
 
    $namedLocationsExcel[$_.Location] += @($IP)
}
 
# Work in each named location in Excel
$namedLocationsExcel.Keys | Foreach {
    Write-Verbose -Message "Working on location $($_) from Excel" -Verbose
 
    $Body = @{
        "@odata.type" = "#microsoft.graph.ipNamedLocation"
        displayName = $_
        isTrusted = $true
        ipRanges = @($namedLocationsExcel[$_] | Foreach {
            if($_ -like "*.*") {
                @{
                    "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                    cidrAddress = $_
                }
            } else {
                @{
                    "@odata.type" = "#microsoft.graph.iPv6CidrRange"
                    cidrAddress = $_
                }
            }
        })
    } | ConvertTo-Json -Depth 4
 
    # $Body
 
    $existingLocation = $namedLocationsAzureAD | ? displayName -eq $_
    if($existingLocation) {
        $key = $_
        if(($existingLocation.ipRanges | where{$_ -notin $namedLocationsExcel[$key]}) -or ($namedLocationsExcel[$key] | where{$_ -notin $existingLocation.ipRanges})) {
            Write-Verbose "Location $($_) has wrong subnets -&amp;gt; updating" -Verbose
            Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/conditionalAccess/namedLocations/$($existingLocation.id)" -Headers $headers -Method Patch -Body $Body -ContentType "application/json" | Out-Null
        }
         
    } else {
        Write-Verbose "Location $($_) does not exist -&amp;gt; creating" -Verbose
        Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/conditionalAccess/namedLocations" -Headers $headers -Method Post -Body $Body -ContentType "application/json" | Out-Null
    }
}

#>