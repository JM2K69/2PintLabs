<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>
if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}

Import-Module DeployR.Utility

# Get the provided variables
$DisableWindowsConsumerFeatures = ${TSEnv:DisableWindowsConsumerFeatures}
$DisableWidgetsOnLockScreen = ${TSEnv:DisableWidgetsOnLockScreen}
[string]$RegisteredOwner = ${TSEnv:RegisteredOwner}
[string]$RegisteredOrganization = ${TSEnv:RegisteredOrganization}
[string]$RegisteredOwner = ${TSEnv:RegisteredOwner}
[string]$OneDriveUpdate = ${TSEnv:OneDriveUpdate}
[string]$OEMSupportPhone = ${TSEnv:OEMSupportPhone}
[string]$OEMSupportHours = ${TSEnv:OEMSupportHours}
[string]$OEMSupportURL = ${TSEnv:OEMSupportURL}
[string]$Manufacturer = ${TSEnv:MakeAlias}
[string]$Model = ${TSEnv:ModelAlias}

write-host "==================================================================="
write-host "Tweaks for Windows 11"
write-host "Reporting Variables:"
write-host "DisableWindowsConsumerFeatures: $DisableWindowsConsumerFeatures"
write-host "DisableWidgetsOnLockScreen: $DisableWidgetsOnLockScreen" 
write-host "RegisteredOwner: $RegisteredOwner"
write-host "RegisteredOrganization: $RegisteredOrganization"
write-host "OneDriveUpdate: $OneDriveUpdate"
write-host "OEMSupportPhone: $OEMSupportPhone"
write-host "OEMSupportHours: $OEMSupportHours"
write-host "OEMSupportURL: $OEMSupportURL"

# Removes Task View from the Taskbar
if ($DisableWindowsConsumerFeatures -eq $true) {
    Write-Host "Attempting to run: DisableWindowsConsumerFeatures"
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -ItemType directory -Force | Out-Null
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}

}
# Removes Widgets from the Lock Screen
if ($DisableWidgetsOnLockScreen -eq $true) {
    <#  This isn't working as I'd expected, so I'm going to try a different method
    Write-Host "Attempting to run: DisableWidgetsOnLockScreen"
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -ItemType directory -Force | Out-Null
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenWidgetsEnabled" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -ItemType directory -Force | Out-Null
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenWidgetsEnabled" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    #>
    Write-Host "Attempting to run: DisableWidgetsOnLockScreen System Wide"
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -ItemType directory -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "DisableWidgetsOnLockScreen" -PropertyType Dword -value 0 -Force | Out-Null

    [GC]::Collect()
    Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
    REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
    Write-Host "Attempting to run: DisableWidgetsOnLockScreen Default Profile"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Lock Screen" -Name "LockScreenWidgetsEnabled" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    Start-Sleep -Seconds 1
    [GC]::Collect()
    Write-Host "Unmounting Default User Registry Hive (REG UNLOAD HKLM\Default)"
    REG UNLOAD HKLM\Default
}

if ($null -ne $RegisteredOwner) {
    Write-Host "Attempting to run: RegisteredOwner"
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOwner" -Value "$RegisteredOwner" -PropertyType STRING -Force
    try { $reg.Handle.Close() } catch {}
}

if ($null -ne $RegisteredOrganization) {
    Write-Host "Attempting to run: RegisteredOrganization"
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value "$RegisteredOrganization" -PropertyType STRING -Force
    try { $reg.Handle.Close() } catch {}
}
[GC]::Collect()


if ($OneDriveUpdate -eq "true") {
    <#
    This script downloads and installs the OneDrive setup executable for Machine Level vs User Level.
    #>
    $OneDriveSetup = "https://go.microsoft.com/fwlink/?linkid=844652"
    $OneDriveARMSetup = "https://go.microsoft.com/fwlink/?linkid=2282608"

    $dest = "$($env:TEMP)\OneDriveSetup.exe"
    $client = new-object System.Net.WebClient
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $url = $OneDriveARMSetup
    } else {
        $url = $OneDriveSetup
    }
    Write-Host "Downloading OneDriveSetup: $url"
    $client.DownloadFile($url, $dest)
    Write-Host "Installing: $dest"
    $proc = Start-Process $dest -ArgumentList "/allusers /silent" -WindowStyle Hidden -PassThru
    $proc.WaitForExit()
    Write-Host "OneDriveSetup exit code: $($proc.ExitCode)"

    Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
    REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT

    Write-Host "Making sure the Run key exists"
    if (-not (Test-Path -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Run")) {
        New-Item -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Run" -ItemType directory -Force -ErrorAction SilentlyContinue | Out-Null
    }
    <#
    & reg.exe add "HKLM\Default\Software\Microsoft\Windows\CurrentVersion\Run" /f /reg:64 2>&1 | Out-Null
    & reg.exe query "HKLM\Default\Software\Microsoft\Windows\CurrentVersion\Run" /reg:64 2>&1 | Out-Null
    #>
    Write-Host "Changing OneDriveSetup value to point to the machine wide EXE"
    # Quotes are so problematic, we'll use the more risky approach and hope garbage collection cleans it up later
    Set-ItemProperty -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Run" -Name OneDriveSetup -Value """C:\Program Files\Microsoft OneDrive\Onedrive.exe"" /background" | Out-Null


    [GC]::Collect()
    Write-Host "Unmounting Default User Registry Hive (REG UNLOAD HKLM\Default)"
    REG UNLOAD HKLM\Default
}

Write-Host "Configuring OEM branding info"
if ($null -ne $Manufacturer) {
    Write-Host "Setting Manufacturer: $Manufacturer"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Manufacturer" -Value $Manufacturer -Force | Out-Null
}
if ($null -ne $Model) {
    Write-Host "Setting Model: $Model"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value $Model -Force | Out-Null
}
if ($null -ne $OEMSupportPhone -and $OEMSupportPhone -ne "") {
    Write-Host "Setting SupportPhone: $OEMSupportPhone"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportPhone" -Value $OEMSupportPhone -Force | Out-Null
}
if ($null -ne $OEMSupportHours -and $OEMSupportHours -ne "") {
    Write-Host "Setting SupportHours: $OEMSupportHours"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportHours" -Value $OEMSupportHours -Force | Out-Null
}
if ($null -ne $OEMSupportURL -and $OEMSupportURL -ne "") {
    Write-Host "Setting SupportURL: $OEMSupportURL"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportURL" -Value $OEMSupportURL -Force | Out-Null
}

Write-Host "Tweaks for Windows 11 UI COMPLETE"
Write-Host "==================================================================="