$folderPath = "C:\Users\Public\TESTFOLDER\Folder"
$user = "AztechIT"
$inheritance = "e"
$grant = "r"
$permission = "(OI)(CI)(F)"

icacls $folderPath /inheritance:$inheritance /grant:$grant $user:$permission
