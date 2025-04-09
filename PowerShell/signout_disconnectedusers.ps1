$sessions = Get-RDUserSession |  ? {$_.SessionState -eq "STATE_DISCONNECTED"}

foreach($session in $sessions)
{
    Invoke-RDUserLogoff -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -Force
}