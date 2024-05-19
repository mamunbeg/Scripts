if (Test-Path $env:OneDriveCommercial){

Set-Location $env:OneDriveCommercial

if ($env:OneDriveCommercial -like "$(Get-location)"){

attrib -p +u /s

}

}