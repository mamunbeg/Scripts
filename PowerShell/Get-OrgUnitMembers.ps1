<#
.SYNOPSIS
Export direct members of each AD OU to CSV files.

.DESCRIPTION
- Resolves Desktop path even if redirected (e.g., OneDrive).
- Exports one CSV per OU listing direct members (Users, Groups, Computers, Contacts).
- Columns (and order): Name, UserPrincipalName, SamAccountName, DistinguishedName, ObjectClass, Enabled.
- Excludes DNSHostName, OperatingSystem, LastLogon.
- Requires RSAT ActiveDirectory module.

.NOTES
Version: 1.0
#>

# Robust Desktop path resolution (handles OneDrive or folder redirection)
function Get-DesktopPath {
    try {
        $path = [Environment]::GetFolderPath('Desktop')
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    } catch {}

    # Fallback: registry (may contain %USERPROFILE%)
    try {
        $reg = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
        if ($reg -and $reg.Desktop) {
            $expanded = [Environment]::ExpandEnvironmentVariables($reg.Desktop)
            if (Test-Path -LiteralPath $expanded) { return $expanded }
        }
    } catch {}

    # Final fallback
    return (Join-Path $env:USERPROFILE 'Desktop')
}

function Safe-FileName {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [int]$Index = 0
    )
    $safe = $Name
    foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe -replace [Regex]::Escape($ch), '_' }
    foreach ($ch in [IO.Path]::GetInvalidPathChars())     { $safe = $safe -replace [Regex]::Escape($ch), '_' }
    # Remove control chars, trim spaces/dots
    $safe = ($safe.ToCharArray() | Where-Object { [int]$_ -ge 32 }) -join ''
    $safe = $safe.Trim().TrimEnd('.')
    # Collapse repeated underscores
    $safe = ($safe -replace '_{2,}', '_')
    # Avoid reserved device names
    $reserved = 'CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9'
    if ($safe.ToUpper() -in $reserved) { $safe = "${safe}_OU" }
    # Cap length
    if ($safe.Length -gt 120) { $safe = $safe.Substring(0,120) }
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "OU_$Index" }
    return $safe
}

# Ensure AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module is required. Install RSAT (Active Directory module) and retry."
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

$desktopPath = Get-DesktopPath
$outRoot     = Join-Path $desktopPath 'OU_Membership'
New-Item -Path $outRoot -ItemType Directory -Force | Out-Null

# Get all OUs
$ous = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName, DistinguishedName, Name |
       Sort-Object CanonicalName, Name

$index = 0
foreach ($ou in $ous) {
    $index++
    $ouName = if ($ou.CanonicalName) { $ou.CanonicalName } else { $ou.Name }

    # Safe, unique filename
    $safeBase = Safe-FileName -Name $ouName -Index $index
    $file     = Join-Path $outRoot "$safeBase.csv"
    if (Test-Path -LiteralPath $file) {
        $file = Join-Path $outRoot "$safeBase`_$index.csv"
    }

    Write-Host "[$index/$($ous.Count)] OU: $ouName"
    $dn = $ou.DistinguishedName

    # Collect direct children (SearchScope OneLevel)
    $users = Get-ADUser -SearchBase $dn -SearchScope OneLevel -Filter * -Properties DisplayName, UserPrincipalName, SamAccountName, Enabled -ErrorAction SilentlyContinue
    $groups = Get-ADGroup -SearchBase $dn -SearchScope OneLevel -Filter * -Properties SamAccountName -ErrorAction SilentlyContinue
    $computers = Get-ADComputer -SearchBase $dn -SearchScope OneLevel -Filter * -Properties SamAccountName, Enabled -ErrorAction SilentlyContinue
    $contacts = Get-ADObject -SearchBase $dn -SearchScope OneLevel -LDAPFilter '(objectClass=contact)' -Properties name, displayName, mail, distinguishedName -ErrorAction SilentlyContinue

    $rows = @()

    if ($users) {
        $rows += $users | ForEach-Object {
            $display = $null
            if ($_.DisplayName) {
                $trim = $_.DisplayName.Trim()
                if ($trim) { $display = $trim }
            }
            if (-not $display) { $display = $_.Name }
            [PSCustomObject]@{
                Name               = $display
                UserPrincipalName  = $_.UserPrincipalName
                SamAccountName     = $_.SamAccountName
                DistinguishedName  = $_.DistinguishedName
                ObjectClass        = 'user'
                Enabled            = $_.Enabled
            }
        }
    }

    if ($groups) {
        $rows += $groups | ForEach-Object {
            [PSCustomObject]@{
                Name               = $_.Name
                UserPrincipalName  = $null
                SamAccountName     = $_.SamAccountName
                DistinguishedName  = $_.DistinguishedName
                ObjectClass        = 'group'
                Enabled            = $null
            }
        }
    }

    if ($computers) {
        $rows += $computers | ForEach-Object {
            [PSCustomObject]@{
                Name               = $_.Name
                UserPrincipalName  = $null
                SamAccountName     = $_.SamAccountName
                DistinguishedName  = $_.DistinguishedName
                ObjectClass        = 'computer'
                Enabled            = $_.Enabled
            }
        }
    }

    if ($contacts) {
        $rows += $contacts | ForEach-Object {
            $display = $null
            if ($_.displayName) {
                $trim = $_.displayName.Trim()
                if ($trim) { $display = $trim }
            }
            if (-not $display) { $display = $_.Name }
            [PSCustomObject]@{
                Name               = $display
                UserPrincipalName  = $_.mail
                SamAccountName     = $null
                DistinguishedName  = $_.DistinguishedName
                ObjectClass        = 'contact'
                Enabled            = $null
            }
        }
    }

    # Ensure column order and export
    $rows |
        Select-Object Name, UserPrincipalName, SamAccountName, DistinguishedName, ObjectClass, Enabled |
        Sort-Object Name |
        Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
}

Write-Host "Done. Files saved to: $outRoot"