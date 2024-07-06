$NameServer = Read-Host "Enter name of server (domain controller) on which to create new user"
$CredAdmin = Get-Credential
$NameFirst = Read-Host "Enter new user's first name (given name)"
$NameLast = Read-Host "Enter new user's last name (surname)"
$NameAccount = Read-Host "Enter new user's username (to be used by user to login)"
$PwdAccount = Read-Host -AsSecureString "Enter new user's password (to be used by user to login)"


$UserNew = @{
    SamAccountName = $NameAccount
    UserPrincipalName = "$NameAccount@gravita.com"
    GivenName = $NameFirst
    Surname = $NameLast
    Name = "$NameFirst $NameLast"
    EmailAddress = "$NameAccount@gravita.com"
    AccountPassword = $PwdAccount
    Enabled = $true
}

New-ADUser @UserNew -Credential $CredAdmin -Server $NameServer

# uncomment the following 3 lines to test
# $PwdPlain = ConvertFrom-SecureString -AsPlainText $PwdAccount
# Write-Host "Creating new user on $NameServer"
# Write-Host "Full user name is - $NameFirst $NameLast and email is $NameAccount@gravita.com and password is $PwdPlain"
