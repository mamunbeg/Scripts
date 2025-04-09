Write-Host "`nYour CSV file must have a column named: " -ForegroundColor Blue -NoNewline
Write-Host "userPrincipalName" -ForegroundColor Red
Read-Host -Prompt "`nPress Enter to continue"

# Connect to Microsoft Graph
Connect-MgGraph -NoWelcome -Scopes "User.Read.All"

# Path to the input CSV file
Write-Host "`nSelect your CSV file in the dialog box. The dialog box may be behind other windows." -ForegroundColor Blue
Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$OpenFileDialog.Filter = "All files (*.*)|*.*"
$OpenFileDialog.ShowDialog() | Out-Null
$inputCsvPath = $OpenFileDialog.FileName

# Path to the output CSV file
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$outputCsvPath = "$DesktopPath\users-domain.csv"

# Import the input CSV file
$userlist = Import-Csv -Path $inputCsvPath

Write-Host "Processing users in your file. Please wait... " -ForegroundColor Blue

# Loop through each user and get the OnPremisesDomainName
foreach ($user in $userlist) {
    $username = $user.userPrincipalName
    Get-MgUser -UserId $username -Property DisplayName,UserPrincipalName,onPremisesDomainName | Select-Object DisplayName,UserPrincipalName,onPremisesDomainName | Export-Csv -Path $outputCsvPath -NoTypeInformation -Append
    }

Write-Host "Export completed. The CSV file is located at $outputCsvPath"
Read-Host -Prompt "`nPress Enter to exit"
