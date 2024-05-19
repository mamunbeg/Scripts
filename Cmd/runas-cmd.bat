@echo off
title Run CMD as user
echo This script will run CMD as a selected user
echo.
color 0b

:authtype
choice /C:123 /D 1 /T 10 /N /M "How does this computer authenticate: 1. Workgroup/Local Machine 2. Domain 3. Azure AD: "
if %errorlevel% EQU 1 (set AuthType=%COMPUTERNAME%)
if %errorlevel% EQU 2 (set AuthType=%DOMAIN%)
if %errorlevel% EQU 3 (set AuthType=AzureAD)

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
set /P SelectUser=Enter username from above list to run CMD as: 
echo %UserList% | findstr /i "\<%SelectUser%\>" >nul 2>&1
if %errorlevel% EQU 1 (echo Username entered is not valid on this machine & timeout /T 10 & exit)

:runascmd
runas /user:%AuthType%\%SelectUser% cmd

timeout /T 10
exit