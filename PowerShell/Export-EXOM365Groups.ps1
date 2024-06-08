#Parameters
# $ProfileLocation = $Env:USERPROFILE
$CSVFilePath = "C:\Users\mamun-local\Downloads\M365-Members.csv"
 
Try {
    #Connect to Exchange Online
    Connect-ExchangeOnline -ShowBanner:$False
 
    #Get all Distribution Lists
    $Result=@()    
    $M365Groups = Get-UnifiedGroup -ResultSize Unlimited
    $GroupsCount = $M365Groups.Count
    $Counter = 1
    $M365Groups | ForEach-Object {
        Write-Progress -Activity "Processing Distribution List: $($_.DisplayName)" -Status "$Counter out of $GroupsCount completed" -PercentComplete (($Counter/$GroupsCount)*100)
        $Group = $_
        Get-UnifiedGroupLinks -Identity $Group.Name -LinkType Members -ResultSize Unlimited | ForEach-Object {
            $member = $_
            $Result += New-Object PSObject -property @{
            GroupName = $Group.Name
            GroupEmail = $Group.PrimarySmtpAddress
            Member = $Member.Name
            EmailAddress = $Member.PrimarySMTPAddress
            RecipientType= $Member.RecipientType
            }
        }
    $Counter++
    }
    #Get Distribution List Members and Exports to CSV
    $Result | Export-CSV $CSVFilePath -NoTypeInformation -Encoding UTF8
}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
}