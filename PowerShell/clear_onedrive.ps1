Get-ChildItem $((Get-ChildItem $env:USERPROFILE -Filter "OneDrive -*").FullName) -Exclude "*.url" -Recurse | 
    Where {! $_.PSIsContainer } |
    Select Fullname, @{n='Attributes';e={[fileAttributesex]$_.Attributes.Value__}} | 
    where-Object { ($_.Attributes -cnotmatch "Unpinned") -or ($_.Attributes -cnotmatch "Offline") -And ($_.Attributes -cnotmatch "RecallOnDataAccess")  } |
    Foreach {  attrib.exe $_.fullname +U -P /S }