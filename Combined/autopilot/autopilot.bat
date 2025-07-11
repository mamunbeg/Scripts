pushd "%~dp0"
color 0b

echo.
echo Enroling device into Autopilot. Please be patient as it may take some time to complete.

powershell -ExecutionPolicy Bypass -File .\AutoPilotOnline.ps1

popd