@echo OFF
title Set region and Autopilot pre-provision
pushd "%~d0"

call .\support\autopilot\SetUKSettings.bat

call .\support\autopilot\autopilot.bat
pause

call .\support\autopilot\reboot15.bat

popd
exit