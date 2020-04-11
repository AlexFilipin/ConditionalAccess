#Policy cleanup
$Policies = Get-GraphConditionalAccessPolicy -accessToken $accessToken -All $true
$SelectedPolicies = $Policies.value | Out-GridView -PassThru
foreach($Item in $SelectedPolicies){
    Remove-GraphConditionalAccessPolicy -accessToken $accessToken -Id $Item.id
    Start-Sleep -Seconds 1
}

#Group cleanup
$Groups = Get-AzureADGroup -Filter "startswith(DisplayName,'CA')"
$SelectedGroups = $Groups | Out-GridView -PassThru
foreach($Item in $SelectedGroups){
    Remove-AzureADGroup -ObjectId $Item.ObjectId
}