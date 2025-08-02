#This will set several Edge policies based on the provided variables.
if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}

#Disable Startup First Run Experience
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HideFirstRunExperience" -Value 1 -Type DWord -Force

#Disable Sync
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SyncDisabled" -Value 1 -Type DWord -Force

#Disable AutoImportAtFirstRun
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "AutoImportAtFirstRunEnabled" -Value 4 -Type DWord -Force