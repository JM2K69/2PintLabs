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
    Set-RegistryValue -Path $StampOSDRegPath -Name "TSID" -Value $tsID | Out-Null
    
    # 2. DeployR Server
    $deployRHost = ${TSEnv:DEPLOYRHOST}
    if (-not $deployRHost) { $deployRHost = "Unknown" }
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeployRServer" -Value $deployRHost | Out-Null
    
    # 3. OS Image Version
    $osImageVersion = ${TSEnv:OSIMAGEVERSION}
    if (-not $osImageVersion) { $osImageVersion = Get-OSBuildInfo }
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageVersion" -Value $osImageVersion | Out-Null
    
    # 4. OS Image Name/Edition
    $osImageName = ${TSEnv:OSIMAGENAME}
    if (-not $osImageName) { $osImageName = Get-OSEdition }
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageName" -Value $osImageName | Out-Null
    
} else {
    Write-Host "`nNon-Task Sequence Environment - Using local system information:" -ForegroundColor Yellow
    
    # Fallback values when not in task sequence
    Set-RegistryValue -Path $StampOSDRegPath -Name "TSID" -Value "No Task Sequence" | Out-Null
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeployRServer" -Value "Unknown" | Out-Null
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageVersion" -Value (Get-OSBuildInfo) | Out-Null
    Set-RegistryValue -Path $StampOSDRegPath -Name "OSImageName" -Value (Get-OSEdition) | Out-Null
}

Write-Host "`nSystem Information:" -ForegroundColor Yellow

# 5. Computer Name
$computerName = $env:COMPUTERNAME
if (-not $computerName) { $computerName = "Unknown" }
Set-RegistryValue -Path $StampOSDRegPath -Name "ComputerName" -Value $computerName | Out-Null

# 6. WinPE Information
write-host "Setting WinPE Information..."
if (${TSEnv:WinPEBuildInfo}){
    $winPEInfo = ${TSEnv:WinPEBuildInfo}
    Write-Host "WinPE Information: $winPEInfo"
    Set-RegistryValue -Path $StampOSDRegPath -Name "WinPEInfo" -Value $winPEInfo | Out-Null
} else {
    Write-Host "WinPE Information not available, skipping..." -ForegroundColor Yellow
}


# 7. Start Time (if available from TS, otherwise current time)
$startTime = if (Get-Module -Name "DeployR.Utility") {
    ${TSEnv:OSDStartTime}
} else {
    $null
}
<<<<<<< HEAD
if ($startTime) {
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentStartTime" -Value $startTime 
    Write-Host "Setting DeploymentStartTime to: $startTime" -ForegroundColor Green
}
else {
    Write-Host "No OSDStartTime found, Please add Step Definition 'Tweaks - Set Initial Variables' into the beginning of your Task Sequence" -ForegroundColor Yellow
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentStartTime" -Value "Missing Element, See Log File"
}



# 8. Finish Time (current time as this is when the stamp is being written)
$finishTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
Write-Host "Setting DeploymentFinishTime to: $finishTime" -ForegroundColor Green
Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentFinishTime" -Value $finishTime
=======
if (-not $startTime) { 
    Write-Host "Start Time not set in Task Sequence, ensure you've added the step to Set Initial Variables" -ForegroundColor Yellow
    Set-RegistryValue -Path $StampOSDRegPath -Name "Missing Start Data, See Log" -Value $startTime | Out-Null
}
else {
    Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentStartTime" -Value $startTime | Out-Null
    Write-Host "Deployment Start Time: $startTime" -ForegroundColor Green
}


# 8. Finish Time (current time as this is when the stamp is being written)
$finishTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Set-RegistryValue -Path $StampOSDRegPath -Name "DeploymentFinishTime" -Value $finishTime | Out-Null
>>>>>>> f5150d36fb3417c1429669ef823acd0d3a596d49

# Calculate Task Sequence Duration
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
    Set-RegistryValue -Path $StampOSDRegPath -Name "TaskSequenceDuration" -Value $duration | Out-Null
    Write-Host "Task Sequence Duration: $duration" -ForegroundColor Green
}
catch {
    Write-Warning "Could not calculate Task Sequence Duration: $($_.Exception.Message)"
    Set-RegistryValue -Path $StampOSDRegPath -Name "TaskSequenceDuration" -Value "Unknown" | Out-Null
}

# Additional useful information
Write-Host "`nAdditional Information:" -ForegroundColor Yellow
<<<<<<< HEAD
Set-RegistryValue -Path $StampOSDRegPath -Name "ScriptVersion" -Value "1.0"
=======
#Set-RegistryValue -Path $StampOSDRegPath -Name "LastStampUpdate" -Value $finishTime
Set-RegistryValue -Path $StampOSDRegPath -Name "ScriptVersion" -Value "1.0" | Out-Null
>>>>>>> f5150d36fb3417c1429669ef823acd0d3a596d49

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