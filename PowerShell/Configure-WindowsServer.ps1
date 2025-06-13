<#
.SYNOPSIS
    Windows Server Configuration Script
.DESCRIPTION
    Interactive script for initial configuration of a new Windows Server including:
      - Renaming server and OS drive
      - Setting language and time zone
      - Installing optional features
      - Configuring as DC (PDC or additional)
      - Setting IP (Static or DHCP)
.NOTES
    File Name      : Configure-WindowsServer.ps1
    Author         : Mamun Beg
    Prerequisite   : PowerShell 5.1 or later, Windows Server 2016 or later
#>

# =======================
# Default Values
# =======================
$DefaultServerName    = "CAP-SRVDC1"
$DefaultDriveLabel    = "OS"
$DefaultPDCIP         = "10.0.50.5"
$DefaultGateway       = "10.0.50.1"
$DefaultDNSForwarder  = "1.1.1.1"   # Default DNS forwarder IP
$DefaultPrefixLength  = 24          # Default subnet prefix length (e.g., 24 = 255.255.255.0)

# Feature lists
$PDCFeatureNames         = @("AD-Domain-Services", "DNS", "GPMC")
$AdditionalDCFeatureNames = @("AD-Domain-Services", "DNS")

# Domain Controller options. Default is first option - Skip domain controller setup
$dcOptions = @(
    "Skip domain controller setup",
    "Primary Domain Controller (new forest)",
    "Additional Domain Controller (existing domain)"
)

# WAC installer mode: '/VERYSILENT' for no UI, '/SP' for standard installation with prompts
$WACInstallerMode = '/SP' # Change to '/VERYSILENT' if you want a completely silent install

# Map of country to culture/language and timezone (expand as needed)
$languageMap = @{
    "Australia"           = @{ Culture = "en-AU"; TimeZone = "AUS Eastern Standard Time" }
    "India"               = @{ Culture = "en-IN"; TimeZone = "India Standard Time" }
    "United Kingdom"      = @{ Culture = "en-GB"; TimeZone = "GMT Standard Time" }
    "United States East"  = @{ Culture = "en-US"; TimeZone = "Eastern Standard Time" }
    "United States West"  = @{ Culture = "en-US"; TimeZone = "Pacific Standard Time" }
    # Add more countries here if needed
}

# =======================
# Initialization
# =======================
$forceReboot = $false
$ErrorActionPreference = "Stop"
$script:completedSections = @()
$logFile = "$env:TEMP\ServerSetup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Inform user where the log file will be written
Write-Host "`nLog file for this session: $logFile" -ForegroundColor Cyan

# =======================
# Utility Functions
# =======================

# Write log messages to file and optionally to console with color
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        # default   { Write-Host $logEntry } # Uncomment if you want INFO messages to also be printed
    }
}

# Display a numbered menu and return the user's selection
function Show-Menu {
    param (
        [string]$Title,
        [array]$Options,
        [string]$Prompt = "Select an option",
        [int]$Default = 1
    )
    if (-not $Options -or $Options.Count -eq 0) {
        Write-Host "No options provided to Show-Menu." -ForegroundColor Red
        return $null
    }
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "$($i + 1). $($Options[$i])"
    }
    do {
        $selection = Read-Host "$Prompt [default: $Default]"
        if ([string]::IsNullOrWhiteSpace($selection)) {
            return $Default
        }
        if ($selection -match "^\d+$") {
            $selectionInt = [int]$selection
            if ($selectionInt -ge 1 -and $selectionInt -le $Options.Count) {
                return $selectionInt
            }
        }
        Write-Host "Invalid selection. Please enter a number between 1 and $($Options.Count), or press Enter for default." -ForegroundColor Red
    } while ($true)
}

# Utility function to prompt for Y/N and only accept Y/y or N/n, default is N
function Read-YesNo {
    param(
        [string]$Prompt = "Enter Y or N [default: N]"
    )
    while ($true) {
        $userInput = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($userInput)) { return $false } # Default to N
        if ($userInput -eq "Y" -or $userInput -eq "y") { return $true }
        if ($userInput -eq "N" -or $userInput -eq "n") { return $false }
        Write-Host "Please enter Y or N." -ForegroundColor Yellow
    }
}

# Check if a reboot is pending on the system
function Test-RebootPending {
    # Check for standard reboot pending registry keys
    $pendingReboot = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) -or
                     (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) -or
                     (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue)

    # Also check if a computer name change is pending
    $activeName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name 'ComputerName' -ErrorAction SilentlyContinue).ComputerName
    $pendingName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName' -ErrorAction SilentlyContinue).ComputerName
    $nameChangePending = $activeName -ne $pendingName

    # Check if a system locale change is pending
    $activeLocale = (Get-WinSystemLocale).Name
    $pendingLocaleLCID = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language' -Name 'Default' -ErrorAction SilentlyContinue).'Default'
    $pendingLocaleName = if ($pendingLocaleLCID) { try { (New-Object System.Globalization.CultureInfo ([int]::Parse($pendingLocaleLCID, 'HexNumber'))).Name } catch { $null } } else { $null }
    $localeChangePending = $pendingLocaleName -and ($activeLocale -ne $pendingLocaleName)

    return $pendingReboot -or $nameChangePending -or $localeChangePending -or $forceReboot
}

# Helper function to log if a reboot becomes required after an operation
function Write-RebootIfPending {
    param(
        [string]$Operation
    )
    if (Test-RebootPending) {
        Write-Log "A reboot is now required after: $Operation" -Level WARNING
    }
}

# Prompt user to reboot if required
function Invoke-RebootIfRequired {
    param([switch]$ExitIfDeclined)
    if (Test-RebootPending) {
        Write-Host "`nA reboot is required to complete configuration." -ForegroundColor Yellow
        $rebootNow = Read-YesNo "Do you want to reboot now? (Y/N) [default: N]"
        if ($rebootNow) {
            Write-Log -Message "Rebooting server to complete configuration..."
            Restart-Computer -Force
            return $true
        } else {
            Write-Host "Some configuration changes will not take effect until after a reboot." -ForegroundColor Yellow
            if ($ExitIfDeclined) {
                Write-Host "`nA reboot is still required. The script will now terminate. Please reboot the server and re-run the script to continue configuration.`n" -ForegroundColor Yellow
                exit
            }
        }
    } else {
        Write-Host "`nNo reboot is currently required.`n" -ForegroundColor Green
    }
    return $false
}

# Validate password complexity for SecureString input
function Test-PasswordComplexity {
    param(
        [Parameter(Mandatory)]
        [System.Security.SecureString]$SecurePassword
    )
    # Convert SecureString to plain text for validation
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
        # At least 16 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special character
        $isComplex = $plainPassword -match '^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{16,}$'
        if (-not $isComplex) {
            Write-Host "Password does not meet complexity requirements. Please use at least 16 characters, including uppercase, lowercase, digit, and special character." -ForegroundColor Red
        }
        return $isComplex
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}

# Validate domain name format (simple DNS name check)
function Test-ValidDomain {
    param([string]$DomainName)
    return $DomainName -match '^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$'
}

# Validate IPv4 address format
function Test-ValidIPv4 {
    param([string]$IPAddress)
    return $IPAddress -match '^(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})){3}$'
}

# Validate adapter object
function Test-ValidAdapter {
    param(
        [Parameter(Mandatory)][object]$Adapter
    )
    if (-not $Adapter -or -not $Adapter.ifIndex) {
        Write-Log "Invalid network adapter specified." -Level ERROR
        Write-Host "Invalid network adapter specified." -ForegroundColor Red
        return $false
    }
    return $true
}

# Validate IP and Gateway addresses
function Test-ValidIPAndGateway {
    param(
        [Parameter(Mandatory)][string]$IPAddress,
        [Parameter(Mandatory)][string]$Gateway
    )
    $valid = $true
    if (-not (Test-ValidIPv4 $IPAddress)) {
        Write-Log "Invalid IP address: $IPAddress" -Level ERROR
        Write-Host "Invalid IP address format: $IPAddress" -ForegroundColor Red
        $valid = $false
    }
    if (-not (Test-ValidIPv4 $Gateway)) {
        Write-Log "Invalid gateway address: $Gateway" -Level ERROR
        Write-Host "Invalid gateway address format: $Gateway" -ForegroundColor Red
        $valid = $false
    }
    return $valid
}

# Set DHCP IP configuration
function Set-DhcpIP {
    param(
        [Parameter(Mandatory)][object]$Adapter
    )
    # Validate adapter
    if (-not (Test-ValidAdapter -Adapter $Adapter)) {
        return
    }
    try {
        # Always remove all existing IPv4 addresses on the adapter before enabling DHCP
        $existingIPs = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($ip in $existingIPs) {
            Remove-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }

        Set-NetIPInterface -InterfaceIndex $Adapter.ifIndex -Dhcp Enabled
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses
        Write-Host "DHCP enabled on $($Adapter.Name)." -ForegroundColor Green
        Write-Log "DHCP enabled on $($Adapter.Name)."

        # --- Wait for DHCP to assign a valid (non-APIPA) IP ---
        Restart-NetAdapter -Name (Get-NetAdapter -InterfaceIndex $Adapter.ifIndex).Name
        $retries = 30
        $DhcpIPInfo = $null
        while ($retries -gt 0) {
            Start-Sleep -Seconds 2
            $DhcpIPInfo = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike '169.254.*' }
            if ($DhcpIPInfo) { break }
            $retries--
        }
        if (-not $DhcpIPInfo) {
            Write-Host "`nWARNING: DHCP did not assign a valid IPv4 address to $($Adapter.Name) after enabling. Please check network configuration.`n" -ForegroundColor Yellow
            Write-Log "DHCP did not assign a valid IPv4 address to $($Adapter.Name) after enabling." -Level WARNING
        }
    } catch {
        Write-Host "Failed to enable DHCP on $($Adapter.Name)." -ForegroundColor Red
        Write-Log "Failed to enable DHCP on $($Adapter.Name): $_" -Level ERROR
    }
}

# Set static IP configuration
function Set-StaticIP {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$IPAddress,
        [Parameter(Mandatory)][string]$Gateway,
        [int]$PrefixLength = $DefaultPrefixLength
    )
    # Validate adapter
    if (-not (Test-ValidAdapter -Adapter $Adapter)) {
        return
    }
    # Validate IP and Gateway
    if (-not (Test-ValidIPAndGateway -IPAddress $IPAddress -Gateway $Gateway)) {
        return
    }
    try {
        # Always remove all existing IPv4 addresses on the adapter
        $existingIPs = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($ip in $existingIPs) {
            Remove-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
        # Add the new static IP
        New-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
        Write-Log "Set static IP $IPAddress/$PrefixLength and gateway $Gateway on adapter $($Adapter.Name)"

        # --- Static IP check after setting ---
        Start-Sleep -Seconds 2 # Allow time for network stack to update
        $StaticIPInfo = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq 'Manual' }
        if (-not $StaticIPInfo) {
            Write-Host "`nERROR: Static IPv4 address was not set successfully on $($Adapter.Name). Please check network configuration.`n" -ForegroundColor Red
            Write-Log "Static IPv4 address was not set successfully on $($Adapter.Name)." -Level ERROR
        }
    } catch {
        Write-Log "Error setting static IP: $_" -Level ERROR
        Write-Host "Error setting static IP: $_" -ForegroundColor Red
    }
}

# Set DNS server address
function Set-DnsServer {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$DnsIP
    )
    try {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $DnsIP
        Write-Log "Set DNS server $DnsIP on adapter $($Adapter.Name)"
    } catch {
        Write-Log "Error setting DNS server $DnsIP on adapter $($Adapter.Name): $_" -Level ERROR
        Write-Host "Error setting DNS server $DnsIP on adapter $($Adapter.Name): $_" -ForegroundColor Red
    }
}

# Check internet connectivity
function Test-InternetConnection {
    param(
        [string]$TestUrl = "https://www.microsoft.com"
    )
    try {
        Invoke-WebRequest -Uri $TestUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to get all "Up" network adpaters
function Get-AllNetAdapters {
    return Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
}

# Select a network adapter
function Select-NetworkAdapter {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    if ($adapters.Count -gt 1) {
        Write-Host "`nMultiple network adapters detected:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $adapters.Count; $i++) {
            Write-Host "$($i+1): $($adapters[$i].Name) - $($adapters[$i].InterfaceDescription)"
        }
        do {
            $nicChoice = Read-Host "Select the adapter to configure (1-$($adapters.Count))"
        } while (-not ($nicChoice -match '^\d+$' -and $nicChoice -ge 1 -and $nicChoice -le $adapters.Count))
        $selectedAdapter = $adapters[$nicChoice-1]
        # Show current network configuration for the chosen NIC
        Show-NetworkConfiguration -Adapter $selectedAdapter
        return $selectedAdapter
    } else {
        $adapter = $adapters | Select-Object -First 1
        # Show current network configuration for the single NIC
        Show-NetworkConfiguration -Adapter $adapter
        return $adapter
    }
}

# Function to show current network configuration for a network adapter
function Show-NetworkConfiguration {
    param(
        [Parameter(Mandatory)][object]$Adapter
    )
    $currentIP = (Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress) -join ', '
    $currentGateway = (Get-NetRoute -InterfaceIndex $Adapter.ifIndex -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty NextHop) -join ', '
    Write-Host "`nNetwork configuration for: $($Adapter.Name) - $($Adapter.InterfaceDescription)" -ForegroundColor Cyan
    Write-Host "    IP Address: $currentIP"
    Write-Host "    Gateway:    $currentGateway"
}

# Install features if missing
function Install-FeatureIfMissing {
    param(
        [Parameter(Mandatory)][string[]]$FeatureNames
    )
    $features = Get-WindowsFeature | Where-Object { $FeatureNames -contains $_.Name }
    $toInstall = $features | Where-Object { -not $_.Installed }
    if ($toInstall) {
        try {
            Install-WindowsFeature -Name $toInstall.Name -IncludeManagementTools
            Write-Log "Installed features: $($toInstall.Name -join ', ')"
        } catch {
            Write-Log "Error installing features: $_" -Level ERROR
        }
    } else {
        Write-Log "No features needed installation. All requested features already installed: $($FeatureNames -join ', ')"
    }
}

# Clean up temporary files and variables
function Clear-Temp {
    try {
        Write-Log "Cleaning up temporary files..."
        # Remove all files in TEMP except the current log file (compare full path)
        $logFileFullPath = (Resolve-Path $logFile).Path
        Get-ChildItem -Path $env:TEMP\* -File | Where-Object { ($_.FullName -ne $logFileFullPath) } | Remove-Item -Force -ErrorAction SilentlyContinue
        Remove-Variable -Name completedSections -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        Write-Log "Cleanup completed."
    } catch {
        Write-Log "Error during cleanup: $_" -Level ERROR
    }
}

# =======================
# Main Script Execution
# =======================
try {
    Write-Log "Starting server configuration script"

    # --- ADMINISTRATOR PASSWORD CHANGE ---
    Write-Host "`n========== ADMINISTRATOR PASSWORD CHANGE ==========`n" -ForegroundColor Cyan
    # Prompt user to change the local Administrator password
    if (Read-YesNo "Do you want to change the local Administrator password? (Y/N) [default: N]") {
        # Loop until a complex password is provided
        do {
            $adminPwd = Read-Host "Enter new Administrator password" -AsSecureString
            $isComplex = Test-PasswordComplexity $adminPwd
        } while (-not $isComplex)
        try {
            # Set the new password for the Administrator account
            $adminUser = Get-LocalUser -Name "Administrator"
            $adminUser | Set-LocalUser -Password $adminPwd
            Write-Host "`nAdministrator password changed successfully.`n" -ForegroundColor Green
            Write-Log "Local Administrator password changed."
        } catch {
            Write-Host "`nFailed to change Administrator password.`n" -ForegroundColor Red
            Write-Log "Error changing Administrator password: $_" -Level ERROR
        }
    }

    # --- SERVER NAME CONFIGURATION ---
    Write-Host "`n========== SERVER NAME CONFIGURATION ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("RenameServer" -notin $script:completedSections) {
        # Show current server name
        Write-Host "`nCurrent Server Name: $($env:COMPUTERNAME)`n" -ForegroundColor Green
        # Prompt user to rename the server
        if (Read-YesNo "Do you want to rename the server? (Y/N) [default: N]") {
            # Get new server name or use default
            $newName = Read-Host "`nEnter new server name [default: $DefaultServerName]"
            if ([string]::IsNullOrWhiteSpace($newName)) { $newName = $DefaultServerName }
            try {
                # Rename the computer
                Rename-Computer -NewName $newName -Force
                $script:completedSections += "RenameServer"
                Write-Host "`nServer rename to $newName scheduled.`n" -ForegroundColor Green
                Write-Log "Server rename to $newName scheduled."
            } catch {
                Write-Host "`nError renaming server.`n" -ForegroundColor Red
                Write-Log "Error renaming server: $_" -Level ERROR
            }
            # Check if reboot is now required
            Write-RebootIfPending "Server Rename"
        }
    }

    # --- OS DRIVE LABEL ---
    Write-Host "`n========== OS DRIVE LABEL ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("RenameDrive" -notin $script:completedSections) {
        # Get current C: drive label
        $drive = Get-Partition -DriveLetter C | Get-Volume
        $currentLabel = $drive.FileSystemLabel
        if ([string]::IsNullOrWhiteSpace($currentLabel)) {
            $currentLabel = "NOT SET"
        }

        # If already correct, skip
        if ($currentLabel -eq $DefaultDriveLabel) {
            Write-Host "`nC: drive is already named $DefaultDriveLabel.`n" -ForegroundColor Green
            Write-Log "C: drive already named $DefaultDriveLabel, skipping rename."
            $script:completedSections += "RenameDrive"
        } else {
            # Show current label and prompt for rename
            Write-Host "`nCurrent C: drive label: $currentLabel`n" -ForegroundColor Green
            if (Read-YesNo "Do you want to rename the C: drive to ${DefaultDriveLabel}? (Y/N) [default: N]") {
                try {
                    # Rename the drive
                    $drive | Set-Volume -NewFileSystemLabel $DefaultDriveLabel
                    Write-Host "`nC: drive renamed to $DefaultDriveLabel`n" -ForegroundColor Green
                    Write-Log "C: drive renamed to $DefaultDriveLabel"
                    $script:completedSections += "RenameDrive"
                } catch {
                    Write-Host "`nError renaming drive.`n" -ForegroundColor Red
                    Write-Log "Error renaming drive: $_" -Level ERROR
                }
                # Check if reboot is now required
                Write-RebootIfPending "OS Drive Label Change"
            }
        }
    }

    # --- LANGUAGE & TIME ZONE ---
    Write-Host "`n========== LANGUAGE & TIME ZONE ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("LanguageSettings" -notin $script:completedSections) {
        $languageOptions = $languageMap.Keys | Sort-Object

        # Try to detect current time zone and country
        try {
            $currentTimeZone = (Get-TimeZone).Id
            $currentCountry = $null
            foreach ($country in $languageOptions) {
                if ($languageMap[$country].TimeZone -eq $currentTimeZone) {
                    $currentCountry = $country
                    break
                }
            }
            # Show current settings
            if ($currentCountry) {
                Write-Host "`nCurrent country/language: $currentCountry ($($languageMap[$currentCountry].Culture)), Time Zone: $currentTimeZone`n" -ForegroundColor Green
                Write-Log "Detected country/language: $currentCountry, Time Zone: $currentTimeZone"
            } else {
                Write-Host "`nCurrent time zone: $currentTimeZone (no matching country)`n" -ForegroundColor Yellow
                Write-Log "Current time zone: $currentTimeZone (no matching country)"
            }
        } catch {
            Write-Host "`nUnable to determine current country/language.`n" -ForegroundColor Yellow
            Write-Log "Unable to determine current country/language."
        }

        # Find the index of the current country in the sorted list (default to 1 if not found)
        $defaultIndex = 1
        if ($currentCountry) {
            $foundIndex = $languageOptions.IndexOf($currentCountry)
            if ($foundIndex -ge 0) { $defaultIndex = $foundIndex + 1 }
        }

        # Prompt user to select country/language, default is current country
        $languageChoice = Show-Menu -Title "Select Country/Language" -Options $languageOptions -Prompt "Enter your choice (1-$($languageOptions.Count))" -Default $defaultIndex

        $selectedCountry = $languageOptions[$languageChoice-1]
        $selectedCulture = $languageMap[$selectedCountry].Culture
        $selectedTimeZone = $languageMap[$selectedCountry].TimeZone

        try {
            # Set time zone and language
            Set-TimeZone -Id $selectedTimeZone
            Set-WinSystemLocale -SystemLocale $selectedCulture
            Set-Culture -CultureInfo $selectedCulture
            Set-WinUILanguageOverride -Language $selectedCulture
            Set-WinUserLanguageList -LanguageList $selectedCulture -Force
            Write-Host "`nConfigured for ${selectedCountry}:" -ForegroundColor Green
            Write-Host " - Time Zone: $selectedTimeZone"
            Write-Host " - Language: $selectedCulture`n"
            Write-Host "System locale and display language set to $selectedCulture. A reboot may be required for all changes to take effect.`n" -ForegroundColor Yellow
            Write-Log "Set time zone to $selectedTimeZone and system/display language to $selectedCulture for $selectedCountry"
            $script:completedSections += "LanguageSettings"
        } catch {
            Write-Host "`nError setting time zone or language.`n" -ForegroundColor Red
            Write-Log "Error setting time zone or language: $_" -Level ERROR
        }
        # Check if reboot is now required
        Write-RebootIfPending "Language/Time Zone/Locale Change"
    }

    # --- SERVER CORE APP COMPATIBILITY ---
    Write-Host "`n========== SERVER CORE APP COMPATIBILITY ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("AppCompat" -notin $script:completedSections) {
        # Check if feature is already installed
        $appCompat = Get-WindowsCapability -Online | Where-Object { $_.Name -like "ServerCore.AppCompatibility*" }
        if ($appCompat.State -eq "Installed") {
            Write-Host "`nServer Core App Compatibility is already installed.`n" -ForegroundColor Green
            Write-Log "Server Core App Compatibility already installed, skipping."
            $script:completedSections += "AppCompat"
        } else {
            # Prompt user to install feature
            if (Read-YesNo "Do you want to install Server Core App Compatibility? (Y/N) [default: N]") {
                try {
                    # Install the feature
                    Add-WindowsCapability -Online -Name ServerCore.AppCompatibility~~~~0.0.1.0
                    Write-Host "`nServer Core App Compatibility installed successfully.`n" -ForegroundColor Green
                    Write-Log "Server Core App Compatibility installed."
                    $script:completedSections += "AppCompat"
                } catch {
                    Write-Host "`nFailed to install Server Core App Compatibility.`n" -ForegroundColor Red
                    Write-Log "Error installing Server Core App Compatibility: $_" -Level ERROR
                }
                # Check if reboot is now required
                Write-RebootIfPending "Server Core App Compatibility Installation"
            }
        }
    }

    # --- FIRST REBOOT CHECK ---
    Write-Host "`n========== FIRST REBOOT CHECK ==========`n" -ForegroundColor Cyan
    # Prompt user to reboot if required
    if (Invoke-RebootIfRequired -ExitIfDeclined) {
        # Script will exit here because system is rebooting or user declined reboot
        return
    }

    # --- WINDOWS ADMIN CENTER ---
    Write-Host "`n========== WINDOWS ADMIN CENTER ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("InstallWAC" -notin $script:completedSections) {
        # Check if WAC is already installed
        $wacRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\9B27DF2F-5386-41DF-B52B-5DF81914B043_is1"
        $wacInstalled = $false
        if (Test-Path $wacRegPath) {
            $installLocation = (Get-ItemProperty -Path $wacRegPath -ErrorAction SilentlyContinue).InstallLocation
            if ($installLocation) {
                $wacInstalled = $true
            }
        }
        if ($wacInstalled) {
            Write-Host "`nWindows Admin Center is already installed.`n" -ForegroundColor Green
            Write-Log "Windows Admin Center already installed, skipping installation."
            $script:completedSections += "InstallWAC"
        } else {
            # Prompt user to install WAC
            if (Read-YesNo "Do you want to install Windows Admin Center? (Y/N) [default: N]") {
                # Check internet connectivity before download
                if (Test-InternetConnection) {
                    try {
                        # Download and install WAC
                        $wacExePath = "$env:TEMP\WindowsAdminCenter.exe"
                        $parameters = @{
                            Source      = "https://aka.ms/WACdownload"
                            Destination = $wacExePath
                        }
                        Write-Host "`nDownloading Windows Admin Center installer from Microsoft...`n" -ForegroundColor Cyan
                        Write-Log "Downloading Windows Admin Center installer from Microsoft..."
                        Start-BitsTransfer @parameters

                        Write-Host "`nInstalling Windows Admin Center...`n" -ForegroundColor Cyan
                        Write-Log "Installing Windows Admin Center..."
                        Start-Process -FilePath $wacExePath -ArgumentList $WACInstallerMode -Wait

                        Write-Host "`nStarting Windows Admin Center service...`n" -ForegroundColor Cyan
                        Write-Log "Starting Windows Admin Center service..."
                        Start-Service -Name WindowsAdminCenter

                        Write-Host "`nWindows Admin Center installation completed.`n" -ForegroundColor Green
                        Write-Log "Windows Admin Center installation completed."
                        $script:completedSections += "InstallWAC"
                    } catch {
                        Write-Host "`nError installing Windows Admin Center.`n" -ForegroundColor Red
                        Write-Log "Error installing Windows Admin Center: $_" -Level ERROR
                    }
                    # Check if reboot is now required
                    Write-RebootIfPending "Windows Admin Center Installation"
                } else {
                    Write-Host "`nInternet connectivity is required to download and install Windows Admin Center. Please check your connection and try again.`n" -ForegroundColor Yellow
                    Write-Log "Internet connectivity check failed. Could not download Windows Admin Center."
                }
            }
        }
    }

    # --- DOMAIN CONTROLLER CONFIGURATION ---
    Write-Host "`n========== DOMAIN CONTROLLER CONFIGURATION ==========`n" -ForegroundColor Cyan
    # Only run if not already completed
    if ("DomainConfig" -notin $script:completedSections) {
        # Always make the first value in $dcOptions the default
        $dcDefaultIndex = 1
        $dcChoice = Show-Menu -Title "Domain Controller Configuration" -Options $dcOptions -Default $dcDefaultIndex

        # Only proceed if user selects PDC (option 2) or Additional DC (option 3)
        if ($dcChoice -eq 2 -or $dcChoice -eq 3) {
            # Prompt for and validate domain name
            do {
                $domainName = Read-Host "Enter the domain name (e.g., corp.example.com)"
                if (-not (Test-ValidDomain $domainName)) {
                    Write-Host "`nInvalid domain name format. Please enter a valid DNS domain name (e.g., corp.example.com).`n" -ForegroundColor Red
                }
            } while (-not (Test-ValidDomain $domainName))

            $allNetAdapters = Get-AllNetAdapters
            if (-not $allNetAdapters -or $allNetAdapters.Count -eq 0) {
                Write-Host "`nWARNING: No network adapters with status 'Up' were found. Domain controller configuration cannot continue.`n" -ForegroundColor Yellow
                Write-Log "No network adapters with status 'Up' found. Skipping domain controller configuration." -Level WARNING
                return
            }
            foreach ($nic in $allNetAdapters) {
                Show-NetworkConfiguration -Adapter $nic

                $useDHCP = Read-YesNo "Do you want to use DHCP for this NIC ($($nic.Name))? (Y/N) [default: N]"
                if ($useDHCP) {
                    Set-DhcpIP -Adapter $nic
                    Show-NetworkConfiguration -Adapter $nic
                } else {
                    $defaultIP = $DefaultPDCIP
                    $staticIP = Read-Host "Enter static IP for $($nic.Name) [default: $defaultIP]"
                    if ([string]::IsNullOrWhiteSpace($staticIP)) { $staticIP = $defaultIP }
                    $gateway = Read-Host "Enter gateway for $($nic.Name) [default: $DefaultGateway]"
                    if ([string]::IsNullOrWhiteSpace($gateway)) { $gateway = $DefaultGateway }
                    Set-StaticIP -Adapter $nic -IPAddress $staticIP -Gateway $gateway
                    Show-NetworkConfiguration -Adapter $nic

                    # Set DNS
                    if ($dcChoice -eq 2) {
                        # PDC: set DNS to self
                        Set-DnsServer -Adapter $nic -DnsIP $staticIP
                    } else {
                        # Prompt for DNS IP, default to $DefaultPDCIP
                        $dnsIP = Read-Host "Enter DNS server IP for $($nic.Name) [default: $DefaultPDCIP]"
                        if ([string]::IsNullOrWhiteSpace($dnsIP)) { $dnsIP = $DefaultPDCIP }
                        Set-DnsServer -Adapter $nic -DnsIP $dnsIP
                    }
                }
            }

            if ($dcChoice -eq 2) {
                # --- PDC Configuration ---
                # Install required features for PDC
                Install-FeatureIfMissing -FeatureNames $PDCFeatureNames

                # Prompt for DSRM password and configure new forest
                do {
                    $safeModePassword = Read-Host "Enter Directory Services Restore Mode password" -AsSecureString
                    $isComplex = Test-PasswordComplexity $safeModePassword
                    if (-not $isComplex) {
                        Write-Host "`nThe Directory Services Restore Mode password does not meet the complexity requirements. Please try again.`n" -ForegroundColor Red
                    }
                } while (-not $isComplex)
                try {
                    Install-ADDSForest -DomainName $domainName -DomainNetbiosName ($domainName.Split('.')[0]).ToUpper() `
                        -InstallDns -SafeModeAdministratorPassword $safeModePassword -Force -NoRebootOnCompletion
                    Add-DnsServerForwarder -IPAddress $DefaultDNSForwarder -PassThru
                    Write-Host "`nConfigured as PDC for domain $domainName`n" -ForegroundColor Green
                    Write-Log "Configured as PDC for domain $domainName"
                    $script:completedSections += "DomainConfig"
                    $forceReboot = $true   # Force reboot after DC setup
                } catch {
                    Write-Host "`nError configuring PDC.`n" -ForegroundColor Red
                    Write-Log "Error configuring PDC: $_" -Level ERROR
                }
                Write-RebootIfPending "Domain Controller (PDC) Setup"
            } elseif ($dcChoice -eq 3) {
                # --- Additional DC Configuration ---
                # Install required features for additional DC
                Install-FeatureIfMissing -FeatureNames $AdditionalDCFeatureNames

                # Prompt for domain admin credentials and promote as additional DC
                try {
                    $credential = Get-Credential -Message "Enter domain administrator credentials"
                    Install-ADDSDomainController -DomainName $domainName -Credential $credential -InstallDns -NoRebootOnCompletion -Force
                    Write-Host "`nConfigured as additional DC for domain $domainName`n" -ForegroundColor Green
                    Write-Log "Configured as additional DC for domain $domainName"
                    $script:completedSections += "DomainConfig"
                    $forceReboot = $true   # Force reboot after DC setup
                } catch {
                    Write-Host "`nError configuring additional DC.`n" -ForegroundColor Red
                    Write-Log "Error configuring additional DC: $_" -Level ERROR
                }
                Write-RebootIfPending "Domain Controller (Additional DC) Setup"
            }
        }
    }

    # --- FINAL REBOOT CHECK ---
    Write-Host "`n========== FINAL REBOOT CHECK ==========`n" -ForegroundColor Cyan
    # Prompt user to reboot if required
    if (Invoke-RebootIfRequired -ExitIfDeclined) {
        # Script will exit here because system is rebooting or user declined reboot
        return
    }

    # Log script completion
    Write-Log -Message "Server configuration script completed."
} catch {
    Write-Log "Script error: $_" -Level ERROR
} finally {
    # Clean up temp files
    Clear-Temp
}
Write-Host " ____                             ___       ____                _         _ " -ForegroundColor Green
Write-Host "/ ___|  ___ _ ____   _____ _ __  |_ _|___  |  _ \ ___  __ _  __| |_   _  | |" -ForegroundColor Green
Write-Host "\___ \ / _ \ '__\ \ / / _ \ '__|  | |/ __| | |_) / _ \/ _` |/ _` | | | | | |" -ForegroundColor Green
Write-Host " ___) |  __/ |   \ V /  __/ |     | |\__ \ |  _ <  __/ (_| | (_| | |_| | |_|" -ForegroundColor Green
Write-Host "|____/ \___|_|    \_/ \___|_|    |___|___/ |_| \_\___|\__,_|\__,_|\__, | (_)" -ForegroundColor Green
Write-Host "                                                                  |___/     " -ForegroundColor Green