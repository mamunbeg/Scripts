pushd "%~dp0"
color 0b

:: Batch file to set UK keyboard and time settings
:: Requires administrator privileges

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please right-click and select "Run as administrator".
    pause
    exit /b
)

echo.
echo Setting UK keyboard layout...
:: Set system locale to UK
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\Locale" /v "Default" /t REG_SZ /d "00000809" /f >nul
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scanline Map" /t REG_BINARY /d "00000000" /f >nul

:: Set input method to UK English
powershell -command "Set-WinUserLanguageList -LanguageList en-GB -Force"

echo Setting UK time zone (GMT/BST)...
:: Set time zone to UK
tzutil /s "GMT Standard Time"

echo Setting UK date format (dd/MM/yyyy)...
:: Set short date format to UK style
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sShortDate" /t REG_SZ /d "dd/MM/yyyy" /f >nul

echo Synchronizing time...
:: Restart time service and sync
net stop w32time >nul
net start w32time >nul
w32tm /resync /force >nul

echo UK settings have been configured successfully.
echo You may need to log off and back on for all changes to take effect.
echo.

popd
