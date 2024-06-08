# Custom profile for PowerShell

# Set custom prompt
function prompt {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
  $currentfolder = Split-Path -Leaf -Path (Get-Location)

  $(if (Test-Path variable:/PSDebugContext) { Write-Host ('[DBG]: ') -NoNewline -ForegroundColor DarkYellow }
    elseif($principal.IsInRole($adminRole)) { Write-Host ("[ADMIN]: ") -NoNewline -ForegroundColor Red }
    else { '' }
  ) +
  (Write-Host ("PS [$env:COMPUTERNAME]>[" + $currentfolder + "]:") -NoNewline) +
    $(if ($NestedPromptLevel -ge 1) { '>>' }) + '> '
}

# Set Notepad++ as default editor
$editor = "$env:ProgramFiles\Notepad++\notepad++.exe"

# Edit PowerShell profiles in default editor
function Edit-ProfileAUAH {& $editor $PROFILE.AllUsersAllHosts}
function Edit-ProfileAUCH {& $editor $PROFILE.AllUsersCurrentHost}
function Edit-ProfileCUAH {& $editor $PROFILE.CurrentUserAllHosts}
function Edit-ProfileCUCH {& $editor $PROFILE.CurrentUserCurrentHost}

Set-Alias -Name pro -Value Edit-ProfileCUAH

# Edit a file in default editor
function Edit-File {
  param ([string] $file)
  & $editor $file
}

Set-Alias -Name edit -Value Edit-File

# Open default File Manager in current location
function fm {
  explorer .
}

# Retrieve IPv4 address
$env:HostIP = (
  Get-NetIPConfiguration |
  Where-Object {
    $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected"
    }
).IPv4Address.IPAddress

# Retrieve all IPv4 addresses
function Get-IPAddresses {
  Get-NetIPAddress |
    Where-Object {$_.AddressFamily -eq "IPv4"} |
      Select-Object InterfaceAlias, IPAddress
}

Set-Alias -Name ip -Value Get-IPAddresses

# List Cmdlet aliases as table
function Get-CmdletAlias {
  param ([string] $cmdletname)
  Get-Alias |
    Where-Object -FilterScript {$_.Definition -like "$cmdletname"} |
      Format-Table -Property Definition, Name -AutoSize
}

# Welcome message
"Profile loaded successfully"