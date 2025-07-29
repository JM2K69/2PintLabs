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
$ExplorerShowFileExtensions = ${TSEnv:ExplorerShowFileExtensions}
$ExplorerShowHiddenFolders = ${TSEnv:ExplorerShowHiddenFolders}
$ExplorerShowSystemFiles = ${TSEnv:ExplorerShowSystemFiles}
$HideLearnMoreAboutThisPicture = ${TSEnv:HideLearnMoreAboutThisPicture}
$DisableSpotlightCollectionOnDesktop = ${TSEnv:DisableSpotlightCollectionOnDesktop}

write-host "==================================================================="
write-host "User Explorer Settings for Windows 11 UI"
write-host "Reporting Variables:"
write-host "ExplorerShowFileExtensions: $ExplorerShowFileExtensions" 
write-host "ExplorerShowHiddenFolders: $ExplorerShowHiddenFolders"
write-host "ExplorerShowSystemFiles: $ExplorerShowSystemFiles"
write-host "HideLearnMoreAboutThisPicture: $HideLearnMoreAboutThisPicture"
write-host "DisableSpotlightCollectionOnDesktop: $DisableSpotlightCollectionOnDesktop"

[GC]::Collect()
Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
# Sets the Explorer Show File Extensions setting
if ($ExplorerShowFileExtensions -eq $true) {
    Write-Host "Attempting to run: ExplorerShowFileExtensions"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value "0" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}
# Sets the Explorer Show Hidden Folders setting
if ($ExplorerShowHiddenFolders -eq $true) {
    Write-Host "Attempting to run: ExplorerShowHiddenFolders"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Sets the Explorer Show System Files setting
if ($ExplorerShowSystemFiles -eq $true) {
    Write-Host "Attempting to run: ExplorerShowSystemFiles"
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# "Learn more about this picture" from the desktop (so wallpaper will work)
if ($HideLearnMoreAboutThisPicture -eq $true) { 
    Write-Host "Attempting to run: HideLearnMoreAboutThisPicture"
    if (-not (Test-Path -Path HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel)) {
        New-Item -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -ItemType directory -Force -ErrorAction SilentlyContinue
    }
    $reg = New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}
# Disabling Windows Spotlight for Desktop
if ($DisableSpotlightCollectionOnDesktop -eq $true) {
    Write-Host "Attempting to run: DisableSpotlightCollectionOnDesktop"
    if (-not (Test-Path -Path HKLM:\Default\Software\Policies\Microsoft\Windows\CloudContent)) {
        New-Item -Path "HKLM:\Default\Software\Policies\Microsoft\Windows\CloudContent" -ItemType directory -Force -ErrorAction SilentlyContinue
    }
    $reg = New-ItemProperty "HKLM:\Default\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableSpotlightCollectionOnDesktop" -Value "1" -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
}

[GC]::Collect()
Write-Host "Unmounting Default User Registry Hive (REG UNLOAD HKLM\Default)"
REG UNLOAD HKLM\Default


write-host "Tweaks for Windows 11 UI COMPLETE"
write-host "==================================================================="