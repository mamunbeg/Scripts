@echo off
REM Import into Autopilot (requires admin)
color 0b

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please right-click and select "Run as administrator".
    pause
    goto :eof
)

REM Check for internet connectivity to Microsoft before running AutoPilot import
echo Checking internet connectivity to Microsoft services...
ping -n 2 login.microsoftonline.com >nul 2>&1
if %errorLevel% neq 0 (
    echo Unable to reach Microsoft services. Please check your internet connection and try again.
    pause
    goto :eof
)

echo.
echo Importing device information into Windows Autopilot online...
echo This may take a few minutes. Please wait...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Install-Script -Name Get-WindowsAutopilotInfo -Force; Get-WindowsAutopilotInfo -Online"
echo.

echo Select when to reboot:
echo   1) 5 minutes (default)
echo   2) 10 minutes
echo   3) 15 minutes
set /p choice="Enter your choice (1,2,3) or Enter for default: "

set reboot_seconds=300
if "%choice%"=="2" set reboot_seconds=600
if "%choice%"=="3" set reboot_seconds=900
set /a reboot_minutes=reboot_seconds/60

echo AutoPilot import complete. Scheduling reboot in %reboot_minutes% minutes...
shutdown /r /t %reboot_seconds% /c "System will reboot in %reboot_minutes% minutes after AutoPilot script execution."
