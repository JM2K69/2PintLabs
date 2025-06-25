#Several Tweaks for Windows 10/11

#>

Import-Module DeployR.Utility

# Get the provided variables
$RemoveWidgetsOnLockScreen = [bool]${TSEnv:RemoveWidgetsOnLockScreen}
$TaskBarRemoveTaskView = [bool]${TSEnv:TaskBarRemoveTaskView}
$TaskBarRemoveCopilot = [bool]${TSEnv:TaskBarRemoveCopilot}
$TaskBarRemoveWidgets = [bool]${TSEnv:TaskBarRemoveWidgets}
$TaskBarRemoveChat = [bool]${TSEnv:TaskBarRemoveChat}
$TaskBarMoveStartLeft = [bool]${TSEnv:TaskBarMoveStartLeft}
$TaskBarRemoveSearch = [bool]${TSEnv:TaskBarRemoveSearch}
$TaskBarStartMorePins = [bool]${TSEnv:TaskBarStartMorePins}
$TaskBarStartMoreRecommendations = [bool]${TSEnv:TaskBarStartMoreRecommendations}

write-host "==================================================================="
write-host "Tweaks for Windows 11 UI"
write-host "Reporting Variables:"
write-host "RemoveWidgetsOnLockScreen: $RemoveWidgetsOnLockScreen"
write-host "TaskBarRemoveTaskView: $TaskBarRemoveTaskView" 
write-host "TaskBarRemoveCopilot: $TaskBarRemoveCopilot"
write-host "TaskBarRemoveWidgets: $TaskBarRemoveWidgets"
write-host "TaskBarRemoveChat: $TaskBarRemoveChat"
write-host "TaskBarMoveStartLeft: $TaskBarMoveStartLeft"
write-host "TaskBarRemoveSearch: $TaskBarRemoveSearch"
write-host "TaskBarStartMorePins: $TaskBarStartMorePins"
write-host "TaskBarStartMoreRecommendations: $TaskBarStartMoreRecommendations"


#Script from Jorgen Nilsson, Thank you!
<#
Customize Taskbar in Windows 11
Sassan Fanai / Jörgen Nilsson
Version 1.1
Added Option to remove CoPIlot and updated remove Search
#>
[string]$RegValueName = "CustomizeTaskbar"
[string]$FullRegKeyName = "HKLM:\SOFTWARE\ccmexec\" 

# Create registry value if it doesn't exist
If (!(Test-Path $FullRegKeyName)) {
    New-Item -Path $FullRegKeyName -type Directory -force 
}

New-ItemProperty $FullRegKeyName -Name $RegValueName -Value "1" -Type STRING -Force

REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT


# Removes Task View from the Taskbar
if ($TaskBarRemoveTaskView) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}
# Removes Widgets from the Taskbar
if ($TaskBarRemoveWidgets) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Copilot from the Taskbar
if ($TaskBarRemoveCopilot) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Chat from the Taskbar
if ($TaskBarRemoveChat) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu alignment 0=Left
if ($TaskBarMoveStartLeft) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMorePins) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
if ($TaskBarStartMoreRecommendations) {
    Write-Host "Attempting to run: $PSItem"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "2" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}    # Removes search from the Taskbar
if ($TaskBarRemoveSearch) {
    Write-Host "Attempting to run: $PSItem"
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