#Requires -RunAsAdministrator
<#
.SYNOPSIS
OSD Registry Stamp Script

.DESCRIPTION
This script connects to the DeployR task sequence and writes deployment information to the registry.
Creates a comprehensive record of the OSD deployment process for tracking and reporting purposes.

.NOTES
Author: Generated Script
Date: July 28, 2025
Requires: Administrator privileges, DeployR Task Sequence environment
#>

# Adding Support for DeployR Task Sequence Variables
try {
    Import-Module DeployR.Utility
    Write-Host "DeployR.Utility module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to load DeployR.Utility module: $($_.Exception.Message)"
    Write-Warning "This script requires the DeployR Task Sequence environment"
}

# Define the registry path for OSD stamping
$StampOSDRegPath = if (Get-Module -Name "DeployR.Utility") {
    if (${TSEnv:StampOSDRegPath}) {
        ${TSEnv:StampOSDRegPath}
    } else {
        "HKLM:\SOFTWARE\2Pint Software\DeployR\OSD"
    }
} else {
    "HKLM:\SOFTWARE\2Pint Software\DeployR\OSD"
}

Write-Host "Using registry path: $StampOSDRegPath" -ForegroundColor Cyan

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

# Main execution
Write-Host "`n=== OSD Registry Stamp Started ===" -ForegroundColor Magenta
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

# Create the registry path if it doesn't exist
if (-not (New-RegistryPath -Path $StampOSDRegPath)) {
    Write-Error "Cannot proceed without registry path access"
    exit 1
}

Write-Host "`nWriting OSD deployment information to registry..." -ForegroundColor Cyan

# Collect and write deployment information
if (Get-Module -Name "DeployR.Utility") {
    Write-Host "`nTask Sequence Information:" -ForegroundColor Yellow
    
    # 1. TS ID
    $tsID = ${TSEnv:TSID}
    if (-not $tsID) { $tsID = "Unknown" }
    Set-RegistryValue -Path $StampOSDRegPath -Name "TSID" -Value $tsID
    
    # 2. DeployR Server
    $deployRHost = ${TSEnv:DEPLOYRHOST}
    if (-not $deployRHost) { $deployRHost = "Unknown" }
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeployRServer" -Value $deployRHost
    
    # 3. OS Image Version
    $osImageVersion = ${TSEnv:OSIMAGEVERSION}
    if (-not $osImageVersion) { $osImageVersion = Get-OSBuildInfo }
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageVersion" -Value $osImageVersion
    
    # 4. OS Image Name/Edition
    $osImageName = ${TSEnv:OSIMAGENAME}
    if (-not $osImageName) { $osImageName = Get-OSEdition }
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageName" -Value $osImageName
    
} else {
    Write-Host "`nNon-Task Sequence Environment - Using local system information:" -ForegroundColor Yellow
    
    # Fallback values when not in task sequence
    Set-RegistryValue -Path $StampOSDRegPath -Name "TSID" -Value "No Task Sequence"
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeployRServer" -Value "Unknown"
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageVersion" -Value (Get-OSBuildInfo)
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageName" -Value (Get-OSEdition)
}

Write-Host "`nSystem Information:" -ForegroundColor Yellow

# 5. Computer Name
$computerName = $env:COMPUTERNAME
if (-not $computerName) { $computerName = "Unknown" }
Set-RegistryValue -Path $StampOSDRegPath -Name "ComputerName" -Value $computerName

# 6. WinPE Information
$winPEInfo = Get-WinPEInfo
Set-RegistryValue -Path $StampOSDRegPath -Name "WinPEInfo" -Value $winPEInfo

# 7. Start Time (if available from TS, otherwise current time)
$startTime = if (Get-Module -Name "DeployR.Utility") {
    ${TSEnv:OSDStartTime}
} else {
    $null
}
if (-not $startTime) { $startTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentStartTime" -Value $startTime

# 8. Finish Time (current time as this is when the stamp is being written)
$finishTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentFinishTime" -Value $finishTime

# Additional useful information
Write-Host "`nAdditional Information:" -ForegroundColor Yellow
Set-RegistryValue -Path $StampOSDRegPath -Name "LastStampUpdate" -Value $finishTime
Set-RegistryValue -Path $StampOSDRegPath -Name "ScriptVersion" -Value "1.0"

# Summary
Write-Host "`n=== OSD Registry Stamp Completed ===" -ForegroundColor Magenta
Write-Host "All deployment information has been written to: $StampOSDRegPath" -ForegroundColor Green
Write-Host "Finish Time: $finishTime" -ForegroundColor Yellow

# Display final registry contents for verification
Write-Host "`nRegistry Contents Verification:" -ForegroundColor Cyan
try {
    $regValues = Get-ItemProperty -Path $StampOSDRegPath -ErrorAction SilentlyContinue
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

Write-Host "`nOSD Registry Stamp process completed successfully!" -ForegroundColor Green