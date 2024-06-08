@echo OFF
title Application install script
echo Installing applications. Please be patient as it may take some time to complete.
echo.
color 0b

pushd "%~dp0"

powershell Add-AppxPackage https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

winget install --id Microsoft.Office --scope machine --override "/configure ./configuration_OfficeProPlus-x64_capellan.xml"
winget install --id Microsoft.VCRedist.2015+.x64 --scope machine
winget install --id Google.Drive --scope machine
winget install --id Microsoft.RemoteDesktopClient --scope machine
winget install --id Microsoft.PowerShell --scope machine
winget install --id Microsoft.PowerToys --scope machine
winget install --id Transmission.Transmission --scope machine
winget install --id Mozilla.Firefox.ESR --scope machine
winget install --id 7zip.7zip --scope machine
winget install --id Notepad++.Notepad++ --scope machine
winget install --id JAMSoftware.TreeSize.Free --scope machine
winget install --id PuTTY.PuTTY --scope machine
winget install --id angryziber.AngryIPScanner --scope machine
winget install --id WinSCP.WinSCP --scope machine
winget install --id WinMerge.WinMerge --scope machine
winget install --id WiresharkFoundation.Wireshark --scope machine
winget install --id Microsoft.VisualStudioCode --scope machine
winget install --id Git.Git --scope machine
winget install --id VMware.WorkstationPro --scope machine
REM winget install --id SonicWALL.NetExtender
REM winget install --id SonicWALL.GlobalVPN