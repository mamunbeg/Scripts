$sessions = Get-RDUserSession

foreach($session in $sessions)
{
    Invoke-RDUserLogoff -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -Force
}