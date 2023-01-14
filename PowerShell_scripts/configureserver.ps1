# Configure server for first use

#Set home location to the United Kingdom
Set-WinHomeLocation 0xf2
#Override language list with just English GB
$1 = New-WinUserLanguageList en-GB
$1[0].Handwriting = 1
Set-WinUserLanguageList $1 -force
#Set system local
Set-WinSystemLocale en-GB
#Set the timezone
Set-TimeZone "GMT Standard Time"



# Configure DHCP network for WAN
$IPType = "IPv4"
$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
$interface = $adapter | Get-NetIPInterface -AddressFamily $IPType
If ($interface.Dhcp -eq "Disabled") {
 # Remove existing gateway
 If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $interface | Remove-NetRoute -Confirm:$false
 }
 # Enable DHCP
 $interface | Set-NetIPInterface -DHCP Enabled
 # Configure the DNS Servers automatically
 $interface | Set-DnsClientServerAddress -ResetServerAddresses
}

# Configure static network for LAN
$IP = "10.10.10.10"
$MaskBits = 24 # This means subnet mask = 255.255.255.0
$Gateway = "10.10.10.1"
$Dns = "10.10.10.100"
$IPType = "IPv4"
# Retrieve the network adapter that you want to configure
$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
# Remove any existing IP, gateway from our ipv4 adapter
If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
 $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}
If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}
 # Configure the IP address and default gateway
$adapter | New-NetIPAddress `
 -AddressFamily $IPType `
 -IPAddress $IP `
 -PrefixLength $MaskBits `
 -DefaultGateway $Gateway
# Configure the DNS client server IP addresses
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

# Enable firewall
Set-NetFirewallProfile   -Profile Domain,Private,Public -Enabled True

# Set LAN connection to Private network
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Enable firewall rules for remote management
Enable-NetFireWallRule -DisplayName "Windows Management Instrumentation (DCOM-In)"
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
Enable-NetFireWallRule -DisplayGroup "Remote Event Log Management"
Enable-NetFireWallRule -DisplayGroup "Remote Service Management"
Enable-NetFireWallRule -DisplayGroup "Remote Volume Management"
Enable-NetFireWallRule -DisplayGroup "Remote Scheduled Tasks Management"

# Confirm roles and features installed
Get-WindowsFeature | Where-Object {$_. installstate -eq "installed"} | ft Name,Installstate

# Install roles and features
Install-WindowsFeature DHCP
Install-WindowsFeature DNS
Install-WindowsFeature AD-Domain-Services
Install-WindowsFeature GPMC
Install-WindowsFeature Print-Server
Install-WindowsFeature WDS
Install-WindowsFeature UpdateServices

# Confirm roles and features installed
Get-WindowsFeature | Where-Object {$_. installstate -eq "installed"} | ft Name,Installstate