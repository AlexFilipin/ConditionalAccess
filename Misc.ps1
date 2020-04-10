# Connect to EXO 
$Session = New-PSSession -ConfigurationName Microsoft.Exchange `
-ConnectionUri https://outlook.office365.com/powershell-liveid/ `
-Credential $cred -Authentication Basic -AllowRedirection

# Configure Mailbox CA Policy and remove the session
Import-PSSession $Session -DisableNameChecking
Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -ConditionalAccessPolicy ReadOnly
Remove-PSSession $Session

# Connect to SPO and configure CA policy
Connect-SPOService -Url https://tenant.sharepoint.com -Credential $cred
Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess