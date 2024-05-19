# Create new folder on desktop

Write-Host `n
$foldername = Read-Host -Prompt "Enter name of folder to be created on Desktop"
$desktoppath = [Environment]::GetFolderPath("Desktop")
$folderpath = $desktoppath+"\"+$foldername

# Test and create folder if not present then move to directory
if (-not (Test-Path $folderpath)) {
    New-Item -Path $folderpath -ItemType Directory
    Set-Location -Path $folderpath
} else {
    Set-Location -Path $folderpath
}
