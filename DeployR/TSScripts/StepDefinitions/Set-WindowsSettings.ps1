<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>


Import-Module DeployR.Utility

# Get the provided variables
$DisableWindowsConsumerFeatures = ${TSEnv:DisableWindowsConsumerFeatures}
$DisableWidgetsOnLockScreen = ${TSEnv:DisableWidgetsOnLockScreen}
[string]$RegisteredOwner = ${TSEnv:RegisteredOwner}
[string]$RegisteredOrganization = ${TSEnv:RegisteredOrganization}


write-host "==================================================================="
write-host "Tweaks for Windows 11"
write-host "Reporting Variables:"
write-host "DisableWindowsConsumerFeatures: $DisableWindowsConsumerFeatures"
write-host "DisableWidgetsOnLockScreen: $DisableWidgetsOnLockScreen" 
write-host "RegisteredOwner: $RegisteredOwner"
write-host "RegisteredOrganization: $RegisteredOrganization" 


# Removes Task View from the Taskbar
if ($DisableWindowsConsumerFeatures -eq $true) {
    Write-Host "Attempting to run: DisableWindowsConsumerFeatures"
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -ItemType directory -Force | Out-Null
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}

}
# Removes Widgets from the Taskbar
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
    [GC]::Collect()
    Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
    REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
    Write-Host "Attempting to run: DisableWidgetsOnLockScreen"
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
write-host "Tweaks for Windows 11 UI COMPLETE"
write-host "==================================================================="