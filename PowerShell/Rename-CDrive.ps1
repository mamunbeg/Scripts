# Rename Local Disk (C:) to a new label
$driveLetter = "C:"
$newLabel = "OS"  # Change this to your desired label

# Get the drive and set the new label
$drive = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = '$driveLetter'"
if ($drive) {
    $drive.Label = $newLabel
    $drive.Put()
    Write-Output "Renamed $driveLetter to $newLabel."
} else {
    Write-Output "Drive $driveLetter not found."
}