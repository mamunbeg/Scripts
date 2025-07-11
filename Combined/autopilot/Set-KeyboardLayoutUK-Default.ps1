$LanguageCode = "en-GB"
$LanguageId = "00000809"
$GeoId = "0xf2"

# Install language pack for UK English (en-GB)
Install-Language -Language $LanguageCodeCode -CopyToSettings

# Set the home location and culture to UK
Set-WinHomeLocation -GeoId $GeoId
Set-Culture $LanguageCode

# Set the preferred language to UK English (en-GB)
Set-PreferredLanguage -Language $LanguageCode
Set-SystemPreferredUILanguage -Language $LanguageCode

# Set the system locale to UK English (en-GB)
Set-WinSystemLocale -SystemLocale $LanguageCode

# Set the UI language override for the welcome screen and new users to UK English (en-GB)
Set-WinUILanguageOverride -Language $LanguageCode

# Set the user keyboard layout to UK English (en-GB)
Set-WinUserLanguageList -Language $LanguageCode -Force -Confirm:$false

# Copy current user settings to the system and new users
Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

<#
# Load the default user registry hive
reg load HKU\DefaultUser C:\Users\Default\NTUSER.DAT

# Set the UK keyboard layout for the default user
Set-ItemProperty -Path "Registry::HKU\DefaultUser\Keyboard Layout\Preload" -Name "1" -Value $LanguageId

# Unload the default user registry hive
reg unload HKU\DefaultUser

# Set the UK keyboard layout for the logon screen
Set-ItemProperty -Path "Registry::HKU\.DEFAULT\Keyboard Layout\Preload\" -Name 1 -Value $LanguageId
#>