#Parameters
# $ProfileLocation = $Env:USERPROFILE
$CSVFilePath = "C:\Users\mamun-local\Downloads\DL-Members.csv"
 
Try {
    #Connect to Exchange Online
    Connect-ExchangeOnline -ShowBanner:$False
 
    #Get all Distribution Lists
    $Result=@()    
    $DistributionGroups = Get-DistributionGroup -ResultSize Unlimited
    $GroupsCount = $DistributionGroups.Count
    $Counter = 1
    $DistributionGroups | ForEach-Object {
        Write-Progress -Activity "Processing Distribution List: $($_.DisplayName)" -Status "$Counter out of $GroupsCount completed" -PercentComplete (($Counter/$GroupsCount)*100)
        $Group = $_
        Get-DistributionGroupMember -Identity $Group.Name -ResultSize Unlimited | ForEach-Object {
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