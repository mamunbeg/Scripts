# Check if Microsoft Office shortcuts exist in common Start Menu and create if not

# Set working paths
$apppath = "C:\Program Files\Microsoft Office\root\Office16"
# $linkpath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
# $toolspath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office Tools"
$linkpath = "C:\Users\Public\Desktop"
$toolspath = "C:\Users\Public\Desktop\Microsoft Office Tools"
if (!(test-path -PathType container $toolspath)) {
      New-Item -ItemType Directory -Path $toolspath
}

# Main Microsoft 365 Applications

# Excel
Test-Path "$apppath\EXCEL.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$linkpath\Excel.lnk")
$Shortcut.TargetPath = "$apppath\EXCEL.EXE"
$Shortcut.Save()

# OneNote
Test-Path "$apppath\ONENOTE.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$linkpath\OneNote.lnk")
$Shortcut.TargetPath = "$apppath\ONENOTE.EXE"
$Shortcut.Save()

# Outlook
Test-Path "$apppath\OUTLOOK.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$linkpath\Outlook.lnk")
$Shortcut.TargetPath = "$apppath\OUTLOOK.EXE"
$Shortcut.Save()

# PowerPoint
Test-Path "$apppath\POWERPNT.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$linkpath\PowerPoint.lnk")
$Shortcut.TargetPath = "$apppath\POWERPNT.EXE"
$Shortcut.Save()

# Word
Test-Path "$apppath\WINWORD.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$linkpath\Word.lnk")
$Shortcut.TargetPath = "$apppath\WINWORD.EXE"
$Shortcut.Save()

# Microsoft Office Tools

# Office Language Preferences
Test-Path "$apppath\SETLANG.EXE"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$toolspath\Office Language Preferences.lnk")
$Shortcut.TargetPath = "$apppath\SETLANG.EXE"
$Shortcut.Save()

# Telemetry Log for Office
Test-Path "$apppath\msoev.exe"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$toolspath\Telemetry Log for Office.lnk")
$Shortcut.TargetPath = "$apppath\msoev.exe"
$Shortcut.Save()

# Database Compare
Test-Path "C:\Program Files\Microsoft Office\root\Client\AppVLP.exe"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$toolspath\Database Compare.lnk")
$Shortcut.TargetPath = `"C:\Program Files\Microsoft Office\root\Client\AppVLP.exe`" `"C:\Program Files (x86)\Microsoft Office\Office16\DCF\DATABASECOMPARE.EXE`"
$Shortcut.Save()

# Spreadsheet Compare
Test-Path "C:\Program Files\Microsoft Office\root\Client\AppVLP.exe"
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$toolspath\Spreadsheet Compare.lnk")
$Shortcut.TargetPath = `"C:\Program Files\Microsoft Office\root\Client\AppVLP.exe`" `"C:\Program Files (x86)\Microsoft Office\Office16\DCF\SPREADSHEETCOMPARE.EXE`"
$Shortcut.Save()
