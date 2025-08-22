@echo off
REM Set UK keyboard and time settings then import into Autopilot (requires admin)
pushd "%~dp0"
color 0b

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
	echo This script requires administrator privileges.
	echo Please right-click and select "Run as administrator".
	pause
	exit /b
)

echo.
echo Setting UK keyboard layout...
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\Locale" /v "Default" /t REG_SZ /d "00000809" /f >nul
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scanline Map" /t REG_BINARY /d "00000000" /f >nul
powershell -command "Set-WinUserLanguageList -LanguageList en-GB -Force"

echo Setting UK time zone (GMT/BST)...
tzutil /s "GMT Standard Time"

echo Setting UK date format (dd/MM/yyyy)...
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sShortDate" /t REG_SZ /d "dd/MM/yyyy" /f >nul

echo Synchronizing time...
net stop w32time >nul
net start w32time >nul
w32tm /resync /force >nul

echo UK settings have been configured successfully.
echo You may need to log off and back on for all changes to take effect.
echo.
popd

REM Check for internet connectivity to Microsoft before running AutoPilot import
echo Checking internet connectivity to Microsoft services...
ping -n 2 login.microsoftonline.com >nul 2>&1
if %errorLevel% neq 0 (
	echo Unable to reach Microsoft services. Please check your internet connection and try again.
	pause
	exit /b
)

echo.
REM Bypass PowerShell execution policy and import device into Autopilot
echo Importing device information into Windows Autopilot online...
echo This may take a few minutes. Please wait...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned; Install-Script -Name Get-WindowsAutopilotInfo -Force; Get-WindowsAutopilotInfo -Online"
echo.
REM Wait 5 minutes (300 seconds) then reboot
echo AutoPilot import complete. Scheduling reboot in 5 minutes...
shutdown /r /t 300 /c "System will reboot in 5 minutes after AutoPilot script execution."
