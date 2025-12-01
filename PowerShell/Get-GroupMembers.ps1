# Script to export list of AD groups and members of each group to CSV

# Create folder on user desktop for results
$folderpath = "$env:HOMEPATH\Desktop\Group_Membership"
if(Test-Path -Path $folderpath){
      Write-Host "Folder already exists."
}
else{
      New-Item -Path $folderpath -ItemType Directory
      Write-Host "Folder created successfully."
}

# Export Security Groups to CSV
Get-ADGroup -Filter 'GroupCategory -eq "Security" -and GroupScope -ne "DomainLocal"' | Sort Name | Select Name, Description | Export-Csv $folderpath\adGroupList.csv

# Create CSV for each group with members
Import-Csv $folderpath\adGroupList.csv | ForEach-Object {
    Get-ADGroupMember -identity "$($_.name)" | Sort Name | select Name | Export-csv -path $folderpath\$($_.name).csv -Notypeinformation
}
