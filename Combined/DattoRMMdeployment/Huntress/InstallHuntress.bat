@echo off

rem This batch file was created as a wrapper for RMM tools that support Powershell scripts, but don't give the option to control the
rem executionpolicy options and/or pass arguments. 

rem This requires InstallHuntress.powershellv2.1.ps1 dated 10 July 2025 !
rem You can always find the most updated version here: https://github.com/huntresslabs/deployment-scripts/tree/main/Powershell

rem ACCTKEY, ORGKEY, TAGS, REREG, REINST, and UNINST must be set as environment variables before running this script.

rem Some RMM agents are 32-bit only, so they will start 32-bit Powershell. If the 64-bit Powershell exists, we'll use that.
set POWERSHELL=powershell
if exist %SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe (
    set POWERSHELL=%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe
)

rem Create log directory if it doesn't exist
if not exist "C:\Program Files\Huntress" mkdir "C:\Program Files\Huntress"
set LOGFILE="C:\Program Files\Huntress\InstallHuntressSettings.log"

rem Delete existing log file to ensure overwrite
if exist %LOGFILE% del %LOGFILE%

set ARGS=-acctkey %ACCTKEY% -orgkey %ORGKEY%
if defined TAGS set ARGS=%ARGS% -tags %TAGS%
if /I "%REREG%"=="true" set ARGS=%ARGS% -reregister
if /I "%REINST%"=="true" set ARGS=%ARGS% -reinstall
if /I "%UNINST%"=="true" set ARGS=%ARGS% -uninstall

rem Log the command and environment variables (settings only, not PS output)
(
    echo ==== InstallHuntress.bat started: %DATE% %TIME% ====
    echo ACCTKEY: %ACCTKEY%
    echo ORGKEY: %ORGKEY%
    echo TAGS: %TAGS%
    echo REREG: %REREG%
    echo REINST: %REINST%
    echo UNINST: %UNINST%
    echo Command: %POWERSHELL% -executionpolicy bypass -f ./InstallHuntress.powershellv2.1.ps1 %ARGS%
) > %LOGFILE%

rem Run the PowerShell script (it handles its own logging)
%POWERSHELL% -executionpolicy bypass -f ./InstallHuntress.powershellv2.1.ps1 %ARGS%

:END