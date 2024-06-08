@echo OFF
title Windows repair script
echo Running Windows repair. Please be patient as it may take some time to complete.
echo.
color 0b

C:\Windows\System32\cleanmgr.exe /sageset:1
C:\Windows\System32\cleanmgr.exe /sagerun:1
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
chkdsk C: /f