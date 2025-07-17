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
    try {
        Set-TimeZone -Id $SetTimeZoneName
    } catch {
        Write-Output "Failed to set Time Zone Name $SetTimeZoneName | $_"
    }
} else {
    Write-Output "No Time Zone Name provided. Skipping time zone setting."
}

if ($EnableLocationServices -eq "true") {
    Write-Output "Enabling Location Services..."
	# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
	Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
    Write-Output "Location Services enabled."
} else {
    Write-Output "Location Services not enabled."
}