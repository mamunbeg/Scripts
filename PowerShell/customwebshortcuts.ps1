#Variables creating local folder and download .ico file
$LocalIconFolderPath = "C:\ProgramData\CustomWebShortcuts"
$SourceIcon = "http://nickydewestelinck.be/wp-content/icons/salesforce.ico"
$DestinationIcon = "C:\ProgramData\CustomWebShortcuts\salesforce.ico"


#Step 1 - Create a folder to place the URL icon
New-Item $LocalIconFolderPath -Type Directory

#Step 2 - Download a ICO file from a website into previous created folder
curl $SourceIcon -o $DestinationIcon

#Step 3 - Add the custom URL shortcut to your Desktop with custom icon
$new_object = New-Object -ComObject WScript.Shell
$destination = $new_object.SpecialFolders.Item('AllUsersDesktop')
$source_path = Join-Path -Path $destination -ChildPath '\\Salesforce.lnk'
$source = $new_object.CreateShortcut($source_path)
$source.TargetPath = 'https://login.salesforce.com'
$source.IconLocation = "C:\ProgramData\CustomWebShortcuts\salesforce.ico"
$source.Save()