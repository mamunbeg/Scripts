Get-NetIPAddress -InterfaceIndex (Get-NetAdapter -Name 'vEthernet-HyperV').ifIndex | Remove-NetIPAddress -confirm:$false
New-NetIPAddress -InterfaceAlias 'vEthernet-HyperV' -IPAddress '10.0.0.1' -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias 'vEthernet-HyperV' -ServerAddresses ("10.0.0.10","1.1.1.1")