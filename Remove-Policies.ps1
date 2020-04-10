#Policy cleanup
$Policies = Get-GraphConditionalAccessPolicy -accessToken $accessToken -All $true
$SelectedPolicies = $Policies.value | Out-GridView -PassThru
foreach($Item in $SelectedPolicies){
    Remove-GraphConditionalAccessPolicy -accessToken $accessToken -Id $Item.id
}

#Group cleanup
$Groups = Get-AzureADGroup -Filter "startswith(DisplayName,'Conditional_Access')"
$SelectedGroups = $Groups | Out-GridView -PassThru
foreach($Item in $SelectedGroups){
    Remove-AzureADGroup -ObjectId $Item.ObjectId
}