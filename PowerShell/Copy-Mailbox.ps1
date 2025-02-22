# PowerShell command to copy mail from one mailbox to another
Connect-ExchangeOnline

# Provide source mailbox
Write-Host "`nPlease enter the " -NoNewline
Write-Host "SOURCE " -ForegroundColor Red -NoNewline
Write-Host "email address of the mailbox that you want to copy emails " -NoNewline
Write-Host "FROM" -ForegroundColor Red -NoNewline
Write-Host "`: " -NoNewline
$SourceEmailAddr = Read-Host
# Provide target mailbox
Write-Host "`nPlease enter the " -NoNewline
Write-Host "TARGET " -ForegroundColor Green -NoNewline
Write-Host "email address of the mailbox that you want to copy emails " -NoNewline
Write-Host "TO" -ForegroundColor Green -NoNewline
Write-Host "`: " -NoNewline
$TargetEmailAddr = Read-Host
# Display copy direction
Write-Host "`nCopying emails from " -NoNewline
Write-Host "$SourceEmailAddr " -ForegroundColor Red -NoNewline
Write-Host "to " -NoNewline
Write-Host "$TargetEmailAddr" -ForegroundColor Green
#Confirm to continue
Read-Host -Prompt "`nPress Enter to continue or Ctrl-C to quit"

# Delete source mailbox
Remove-Mailbox -Identity "$SourceEmailAddr" -Confirm:$false
Write-Host "Deleting $SourceEmailAddr mailbox and waiting 3 minutes for changes to propagate...`n"
Start-Sleep -Seconds 180
# Retrieve mailbox GUIDs
$SourceEmailGuid = (Get-Mailbox -SoftDeletedMailbox "$SourceEmailAddr").ExchangeGuid
$TargetEmailGuid = (Get-Mailbox "$TargetEmailAddr").ExchangeGuid

# Copy data in mailbox
New-MailboxRestoreRequest -SourceMailbox "$SourceEmailGuid" -TargetMailbox "$TargetEmailGuid" -AllowLegacyDNMismatch
#Copy archive data in mailbox
New-MailboxRestoreRequest -SourceMailbox "$SourceEmailGuid" -SourceisArchive -TargetMailbox "$TargetEmailGuid" -TargetisArchive -AllowLegacyDNMismatch
# View results
Get-MailboxRestoreRequest | Format-List

# Disconnect-ExchangeOnline