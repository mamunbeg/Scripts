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

# Configure DHCP network for NIC
function dhcpassign {
    $IPType = "IPv4"
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "up"}
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
    
# Configure static network for NIC
function staticassign {
    $IPdefault = "10.0.50.10"
    if (!($IPvalue = Read-Host "Enter IP address to be set. [Default is $IPdefault]")) {
        $IPvalue = $IPdefault
    }
    $MaskBitsdefault = 24 # This means subnet mask = 255.255.255.0
    if (!($MaskBitsvalue = Read-Host "Enter Subnet Mask bit to be set. [Default is $MaskBitsdefault]")) {
        $MaskBitsvalue = $MaskBitsdefault
    }
    $Gatewaydefault = "10.0.50.1"
    if (!($Gatewayvalue = Read-Host "Enter Gateway address to be set. [Default is $Gatewaydefault]")) {
        $Gatewayvalue = $Gatewaydefault
    }
    $DNSdefault = "10.0.50.10"
    if (!($DNSvalue = Read-Host "Enter DNS server address to be set. [Default is $DNSdefault]")) {
        $DNSvalue = $DNSdefault
    }
    $DNSfwddefault = "1.1.1.1"
    if (!($DNSfwdvalue = Read-Host "Enter DNS forwarder address to be set. [Default is $DNSfwddefault]")) {
        $DNSfwdvalue = $DNSfwddefault
    }
    $IPType = "IPv4"
    # Retrieve the network adapter that you want to configure
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "up"}
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
    # Configure the DNS forwarder address
    $adapter | Add-DnsServerForwarder -IPAddress $DNSfwdvalue
}

# Rename NICs
Get-NetAdapter | Where-Object {$_.Name -eq "Ethernet"} | Rename-NetAdapter -NewName "LAN"
Get-NetAdapter | Where-Object {$_.Name -eq "Ethernet 2"} | Rename-NetAdapter -NewName "MGMT"

$niclist = Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802*"}
foreach ($nicitem in $niclist) {
    # Choose static or DHCP assignment of IP
    do {
        $nicname = $nicitem.Name
        Write-Host `n"How do you want to assign an IP address for $nicname - DHCP or static?"
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
}

# Display network configuration
Get-NetIPConfiguration

msiexec /i WindowsAdminCenter*.msi /qn /L*v log.txt SME_PORT=3443 SSL_CERTIFICATE_OPTION=generate

# Enable firewall
Set-NetFirewallProfile   -Profile Domain,Private,Public -Enabled True

# Set LAN connection to Private network
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Enable firewall rules for remote management
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
Enable-NetFireWallRule -DisplayGroup "Remote Event Log Management"
Enable-NetFireWallRule -DisplayGroup "Remote Service Management"
Enable-NetFireWallRule -DisplayGroup "Remote Volume Management"
Enable-NetFireWallRule -DisplayGroup "Remote Scheduled Tasks Management"
Enable-NetFireWallRule -DisplayName "Windows Management Instrumentation (DCOM-In)"
New-NetFirewallRule -DisplayName "Windows Admin Center" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol TCP -LocalPort 3443

# Install roles and features
Install-WindowsFeature DHCP -IncludeManagementTools
Install-WindowsFeature DNS -IncludeManagementTools
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-WindowsFeature GPMC -IncludeManagementTools
Install-WindowsFeature Print-Server -IncludeManagementTools
Install-WindowsFeature WDS -IncludeManagementTools
Install-WindowsFeature UpdateServices -IncludeManagementTools

# Confirm roles and features installed
Get-WindowsFeature | Where-Object {$_. installstate -eq "installed"} | Format-Table Name,Installstate

# Choose setup new domain or add to existing domain
Get-Command -Module ADDSDeployment
do {
    $domain = Read-Host `n"Enter the domain for your server"
    $netbios = Read-Host `n"Enter the NETBIOS domain for your server"
    Write-Host `n"Do you want to set up a new domain on the server or add the server to an existing domain?"
    $setdomain = Read-Host -Prompt `n"1. New domain:`n2. Existing domain"
    if ($setdomain -eq 1) {
        Install-ADDSForest -DomainName $domain -DomainNetbiosName $netbios -InstallDns:$true
    }
    elseif ($setdomain -eq 2) {
        Install-ADDSDomainController -DomainName $domain -InstallDns -Credential (get-credential $netbios\Administrator)
    }
    else {
        Write-Host `n "Invalid entry" `n
    }    
} until (
    ($setdomain -eq 1) -or ($setdomain -eq 2)
)

