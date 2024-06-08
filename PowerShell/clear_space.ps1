get-childitem "C:\Users\*\AppData\Roaming\Microsoft\Teams\Service Worker\CacheStorage\*" -directory | Where name -in ('2b5c392d2730c0910fd56433cc5e73e510d0f2b4') | ForEach{Remove-Item $_.FullName -Recurse -Force}

get-childitem "C:\Users\*\AppData\Roaming\Microsoft\Teams\*" -directory | Where name -in ('cache','Code Cache') | ForEach{Remove-Item $_.FullName -Recurse -Force}

get-childitem "C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Service Worker\CacheStorage\*" | ForEach{Remove-Item $_.FullName -Recurse -Force}

get-childitem "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage\*" | ForEach{Remove-Item $_.FullName -Recurse -Force}

get-childitem "C:\Users\*\AppData\Local\Temp\*" | ForEach{Remove-Item $_.FullName -Recurse -Force}
get-childitem "C:\Users\*\AppData\Local\Microsoft\Office\16.0\OfficeFileCache\0\0\*" | ForEach{Remove-Item $_.FullName -Recurse -Force}