# Install and Import Microsoft.Graph module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module -Name Microsoft.Graph -Force -Scope CurrentUser
}
Import-Module Microsoft.Graph.Devices.CorporateManagement

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# Initialize loop control variable
$continue = $true

# Loop to delete multiple devices
while ($continue) {
    # Ask the user to enter the device name
    $deviceName = Read-Host "Enter the device name"
    Write-Output ""  # Blank line

    # Search for the device by name
    $device = Get-MgDevice -Filter "displayName eq '$deviceName'"

    # Check if the device was found
    if ($device) {
        # Output the Device ID in cyan color
        Write-Host "Device Name: " -NoNewline
        Write-Host "$deviceName" -ForegroundColor Cyan
        Write-Host "Device ID:   " -NoNewline
        Write-Host "$($device.Id)" -ForegroundColor Cyan
        Write-Output ""  # Blank line

        # Ask for confirmation before deleting the device
        $confirmation = Read-Host "Are you sure you want to delete this device? (Y/N)"
        Write-Output ""  # Blank line

        if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
            # Delete the device using its ID
            Remove-MgDevice -DeviceId $device.Id
            Write-Host "Device " -NoNewline -ForegroundColor Green
            Write-Host "$deviceName" -ForegroundColor Cyan
            Write-Host "has been deleted." -NoNewline -ForegroundColor Green
            Write-Output ""  # Blank line
        } else {
            Write-Host "Deletion canceled." -ForegroundColor Yellow
            Write-Output ""  # Blank line
        }
    } else {
        Write-Host "Device not found." -ForegroundColor Red
        Write-Output ""  # Blank line
    }

    # Ask the user if they want to delete another device
    $continueResponse = Read-Host "Do you want to delete another device? (Y/N)"
    Write-Output ""  # Blank line

    if ($continueResponse -ne 'Y' -and $continueResponse -ne 'y') {
        $continue = $false
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph