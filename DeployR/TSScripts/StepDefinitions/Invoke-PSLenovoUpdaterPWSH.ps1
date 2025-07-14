write-host -ForegroundColor Cyan "Starting Invoke-PSLenovoUpdater..."
write-host "Start-Process -FilePath `"C:\Program Files\PowerShell\7\pwsh.exe`" -ArgumentList `"-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Invoke-PSLenovoUpdater.ps1`"`""

Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Invoke-PSLenovoUpdater.ps1`"" -Wait -NoNewWindow -PassThru 
if ($LASTEXITCODE -ne 0) {
    Write-Host -ForegroundColor Red "Invoke-PSLenovoUpdater failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
} else {
    Write-Host -ForegroundColor Green "Invoke-PSLenovoUpdater completed successfully."
}