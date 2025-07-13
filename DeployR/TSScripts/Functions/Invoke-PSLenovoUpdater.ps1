# Based on: https://github.com/jantari/LSUClient

function Invoke-PSLenovoUpdater {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('True', 'False')]
    [string]$updateTypeDrivers = 'True',

    [Parameter(Mandatory = $false)]
    [ValidateSet('True', 'False')]
    [string]$updateTypeBIOS = 'false',

    [Parameter(Mandatory = $false)]
    [ValidateSet('True', 'False')]
    [string]$scanonly = 'False'
)
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")

Write-Host "==================================================================="
Write-Host "Lenovo Update Script"

#Check For Module & Install if not present
$ModuleFile = Get-ChildItem -path 'C:\Program Files\PowerShell\Modules\LSUClient' -ErrorAction SilentlyContinue -Filter "*.psd1" -recurse
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


Write-Host "Importing DeployR.Utility module..."
Import-Module DeployR.Utility
$LSUDrivers = $updateTypeDrivers
$LSUBIOS = $updateTypeBIOS
$LSUScanOnly = $scanonly

Write-Host "LSUDrivers: $LSUDrivers"
Write-Host "LSUBIOS: $LSUBIOS"
Write-Host "LSUScanOnly: $LSUScanOnly"

Write-Host "==================================================================="
Write-Host ""
Write-Host "Checking for Lenovo updates..." -ForegroundColor Cyan

#Find and Report Updates
try {
    $updates = Get-LSUpdate -ErrorAction SilentlyContinue | Where-Object { $_.Installer.Unattended }
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

if ($LSUDrivers -eq $true -and $LSUBIOS -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing Driver and BIOS Updates..."
    foreach ($update in $updates) {
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
    $updates | Install-LSUpdate -Verbose
} elseif ($LSUDrivers -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing Driver Updates..."
    $Updates = $updates | Where-Object { $_.Type -eq 'Driver' }
    foreach ($update in $Updates) {
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
} elseif ($LSUBIOS -eq $true) {
    Write-Host -ForegroundColor Cyan "Installing BIOS Updates..."
    $Updates = $updates | Where-Object { $_.Type -eq 'BIOS' }
    foreach ($update in $Updates) {
        $install = Install-LSUpdate -Verbose -SaveBIOSUpdateInfoToRegistry -Package $update
        if ($install.PendingAction -match "REBOOT"){
            ${TSEnv:SMSTSRebootRequested} = $true
        }
    }
} else {
    Write-Host -ForegroundColor Yellow "No updates selected for installation."
}

Write-Host -ForegroundColor Green "Lenovo updates completed."
}
#Invoke-PSLenovoUpdater -updateTypeDrivers $true