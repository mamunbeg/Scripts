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
function dhcpassign {
    $IPType = "IPv4"
    $adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
    $interface = $adapter | Get-NetIPInterface -AddressFamily $IPType
    if ($interface.Dhcp -eq "Disabled") {
        # Remove existing gateway
        if (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
        $interface | Remove-NetRoute -Confirm:$false
        }
        # Enable DHCP
        $interface | Set-NetIPInterface -DHCP Enabled
        # Configure the DNS Servers automatically
        $interface | Set-DnsClientServerAddress -ResetServerAddresses
    }
}
    
# Configure static network for LAN
function staticassign {
    $IPdefault = "10.10.10.10"
    if (!($IPvalue = Read-Host "Enter IP address to be set. [Default is $IPdefault]")) {
        $IPvalue = $IPdefault
    }
    $MaskBitsdefault = 24 # This means subnet mask = 255.255.255.0
    if (!($MaskBitsvalue = Read-Host "Enter Subnet Mask bit to be set. [Default is $MaskBitsdefault]")) {
        $MaskBitsvalue = $MaskBitsdefault
    }
    $Gatewaydefault = "10.10.10.1"
    if (!($Gatewayvalue = Read-Host "Enter Gateway address to be set. [Default is $Gatewaydefault]")) {
        $Gatewayvalue = $Gatewaydefault
    }
    $DNSdefault = "10.10.10.100"
    if (!($DNSvalue = Read-Host "Enter DNS server address to be set. [Default is $DNSdefault]")) {
        $DNSvalue = $DNSdefault
    }
    $IPType = "IPv4"
    # Retrieve the network adapter that you want to configure
    $adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
    # Remove any existing IP, gateway from our IPv4 adapter
    if (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
        $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
    }
    if (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
        $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
    }
    # Configure the IP address and default gateway
    $adapter | New-NetIPAddress -AddressFamily $IPType -IPAddress $IPvalue -PrefixLength $MaskBitsvalue -DefaultGateway $Gatewayvalue
    # Configure the DNS client server IP addresses
    $adapter | Set-DnsClientServerAddress -ServerAddresses $DNSvalue
}

# Choose static or DHCP assignment of IP
do {
    Write-Host `n"How do you want to assign an IP address - DHCP or static?"
    $ipassign = Read-Host -Prompt `n"1. DHCP:`n2. Static"
    if ($ipassign -eq 1) {
        dhcpassign
    }
    elseif ($ipassign -eq 2) {
        staticassign
    }
    else {
        Write-Host `n "Invalid entry" `n
    }    
} until (
    ($ipassign -eq 1) -or ($ipassign -eq 2)
)

# Display network configuration
Get-NetIPConfiguration

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