$GroupEmailID = Read-Host "Enter email address of distribution list"
 
<#
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'Text (*.txt)|*.txt|Comma separated (*.csv)|*.csv|Documents (*.docx)|*.docx|SpreadSheet (*.xlsx)|*.xlsx'
}
$null = $FileBrowser.ShowDialog()
#>

$FileBrowser = Read-Host "Enter path to file (txt/csv) that contains list of user email addresses to add to distribution list"

#Connect to Exchange Online
Connect-ExchangeOnline -ShowBanner:$False
 
#Get Existing Members of the Distribution List
$DLMembers =  Get-DistributionGroupMember -Identity $GroupEmailID -ResultSize Unlimited | Select-Object -Expand PrimarySmtpAddress
 
#Import Distribution List Members from CSV
Import-CSV $FileBrowser -Header "UPN" | ForEach-Object {
    #Check if the Distribution List contains the particular user
    If ($DLMembers -contains $_.UPN)
    {
        Write-host -f Yellow "User is already member of the Distribution List:"$_.UPN
    }
    Else
    {      
        Add-DistributionGroupMember –Identity $GroupEmailID -Member $_.UPN
        Write-host -f Green "Added User to Distribution List:"$_.UPN
    }
}