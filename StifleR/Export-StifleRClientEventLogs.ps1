## Description: This script exports StifleR client event logs to a specified directory.

Function Export-StifleRClientEventLogs {
    [CmdletBinding()]
    param (
        [string]$OutputDirectory = "C:\StifleRLogs"
    )

    # Ensure the output directory exists
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    # Get all StifleR client event logs
    $StifleREvents = Get-WinEvent -ListProvider *StifleR*

    # Export each event log to a file
    foreach ($event in $StifleREvents) {
        $logName = $event.ProviderName
        $logFilePath = Join-Path -Path $OutputDirectory -ChildPath "$logName"
        $Events = $null
        $Events = (Get-WinEvent -ListProvider $logName -ErrorAction SilentlyContinue).Events
        if ($Events) { 
            $Events | Export-Csv -Path "$logFilePath.csv" -Force
            $LogNameExtended = $event.LogLinks.LogName
            foreach ($logLink in $LogNameExtended) {
                $logFilePath = Join-Path -Path $OutputDirectory -ChildPath "$($logLink.replace('/', '_'))"
                Start-Process wevtutil.exe -ArgumentList "export-log $logLink `"$logFilePath.evtx`"" -NoNewWindow -Wait
            }
            

        }
    }

    Write-Host "StifleR client event logs exported to $OutputDirectory"
}
