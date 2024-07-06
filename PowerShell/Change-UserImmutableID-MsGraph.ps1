# PowerShell modules required for this script
Write-Host "This script requires " -NoNewline
Write-Host "Microsoft.Graph" -ForegroundColor Blue -NoNewline
Write-Host " and " -NoNewline
Write-Host "ActiveDirectory" -ForegroundColor Blue -NoNewline
Write-Host " PowerShell modules installed. If not installed Ctrl-C to cancel."

# Azure (M365) admininstrator account credentials used to manage the tenant
Write-Host "`n Enter M365 administrator credentials: `n"
# Microsoft.Graph module to connect to Azure tenant
Connect-MgGraph -NoWelcome -Scopes "Directory.AccessAsUser.All"

<#
# Old domain controller name that account will be moved from
$NameServerOld = Read-Host "Enter name of current domain controller FROM which user account will be moved"
Write-Host "`n Enter $NameServerOld administrator credentials:"
# Old domain controller credentials that account will be moved from
$CredAdminOld = Get-Credential
Write-Host "`n Please wait, retrieving domain details... `n"
# Old domain
$NameDomainOld = ((Get-ADDomain -Credential $CredAdminOld -Server $NameServerOld).Forest)
#>

# New domain controller name that account will be moved from
$NameServerNew = Read-Host "Enter name of new domain controller TO which user account will be moved"
Write-Host "`n Enter $NameServerNew administrator credentials:"
# New domain controller credentials that account will be moved from
$CredAdminNew = Get-Credential
Write-Host "`n Please wait, retrieving domain details... `n"
# New domain
$NameDomainNew = ((Get-ADDomain -Credential $CredAdminNew -Server $NameServerNew).Forest)

# Username of account to be moved
$userUPN = Read-Host "Enter user principal name (UPN) of user"

<#
# Immutable ID from old domain
Write-Host "`n Please wait, retrieving Immutable ID details... `n"
# Retrieving Immutable ID from old domain
$guid1 = [guid]((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Credential $CredAdminOld -Server $NameServerOld).objectGuid)
# Converting data format
$DomainimmutableIdOld = [System.Convert]::ToBase64String($guid1.ToByteArray())
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " Immutable ID on " -NoNewline
Write-Host "$NameDomainOld" -ForegroundColor Red -NoNewline
Write-Host " is " -NoNewline
Write-Host "$DomainimmutableIdOld" -ForegroundColor Green
#>

# Immutable ID from new domain
Write-Host "`n Please wait, retrieving Immutable ID details... `n"
# Retrieving Immutable ID from new domain
$guid2 = [guid]((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Credential $CredAdminNew -Server $NameServerNew).objectGuid)
# Converting data format
$DomainimmutableIdNew = [System.Convert]::ToBase64String($guid2.ToByteArray())
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " Immutable ID on " -NoNewline
Write-Host "$NameDomainNew" -ForegroundColor Red -NoNewline
Write-Host " is " -NoNewline
Write-Host "$DomainimmutableIdNew" -ForegroundColor Green

# Immutable ID from Azure before change
Write-Host "`n Current Azure Immutable ID details: `n"
# Retrieving Immutable ID from Azure before change
$AzureimmutableId = ((Get-MgUser -UserId $userUPN -Property OnPremisesImmutableId).OnPremisesImmutableId)
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " current" -ForegroundColor Red -NoNewline
Write-Host " Immutable ID on Azure is: " -NoNewline
Write-Host "$AzureimmutableId" -ForegroundColor Green

# Copy Immutable ID from new domain to Azure
Write-Host "`n Copying new Immutable ID to Azure..."
Update-MgUser -UserId $userUPN -OnPremisesImmutableId "$DomainimmutableIdNew"

# Immutable ID from Azure after change
Write-Host "`n New Azure Immutable ID details: `n"
# Retrieving Immutable ID from Azure after change
$AzureimmutableId = ((Get-MgUser -UserId $userUPN -Property OnPremisesImmutableId).OnPremisesImmutableId)
Write-Host "$userUPN" -ForegroundColor Cyan -NoNewline
Write-Host " new" -ForegroundColor Red -NoNewline
Write-Host " Immutable ID on Azure is: " -NoNewline
Write-Host "$AzureimmutableId" -ForegroundColor Green

Read-Host -Prompt "`n Press Enter to exit"