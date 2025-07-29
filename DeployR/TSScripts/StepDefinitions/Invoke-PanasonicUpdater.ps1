if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}
# Based on: https://github.com/jantari/LSUClient
Write-Host "==================================================================="
Write-Host "Panasonic Corporation Update Script"
Write-Host "Importing DeployR.Utility module..."
Import-Module DeployR.Utility
$PCUDrivers = ${TSEnv:updateTypeDrivers}
$PCUBIOS = ${TSEnv:updateTypeBIOS}
$PCUScanOnly = ${TSEnv:scanonly}

[String]$MakeAlias = ${TSEnv:MakeAlias}
if ($MakeAlias -ne "Panasonic Corporation") {
    Write-Host "MakeAlias must be Panasonic Corporation. Exiting script."
    Exit 0
}

#Setup LOCALAPPDATA Variable
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")



#Check For Module & Install if not present
$ModuleFile = Get-ChildItem -path 'C:\Program Files\WindowsPowerShell\Modules\PanasonicCommandUpdate' -ErrorAction SilentlyContinue -Filter "*.psd1" -recurse
if ($ModuleFile) {
    Write-Host "PanasonicCommandUpdate module found at $($ModuleFile.FullName)"
} 
else {
    Write-Host "PanasonicCommandUpdate module not found, installing..."
    Install-Module -Name 'PanasonicCommandUpdate' -Force -Scope AllUsers -AcceptLicense
    $ModuleFile = Get-ChildItem -path 'C:\Program Files\PowerShell\Modules\PanasonicCommandUpdate' -ErrorAction SilentlyContinue -Filter "*.psd1" -recurse
}
# Try to import the module
try {
    Import-Module $ModuleFile.FullName -Force -Verbose
    Write-Host "PanasonicCommandUpdate module found and imported successfully."
} catch {
    Write-Host "Still Unable to import PanasonicCommandUpdate module, please check the installation." -ForegroundColor Red
    exit 0
}

