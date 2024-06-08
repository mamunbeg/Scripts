# Create shortcut to any application in any location
# call script like this: Set-ShortCut "C:\Program Files (x86)\ColorPix\ColorPix.exe" "Arguments" "$Home\Desktop\ColorPix.lnk"

param ( [string]$SourceExe, [string]$ArgumentsToSourceExe, [string]$DestinationPath )
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()