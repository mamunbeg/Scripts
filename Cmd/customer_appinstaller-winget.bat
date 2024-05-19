@echo OFF
title Application install script
echo Installing applications. Please be patient as it may take some time to complete.
echo.
color 0b

pushd "%~dp0"

powershell Add-AppxPackage https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

winget install --id Microsoft.Office --scope machine --override "/configure ./Configuration_Office365_x64.xml"
winget install --id Microsoft.Teams --scope machine
winget install --id Microsoft.RemoteDesktopClient --scope machine
winget install --id Google.Chrome --scope machine
winget install --id 7zip.7zip --scope machine
winget install --id Adobe.Acrobat.Reader.64-bit --scope machine
REM winget install --id SonicWALL.NetExtender
REM winget install --id SonicWALL.GlobalVPN