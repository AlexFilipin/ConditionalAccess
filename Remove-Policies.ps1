try{Disconnect-MgGraph -ErrorAction SilentlyContinue}catch{}
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Group.ReadWrite.All" -ErrorAction Stop

#Policy cleanup
$Policies = Get-MgIdentityConditionalAccessPolicy -All

$SelectedPolicies = $Policies | Out-GridView -PassThru
foreach($Item in $SelectedPolicies){
    Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $Item.Id
}

#Group cleanup
#$Groups = Get-MgGroup -Filter "startswith(DisplayName,'ZT')"
$Groups = Get-MgGroup -All
$SelectedGroups = $Groups | Out-GridView -PassThru
foreach($Item in $SelectedGroups){
    Remove-MgGroup -GroupId $Item.Id
}