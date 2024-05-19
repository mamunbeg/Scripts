# Powershell script to change file name or extension

# Set all variables to zero or null
$choice = $countfile1 = $countfile2 = $changefile = 0
$listfiles = $renamefiles = $wording = $vnameold = $vnamenew = $fnameold = $fnamenew = $confirmation = $null

# Function to count and display number of files renamed
function FileList {
    Get-ChildItem -File | Where-Object ($listfiles)
}

function FilesChanged {
    $fnamenew = FileList
    $countfile1 = $fnameold.Count
    $countfile2 = $fnamenew.Count
    $changefile = ($countfile1 - $countfile2)
    Write-Host `n"Number of files renamed is: $changefile" `n
}

# Choose to change file name or extension
Write-Host `n
Write-Host "Do you want to change the file name or the extension?" `n
$choice = Read-Host -Prompt "To change the file name enter 1 `nTo change the extension enter 2 `n"
if ($choice -eq 1) {
    $listfiles = {$_.BaseName -like "*$vnameold*"}
    $renamefiles = {$_.BaseName.Replace("$vnameold","$vnamenew") + $_.Extension}
    $wording = "part of the file name"
} elseif ($choice -eq 2) {
    $listfiles = {$_.Extension -like ".$vnameold"}
    $renamefiles = {$_.BaseName + $_.Extension.Replace("$vnameold","$vnamenew")}
    $wording = "file extension"
} else {
    Write-Host `n"Invalid entry. Exiting script without any changes made."
    Write-Host `n"Number of files renamed is: $changefile" `n
    Exit
}

# Prompt user for information and display present working directory
$vnameold = Read-Host -Prompt "`nEnter the $wording that you want to replace"
$vnamenew = Read-Host -Prompt "`nEnter the new $wording"
Write-Host `n
Write-Host "You are currently in the following directory:" `n
Write-Host $PWD `n

# Confirm directory and change name
$confirmation = Read-Host -Prompt "Is this the correct location where you want to run this script?"
if ($confirmation -eq 'y') {
    $fnameold = FileList
    $fnameold | Rename-Item -NewName ($renamefiles)
    FilesChanged
}
else {
    Write-Host `n"Exiting script without any changes made."
    $fnameold = FileList
    FilesChanged
}

Exit