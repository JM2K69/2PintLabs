Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Invoke-PSLenovoUpdater.ps1`"" -Wait -NoNewWindow -PassThru | ForEach-Object {
    if ($_.ExitCode -ne 0) {
        Write-Host "Error: Lenovo Updater script failed with exit code $($_.ExitCode)"
        exit $_.ExitCode
    }
}