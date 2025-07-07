<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>

Import-Module DeployR.Utility

# Get the provided variables
$TaskBarRemoveTaskView = ${TSEnv:TaskBarRemoveTaskView}
$TaskBarRemoveCopilot = ${TSEnv:TaskBarRemoveCopilot}
$TaskBarRemoveWidgets = ${TSEnv:TaskBarRemoveWidgets}
$TaskBarRemoveChat = ${TSEnv:TaskBarRemoveChat}
$TaskBarMoveStartLeft = ${TSEnv:TaskBarMoveStartLeft}
$TaskBarRemoveSearch = ${TSEnv:TaskBarRemoveSearch}
$TaskBarStartMorePins = ${TSEnv:TaskBarStartMorePins}
$TaskBarStartMoreRecommendations = ${TSEnv:TaskBarStartMoreRecommendations}

write-host "==================================================================="
write-host "User Taskbar Settings for Windows 11 UI"
write-host "Reporting Variables:"
write-host "TaskBarRemoveTaskView: $TaskBarRemoveTaskView" 
write-host "TaskBarRemoveCopilot: $TaskBarRemoveCopilot"
write-host "TaskBarRemoveWidgets: $TaskBarRemoveWidgets"
write-host "TaskBarRemoveChat: $TaskBarRemoveChat"
write-host "TaskBarMoveStartLeft: $TaskBarMoveStartLeft"
write-host "TaskBarRemoveSearch: $TaskBarRemoveSearch"
write-host "TaskBarStartMorePins: $TaskBarStartMorePins"
write-host "TaskBarStartMoreRecommendations: $TaskBarStartMoreRecommendations"



<#
Customize Taskbar in Windows 11
Sassan Fanai / Jörgen Nilsson
- then modified heavily by Gary Blok
Version 25.6.25
#>
[GC]::Collect()
Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
# Removes Task View from the Taskbar
if ($TaskBarRemoveTaskView -eq $true) {
    Write-Host "Attempting to run: TaskBarRemoveTaskView"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}
# Removes Widgets from the Taskbar
if ($TaskBarRemoveWidgets -eq $true) {
    Write-Host "Attempting to run: TaskBarRemoveWidgets"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Copilot from the Taskbar
if ($TaskBarRemoveCopilot -eq $true) {
    Write-Host "Attempting to run: TaskBarRemoveCopilot"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Chat from the Taskbar
if ($TaskBarRemoveChat -eq $true) {
    Write-Host "Attempting to run: TaskBarRemoveChat"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu alignment 0=Left
if ($TaskBarMoveStartLeft -eq $true) {
    Write-Host "Attempting to run: TaskBarMoveStartLeft"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMorePins -eq $true) {
    Write-Host "Attempting to run: TaskBarStartMorePins"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMoreRecommendations -eq $true) {
    Write-Host "Attempting to run: TaskBarStartMoreRecommendations"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "2" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}    # Removes search from the Taskbar
if ($TaskBarRemoveSearch -eq $true) {
    Write-Host "Attempting to run: TaskBarRemoveSearch RunOnce"
    $RegKey = "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    if (-not(Test-Path $RegKey )) {
        $reg = New-Item $RegKey -Force | Out-Null
        try { $reg.Handle.Close() } catch {}
    }
    $reg = New-ItemProperty $RegKey -Name "RemoveSearch"  -Value "reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Search /t REG_DWORD /v SearchboxTaskbarMode /d 0 /f" -PropertyType String -Force
    try { $reg.Handle.Close() } catch {}

    Write-Host "Attempting to run: TaskBarRemoveSearch HKCU"
    $RegKey = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not(Test-Path $RegKey )) {
        $reg = New-Item $RegKey -Force | Out-Null
        try { $reg.Handle.Close() } catch {}
    }
    $reg = New-ItemProperty $RegKey -Name "SearchboxTaskbarMode"  -Value "0" -PropertyType String -Force
    try { $reg.Handle.Close() } catch {}
}

[GC]::Collect()
Write-Host "Unmounting Default User Registry Hive (REG UNLOAD HKLM\Default)"
REG UNLOAD HKLM\Default


write-host "Tweaks for Windows 11 UI COMPLETE"
write-host "==================================================================="