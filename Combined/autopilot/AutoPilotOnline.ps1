[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
 Install-Script -Name Get-WindowsAutopilotInfo -Force
 Get-WindowsAutopilotInfo -Online