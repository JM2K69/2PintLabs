if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}

# Based on: https://github.com/jantari/LSUClient
Write-Host "==================================================================="
Write-Host "Lenovo Update Script"
Write-Host "Importing DeployR.Utility module..."
Import-Module DeployR.Utility
$LSUDrivers = ${TSEnv:updateTypeDrivers}
$LSUBIOS = ${TSEnv:updateTypeBIOS}
$LSUScanOnly = ${TSEnv:scanonly}

[String]$MakeAlias = ${TSEnv:MakeAlias}
if ($MakeAlias -ne "Lenovo") {
    Write-Host "MakeAlias must be Lenovo. Exiting script."
    Exit 0
}

#Setup LOCALAPPDATA Variable
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")



#Check For Module & Install if not present
$ModuleFile = Get-ChildItem -path 'C:\Program Files\WindowsPowerShell\Modules\LSUClient' -ErrorAction SilentlyContinue -Filter "*.psd1" -recurse
if ($ModuleFile) {
    Write-Host "LSUClient module found at $($ModuleFile.FullName)"
} 
else {
    Write-Host "LSUClient module not found, installing..."
    Install-Module -Name 'LSUClient' -Force -Scope AllUsers
    $ModuleFile = Get-ChildItem -path 'C:\Program Files\PowerShell\Modules\LSUClient' -ErrorAction SilentlyContinue -Filter "*.psd1" -recurse
}
# Try to import the module
try {
    Import-Module $ModuleFile.FullName -Force -Verbose
    Write-Host "LSUClient module found and imported successfully."
} catch {
    Write-Host "Still Unable to import LSUClient module, please check the installation." -ForegroundColor Red
    exit 0
}


Write-Host "==================================================================="
write-host "Reporting Variables"
Write-Host "LSUDrivers: $LSUDrivers"
Write-Host "LSUBIOS: $LSUBIOS"
Write-Host "LSUScanOnly: $LSUScanOnly"


Write-Host ""
Write-Host "Checking for Lenovo updates..." -ForegroundColor Cyan
#Find and Report Updates
try {
    Write-Progress -Activity "Checking for Updates" -Status "Searching for Lenovo updates..." -PercentComplete 5
    $updates = Get-LSUpdate -ErrorAction SilentlyContinue | Where-Object { $_.Installer.Unattended }
    Write-Progress -Activity "Checking for Updates" -Status "Searching for Lenovo updates..." -PercentComplete 100
} catch {
    Write-Host -ForegroundColor Red "Error retrieving updates: $_"
    exit 0
}


if ($updates.Count -eq 0) {
    Write-Host -ForegroundColor Green "No updates found."
    exit 0
} else {
    Write-Host -ForegroundColor Cyan "Found $($updates.Count) updates."
    $updates = $updates | Sort-Object -Property Type, Title
    foreach ($update in $updates) {
        Write-Host -ForegroundColor Yellow "Update:$($update.Type) | $($update.Title)"
    }
}
if ($LSUScanOnly -eq $true) {
    Write-Host -ForegroundColor Green "Scan only mode enabled. Exiting without applying updates."
    exit 0
}
$UpdateCount = $updates.Count
$RunningCount = 0
if ($LSUDrivers -eq $true -and $LSUBIOS -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing Driver and BIOS Updates..."
    foreach ($update in $updates) {
        $RunningCount++
        $PercentComplete = [math]::Round(($RunningCount / $UpdateCount) * 100)
        Write-Host "Processing $($update.Title) - Percent Complete: $PercentComplete"
        Write-Progress -Activity "Updating" -Status "Processing $($update.Title)" -PercentComplete $PercentComplete
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
    #$updates | Install-LSUpdate -Verbose
} elseif ($LSUDrivers -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing Driver Updates..."
    $Updates = $updates | Where-Object { $_.Type -eq 'Driver' }
    foreach ($update in $Updates) {
        $RunningCount++
        $PercentComplete = [math]::Round(($RunningCount / $UpdateCount) * 100)
        Write-Host "Processing $($update.Title) - Percent Complete: $PercentComplete"
        Write-Progress -Activity "Updating" -Status "Processing $($update.Title)" -PercentComplete $PercentComplete
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
} elseif ($LSUBIOS -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing BIOS Updates..."
    $Updates = $updates | Where-Object { $_.Type -eq 'BIOS' }
    foreach ($update in $Updates) {
        $RunningCount++
        $PercentComplete = [math]::Round(($RunningCount / $UpdateCount) * 100)
        Write-Host "Processing $($update.Title) - Percent Complete: $PercentComplete"
        Write-Progress -Activity "Updating" -Status "Processing $($update.Title)" -PercentComplete $PercentComplete
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
} else {
    Write-Host -ForegroundColor Yellow "No updates selected for installation."
}

Write-Host -ForegroundColor Green "Lenovo updates completed."

