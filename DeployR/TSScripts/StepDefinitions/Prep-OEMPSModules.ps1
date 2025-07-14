#This script will grab different OEM Modules and stage them before it reboots into the full OS, so they are there to use for later operations.

#Connect to TS Environment
Import-Module DeployR.Utility



[String]$MakeAlias = ${TSEnv:MakeAlias}
[String]$ModelAlias = ${TSEnv:ModelAlias}
[String]$OSDTargetSystemDrive = ${TSEnv:OSDTargetSystemDrive}

Write-Host "==================================================================="
Write-Host "Adding OEM PowerShell Modules"
Write-Host "MakeAlias: $MakeAlias"
Write-Host "ModelAlias: $ModelAlias"
Write-Host "OSDTargetSystemDrive: $OSDTargetSystemDrive"

if (-not(Test-Path - Path "$($OSDTargetSystemDrive)\Program Files\PowerShell\Modules")){
    Write-Host "PowerShell Modules directory does not exist, creating it."
    New-Item -Path "$($OSDTargetSystemDrive)\Program Files\PowerShell\Modules" -ItemType Directory -Force | Out-Null
}


if ($MakeAlias -eq "Lenovo"){
    #Get the LSUClient Module
    #Write-Host "Attempting to run: Save-Module -Name LSUClient -Path $($OSDTargetSystemDrive)\Program Files\WindowsPowerShell\Modules"
    #Save-Module -Name LSUClient -Path "$($OSDTargetSystemDrive)\Program Files\WindowsPowerShell\Modules"
    #Write-Host "Attempting to run: Save-Module -Name LSUClient -Path $($OSDTargetSystemDrive)\_2P\Client\PSModules"
    #Save-Module -Name LSUClient -Path "$($OSDTargetSystemDrive)\_2P\Client\PSModules" -Force
    Write-Host "Attempting to run: Save-Module -Name LSUClient -Path $($OSDTargetSystemDrive)\Program Files\PowerShell\Modules"
    Save-Module -Name LSUClient -Path "$($OSDTargetSystemDrive)\Program Files\PowerShell\Modules"
}

if ($MakeAlias -eq "Dell"){}

if ($MakeAlias -eq "HP"){
    #Get the HPBIOSConfigUtility Module
    #Write-Host "Attempting to run: Save-Module -Name HPCMSL -Path $($OSDTargetSystemDrive)\Program Files\WindowsPowerShell\Modules"
    #Save-Module -Name HPCMSL -Path "$($OSDTargetSystemDrive)\Program Files\WindowsPowerShell\Modules"
    #Write-Host "Attempting to run: Save-Module -Name HPCMSL -Path $($OSDTargetSystemDrive)\_2P\Client\PSModules"
    #Save-Module -Name HPCMSL -Path "$($OSDTargetSystemDrive)\_2P\Client\PSModules" -Force
    Write-Host "Attempting to run: Save-Module -Name HPCMSL -Path $($OSDTargetSystemDrive)\Program Files\PowerShell\Modules"
    Save-Module -Name HPCMSL -Path "$($OSDTargetSystemDrive)\Program Files\PowerShell\Modules"  
}

if ($MakeAlias -eq "Microsoft"){}

write-host "==================================================================="

<#
Invoke-WebRequest -Uri "https://download.explorerplusplus.com/dev/latest/explorerpp_x64.zip" -OutFile $env:TEMP\explorerpp_x64.zip
Expand-Archive -Path $env:TEMP\explorerpp_x64.zip -DestinationPath "$env:TEMP\explorerpp" -Force
Start-Process -FilePath "$env:TEMP\explorerpp\Explorer++.exe"
#>