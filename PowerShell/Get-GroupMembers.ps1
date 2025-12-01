# Script to export list of AD groups and members of each group to CSV

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

$desktopPath = Get-DesktopPath
$folderpath  = Join-Path $desktopPath 'Group_Membership'

if (Test-Path -Path $folderpath) {
    Write-Host "Folder already exists: $folderpath"
} else {
    New-Item -Path $folderpath -ItemType Directory -Force | Out-Null
    Write-Host "Folder created: $folderpath"
}

# Export Security Groups to CSV
$groupListPath = Join-Path $folderpath 'adGroupList.csv'
Get-ADGroup -Filter 'GroupCategory -eq "Security" -and GroupScope -ne "DomainLocal"' |
    Sort-Object Name |
    Select-Object Name, Description |
    Export-Csv -Path $groupListPath -NoTypeInformation

# Create CSV for each group with members (including UPN)
Import-Csv $groupListPath | ForEach-Object {
    $groupName = $_.Name
    Write-Host "Processing group: $groupName"

    $members = Get-ADGroupMember -Identity $groupName -ErrorAction SilentlyContinue

    $output = foreach ($m in $members) {
        $upn = $null
        if ($m.objectClass -eq 'user') {
            try {
                $upn = (Get-ADUser -Identity $m.SamAccountName -Properties userPrincipalName -ErrorAction Stop).userPrincipalName
            } catch {
                $upn = $null
            }
        }
        [PSCustomObject]@{
            Name              = $m.Name
            UserPrincipalName = $upn
            SamAccountName    = $m.SamAccountName
            ObjectClass       = $m.objectClass
        }
    }

    $safeFile = ($groupName -replace '[\\/:*?"<>|]', '_') + '.csv'
    $groupPath = Join-Path $folderpath $safeFile
    $output | Sort-Object Name | Export-Csv -Path $groupPath -NoTypeInformation
}
Write-Host "Export complete. Files located in: $folderpath"
