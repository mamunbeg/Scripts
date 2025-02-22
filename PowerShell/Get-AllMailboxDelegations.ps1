Connect-ExchangeOnline
$user = Read-Host "Enter mailbox username"
$results = @()

# Check FullAccess permissions
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $mailbox = $_.PrimarySmtpAddress
    $permissions = Get-MailboxPermission -Identity $mailbox | Where-Object { $_.User -eq $user -and $_.AccessRights -like "*FullAccess*" }
    if ($permissions) {
        $results += [PSCustomObject]@{
            Mailbox = $mailbox
            AccessRights = $permissions.AccessRights
        }
    }
}

# Check Send-As permissions
Get-Recipient -ResultSize Unlimited | ForEach-Object {
    $mailbox = $_.PrimarySmtpAddress
    $permissions = Get-RecipientPermission -Identity $mailbox | Where-Object { $_.Trustee -eq $user -and $_.AccessRights -like "*SendAs*" }
    if ($permissions) {
        $results += [PSCustomObject]@{
            Mailbox = $mailbox
            AccessRights = $permissions.AccessRights
        }
    }
}

# Check Send on Behalf permissions
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $mailbox = $_.PrimarySmtpAddress
    if ($_.GrantSendOnBehalfTo -contains $user) {
        $results += [PSCustomObject]@{
            Mailbox = $mailbox
            AccessRights = "SendOnBehalf"
        }
    }
}

# Display results
$results | Format-Table -AutoSize