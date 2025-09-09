<#
.SYNOPSIS
Reinstall a set of PowerShell modules into the AllUsers scope.

.DESCRIPTION
This script ensures a curated list of modules is installed for all users on the system.
It is intended to be run with elevated (Administrator) privileges. The script:
 - Checks the current process has admin rights.
 - Uninstalls any copies of the module found in the current user's profile (best-effort cleanup).
 - Installs the module into the AllUsers scope (or falls back to the default Install-Module behaviour on older systems).

USAGE
 - Run PowerShell as Administrator and execute this script.
 - The script will attempt to install modules from PSGallery and will overwrite existing installations.

NOTES
 - This script prefers AllUsers installations and will exit early if not run as admin.
 - It detects whether the local PowerShellGet supports the -Scope parameter and adapts accordingly.
 - No modules are installed to CurrentUser by design.
#>

# require-admin helper
function Test-IsAdmin { ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# Immediately stop execution if not running as Administrator.
# Installing into AllUsers requires elevated privileges; fail-fast to avoid partial state.
if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with administrator privileges to install modules for all users. Please re-run as an administrator."
    exit 1
}

# Helper: check whether a cmdlet supports a named parameter on this system.
# This allows the script to be compatible with older/newer PowerShellGet versions.
function Test-Parameter {
    param(
        [Parameter(Mandatory=$true)][string]$CommandName,
        [Parameter(Mandatory=$true)][string]$ParameterName
    )
    $cmd = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    return $cmd.Parameters.ContainsKey($ParameterName)
}

# List of modules to ensure are installed for AllUsers.
# Update this array to add/remove modules you want managed by the script.
$modules = @(
    "ExchangeOnlineManagement",
    "Microsoft.Graph",
    "PnP.PowerShell",
    "PowerShellGet"
)

foreach ($module in $modules) {
    Write-Host "`n🔄 Processing module: $module"
    try {
        # Attempt to find any installed instances in the CurrentUser scope to remove them.
        # This is a cleanup step to avoid conflicts between user-scoped and system-scoped installs.
        if (Test-Parameter -CommandName 'Get-InstalledModule' -ParameterName 'Scope') {
            # Modern PowerShellGet supports -Scope; query CurrentUser explicitly.
            $installedCU = Get-InstalledModule -Name $module -Scope CurrentUser -ErrorAction SilentlyContinue
        } else {
            # Older PowerShellGet does not support -Scope. Get all installed modules and
            # do a best-effort filter to identify those in the user's profile path.
            $installedCU = Get-InstalledModule -Name $module -ErrorAction SilentlyContinue
            if ($installedCU) {
                $installedCU = $installedCU | Where-Object { $_.InstalledLocation -like "$env:USERPROFILE*" }
            }
        }

        if ($installedCU) {
            Write-Host "🗑 Uninstalling $module from CurrentUser scope..."
            # Only remove the specific versions discovered during the query above.
            $installedCU | ForEach-Object { Uninstall-Module -Name $_.Name -RequiredVersion $_.Version -Force -ErrorAction Stop }
        } else {
            Write-Host "ℹ️ $module not found in CurrentUser scope."
        }

        # Install the module into AllUsers. The script assumes it is running as administrator.
        # If the local Install-Module supports -Scope we explicitly request AllUsers; otherwise
        # we fall back to Install-Module without -Scope which will typically install to AllUsers when elevated.
        if (Test-Parameter -CommandName 'Install-Module' -ParameterName 'Scope') {
            Write-Host "📦 Installing $module in AllUsers scope..."
            Install-Module -Name $module -Scope AllUsers -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
        } else {
            Write-Host "📦 Installing $module (no -Scope available, will install for AllUsers as admin)..."
            Install-Module -Name $module -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
        }

        Write-Host "✅ $module successfully installed for AllUsers."
    } catch {
        # Catch any errors per-module so the script can continue processing the remaining modules.
        Write-Warning "⚠️ Failed to process $($module): $($_.Exception.Message)"
    }
}
