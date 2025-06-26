<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>

Import-Module DeployR.Utility

# Get the provided variables
[bool]$ExplorerShowFileExtensions = ${TSEnv:ExplorerShowFileExtensions}
[bool]$ExplorerShowHiddenFolders = ${TSEnv:ExplorerShowHiddenFolders}
[bool]$ExplorerShowSystemFiles = ${TSEnv:ExplorerShowSystemFiles}
[bool]$HideLearnMoreAboutThisPicture = ${TSEnv:HideLearnMoreAboutThisPicture}
[bool]$DisableSpotlightCollectionOnDesktop = ${TSEnv:DisableSpotlightCollectionOnDesktop}

write-host "==================================================================="
write-host "User Explorer Settings for Windows 11 UI"
write-host "Reporting Variables:"
write-host "ExplorerShowFileExtensions: $ExplorerShowFileExtensions" 
write-host "ExplorerShowHiddenFolders: $ExplorerShowHiddenFolders"
write-host "ExplorerShowSystemFiles: $ExplorerShowSystemFiles"
write-host "HideLearnMoreAboutThisPicture: $HideLearnMoreAboutThisPicture"
write-host "DisableSpotlightCollectionOnDesktop: $DisableSpotlightCollectionOnDesktop"

REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
# Removes Task View from the Taskbar
if ($ExplorerShowFileExtensions) {
    Write-Host "Attempting to run: ExplorerShowFileExtensions"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}
# Removes Widgets from the Taskbar
if ($ExplorerShowHiddenFolders) {
    Write-Host "Attempting to run: TaskBarRemoveWidgets"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Removes Copilot from the Taskbar
if ($ExplorerShowSystemFiles) {
    Write-Host "Attempting to run: TaskBarRemoveCopilot"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# "Learn more about this picture" from the desktop (so wallpaper will work)
if ($HideLearnMoreAboutThisPicture) { 
    Write-Host "Attempting to run: HideLearnMoreAboutThisPicture"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Disabling Windows Spotlight for Desktop
if ($DisableSpotlightCollectionOnDesktop) {
    Write-Host "Attempting to run: DisableSpotlightCollectionOnDesktop"
    $reg = New-ItemProperty "HKLM:\Default\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableSpotlightCollectionOnDesktop" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}

[GC]::Collect()
REG UNLOAD HKLM\Default


write-host "Tweaks for Windows 11 UI COMPLETE"
write-host "==================================================================="