@echo off
title Apply permissions on file or folder
echo This script will set permissions on file(s) or folder(s)
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

:: Reset variables
set "folderPath="
set "UserAssign="
set "ownerAction="
set "inheritAction="
set "inheritLevel="
set "permAction="
set "permLevel="
set "depth="
set "access="

:pathuser
set /P folderPath=Enter the path to the file/folder whose permissions you want to change: 
set /P UserAssign=Enter the username that you want to assign permissions for: 

REM test data --------------------------

:: set "folderPath=C:\Users\Public\TESTFOLDER\Folder"
:: set "UserAssign=MamunBeg"

REM test data --------------------------

:owner
choice /C:NY /D N /T 10 /M "Do you want to change the owner"
if %errorlevel% EQU 1 (set "ownerAction=")
if %errorlevel% EQU 2 (set "ownerAction=/setowner" & goto setowner)

:inheritaction
choice /C:NY /D N /T 10 /M "Do you want to change inherited permissions from parent folders"
if %errorlevel% EQU 1 (set "inheritAction=" & set "inheritance=" & goto permaction)
if %errorlevel% EQU 2 (set "inheritAction=/inheritance" & goto inheritperm)

:inheritperm
choice /C:EDR /D E /T 10 /N /M "Do you want to [E]nable inherited permissions, [D]isable and copy permissions or [R]emove inherited permissions?"
if %errorlevel% EQU 1 (set "inheritLevel=:e")
if %errorlevel% EQU 2 (set "inheritLevel=:d")
if %errorlevel% EQU 3 (set "inheritLevel=:r")
goto permaction

:permaction
choice /C:GDR /D G /T 10 /N /M "Do you want to [G]rant, [D]eny or [R]emove permissions?"
if %errorlevel% EQU 1 (set "permAction=/grant" & goto grantperm)
if %errorlevel% EQU 2 (set "permAction=/deny" & goto denyperm)
if %errorlevel% EQU 3 (set "permAction=/remove" & goto removeperm)

:grantperm
choice /C:AR /D A /T 10 /N /M "Do you want to [A]dd or [R]eplace permissions?"
if %errorlevel% EQU 1 (set "permLevel=")
if %errorlevel% EQU 2 (set "permLevel=:r")
goto depthaccess

:denyperm
set "permLevel="
goto depthaccess

:removeperm
choice /C:GD /D G /T 10 /N /M "Do you want to remove [G]ranted or [D]enied permissions?"
if %errorlevel% EQU 1 (set "permLevel=:g")
if %errorlevel% EQU 2 (set "permLevel=:d")
goto setperm

:depthaccess
choice /C:TS /D T /T 10 /N /M "Do you want to apply permissions to [T]his folder only or also to [S]ubfolders?"
if %errorlevel% EQU 1 (set "depth=:(OI)")
if %errorlevel% EQU 2 (set "depth=:(OI)(CI)")
choice /C:FMRWXDN /D X /T 10 /N /M "Type of access to allow is [F]ull, [M]odify, [R]ead, [W]rite, read and e[X]ecute, [D]elete, [N]o access:"
if %errorlevel% EQU 1 (set "access=(F)")
if %errorlevel% EQU 2 (set "access=(M)")
if %errorlevel% EQU 3 (set "access=(R)")
if %errorlevel% EQU 4 (set "access=(W)")
if %errorlevel% EQU 5 (set "access=(X)")
if %errorlevel% EQU 6 (set "access=(D)")
if %errorlevel% EQU 7 (set "access=(N)")
goto setperm

:setperm
echo Assigning permissions for %UserAssign%
icacls %folderPath% %inheritAction%%inheritLevel% %permAction%%permLevel% "%UserAssign%"%depth%%access% /C
timeout /T 10 & exit

:setowner
echo Assigning ownership to %UserAssign%
icacls %folderPath% %ownerAction% "%UserAssign%" /C
timeout /T 10 & exit
