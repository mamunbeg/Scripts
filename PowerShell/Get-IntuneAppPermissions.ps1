<#
.SYNOPSIS
    Accurately reports Intune app assignments including inclusion/exclusion status
.DESCRIPTION
    Correctly identifies when groups are targeted as included or excluded
#>

# Function to get Desktop path
function Get-DesktopPath {
    $path = [Environment]::GetFolderPath("Desktop")
    if (-not (Test-Path -Path $path)) {
        $path = [Environment]::GetFolderPath("UserProfile")
    }
    return $path
}

# Main script
try {
    # Clear existing Graph connections
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    # Install and import required modules
    $modules = @("Microsoft.Graph", "Microsoft.Graph.Intune", "Microsoft.Graph.DeviceManagement")
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        }
        Import-Module $module -Force -ErrorAction Stop
    }

    # Connect to Graph with required permissions
    Connect-MgGraph -Scopes "DeviceManagementApps.Read.All", "Group.Read.All" -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph" -ForegroundColor Green

    # Get target group
    $groupName = Read-Host "Enter the exact name of the Azure AD group"
    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction Stop
    if (-not $group) {
        throw "Group '$groupName' not found"
    }
    Write-Host "Found group: $($group.DisplayName) (ID: $($group.Id))" -ForegroundColor Cyan

    # Get all app assignments
    $apps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments" -ErrorAction Stop

    $results = @()
    foreach ($app in $apps.value) {
        foreach ($assignment in $app.assignments) {
            $assignmentInfo = $null
            
            # Check for inclusion/exclusion in different assignment target types
            switch ($assignment.target.'@odata.type') {
                "#microsoft.graph.groupAssignmentTarget" {
                    if ($assignment.target.groupId -eq $group.Id) {
                        $assignmentInfo = @{
                            Status = "Included"
                            TargetType = "Group"
                        }
                    }
                }
                "#microsoft.graph.exclusionGroupAssignmentTarget" {
                    if ($assignment.target.groupId -eq $group.Id) {
                        $assignmentInfo = @{
                            Status = "Excluded"
                            TargetType = "Exclusion Group"
                        }
                    }
                }
                "#microsoft.graph.allLicensedUsersAssignmentTarget" {
                    $assignmentInfo = @{
                        Status = "Included"
                        TargetType = "All Users"
                    }
                }
                "#microsoft.graph.allDevicesAssignmentTarget" {
                    $assignmentInfo = @{
                        Status = "Included"
                        TargetType = "All Devices"
                    }
                }
            }

            if ($assignmentInfo) {
                $results += [PSCustomObject]@{
                    AppName = $app.displayName
                    AppType = $app.'@odata.type'.Split('.')[-1]
                    AssignmentIntent = $assignment.intent
                    InclusionStatus = $assignmentInfo.Status
                    TargetType = $assignmentInfo.TargetType
                    AppId = $app.id
                    AssignmentId = $assignment.id
                }
            }
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "No relevant assignments found for this group." -ForegroundColor Yellow
        exit
    }

    # Display results with color coding
    $results | ForEach-Object {
        $color = if ($_.InclusionStatus -eq "Included") { "Green" } else { "Red" }
        Write-Host "$($_.AppName) ($($_.AppType))" -ForegroundColor Cyan
        Write-Host "  Intent: $($_.AssignmentIntent), Status: $($_.InclusionStatus)" -ForegroundColor $color
        Write-Host "  Target: $($_.TargetType)"
        Write-Host "  App ID: $($_.AppId)`n"
    }

    # Export option
    if ((Read-Host "Export to CSV? (Y/N)") -match "^[yY]") {
        $csvPath = Join-Path (Get-DesktopPath) "IntuneAppAssignments_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Exported to $csvPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}