Powershell.exe Get-AppxPackage -AllUsers | Remove-AppxPackage
Powershell.exe Get-AppxPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register “$($_.InstallLocation)\AppXManifest.xml”}
C:\Windows\System32\Sysprep\sysprep.exe