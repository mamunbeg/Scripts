#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Creates Active Directory groups based on folder names with different access levels.

.DESCRIPTION
    This script reads folder names from a specified directory and creates three types of AD groups for each folder:
    - Full Access group (suffix: _FullAccess)
    - Read Only group (suffix: _ReadOnly)
    - No Access group (suffix: _NoAccess)

.PARAMETER FolderPath
    The path to the directory containing folders to process.

.PARAMETER GroupOUPath
    The Distinguished Name of the OU where groups will be created. If not specified, groups will be created in the default Groups container.

.PARAMETER GroupPrefix
    Optional prefix to add to all group names (default: empty).

.EXAMPLE
    .\Create-ADGroupsFromFolders.ps1 -FolderPath "C:\Shared\Departments"
    
.EXAMPLE
    .\Create-ADGroupsFromFolders.ps1 -FolderPath "C:\Shared\Projects" -GroupOUPath "OU=Security Groups,DC=domain,DC=com" -GroupPrefix "Proj_"

.NOTES
    Author: Generated Script
    Version: 1.0
    Requires: Active Directory PowerShell Module
    Requires: Sufficient permissions to create AD groups
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if (Test-Path $_ -PathType Container) {
            $true
        } else {
            throw "The specified folder path '$_' does not exist or is not a directory."
        }
    })]
    [string]$FolderPath,
    
    [Parameter(Mandatory = $false)]
    [string]$GroupOUPath,
    
    [Parameter(Mandatory = $false)]
    [string]$GroupPrefix = ""
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import Active Directory module. Please ensure it's installed and you have appropriate permissions."
    exit 1
}

# Function to create AD group
function New-ADSecurityGroup {
    param(
        [string]$GroupName,
        [string]$Description,
        [string]$Path
    )
    
    try {
        $groupParams = @{
            Name = $GroupName
            GroupScope = 'Global'
            GroupCategory = 'Security'
            Description = $Description
        }
        
        if ($Path) {
            $groupParams.Path = $Path
        }
        
        if ($PSCmdlet.ShouldProcess($GroupName, "Create AD group")) {
            New-ADGroup @groupParams
            Write-Host "Created group: $GroupName" -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would create group '$GroupName' with description '$Description'" -ForegroundColor Yellow
            if ($Path) {
                Write-Host "WHATIF: Group would be created in OU: $Path" -ForegroundColor Yellow
            }
        }
        
        return $true
    } catch {
        Write-Warning "Failed to create group '$GroupName': $($_.Exception.Message)"
        return $false
    }
}

# Function to validate OU path
function Test-OUPath {
    param([string]$Path)
    
    if ([string]::IsNullOrEmpty($Path)) {
        return $true
    }
    
    try {
        Get-ADOrganizationalUnit -Identity $Path -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-Warning "Specified OU path '$Path' does not exist or is not accessible."
        return $false
    }
}

# Main script execution
Write-Host "Starting AD Group Creation Script" -ForegroundColor Cyan
Write-Host "Folder Path: $FolderPath" -ForegroundColor White
Write-Host "Group Prefix: '$GroupPrefix'" -ForegroundColor White

if ($GroupOUPath) {
    Write-Host "Target OU: $GroupOUPath" -ForegroundColor White
    if (-not (Test-OUPath -Path $GroupOUPath)) {
        Write-Error "Invalid OU path specified. Exiting."
        exit 1
    }
}

# Get all folders in the specified directory
try {
    $folders = Get-ChildItem -Path $FolderPath -Directory -ErrorAction Stop
    Write-Host "Found $($folders.Count) folders to process." -ForegroundColor White
} catch {
    Write-Error "Failed to read folders from '$FolderPath': $($_.Exception.Message)"
    exit 1
}

if ($folders.Count -eq 0) {
    Write-Warning "No folders found in the specified directory."
    exit 0
}

# Initialize counters
$successCount = 0
$failureCount = 0
$totalGroups = $folders.Count * 3

Write-Host "`nProcessing folders..." -ForegroundColor Cyan

foreach ($folder in $folders) {
    $folderName = $folder.Name
    Write-Host "`nProcessing folder: $folderName" -ForegroundColor White
    
    # Clean folder name for group name (remove invalid characters, including apostrophes and &)
    $cleanFolderName = $folderName -replace "[&'\W]", ''
    
    # Define group names with prefix
    $baseGroupName = "$GroupPrefix$cleanFolderName"
    
    $groups = @(
        @{
            Name = "${baseGroupName}_FullAccess"
            Description = "Full Access to $folderName folder"
        },
        @{
            Name = "${baseGroupName}_ReadOnly"
            Description = "Read Only access to $folderName folder"
        },
        @{
            Name = "${baseGroupName}_NoAccess"
            Description = "No Access (Deny) to $folderName folder"
        }
    )
    
    # Create each group
    foreach ($group in $groups) {
        # Check if group already exists
        try {
            $existingGroup = Get-ADGroup -Identity $group.Name -ErrorAction Stop
            Write-Warning "Group '$($group.Name)' already exists. Skipping."
            continue
        } catch {
            # Group doesn't exist, proceed with creation
        }
        
        $success = New-ADSecurityGroup -GroupName $group.Name -Description $group.Description -Path $GroupOUPath
        
        if ($success) {
            $successCount++
        } else {
            $failureCount++
        }
    }
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "SCRIPT EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "Total folders processed: $($folders.Count)" -ForegroundColor White
Write-Host "Total groups to create: $totalGroups" -ForegroundColor White
Write-Host "Groups created successfully: $successCount" -ForegroundColor Green
Write-Host "Groups failed to create: $failureCount" -ForegroundColor Red

if ($failureCount -gt 0) {
    Write-Host "`nPlease review the warnings above for details about failed group creations." -ForegroundColor Yellow
}

Write-Host "`nScript execution completed." -ForegroundColor Cyan
