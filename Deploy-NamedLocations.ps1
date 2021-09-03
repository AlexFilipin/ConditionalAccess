#Note: This is just a sample based on https://goodworkaround.com/2019/11/09/populating-azure-ad-named-and-trusted-locations-using-graph/

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

    New-MgIdentityConditionalAccessNamedLocation -BodyParameter $Body
}