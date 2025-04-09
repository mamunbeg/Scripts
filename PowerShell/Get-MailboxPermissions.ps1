<#
.SYNOPSIS
    Checks permissions on a shared mailbox in Exchange Online.
.DESCRIPTION
    This script checks for and installs the required Exchange Online module if needed,
    then connects to Exchange Online and retrieves all permissions assigned to a specified
    shared mailbox, including mailbox-level and folder-level permissions.
.NOTES
    File Name      : Check-SharedMailboxPermissions.ps1
    Prerequisites  : PowerShell 5.1 or later
    Version       : 2.0
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$MailboxIdentity,
    
    [switch]$IncludeFolderPermissions
)

# Function to check and install Exchange Online Management module
function Install-ExchangeOnlineModule {
    try {
        # Check if module is already installed
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Host "Exchange Online Management module not found. Installing..." -ForegroundColor Yellow
            
            # Install the module for all users
            Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope AllUsers
            
            # Import the module
            Import-Module ExchangeOnlineManagement -Force
            
            Write-Host "Exchange Online Management module installed successfully." -ForegroundColor Green
        } else {
            # Module exists, just import it
            Import-Module ExchangeOnlineManagement -Force
        }
        return $true
    } catch {
        Write-Host "Failed to install Exchange Online Management module: $_" -ForegroundColor Red
        return $false
    }
}

# Main script execution
try {
    # Check and install Exchange Online module if needed
    if (-not (Install-ExchangeOnlineModule)) {
        throw "Exchange Online Management module is required but could not be installed."
    }

    # Connect to Exchange Online (will prompt for credentials if not already connected)
    if (-not (Get-ConnectionInformation)) {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false
    }

    Write-Host "`nChecking permissions for shared mailbox: $MailboxIdentity" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------`n"

    # Check mailbox-level permissions
    Write-Host "Mailbox-Level Permissions:" -ForegroundColor Green
    
    # Full Access permissions
    $fullAccess = Get-MailboxPermission -Identity $MailboxIdentity | 
                  Where-Object { $_.AccessRights -contains "FullAccess" -and -not $_.User.ToString().Contains("NT AUTHORITY") } |
                  Select-Object User, AccessRights, IsInherited
    
    if ($fullAccess) {
        Write-Host "`nFull Access Permissions:" -ForegroundColor Yellow
        $fullAccess | Format-Table -AutoSize
    } else {
        Write-Host "No Full Access permissions found (excluding system accounts)." -ForegroundColor Gray
    }

    # Send As permissions
    $sendAs = Get-RecipientPermission -Identity $MailboxIdentity | 
              Where-Object { $_.AccessRights -contains "SendAs" -and -not $_.Trustee.ToString().Contains("NT AUTHORITY") } |
              Select-Object Trustee, AccessRights
    
    if ($sendAs) {
        Write-Host "`nSend As Permissions:" -ForegroundColor Yellow
        $sendAs | Format-Table -AutoSize
    } else {
        Write-Host "No Send As permissions found (excluding system accounts)." -ForegroundColor Gray
    }

    # Send on Behalf permissions
    $mailbox = Get-Mailbox -Identity $MailboxIdentity
    if ($mailbox.GrantSendOnBehalfTo) {
        Write-Host "`nSend on Behalf Permissions:" -ForegroundColor Yellow
        $mailbox.GrantSendOnBehalfTo | ForEach-Object {
            [PSCustomObject]@{
                User = $_
                Permission = "SendOnBehalf"
            }
        } | Format-Table -AutoSize
    } else {
        Write-Host "No Send on Behalf permissions found." -ForegroundColor Gray
    }

    # Check folder-level permissions if requested
    if ($IncludeFolderPermissions) {
        Write-Host "`nFolder-Level Permissions:" -ForegroundColor Green
        $folderPermissions = Get-MailboxFolderPermission -Identity "$($MailboxIdentity):\*" | 
                            Where-Object { $_.User -notlike "Default" -and $_.User -notlike "Anonymous" } |
                            Select-Object FolderName, User, AccessRights
        
        if ($folderPermissions) {
            $folderPermissions | Format-Table -AutoSize
        } else {
            Write-Host "No custom folder-level permissions found (excluding Default and Anonymous)." -ForegroundColor Gray
        }
    }

} catch {
    Write-Host "`nAn error occurred: $_" -ForegroundColor Red
} finally {
    # Disconnect if we connected in this session
    try {
        if ((Get-ConnectionInformation) -and (Get-ConnectionInformation).Connected) {
            Write-Host "`nDisconnecting from Exchange Online..." -ForegroundColor Cyan
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Host "Error disconnecting: $_" -ForegroundColor DarkYellow
    }
}

Write-Host "`nScript completed." -ForegroundColor Cyan