# Unpin Microsoft Store from Taskbar
$appName = "Microsoft Store"

((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
 ?{$_.Name -eq $appname}).Verbs() |
  ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} |
   %{$_.DoIt(); $exec = $true}
