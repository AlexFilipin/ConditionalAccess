$AADCAPolicies = Get-GraphConditionalAccessPolicies -accessToken $accessToken

$AADCAPolicies.value.count
$AADCAPolicies.value[20]
$PoliciesToDelete = $AADCAPolicies.value[1..20]

foreach($Item in $PoliciesToDelete){
    Remove-GraphConditionalAccessPolicy -accessToken $accessToken -Id $Item.id
}