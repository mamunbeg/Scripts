#--------------------------------------------------------------------------------
# Name : Set Desktop Background using CSP Personalization feature
#--------------------------------------------------------------------------------

$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

$DesktopPath = "DesktopImagePath"
$DesktopStatus = "DesktopImageStatus"
$DesktopUrl = "DesktopImageUrl"

$StatusValue = "1"
$DesktopImageValue = "C:\Windows\Web\Lenovo\Think_Black.jpg"  #Change as per your needs

if (!(Test-Path $RegKeyPath)) { Write-Host "Creating registry path $($RegKeyPath)." 
New-Item -Path $RegKeyPath -Force | Out-Null 
}
New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $Statusvalue -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null

RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters 1, True