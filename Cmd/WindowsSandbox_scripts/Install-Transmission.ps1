# Download Transmission
$dest = "$env:LOCALAPPDATA\\Temp\\transmission.msi"
Invoke-WebRequest -Uri "https://github.com/transmission/transmission-releases/raw/master/transmission-3.00-x64.msi" -OutFile $dest

# Install Transmission silently
Start-Process msiexec.exe -ArgumentList "/i `"$dest`" /quiet" -Wait