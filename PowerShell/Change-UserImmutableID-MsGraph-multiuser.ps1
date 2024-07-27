# PowerShell modules required for this script
Write-Host "`nThis script requires " -NoNewline
Write-Host "Microsoft.Graph" -ForegroundColor Blue -NoNewline
Write-Host " and " -NoNewline
Write-Host "ActiveDirectory" -ForegroundColor Blue -NoNewline
Write-Host " PowerShell modules installed. If not installed press Ctrl-C to cancel."
Read-Host -Prompt "`nPress Enter to continue"

# Set variables to zero
$response = 0
$totalusers = 0

# Azure (M365) admininstrator account credentials used to manage the tenant
Write-Host "`nEnter M365 administrator credentials:"
# Microsoft.Graph module to connect to Azure tenant
Connect-MgGraph -NoWelcome -Scopes "Directory.AccessAsUser.All"

# New domain controller that account will be synced to
$DomainServer = Read-Host "`nEnter name of new domain controller TO which user account will be synced"
Write-Host "`nEnter $DomainServer administrator credentials:"
# New domain controller credentials that account will be synced to
$AdminCred = Get-Credential
Write-Host "`nPlease wait, retrieving domain details..."
# Retrieve new domain
$DomainName = ((Get-ADDomain -Credential $AdminCred -Server $DomainServer).Forest)
Write-Host "`nConnected to $DomainName"

do {
    choice /c yn /m "`nDo you want to change a user's Immutable ID in Azure?"
    $response = $LASTEXITCODE
    if ($response -eq 1) {
        # Username of account to be moved
        $userUPN = Read-Host "`nEnter user principal name (UPN) of user"

        # Immutable ID of account on new domain
        Write-Host "`nPlease wait, retrieving Domain Immutable ID details..."
        # Retrieve Immutable ID from new domain
        $DomainGUID = [guid]((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Credential $AdminCred -Server $DomainServer).objectGuid)
        # Convert data format
        $DomainImmutableID = [System.Convert]::ToBase64String($DomainGUID.ToByteArray())
        # Output information with color
        Write-Host "`n $userUPN" -ForegroundColor Cyan -NoNewline
        Write-Host " Immutable ID on " -NoNewline
        Write-Host "$DomainName" -ForegroundColor Red -NoNewline
        Write-Host " is " -NoNewline
        Write-Host "$DomainImmutableID" -ForegroundColor Green

        # Immutable ID of account on Azure before change
        Write-Host "`nPlease wait, retrieving Azure Immutable ID details..."
        # Retrieve Immutable ID from Azure before change
        $AzureImmutableID = ((Get-MgUser -UserId $userUPN -Property OnPremisesImmutableId).OnPremisesImmutableId)
        # Output information with color
        Write-Host "`n $userUPN" -ForegroundColor Cyan -NoNewline
        Write-Host " current" -ForegroundColor Red -NoNewline
        Write-Host " Immutable ID on Azure is: " -NoNewline
        Write-Host "$AzureImmutableID" -ForegroundColor Green

        # Verify user details of account
        # Retrieve user details from new domain
        $DomainUserDetails = ((Get-ADUser -LdapFilter "(userPrincipalName=$userUPN)" -Properties DisplayName -Credential $AdminCred -Server $DomainServer).DisplayName)
        # Retrieve user details from Azure
        $AzureUserDetails = ((Get-MgUser -UserId $userUPN -Property DisplayName).DisplayName)
        # Comapare user details
        if ($DomainUserDetails -eq $AzureUserDetails) {
            # If user details match output information with color
            Write-Host "`nDetails for " -NoNewline
            Write-Host "$DomainUserDetails" -ForegroundColor Cyan -NoNewline
            Write-Host " MATCH" -ForegroundColor Green -NoNewline
            Write-Host " in Azure and in domain " -NoNewline
            Write-Host "$DomainName" -ForegroundColor Red
        } else {
            # If user details don't match output information with color
            Write-Host "`nDetails for " -NoNewline
            Write-Host "$DomainUserDetails" -ForegroundColor Cyan -NoNewline
            Write-Host " DO NOT MATCH" -ForegroundColor Red -NoNewline
            Write-Host " in Azure and in domain " -NoNewline
            Write-Host "$DomainName" -ForegroundColor Red
        }

        # If user details match change Immutable ID
        if ($DomainUserDetails -eq $AzureUserDetails) {
            Read-Host -Prompt "`nDo you want to copy the user's Immutable ID from the domain to Azure? Press Enter if you want to continue or Ctrl-C to cancel"
            # Copy Immutable ID from new domain to Azure
            Write-Host "`nCopying new Immutable ID to Azure..."
            Update-MgUser -UserId $userUPN -OnPremisesImmutableId "$DomainImmutableID"
            
            # Immutable ID from Azure after change
            Write-Host "`nPlease wait, retrieving Azure Immutable ID details..."
            # Retrieve Immutable ID from Azure after change
            $AzureImmutableID = ((Get-MgUser -UserId $userUPN -Property OnPremisesImmutableId).OnPremisesImmutableId)
            # Output information with color
            Write-Host "`n $userUPN" -ForegroundColor Cyan -NoNewline
            Write-Host " new" -ForegroundColor Red -NoNewline
            Write-Host " Immutable ID on Azure is: " -NoNewline
            Write-Host "$AzureImmutableID" -ForegroundColor Green

            Write-Host "`nAnother user changed."
            $totalusers = $totalusers + 1
            Write-Host "Number of users changed is $totalusers."
        }
    }
} until ($response -eq 2)

Write-Host "`nTotal number of users changed is $totalusers."

# Sync changes to Azure (M365)
Invoke-Command -ComputerName $DomainServer -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -Credential $AdminCred

Read-Host -Prompt "`nPress Enter to exit"