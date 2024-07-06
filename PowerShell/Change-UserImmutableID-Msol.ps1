# PowerShell modules required for this script
Write-Host "This script requires " -NoNewline
Write-Host "MSOnline" -ForegroundColor Blue -NoNewline
Write-Host " and " -NoNewline
Write-Host "ActiveDirectory" -ForegroundColor Blue -NoNewline
Write-Host " PowerShell modules installed. If not installed Ctrl-C to cancel."

# Azure (M365) admininstrator account credentials used to manage the tenant
Write-Host "`n Enter M365 administrator credentials: `n"
# MSOnline module to connect to Azure tenant
Connect-MsolService

# Old domain controller name that account will be moved from
$NameServer1 = Read-Host "Enter name of current domain controller FROM which user account will be moved"
Write-Host "`n Enter $NameServer1 administrator credentials:"
# Old domain controller credentials that account will be moved from
$CredAdmin1 = Get-Credential
Write-Host "`n Please wait, retrieving domain details... `n"
# Old domain
$NameDomain1 = ((Get-ADDomain -Credential $CredAdmin1 -Server $NameServer1).Forest)

# New domain controller name that account will be moved from
$NameServer2 = Read-Host "Enter name of new domain controller TO which user account will be moved"
Write-Host "`n Enter $NameServer2 administrator credentials:"
# New domain controller credentials that account will be moved from
$CredAdmin2 = Get-Credential
Write-Host "`n Please wait, retrieving domain details... `n"
# New domain
$NameDomain2 = ((Get-ADDomain -Credential $CredAdmin2 -Server $NameServer2).Forest)

# Username of account to be moved
$userUPN = Read-Host "Enter user principal name (UPN) of user"

# Immutable ID from old domain
Write-Host "`n Please wait, retrieving Immutable ID details... `n"
# Retrieving Immutable ID from old domain
$guid1 = [guid]((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Credential $CredAdmin1 -Server $NameServer1).objectGuid)
# Converting data format
$DomainimmutableId1 = [System.Convert]::ToBase64String($guid1.ToByteArray())
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " Immutable ID on " -NoNewline
Write-Host "$NameDomain1" -ForegroundColor Red -NoNewline
Write-Host " is " -NoNewline
Write-Host "$DomainimmutableId1" -ForegroundColor Green

# Immutable ID from new domain
Write-Host "`n Please wait, retrieving Immutable ID details... `n"
# Retrieving Immutable ID from new domain
$guid2 = [guid]((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Credential $CredAdmin2 -Server $NameServer2).objectGuid)
# Converting data format
$DomainimmutableId2 = [System.Convert]::ToBase64String($guid2.ToByteArray())
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " Immutable ID on " -NoNewline
Write-Host "$NameDomain2" -ForegroundColor Red -NoNewline
Write-Host " is " -NoNewline
Write-Host "$DomainimmutableId2" -ForegroundColor Green

# Immutable ID from Azure before change
Write-Host "`n Current Azure Immutable ID details: `n"
# Retrieving Immutable ID from Azure before change
$AzureimmutableId = (Get-MsolUser -UserPrincipalName $userUPN | Select-Object -ExpandProperty ImmutableID)
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " current" -ForegroundColor Red -NoNewline
Write-Host " Immutable ID on Azure is: " -NoNewline
Write-Host "$AzureimmutableId" -ForegroundColor Green

# Copy Immutable ID from new domain to Azure
Write-Host "`n Copying new Immutable ID to Azure..."
Set-MsolUser -UserPrincipalName $userUPN -ImmutableId "$DomainimmutableId2"

# Immutable ID from Azure after change
Write-Host "`n New Azure Immutable ID details: `n"
# Retrieving Immutable ID from Azure after change
$AzureimmutableId = (Get-MsolUser -UserPrincipalName $userUPN | Select-Object -ExpandProperty ImmutableID)
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " new" -ForegroundColor Red -NoNewline
Write-Host " Immutable ID on Azure is: " -NoNewline
Write-Host "$AzureimmutableId" -ForegroundColor Green

Read-Host -Prompt "`n Press Enter to exit"