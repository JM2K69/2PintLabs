write-host -ForegroundColor Cyan "Starting Invoke-PSLenovoUpdater..."
write-host 'cmd.exe /c pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-PSLenovoUpdater.ps1 -Wait -NoNewWindow -PassThru '

cmd.exe /c pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-PSLenovoUpdater.ps1 -Wait -NoNewWindow -PassThru 
