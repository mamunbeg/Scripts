#--------------------------------------------------------------------------------
# Name : Set Desktop Background using CSP Personalization feature
# Credits : https://www.thelazyadministrator.com
#--------------------------------------------------------------------------------

$DownloadUrl = "https://www.capellan.one/artwork/Capellan_Wallpaper_Black.jpg"  #Change as per your needs
$ImageFolder = "C:\Windows\Web\Capellan"
$ImageFile = "Capellan_Wallpaper.jpg"
$StatusValue = "1"
$ImageValue = Join-Path -Path $ImageFolder -ChildPath $ImageFile

$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
$ImagePath = "DesktopImagePath"
$ImageStatus = "DesktopImageStatus"
$ImageUrl = "DesktopImageUrl"

if (!(Test-Path -Path $ImageFolder)) {
    New-Item -ItemType Directory -Path $ImageFolder
}
Invoke-WebRequest $DownloadUrl -OutFile $ImageValue

if (!(Test-Path $RegKeyPath)) {
    New-Item -Path $RegKeyPath -Force | Out-Null 
}

New-ItemProperty -Path $RegKeyPath -Name $ImagePath -Value $ImageValue -PropertyType STRING -Force | Out-Null
New-ItemProperty -Path $RegKeyPath -Name $ImageStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RegKeyPath -Name $ImageUrl -Value $ImageValue -PropertyType STRING -Force | Out-Null

RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters 1, True
