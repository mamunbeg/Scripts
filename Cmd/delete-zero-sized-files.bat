@echo off
set /p folder=Enter folder path: 
if not exist "%folder%" (
    echo Folder not found!
    pause
    exit
)

echo Searching for files with 0KB size in "%folder%"...
forfiles /p "%folder%" /s /m *.* /c "cmd /c if @fsize==0 echo @path"

set /p confirm=Do you want to delete these files? (Y/N): 
if /i "%confirm%"=="Y" (
    echo Removing Hidden, Read-Only, and System Attributes from 0KB files...
    forfiles /p "%folder%" /s /m *.* /c "cmd /c if @fsize==0 attrib -h -r -s @file"

    echo Deleting 0KB Files...
    forfiles /p "%folder%" /s /m *.* /c "cmd /c if @fsize==0 del /f /q @file" >nul 2>&1

    echo All 0KB files deleted successfully!
) else (
    echo Operation cancelled!
)

pause
