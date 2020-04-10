# Connect to EXO 
$Session = New-PSSession -ConfigurationName Microsoft.Exchange `
-ConnectionUri https://outlook.office365.com/powershell-liveid/ `
-Credential $cred -Authentication Basic -AllowRedirection 
# Gaaaa!! We are using basic auth for this.
 
# Configure Mailbox CA Policy and remove the session
Import-PSSession $Session -DisableNameChecking
Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -ConditionalAccessPolicy ReadOnly
Remove-PSSession $Session
 
# Connect to SPO and configure CA policy
Connect-SPOService -Url https://M365x436188-admin.sharepoint.com -Credential $cred
Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess
# Note, this will create two CA policies that are enabled for all users!
#>
#Write-Host "Enabling app enforced restrictions not yet implemented, please do it manually"