# Powershell script to change file name or extension

# Enter variables and show directory
Write-Host `n
$vnameold = Read-Host -Prompt "Enter the part of the file name that you want to replace"
$vnamenew = Read-Host -Prompt "Enter the new part of the file name"
Write-Host `n
Write-Host "You are currently in the following directory:" `n
Write-Host $PWD `n

# Confirm directory and change name
$confirmation = Read-Host -Prompt "Is this the correct location where you want to run this script?"
if ($confirmation -eq 'y') {
    $fnameold = Get-ChildItem -File | Where-Object {$_.BaseName -like "*$vnameold*"}
    $fnameold | Rename-Item -NewName {$_.BaseName.Replace("$vnameold","$vnamenew") + $_.Extension}
}
else {
    Write-Host `n "Exiting script without any changes made" `n
    Exit
}

# Count and display number of files renamed
$fnamenew = Get-ChildItem -File | Where-Object {$_.BaseName -like "*$vnameold*"}
$countfile1 = $fnameold.Count
$countfile2 = $fnamenew.Count
$changefile = ($countfile1 - $countfile2)
Write-Host `n "Number of files renamed is: $changefile" `n