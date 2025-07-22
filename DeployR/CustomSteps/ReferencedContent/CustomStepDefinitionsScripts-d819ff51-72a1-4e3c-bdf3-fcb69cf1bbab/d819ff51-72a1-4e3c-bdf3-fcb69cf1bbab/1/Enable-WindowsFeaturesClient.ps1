#Requires -RunAsAdministrator
<#
.SYNOPSIS
Enable Windows Features Client Script

.DESCRIPTION
This script enables various Windows features based on the variables defined below.
Each feature can be enabled/disabled by setting the corresponding variable to $true/$false.

.NOTES
Author: Generated Script
Date: July 20, 2025
Requires: Administrator privileges
#>

#Adding Support for DeployR Task Sequence Variables
try {
    Import-Module DeployR.Utility
}
catch {}

# Detect if we're running in WinPE
$inWinPE = $env:SystemDrive -eq "X:"
$OfflineOSPath = "S:\"

# Set the appropriate path for Windows features operations
if ($inWinPE) {
    Write-Host "WinPE detected - targeting offline OS at $OfflineOSPath" -ForegroundColor Cyan
    
    # Validate that the offline OS path exists
    if (-not (Test-Path $OfflineOSPath)) {
        Write-Error "Offline OS path '$OfflineOSPath' not found. Cannot proceed with Windows features configuration."
        return $false
    }
    
    # Validate that it looks like a Windows installation
    $WindowsDir = Join-Path $OfflineOSPath "Windows"
    if (-not (Test-Path $WindowsDir)) {
        Write-Error "Windows directory not found at '$WindowsDir'. This may not be a valid Windows installation."
        return $false
    }
    
    Write-Host "Offline Windows installation validated at $OfflineOSPath" -ForegroundColor Green
    $WindowsPath = $OfflineOSPath
} else {
    Write-Host "Full Windows OS detected - targeting online system" -ForegroundColor Cyan
    $WindowsPath = $null  # Will use -Online parameter
}

if (Get-Module -name "DeployR.Utility"){
    $inTS = $true
    # Get the provided variables
    $FeatureEnableSkipReboot = ${TSEnv:FeatureEnableSkipReboot} # SkipReboot
    $FeatureEnableHyperV =  ${TSEnv:FeatureEnableHyperV}                # Microsoft-Hyper-V-All
    $FeatureEnableIIS = ${TSEnv:FeatureEnableIIS}                       # IIS-WebServerRole
    $FeatureEnableTelnetClient = ${TSEnv:FeatureEnableTelnetClient}     # TelnetClient
    $FeatureEnableTFTPClient = ${TSEnv:FeatureEnableTFTPClient}         # TFTP
    $FeatureEnableNFSClient = ${TSEnv:FeatureEnableNFSClient}           # ServicesForNFS-ClientOnly
    $FeatureEnableSMB1 = ${TSEnv:FeatureEnableSMB1}                     # SMB1Protocol
    $FeatureEnableNetFx3 = ${TSEnv:FeatureEnableNetFx3}                 # NetFx3
    $FeatureEnableNetFx4Extended = ${TSEnv:FeatureEnableNetFx4Extended} # NetFx4Extended-ASPNET45
    $FeatureEnableWindowsSubsystemLinux = ${TSEnv:FeatureEnableWindowsSubsystemLinux} # Microsoft-Windows-Subsystem-Linux
    $FeatureEnableVirtualMachinePlatform = ${TSEnv:FeatureEnableVirtualMachinePlatform} # VirtualMachinePlatform
    $FeatureEnableContainers = ${TSEnv:FeatureEnableContainers}         # Containers
    $FeatureEnableWindowsDefenderApplicationGuard = ${TSEnv:FeatureEnableWindowsDefenderApplicationGuard} # Windows-Defender-ApplicationGuard
    $FeatureEnableWindowsSandbox = ${TSEnv:FeatureEnableWindowsSandbox} # Containers-DisposableClientVM
    $FeatureEnableLegacyComponents = ${TSEnv:FeatureEnableLegacyComponents} # LegacyComponents
    $FeatureEnableDirectPlay = ${TSEnv:FeatureEnableDirectPlay}         # DirectPlay
    $FeatureEnablePrintAndDocumentServices = ${TSEnv:FeatureEnablePrintAndDocumentServices} # Printing-PrintToPDFServices-Features
    $FeatureEnableWorkFolders = ${TSEnv:FeatureEnableWorkFolders}       # WorkFolders-Client
    $FeatureEnableWindowsMediaPlayer = ${TSEnv:FeatureEnableWindowsMediaPlayer} # WindowsMediaPlayer
    $FeatureEnableInternetExplorer11 = ${TSEnv:FeatureEnableInternetExplorer11} # Internet-Explorer-Optional-amd64
    $FeatureEnableMicrosoftPrintToPDF = ${TSEnv:FeatureEnableMicrosoftPrintToPDF} # Printing-PrintToPDFServices-Features
    $FeatureEnableXPSViewer = ${TSEnv:FeatureEnableXPSViewer}           # Printing-XPSServices-Features
    $FeatureEnableFaxAndScan = ${TSEnv:FeatureEnableFaxAndScan}         # FaxServicesClientPackage
    $FeatureEnableMicrosoftMessageQueue = ${TSEnv:FeatureEnableMicrosoftMessageQueue} # MSMQ-Container
    $FeatureEnableSimpleTCP = ${TSEnv:FeatureEnableSimpleTCP}           # SimpleTCP
    $FeatureEnableSNMP = ${TSEnv:FeatureEnableSNMP}                     # SNMP
}
else {
    #Testing outside of DeployR
    $FeatureEnableSkipReboot = $true                                       # SkipReboot
    $FeatureEnableHyperV = $true                                        # Hyper-V Platform
    $FeatureEnableIIS = $false                                          # Internet Information Services Web Server
    $FeatureEnableTelnetClient = $false                                 # Telnet Client
    $FeatureEnableTFTPClient = $false                                   # TFTP Client
    $FeatureEnableNFSClient = $false                                    # Services for NFS Client
    $FeatureEnableSMB1 = $false                                         # SMB 1.0/CIFS File Sharing Support
    $FeatureEnableNetFx3 = $false                                       # .NET Framework 3.5 (includes .NET 2.0 and 3.0)
    $FeatureEnableNetFx4Extended = $false                               # .NET Framework 4.x Advanced Services
    $FeatureEnableWindowsSubsystemLinux = $false                        # Windows Subsystem for Linux
    $FeatureEnableVirtualMachinePlatform = $false                       # Virtual Machine Platform
    $FeatureEnableContainers = $false                                   # Containers Platform
    $FeatureEnableWindowsDefenderApplicationGuard = $false              # Windows Defender Application Guard
    $FeatureEnableWindowsSandbox = $false                               # Windows Sandbox
    $FeatureEnableLegacyComponents = $false                             # Legacy Components
    $FeatureEnableDirectPlay = $false                                   # DirectPlay
    $FeatureEnablePrintAndDocumentServices = $false                     # Microsoft Print to PDF
    $FeatureEnableWorkFolders = $false                                  # Work Folders Client
    $FeatureEnableWindowsMediaPlayer = $false                           # Windows Media Player
    $FeatureEnableInternetExplorer11 = $false                           # Internet Explorer 11
    $FeatureEnableMicrosoftPrintToPDF = $false                          # Microsoft Print to PDF
    $FeatureEnableXPSViewer = $false                                    # Microsoft XPS Document Writer
    $FeatureEnableFaxAndScan = $false                                   # Windows Fax and Scan
    $FeatureEnableMicrosoftMessageQueue = $false                        # Microsoft Message Queue (MSMQ) Server
    $FeatureEnableSimpleTCP = $false                                    # Simple TCP/IP Services
    $FeatureEnableSNMP = $false                                         # Simple Network Management Protocol (SNMP)
    
}
if ($FeatureEnableSkipReboot -eq "true") {[bool]$SkipReboot = $true} 
else {[bool]$SkipReboot = $false}
if ($FeatureEnableHyperV -eq "true") {[bool]$EnableHyperV = $true} 
else {[bool]$EnableHyperV = $false}
if ($FeatureEnableIIS -eq "true") {[bool]$EnableIIS = $true} 
else {[bool]$EnableIIS = $false}
if ($FeatureEnableTelnetClient -eq "true") {[bool]$EnableTelnetClient = $true} 
else {[bool]$EnableTelnetClient = $false}
if ($FeatureEnableTFTPClient -eq "true") {[bool]$EnableTFTPClient = $true} 
else {[bool]$EnableTFTPClient = $false}
if ($FeatureEnableNFSClient -eq "true") {[bool]$EnableNFSClient = $true} 
else {[bool]$EnableNFSClient = $false}
if ($FeatureEnableSMB1 -eq "true") {[bool]$EnableSMB1 = $true} 
else {[bool]$EnableSMB1 = $false}
if ($FeatureEnableNetFx3 -eq "true") {[bool]$EnableNetFx3 = $true} 
else {[bool]$EnableNetFx3 = $false}
if ($FeatureEnableNetFx4Extended -eq "true") {[bool]$EnableNetFx4Extended = $true} 
else {[bool]$EnableNetFx4Extended = $false}
if ($FeatureEnableWindowsSubsystemLinux -eq "true") {[bool]$EnableWindowsSubsystemLinux = $true} 
else {[bool]$EnableWindowsSubsystemLinux = $false}
if ($FeatureEnableVirtualMachinePlatform -eq "true") {[bool]$EnableVirtualMachinePlatform = $true} 
else {[bool]$EnableVirtualMachinePlatform = $false}
if ($FeatureEnableContainers -eq "true") {[bool]$EnableContainers = $true} 
else {[bool]$EnableContainers = $false}
if ($FeatureEnableWindowsDefenderApplicationGuard -eq "true") {[bool]$EnableWindowsDefenderApplicationGuard = $true} 
else {[bool]$EnableWindowsDefenderApplicationGuard = $false}
if ($FeatureEnableWindowsSandbox -eq "true") {[bool]$EnableWindowsSandbox = $true} 
else {[bool]$EnableWindowsSandbox = $false}
if ($FeatureEnableLegacyComponents -eq "true") {[bool]$EnableLegacyComponents = $true} 
else {[bool]$EnableLegacyComponents = $false}
if ($FeatureEnableDirectPlay -eq "true") {[bool]$EnableDirectPlay = $true} 
else {[bool]$EnableDirectPlay = $false}
if ($FeatureEnablePrintAndDocumentServices -eq "true") {[bool]$EnablePrintAndDocumentServices = $true} 
else {[bool]$EnablePrintAndDocumentServices = $false}
if ($FeatureEnableWorkFolders -eq "true") {[bool]$EnableWorkFolders = $true} 
else {[bool]$EnableWorkFolders = $false}
if ($FeatureEnableWindowsMediaPlayer -eq "true") {[bool]$EnableWindowsMediaPlayer = $true} 
else {[bool]$EnableWindowsMediaPlayer = $false}
if ($FeatureEnableInternetExplorer11 -eq "true") {[bool]$EnableInternetExplorer11 = $true} 
else {[bool]$EnableInternetExplorer11 = $false}
if ($FeatureEnableMicrosoftPrintToPDF -eq "true") {[bool]$EnableMicrosoftPrintToPDF = $true} 
else {[bool]$EnableMicrosoftPrintToPDF = $false}
if ($FeatureEnableXPSViewer -eq "true") {[bool]$EnableXPSViewer = $true} 
else {[bool]$EnableXPSViewer = $false}
if ($FeatureEnableFaxAndScan -eq "true") {[bool]$EnableFaxAndScan = $true} 
else {[bool]$EnableFaxAndScan = $false}
if ($FeatureEnableMicrosoftMessageQueue -eq "true") {[bool]$EnableMicrosoftMessageQueue = $true} 
else {[bool]$EnableMicrosoftMessageQueue = $false}
if ($FeatureEnableSimpleTCP -eq "true") {[bool]$EnableSimpleTCP = $true} 
else {[bool]$EnableSimpleTCP = $false}
if ($FeatureEnableSNMP -eq "true") {[bool]$EnableSNMP = $true} 
else {[bool]$EnableSNMP = $false}

# Reboot tracking variable
$RebootRequired = $false

# Function to check if a Windows feature is enabled
function Get-WindowsFeatureStatus {
    param(
    [string]$FeatureName,
    [string]$DisplayName,
    [string]$WindowsPath = $null
    )
    
    try {
        if ($WindowsPath) {
            # WinPE scenario - check offline OS
            $feature = Get-WindowsOptionalFeature -FeatureName $FeatureName -Path $WindowsPath -ErrorAction SilentlyContinue
        } else {
            # Full OS scenario - check online
            $feature = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online -ErrorAction SilentlyContinue
        }
        
        if ($feature) {
            return @{
                Name = $DisplayName
                FeatureName = $FeatureName
                State = $feature.State
                IsEnabled = ($feature.State -eq "Enabled")
            }
        } else {
            return @{
                Name = $DisplayName
                FeatureName = $FeatureName
                State = "NotFound"
                IsEnabled = $false
            }
        }
    }
    catch {
        return @{
            Name = $DisplayName
            FeatureName = $FeatureName
            State = "Error"
            IsEnabled = $false
        }
    }
}

# Function to enable/disable Windows features
function Set-WindowsFeatureState {
    param(
    [string]$FeatureName,
    [bool]$Enable,
    [string]$DisplayName,
    [string]$WindowsPath = $null
    )
    
    try {
        if ($Enable) {
            Write-Host "Enabling feature: $DisplayName ($FeatureName)" -ForegroundColor Green
            
            if ($WindowsPath) {
                # WinPE scenario - enable on offline OS
                Write-Host "  Applying to offline OS at: $WindowsPath" -ForegroundColor Gray
                $result = Enable-WindowsOptionalFeature -FeatureName $FeatureName -Path $WindowsPath -All
                # Note: Offline operations don't require reboot tracking as the OS isn't running
                Write-Host "  Feature enabled on offline OS" -ForegroundColor Green
            } else {
                # Full OS scenario - enable online
                Write-Host "  Applying to online system" -ForegroundColor Gray
                $result = Enable-WindowsOptionalFeature -FeatureName $FeatureName -Online -All -NoRestart
                if ($result.RestartNeeded) {
                    $script:RebootRequired = $true
                    Write-Warning "Reboot required for feature: $DisplayName"
                }
            }
        } else {
            Write-Host "Skipping feature: $DisplayName ($FeatureName)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to configure feature $DisplayName ($FeatureName): $($_.Exception.Message)"
    }
}

# Main execution
if ($inWinPE) {
    Write-Host "Starting Windows Features Configuration for WinPE (Offline OS: $OfflineOSPath)..." -ForegroundColor Cyan
} else {
    Write-Host "Starting Windows Features Configuration for Full Windows OS..." -ForegroundColor Cyan
}

# Define all features with their settings
$AllFeatures = @(
@{ Variable = $EnableHyperV; FeatureName = "Microsoft-Hyper-V-All"; DisplayName = "Hyper-V" },
@{ Variable = $EnableIIS; FeatureName = "IIS-WebServerRole"; DisplayName = "Internet Information Services (IIS)" },
@{ Variable = $EnableTelnetClient; FeatureName = "TelnetClient"; DisplayName = "Telnet Client" },
@{ Variable = $EnableTFTPClient; FeatureName = "TFTP"; DisplayName = "TFTP Client" },
@{ Variable = $EnableNFSClient; FeatureName = "ServicesForNFS-ClientOnly"; DisplayName = "Services for NFS" },
@{ Variable = $EnableSMB1; FeatureName = "SMB1Protocol"; DisplayName = "SMB 1.0/CIFS File Sharing Support" },
@{ Variable = $EnableNetFx3; FeatureName = "NetFx3"; DisplayName = ".NET Framework 3.5" },
@{ Variable = $EnableNetFx4Extended; FeatureName = "NetFx4Extended-ASPNET45"; DisplayName = ".NET Framework 4.x Extended" },
@{ Variable = $EnableWindowsSubsystemLinux; FeatureName = "Microsoft-Windows-Subsystem-Linux"; DisplayName = "Windows Subsystem for Linux" },
@{ Variable = $EnableVirtualMachinePlatform; FeatureName = "VirtualMachinePlatform"; DisplayName = "Virtual Machine Platform" },
@{ Variable = $EnableContainers; FeatureName = "Containers"; DisplayName = "Containers" },
@{ Variable = $EnableWindowsDefenderApplicationGuard; FeatureName = "Windows-Defender-ApplicationGuard"; DisplayName = "Windows Defender Application Guard" },
@{ Variable = $EnableWindowsSandbox; FeatureName = "Containers-DisposableClientVM"; DisplayName = "Windows Sandbox" },
@{ Variable = $EnableLegacyComponents; FeatureName = "LegacyComponents"; DisplayName = "Legacy Components" },
@{ Variable = $EnableDirectPlay; FeatureName = "DirectPlay"; DisplayName = "DirectPlay" },
@{ Variable = $EnablePrintAndDocumentServices; FeatureName = "Printing-PrintToPDFServices-Features"; DisplayName = "Microsoft Print to PDF" },
@{ Variable = $EnableWorkFolders; FeatureName = "WorkFolders-Client"; DisplayName = "Work Folders Client" },
@{ Variable = $EnableWindowsMediaPlayer; FeatureName = "WindowsMediaPlayer"; DisplayName = "Windows Media Player" },
@{ Variable = $EnableInternetExplorer11; FeatureName = "Internet-Explorer-Optional-amd64"; DisplayName = "Internet Explorer 11" },
@{ Variable = $EnableXPSViewer; FeatureName = "Printing-XPSServices-Features"; DisplayName = "XPS Viewer" },
@{ Variable = $EnableFaxAndScan; FeatureName = "FaxServicesClientPackage"; DisplayName = "Windows Fax and Scan" },
@{ Variable = $EnableMicrosoftMessageQueue; FeatureName = "MSMQ-Container"; DisplayName = "Microsoft Message Queue (MSMQ)" },
@{ Variable = $EnableSimpleTCP; FeatureName = "SimpleTCP"; DisplayName = "Simple TCP/IP Services" },
@{ Variable = $EnableSNMP; FeatureName = "SNMP"; DisplayName = "Simple Network Management Protocol (SNMP)" }
)

# Phase 1: Check current status of all features
Write-Host "`n=== PHASE 1: Current Status Report ===" -ForegroundColor Magenta
Write-Host "Checking current status of all Windows features..." -ForegroundColor Cyan

$CurrentlyEnabled = @()
$CurrentlyDisabled = @()

foreach ($feature in $AllFeatures) {
    $status = Get-WindowsFeatureStatus -FeatureName $feature.FeatureName -DisplayName $feature.DisplayName -WindowsPath $WindowsPath
    if ($status.IsEnabled) {
        $CurrentlyEnabled += $status
        Write-Host "✓ ENABLED: $($status.Name)" -ForegroundColor Green
    } else {
        $CurrentlyDisabled += $status
        Write-Host "✗ DISABLED: $($status.Name) ($($status.State))" -ForegroundColor Red
    }
}

Write-Host "`nSUMMARY - Currently Enabled: $($CurrentlyEnabled.Count) | Currently Disabled: $($CurrentlyDisabled.Count)" -ForegroundColor Cyan

# Phase 2: Report what will be enabled
Write-Host "`n=== PHASE 2: Features to be Enabled ===" -ForegroundColor Magenta
$FeaturesToEnable = $AllFeatures | Where-Object { $_.Variable -eq $true }

if ($FeaturesToEnable.Count -gt 0) {
    Write-Host "The following features will be enabled:" -ForegroundColor Cyan
    foreach ($feature in $FeaturesToEnable) {
        $currentStatus = $CurrentlyEnabled | Where-Object { $_.FeatureName -eq $feature.FeatureName }
        if ($currentStatus) {
            Write-Host "→ $($feature.DisplayName) (Already Enabled)" -ForegroundColor Yellow
        } else {
            Write-Host "→ $($feature.DisplayName) (Will be Enabled)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "No features are set to be enabled." -ForegroundColor Yellow
}

# Phase 3: Enable features
Write-Host "`n=== PHASE 3: Enabling Features ===" -ForegroundColor Magenta

# Process each feature based on variable settings
foreach ($feature in $FeaturesToEnable) {
    Set-WindowsFeatureState -FeatureName $feature.FeatureName -Enable $true -DisplayName $feature.DisplayName -WindowsPath $WindowsPath
}

# Phase 4: Final status report of enabled features
Write-Host "`n=== PHASE 4: Final Status Report ===" -ForegroundColor Magenta
Write-Host "Checking final status of all enabled features..." -ForegroundColor Cyan

$FinalEnabledFeatures = @()
foreach ($feature in $AllFeatures) {
    $status = Get-WindowsFeatureStatus -FeatureName $feature.FeatureName -DisplayName $feature.DisplayName -WindowsPath $WindowsPath
    if ($status.IsEnabled) {
        $FinalEnabledFeatures += $status
        Write-Host "✓ ENABLED: $($status.Name)" -ForegroundColor Green
    }
}

Write-Host "`nFINAL SUMMARY:" -ForegroundColor Cyan
Write-Host "Total Features Enabled: $($FinalEnabledFeatures.Count)" -ForegroundColor Green
Write-Host "Features that were already enabled: $($CurrentlyEnabled.Count)" -ForegroundColor Yellow
Write-Host "Features newly enabled this session: $($FinalEnabledFeatures.Count - $CurrentlyEnabled.Count)" -ForegroundColor Green

Write-Host "`nWindows Features Configuration Complete!" -ForegroundColor Cyan

if ($inWinPE) {
    Write-Host "Features have been applied to the offline OS at $OfflineOSPath" -ForegroundColor Green
    Write-Host "No reboot required in WinPE - features will be active when the OS boots." -ForegroundColor Green
    Write-Host "Reboot Required: $false" -ForegroundColor Green
    $RebootRequired = $false
} elseif ($RebootRequired) {
    Write-Warning "A reboot is required to complete the installation of one or more features."
    Write-Host "Reboot Required: $RebootRequired" -ForegroundColor Red
    if ($SkipReboot) {
        Write-Host "Skipping reboot as per configuration." -ForegroundColor Yellow
    } 
    else {
        if ($inTS) {
            Write-Host "Setting SMSTSRebootRequested to true for task sequence." -ForegroundColor Yellow
            # Set the task sequence variable to indicate a reboot is requested
            ${TSEnv:SMSTSRebootRequested} = $true
        }
        else {
            Write-Host "Please reboot the system to apply changes." -ForegroundColor Yellow
        }
    }

} else {
    Write-Host "No reboot required." -ForegroundColor Green
    Write-Host "Reboot Required: $RebootRequired" -ForegroundColor Green
}
