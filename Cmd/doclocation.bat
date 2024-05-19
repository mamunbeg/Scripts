@echo OFF
setlocal enabledelayedexpansion

setlocal ENABLEEXTENSIONS
set KEY_NAME="HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
set VALUE_NAME=Personal

FOR /F "usebackq tokens=1-2*" %%A IN (`REG QUERY %KEY_NAME% /v %VALUE_NAME% 2^>nul`) DO (
    set ValueName=%%A
    set ValueType=%%B
    set ValueValue=%%C
)

set DocLocation=%ValueValue%
for /f "tokens=*" %%A in ('echo %ValueValue%') do @set DocLocation=%%A

if defined ValueName (
    @echo Documents folder is located in %DocLocation%
) else (
    @echo %KEY_NAME%\%VALUE_NAME% not found.
)

PAUSE