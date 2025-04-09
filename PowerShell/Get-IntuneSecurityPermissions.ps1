<#
.SYNOPSIS
    Reports Intune security-related policy assignments including inclusion/exclusion status
.DESCRIPTION
    Identifies security policies across different Intune policy types and shows group assignments
.NOTES
    Version: 3.0
    Date: 2025-04-08
#>

function Get-DesktopPath {
    $path = [Environment]::GetFolderPath("Desktop")
    if (-not (Test-Path -Path $path)) {
        $path = [Environment]::GetFolderPath("UserProfile")
    }
    return $path
}

function Get-AllSecurityRelatedPolicies {
    try {
        # Initialize array for all policies
        $allPolicies = @()

        # Get Device Configuration Policies (many security settings are here)
        $configPolicies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -ErrorAction SilentlyContinue
        if ($configPolicies.value) {
            foreach ($policy in $configPolicies.value) {
                $allPolicies += [PSCustomObject]@{
                    PolicyName = $policy.displayName
                    PolicyType = $policy.'@odata.type'.Split('.')[-1]
                    PolicyId = $policy.id
                    Category = "Device Configuration"
                    Endpoint = "deviceManagement/deviceConfigurations"
                }
            }
        }

        # Get Device Compliance Policies
        $compliancePolicies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" -ErrorAction SilentlyContinue
        if ($compliancePolicies.value) {
            foreach ($policy in $compliancePolicies.value) {
                $allPolicies += [PSCustomObject]@{
                    PolicyName = $policy.displayName
                    PolicyType = $policy.'@odata.type'.Split('.')[-1]
                    PolicyId = $policy.id
                    Category = "Device Compliance"
                    Endpoint = "deviceManagement/deviceCompliancePolicies"
                }
            }
        }

        # Get Administrative Templates (Group Policy)
        $adminTemplates = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" -ErrorAction SilentlyContinue
        if ($adminTemplates.value) {
            foreach ($policy in $adminTemplates.value) {
                $allPolicies += [PSCustomObject]@{
                    PolicyName = $policy.displayName
                    PolicyType = "AdministrativeTemplate"
                    PolicyId = $policy.id
                    Category = "Group Policy"
                    Endpoint = "deviceManagement/groupPolicyConfigurations"
                }
            }
        }

        return $allPolicies
    }
    catch {
        Write-Host "Error retrieving policies: $_" -ForegroundColor Red
        return $null
    }
}

function Get-PolicyAssignments {
    param(
        [string]$policyId,
        [string]$endpoint
    )
    try {
        $assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/$endpoint/$policyId/assignments" -ErrorAction SilentlyContinue
        return $assignments.value
    }
    catch {
        Write-Host "Error retrieving assignments for policy $policyId : $_" -ForegroundColor DarkYellow
        return $null
    }
}

# Main script
try {
    # Clear existing Graph connections
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    # Install and import required modules
    $modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement", "Microsoft.Graph.DeviceManagement")
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        }
        Import-Module $module -Force -ErrorAction Stop
    }

    # Connect to Graph with required permissions
    Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All", "Group.Read.All" -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph" -ForegroundColor Green

    # Get target group
    $groupName = Read-Host "Enter the exact name of the Azure AD group"
    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction Stop
    if (-not $group) {
        throw "Group '$groupName' not found"
    }
    Write-Host "Found group: $($group.DisplayName) (ID: $($group.Id))" -ForegroundColor Cyan

    # Get all security-related policies
    $allPolicies = Get-AllSecurityRelatedPolicies
    if (-not $allPolicies) {
        throw "No security-related policies found or unable to retrieve them"
    }

    $results = @()
    
    foreach ($policy in $allPolicies) {
        Write-Host "Checking policy: $($policy.PolicyName) ($($policy.Category))" -ForegroundColor DarkCyan
        
        $assignments = Get-PolicyAssignments -policyId $policy.PolicyId -endpoint $policy.Endpoint
        if (-not $assignments) {
            continue
        }

        foreach ($assignment in $assignments) {
            $assignmentInfo = $null
            
            # Check for inclusion/exclusion
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
                    PolicyName = $policy.PolicyName
                    PolicyType = $policy.Category
                    DetailedType = $policy.PolicyType
                    AssignmentIntent = $assignment.intent
                    InclusionStatus = $assignmentInfo.Status
                    TargetType = $assignmentInfo.TargetType
                    PolicyId = $policy.PolicyId
                    AssignmentId = $assignment.id
                }
            }
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "No relevant security policy assignments found for this group." -ForegroundColor Yellow
        exit
    }

    # Display results with color coding
    $results | Sort-Object PolicyType, PolicyName | ForEach-Object {
        $color = if ($_.InclusionStatus -eq "Included") { "Green" } else { "Red" }
        Write-Host "$($_.PolicyName) ($($_.PolicyType))" -ForegroundColor Cyan
        Write-Host "  Type: $($_.DetailedType)"
        Write-Host "  Intent: $($_.AssignmentIntent), Status: $($_.InclusionStatus)" -ForegroundColor $color
        Write-Host "  Target: $($_.TargetType)"
        Write-Host "  Policy ID: $($_.PolicyId)`n"
    }

    # Export option
    if ((Read-Host "Export to CSV? (Y/N)") -match "^[yY]") {
        $csvPath = Join-Path (Get-DesktopPath) "IntuneSecurityAssignments_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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