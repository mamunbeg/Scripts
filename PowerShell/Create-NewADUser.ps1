
$ErrorActionPreference= 'silentlycontinue'

$NameServer = Read-Host "Enter name of server (domain controller) on which to create new user"
Write-Host "Enter administrator credentials for this server"
$CredAdmin = Get-Credential

[string[]]$ListCompany = 'Gravita UK','Datamatics','DOT','Horizon','Scrubbed','SMC'
[string[]]$ListCompanyProp = 'Gravita','Offshore-Datamatics','Offshore-DOT','Offshore-Horizon','Offshore-Scrubbed','Offshore-SMC'

Write-Output "Choose the new user's company from below:"
1..$ListCompany.Length | foreach-object { Write-Output "$($_): $($ListCompany[$_-1])" }
[ValidateScript({$_ -ge 1 -and $_ -le $ListCompany.Length})]
[ValidateScript({$_ -ge 1 -and $_ -le $ListCompanyProp.Length})]
[int]$NumberCompany = Read-Host "Press the number to select a company"

if($?) {
    $NameCompany = $($ListCompanyProp[$NumberCompany-1])
    $NameFirst = Read-Host "Enter new user's first name (given name)"
    $NameLast = Read-Host "Enter new user's last name (surname)"
    $NameAccount = Read-Host "Enter new user's username (to be used by user to login)"
    $PwdAccount = Read-Host -AsSecureString "Enter new user's password (to be used by user to login)"

    # comment out the following lines when testing
    #<#
    $UserNew = @{
        SamAccountName = $NameAccount
        UserPrincipalName = "$NameAccount@gravita.com"
        GivenName = $NameFirst
        Surname = $NameLast
        Name = "$NameFirst $NameLast"
        Company = $NameCompany
        EmailAddress = "$NameAccount@gravita.com"
        AccountPassword = $PwdAccount
        Enabled = $true
    }

    New-ADUser @UserNew -Credential $CredAdmin -Server $NameServer
    Invoke-Command -ComputerName $NameServer -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -Credential $CredAdmin
    #>

    # uncomment the following lines to test
    <#
    $PwdPlain = ConvertFrom-SecureString -AsPlainText $PwdAccount
    Write-Host "Creating new user on $NameServer"
    Write-Host "Full user name is - $NameFirst $NameLast and email is $NameAccount@gravita.com and password is $PwdPlain"
    Write-Output "User will be based at $($ListCompany[$NumberCompany-1]) with property $NameCompany"
    #>
} else {
    Write-Output "You entered an invalid selection"
    Exit
}