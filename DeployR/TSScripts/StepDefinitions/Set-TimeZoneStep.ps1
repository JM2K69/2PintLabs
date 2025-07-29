<#
DeployR
#>

Import-Module DeployR.Utility

# Get the provided variables
[String]$SetTimeZoneName = ${TSEnv:SetTimeZoneName}
[String]$EnableLocationServices = ${TSEnv:EnableLocationServices}

#Report Variables:
Write-Output "Var SetTimeZoneName: $SetTimeZoneName"
Write-Output "Var EnableLocationServices: $EnableLocationServices"


if ($SetTimeZoneName -ne "") {
    Write-Output "Setting Time Zone Name to: $SetTimeZoneName"
    ${TSEnv:TimeZone} = $SetTimeZoneName
    if ($env:SystemDrive -eq "X:") {
        Write-Output "Running in WinPE, set TIMEZONE Variable for DeployR to add to unattended.xml"
    }
    else {
        try {
            Set-TimeZone -Id $SetTimeZoneName
        } catch {
            Write-Output "Failed to set Time Zone Name $SetTimeZoneName | $_"
        }
    }

} else {
    Write-Output "No Time Zone Name provided. Skipping time zone setting."
}

if ($EnableLocationServices -eq "true") {
    if ($env:SystemDrive -eq "X:"){
        Write-Output "Running in WinPE, Mounting offline Registry to enable Location Services..."
        #Mounting the Offline Software Hive
        [GC]::Collect()
        Start-Sleep -Milliseconds 500
        $offlineSoftwareHive = "S:\Windows\System32\config\SOFTWARE"
        REG LOAD HKLM\OfflineSoftware $offlineSoftwareHive
        Write-Host "Creating Registry Key: HKLM:\OfflineSoftware\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        New-Item -path "HKLM:\OfflineSoftware\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force -ItemType directory | Out-Null
        write-host "Setting Registry Value: HKLM:\OfflineSoftware\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location Value to Allow"
        Set-ItemProperty -Path "HKLM:\OfflineSoftware\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
	    write-host "Creating Registry Key: HKLM:\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
        New-Item -path "HKLM:\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Force -ItemType directory | Out-Null
        Write-Host "Setting Registry Value: HKLM:\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44} SensorPermissionState to 1"
        Set-ItemProperty -Path "HKLM:\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
        #unload the offline registry hive
        [GC]::Collect()
        REG UNLOAD HKLM\OfflineSoftware
        Start-Sleep -Milliseconds 500
        [GC]::Collect()
    }
    else{
            Write-Output "Enabling Location Services..."
	# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
	Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
    Write-Output "Location Services enabled."
    }

} else {
    Write-Output "Location Services not enabled."
}