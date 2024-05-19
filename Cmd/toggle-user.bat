@echo off
title Toggle username on login
echo This script will show/hide a selected user on the login screen
echo.
color 0b

:: BatchGetAdmin
::-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"="
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
::--------------------------------------

::ENTER YOUR CODE BELOW:

:userlist
set "UserList="
set Users="dir C:\Users\ /B"
setlocal enableDelayedExpansion
for /F "tokens=1*" %%A IN ('%Users%') DO (
    set "Name=%%A"
    if /I "!NAME!" NEQ "Administrator" (
        if /I "!NAME!" NEQ "Public" (
            if /I "!NAME!" NEQ !USERNAME! (
                set "UserList=!UserList! "
                set "UserList=!UserList!%%A"

            )
        )
    )
)
echo List of users on this machine: %UserList%
echo.

:selectuser
set /p SelectUser=Enter username from above list to show/hide on login screen: 
echo %UserList% |findstr /i "\<%SelectUser%\>" >nul 2>&1
if %errorlevel% equ 1 (echo Username entered is not valid on this machine & timeout /T 10 & exit)

:showhide
set ToggleList="1" "0"
set /p Toggle=Enter "1" to show or "0" to hide %SelectUser% account: 
echo %ToggleList% |findstr /i "\<%Toggle%\>" >nul 2>&1
if %errorlevel% equ 1 (echo Value entered is not valid & timeout /T 10 & exit)
echo Will toggle user visibility on login screen now . . .

:tweakregistry
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v %SelectUser% /t REG_DWORD /d %Toggle%

timeout /T 10
exit