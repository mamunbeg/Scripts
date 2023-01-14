@echo off
title Run CMD as user
echo This script will run CMD as a selected user
echo.
color 0b

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
set /p SelectUser=Enter username from above list to run CMD as: 
echo %UserList% |findstr /i "\<%SelectUser%\>" >nul 2>&1
if %errorlevel% equ 1 (echo Username entered is not valid on this machine & pause & exit)

:runascmd
runas /user:%SelectUser% cmd

exit