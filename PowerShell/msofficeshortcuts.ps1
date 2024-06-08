# Check if Microsoft Office shortcuts exist in common Start Menu and create if not

# Set Microsoft Office installatin path
$apppath = "C:\Program Files\Microsoft Office\root\Office16"

# Main Office 365 applications
$linkpath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"

# Excel
if (Test-Path "$apppath\EXCEL.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Excel.lnk")
      $Shortcut.TargetPath = "$apppath\EXCEL.EXE"
      $Shortcut.Save()
}

# OneNote
if (Test-Path "$apppath\ONENOTE.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\OneNote.lnk")
      $Shortcut.TargetPath = "$apppath\ONENOTE.EXE"
      $Shortcut.Save()
}

# Outlook
if (Test-Path "$apppath\OUTLOOK.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Outlook.lnk")
      $Shortcut.TargetPath = "$apppath\OUTLOOK.EXE"
      $Shortcut.Save()
}

# PowerPoint
if (Test-Path "$apppath\POWERPNT.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\PowerPoint.lnk")
      $Shortcut.TargetPath = "$apppath\POWERPNT.EXE"
      $Shortcut.Save()
}

# Word
if (Test-Path "$apppath\WINWORD.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Word.lnk")
      $Shortcut.TargetPath = "$apppath\WINWORD.EXE"
      $Shortcut.Save()
}

# Access
if (Test-Path "$apppath\MSACCESS.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Access.lnk")
      $Shortcut.TargetPath = "$apppath\MSACCESS.EXE"
      $Shortcut.Save()
}

# Publisher
if (Test-Path "$apppath\MSPUB.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Publisher.lnk")
      $Shortcut.TargetPath = "$apppath\MSPUB.EXE"
      $Shortcut.Save()
}

# Skype for Business
if (Test-Path "$apppath\lync.exe") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$linkpath\Skype for Business.lnk")
      $Shortcut.TargetPath = "$apppath\lync.exe"
      $Shortcut.Save()
}

# Microsoft Office Tools
$toolspath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office Tools"
if (!(test-path -PathType container $toolspath)) {
      New-Item -ItemType Directory -Path $toolspath
}

# Office Language Preferences
if (Test-Path "$apppath\SETLANG.EXE") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$toolspath\Office Language Preferences.lnk")
      $Shortcut.TargetPath = "$apppath\SETLANG.EXE"
      $Shortcut.Save()
}

# Telemetry Log for Office
if (Test-Path "$apppath\msoev.exe") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$toolspath\Telemetry Log for Office.lnk")
      $Shortcut.TargetPath = "$apppath\msoev.exe"
      $Shortcut.Save()
}

# Skype for Business Recording Manager
if (Test-Path "$apppath\OcPubMgr.exe") {
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$toolspath\Skype for Business Recording Manager.lnk")
      $Shortcut.TargetPath = "$apppath\OcPubMgr.exe"
      $Shortcut.Save()
}
