<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>


Import-Module DeployR.Utility

# Get the provided variables
$DisableWindowsConsumerFeatures = [bool]${TSEnv:DisableWindowsConsumerFeatures}
$DisableWidgetsOnLockScreen = [bool]${TSEnv:DisableWidgetsOnLockScreen}


$TaskBarRemoveCopilot = [bool]${TSEnv:TaskBarRemoveCopilot}
write-host "==================================================================="
write-host "Tweaks for Windows 11"
write-host "Reporting Variables:"
write-host "DisableWindowsConsumerFeatures: $DisableWindowsConsumerFeatures"
write-host "DisableWidgetsOnLockScreen: $DisableWidgetsOnLockScreen" 



# Removes Task View from the Taskbar
if ($DisableWindowsConsumerFeatures) {
    Write-Host "Attempting to run: DisableWindowsConsumerFeatures"
    $reg = New-ItemProperty "HKLM:\Default\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    $reg = New-ItemProperty "HKLM:\Default\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Widgets from the Taskbar
if ($DisableWidgetsOnLockScreen) {
    Write-Host "Attempting to run: DisableWidgetsOnLockScreen"
    $reg = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenWidgetsEnabled" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}

# Removes Copilot from the Taskbar
if ($TaskBarRemoveCopilot) {
    Write-Host "Attempting to run: TaskBarRemoveCopilot"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Chat from the Taskbar
if ($TaskBarRemoveChat) {
    Write-Host "Attempting to run: TaskBarRemoveChat"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu alignment 0=Left
if ($TaskBarMoveStartLeft) {
    Write-Host "Attempting to run: TaskBarMoveStartLeft"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMorePins) {
    Write-Host "Attempting to run: TaskBarStartMorePins"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMoreRecommendations) {
    Write-Host "Attempting to run: TaskBarStartMoreRecommendations"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "2" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}    # Removes search from the Taskbar
if ($TaskBarRemoveSearch) {
    Write-Host "Attempting to run: TaskBarRemoveSearch"
    $RegKey = "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    if (-not(Test-Path $RegKey )) {
        $reg = New-Item $RegKey -Force | Out-Null
        try { $reg.Handle.Close() } catch {}
    }
    $reg = New-ItemProperty $RegKey -Name "RemoveSearch"  -Value "reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Search /t REG_DWORD /v SearchboxTaskbarMode /d 0 /f" -PropertyType String -Force
    try { $reg.Handle.Close() } catch {}
}

[GC]::Collect()
REG UNLOAD HKLM\Default


write-host "Tweaks for Windows 11 UI COMPLETE"
write-host "==================================================================="