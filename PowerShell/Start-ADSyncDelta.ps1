$NameServer = Read-Host "Enter name of server (domain controller)"
$CredAdmin = Get-Credential
Invoke-Command -ComputerName $NameServer -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -Credential $CredAdmin