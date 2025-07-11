@echo off
set /p folder=Enter folder path: 
if not exist "%folder%" (
    echo Folder not found!
    pause
    exit
)

echo Searching for ~$ files in "%folder%"...
forfiles /p "%folder%" /s /m "~$*" /c "cmd /c echo @path"

set /p confirm=Do you want to delete these files? (Y/N): 
if /i "%confirm%"=="Y" (
    echo Removing Hidden, Read-Only, and System Attributes...
    forfiles /p "%folder%" /s /m "~$*" /c "cmd /c attrib -h -r -s @file"

    echo Deleting Files...
    forfiles /p "%folder%" /s /m "~$*" /c "cmd /c del /f /q @file" >nul 2>&1

    echo All ~$ files deleted successfully!
) else (
    echo Operation cancelled!
)

pause