# Set-WinNetworkSettings.ps1

if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}

Import-Module DeployR.Utility


# Variables - Set these to $true or $false as needed
[string]$EnableRDP = ${TSEnv:EnableRDP}
[string]$EnableICMP = ${TSEnv:EnableICMP}
[string]$EnableLocationServices = ${TSEnv:EnableLocationServices}

# Write out which script is running, and the variables being used
write-host "==================================================================="
write-host "Set-WinNetworkSettings Script" 
write-host "Reporting Variables:"
write-host "EnableRDP: $EnableRDP"  
write-host "EnableICMP: $EnableICMP"


# Enable RDP if requested
if ($EnableRDP -eq "True") {
    Write-Host "Enabling RDP..."
    # Enable Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0  | Out-Null
    # Enable RDP firewall rule
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

# Enable ICMP (Ping) if requested
if ($EnableICMP -eq "True") {
    Write-Host "Enabling ICMP (Ping)..."
# Run as Administrator
# Enable ICMP Echo Request (Ping) for both IPv4 and IPv6

# Enable ICMPv4-In
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Action Allow -Profile Any -Enabled True  | Out-Null

# Enable ICMPv6-In
New-NetFirewallRule -DisplayName "Allow ICMPv6-In" -Protocol ICMPv6 -IcmpType 8 -Action Allow -Profile Any -Enabled True  | Out-Null

Write-Host "ICMP (Ping) has been enabled in Windows Firewall for both IPv4 and IPv6"
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
}
Write-Host "Network settings updated."
write-host "==================================================================="