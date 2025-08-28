#Requires -RunAsAdministrator
<#
.SYNOPSIS
OSD Registry Record Metrics

.DESCRIPTION
This script connects to the DeployR task sequence and writes deployment information to the registry.
Creates a comprehensive record of the OSD deployment process for tracking and reporting purposes.

.NOTES
Author: Generated Script
Date: July 28, 2025
Requires: Administrator privileges, DeployR Task Sequence environment
#>
if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}
# Adding Support for DeployR Task Sequence Variables
try {
    Import-Module DeployR.Utility
    Write-Host "DeployR.Utility module loaded successfully" -ForegroundColor Green
    
}
catch {
    Write-Warning "Failed to load DeployR.Utility module: $($_.Exception.Message)"
    Write-Warning "This script requires the DeployR Task Sequence environment"
}

# Define the registry path for OSD Inventorying
$InventoryOSDRegPath = if (Get-Module -Name "DeployR.Utility") {
    if (${TSEnv:InventoryOSDRegPath}) {
        ${TSEnv:InventoryOSDRegPath}
    } else {
        "HKLM:\SOFTWARE\2Pint Software\DeployR\OSD"
    }
} else {
    "HKLM:\SOFTWARE\2Pint Software\DeployR\OSD"
}

#Get the Task Sequence Environment Variables
if (Get-Module -Name "DeployR.Utility") {
    $InventoryWinPEInfo =       ${TSEnv:InventoryWinPEInfo}
    $InventoryOSIMAGENAME =     ${TSEnv:InventoryOSIMAGENAME}
    $InventoryDEPLOYRHOST =     ${TSEnv:InventoryDEPLOYRHOST}
    $InventoryOSIMAGEVERSION =  ${TSEnv:InventoryOSIMAGEVERSION}
    $InventoryTSID =            ${TSEnv:InventoryTSID}
    $InventoryCOMPUTERNAME =    ${TSEnv:InventoryCOMPUTERNAME}
    $InventoryDurationTime =    ${TSEnv:InventoryDurationTime}
    $InventoryStartTime =       ${TSEnv:InventoryStartTime}
    $InventoryApps =            ${TSEnv:InventoryApps}
    $InventoryDriverPackURL =   ${TSEnv:DriverPackURL}
    $InventoryDriverPackName =  ${TSEnv:DriverPackName}
    $InventoryDriverPackID =    ${TSEnv:DriverPackID}
    $InventoryDriverMigrateCount = ${TSEnv:DriverMigrateCount}
    $InventoryDriverPackCustom = ${TSEnv:DriverPackCustom}
    $InventoryDriverPackCustomCount = ${TSEnv:DriverPackCustomCount}
    $InventoryDriverPackMethod = ${TSEnv:DriverPackMethod}
}

#Write out all Vars
Write-Host "==============================================================="
Write-Host "InventoryOSDRegPath:        $InventoryOSDRegPath" -ForegroundColor Cyan
Write-Host "InventoryStartTime:         $InventoryStartTime" -ForegroundColor Cyan
Write-Host "InventoryDurationTime:      $InventoryDurationTime" -ForegroundColor Cyan
Write-Host "InventoryWinPEInfo:         $InventoryWinPEInfo" -ForegroundColor Cyan
Write-Host "InventoryOSIMAGENAME:       $InventoryOSIMAGENAME" -ForegroundColor Cyan
Write-Host "InventoryDEPLOYRHOST:       $InventoryDEPLOYRHOST" -ForegroundColor Cyan
Write-Host "InventoryOSIMAGEVERSION:    $InventoryOSIMAGEVERSION" -ForegroundColor Cyan
Write-Host "InventoryTSID:              $InventoryTSID" -ForegroundColor Cyan
Write-Host "InventoryCOMPUTERNAME:      $InventoryCOMPUTERNAME" -ForegroundColor Cyan
Write-Host "InventoryApps:              $InventoryApps" -ForegroundColor Cyan
Write-Host "InventoryDriverPackURL:     $InventoryDriverPackURL" -ForegroundColor Cyan
Write-Host "InventoryDriverPackName:    $InventoryDriverPackName" -ForegroundColor Cyan
Write-Host "InventoryDriverPackID:      $InventoryDriverPackID" -ForegroundColor Cyan
Write-Host "InventoryDriverPackMethod:  $InventoryDriverPackMethod" -ForegroundColor Cyan
Write-Host "InventoryDriverPackCustom:  $InventoryDriverPackCustom" -ForegroundColor Cyan
Write-Host "InventoryDriverPackCustomCount: $InventoryDriverPackCustomCount" -ForegroundColor Cyan
Write-Host "==============================================================="

#region Helper Functions
# Function to create registry path if it doesn't exist
function New-RegistryPath {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -Force | Out-Null
            Write-Host "Created registry path: $Path" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to create registry path '$Path': $($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

# Function to write registry value with error handling
function Set-RegistryValue {
    param(
    [string]$Path,
    [string]$Name,
    [string]$Value,
    [string]$Type = "String"
    )
    
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Host "✓ $Name`: $Value" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to write registry value '$Name': $($_.Exception.Message)"
        return $false
    }
}

# Function to detect if running in WinPE
function Get-WinPEInfo {
    $inWinPE = $env:SystemDrive -eq "X:"
    if ($inWinPE) {
        try {
            # Get WinPE version information
            $winpeVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).BuildLabEx
            if (-not $winpeVersion) {
                $winpeVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).BuildLab
            }
            return "WinPE - Version: $winpeVersion"
        }
        catch {
            return "WinPE - Version Unknown"
        }
    } else {
        return "Full Windows OS"
    }
}

# Function to get OS Build and UBR information
function Get-OSBuildInfo {
    try {
        $currentVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        $build = $currentVersion.CurrentBuild
        $ubr = $currentVersion.UBR
        
        if ($build -and $ubr) {
            return "$build.$ubr"
        } elseif ($build) {
            return $build
        } else {
            return "Unknown"
        }
    }
    catch {
        return "Unknown"
    }
}

# Function to get OS Edition information
function Get-OSEdition {
    try {
        $productName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName
        if ($productName) {
            return $productName
        } else {
            return "Unknown"
        }
    }
    catch {
        return "Unknown"
    }
}
function Get-InstalledApps
{
    if (![Environment]::Is64BitProcess) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}
#endregion

# Main execution
Write-Host "`n=== OSD Registry Inventory Started ===" -ForegroundColor Magenta
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

# Create the registry path if it doesn't exist
if (-not (New-RegistryPath -Path $InventoryOSDRegPath)) {
    Write-Error "Cannot proceed without registry path access"
    exit 1
}

Write-Host "`nWriting OSD deployment information to registry..." -ForegroundColor Cyan

# Collect and write deployment information
if (Get-Module -Name "DeployR.Utility") {
    Write-Host "`nTask Sequence Information:" -ForegroundColor Yellow
    
    # 1. TS ID
    if ($InventoryTSID -eq "True"){
        $tsID = ${TSEnv:TSID}
        if (-not $tsID) { $tsID = "Unknown" }
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "TSID" -Value $tsID | Out-Null
    }
    
    # 2. DeployR Server
    if ($InventoryDEPLOYRHOST -eq "True"){
        $deployRHost = ${TSEnv:DEPLOYRHOST}
        if (-not $deployRHost) { $deployRHost = "Unknown" }
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "DeployRServer" -Value $deployRHost | Out-Null
    }
    
    # 3. OS Image Version
    if ($InventoryOSIMAGEVERSION -eq "True"){
        $osImageVersion = ${TSEnv:OSIMAGEVERSION}
        if (-not $osImageVersion) { $osImageVersion = Get-OSBuildInfo }
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "OSImageVersion" -Value $osImageVersion | Out-Null
    }
    
    # 4. OS Image Name/Edition
    if ($InventoryOSIMAGENAME -eq "True"){
        $osImageName = ${TSEnv:OSIMAGENAME}
        if (-not $osImageName) { $osImageName = Get-OSEdition }
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "OSImageName" -Value $osImageName | Out-Null
    }
    
    
} else {
    Write-Host "`nNon-Task Sequence Environment - Using local system information:" -ForegroundColor Yellow
    
    # Fallback values when not in task sequence
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "TSID" -Value "No Task Sequence" | Out-Null
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DeployRServer" -Value "Unknown" | Out-Null
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "OSImageVersion" -Value (Get-OSBuildInfo) | Out-Null
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "OSImageName" -Value (Get-OSEdition) | Out-Null
}

Write-Host "`nSystem Information:" -ForegroundColor Yellow

# 5. Computer Name
if ($InventoryCOMPUTERNAME -eq "True"){
    $computerName = $env:COMPUTERNAME
    if (-not $computerName) { $computerName = "Unknown" }
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "ComputerName" -Value $computerName | Out-Null
}


# 6. WinPE Information
if ($InventoryWinPEInfo -eq "True"){
    write-host "Setting WinPE Information..."
    if (${TSEnv:WinPEBuildInfo}){
        $winPEInfo = ${TSEnv:WinPEBuildInfo}
        Write-Host "WinPE Information: $winPEInfo"
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "WinPEBuild" -Value $winPEInfo | Out-Null
    } else {
        Write-Host "WinPE Information not available, skipping..." -ForegroundColor Yellow
    }
}



# 7. Start Time (if available from TS, otherwise current time)
if ($InventoryStartTime -eq "True") {
    $startTime = if (Get-Module -Name "DeployR.Utility") {
        ${TSEnv:OSDStartTime}
    } else {
        $null
    }
    if ($startTime) {
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "DeploymentStartTime" -Value $startTime 
        Write-Host "Setting DeploymentStartTime to: $startTime" -ForegroundColor Green
    }
    else {
        Write-Host "No OSDStartTime found, Please add Step Definition 'Tweaks - Set Initial Variables' into the beginning of your Task Sequence" -ForegroundColor Yellow
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "DeploymentStartTime" -Value "Missing Element, See Log File"
    }
}




# 8. Finish Time (current time as this is when the Inventory is being written)
$finishTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
Write-Host "Setting DeploymentFinishTime to: $finishTime" -ForegroundColor Green
Set-RegistryValue -Path $InventoryOSDRegPath -Name "DeploymentFinishTime" -Value $finishTime

# Calculate Task Sequence Duration
if ($InventoryDurationTime -eq "True") {
    try {
        $duration = $null
        if ($startTime -and $finishTime) {
            # Parse times to DateTime objects
            $startDT = [datetime]::ParseExact($startTime, 'yyyy-MM-dd HH:mm:ss', $null)
            $finishDT = [datetime]::ParseExact($finishTime, 'yyyy-MM-dd HH:mm:ss', $null)
            $durationSpan = $finishDT - $startDT
            $duration = $durationSpan.ToString()
        } else {
            $duration = "Unknown"
        }
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "TaskSequenceDuration" -Value $duration | Out-Null
        Write-Host "Task Sequence Duration: $duration" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not calculate Task Sequence Duration: $($_.Exception.Message)"
        Set-RegistryValue -Path $InventoryOSDRegPath -Name "TaskSequenceDuration" -Value "Unknown" | Out-Null
    }
}

#Driver Inventory
if ($InventoryDriverMigrateCount -ne "" -and $null -ne $InventoryDriverMigrateCount) {
    Write-Host "DriverPack Migrate Count: $InventoryDriverMigrateCount" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackMigrateCount" -Value $InventoryDriverMigrateCount | Out-Null
}
if ($InventoryDriverPackURL -ne "" -and $null -ne $InventoryDriverPackURL) {    
    Write-Host "DriverPack URL: $InventoryDriverPackURL" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackURL" -Value $InventoryDriverPackURL | Out-Null
}
if ($InventoryDriverPackName -ne "" -and $null -ne $InventoryDriverPackName) {
    Write-Host "DriverPack Name: $InventoryDriverPackName" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackName" -Value $InventoryDriverPackName | Out-Null
}
if ($InventoryDriverPackID -ne "" -and $null -ne $InventoryDriverPackID) {
    Write-Host "DriverPack ID: $InventoryDriverPackID" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackID" -Value $InventoryDriverPackID | Out-Null
}
if ($InventoryDriverPackCustom -ne "" -and $null -ne $InventoryDriverPackCustom) {
    Write-Host "DriverPack Custom: $InventoryDriverPackCustom" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackCustom" -Value $InventoryDriverPackCustom | Out-Null
}
if ($InventoryDriverPackCustomCount -ne "" -and $null -ne $InventoryDriverPackCustomCount) {
    Write-Host "DriverPack Custom Count: $InventoryDriverPackCustomCount" -ForegroundColor Green
    Set-RegistryValue -Path $InventoryOSDRegPath -Name "DriverPackCustomCount" -Value $InventoryDriverPackCustomCount | Out-Null
}

if ($InventoryApps -eq "True") {
    Write-Host "`nInstalled Applications:" -ForegroundColor Yellow
    $installedApps = Get-InstalledApps
    $recordApps = $installedApps | Where-Object {$_.DisplayName -ne "Remote Desktop Connection"}
    if ($recordApps) {
        New-Item -Path "$InventoryOSDRegPath\Apps" -ItemType Directory -Force | Out-Null
        $recordApps | ForEach-Object {
            Set-RegistryValue -Path "$InventoryOSDRegPath\Apps" -Name "App_$($_.DisplayName)" -Value "$($_.DisplayVersion) by $($_.Publisher)" | Out-Null
            Write-Host "  Installed: $($_.DisplayName) - Version: $($_.DisplayVersion) by $($_.Publisher)" -ForegroundColor Green
        }
    } else {
        Write-Warning "No installed applications found."
    }
}


# Additional useful information
Write-Host "`nAdditional Information:" -ForegroundColor Yellow
Set-RegistryValue -Path $InventoryOSDRegPath -Name "ScriptVersion" -Value "1.0" | Out-Null

# Summary
Write-Host "`n=== OSD Registry Inventory Completed ===" -ForegroundColor Magenta
Write-Host "All deployment information has been written to: $InventoryOSDRegPath" -ForegroundColor Green
Write-Host "Finish Time: $finishTime" -ForegroundColor Yellow

# Display final registry contents for verification
Write-Host "`nRegistry Contents Verification:" -ForegroundColor Cyan
try {
    $regValues = Get-ItemProperty -Path $InventoryOSDRegPath -ErrorAction SilentlyContinue
    if ($regValues) {
        $regValues.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    } else {
        Write-Warning "Could not read back registry values for verification"
    }
}
catch {
    Write-Warning "Could not verify registry contents: $($_.Exception.Message)"
}

Write-Host "`nOSD Registry Inventory process completed successfully!" -ForegroundColor Green