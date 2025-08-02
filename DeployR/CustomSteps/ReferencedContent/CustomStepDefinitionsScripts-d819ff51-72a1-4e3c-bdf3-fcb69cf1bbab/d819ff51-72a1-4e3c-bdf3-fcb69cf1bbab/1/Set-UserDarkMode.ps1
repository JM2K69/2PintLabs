<#Several Tweaks for Windows 10/11
2Pint Software - Gary Blok
For use with DeployR Task Sequence
#>


#THIS DOES NOT WORK AT ALL...


Import-Module DeployR.Utility

# Get the provided variables
$SetDarkMode = ${TSEnv:SetDarkMode}
$SetDarkMode = "TRUE"

write-host "==================================================================="
write-host "User Experience to Dark Mode"
write-host "Reporting Variables:"
write-host "SetDarkMode: $SetDarkMode" 


[GC]::Collect()
Write-Host "Mounting Default User Registry Hive (REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT)"
REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
# Sets the Explorer Show File Extensions setting
if ($SetDarkMode -eq $true) {
    Write-Host "Attempting to run: SetDarkMode"

    # Enable Dark Mode for Windows (System-wide)
    $reg = New-ItemProperty -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -PropertyType Dword -Force

    # Enable Dark Mode for Apps
    $reg = New-ItemProperty -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -PropertyType Dword -Force
    try { $reg.Handle.Close() } catch {}
    
}
[GC]::Collect()
Write-Host "Unmounting Default User Registry Hive (REG UNLOAD HKLM\Default)"
REG UNLOAD HKLM\Default


write-host "Setting User Experience to DarkMode COMPLETE"
write-host "==================================================================="