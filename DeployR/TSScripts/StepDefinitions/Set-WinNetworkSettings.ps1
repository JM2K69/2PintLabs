# Set-WinNetworkSettings.ps1


Import-Module DeployR.Utility


# Variables - Set these to $true or $false as needed
[string]$EnableRDP = ${TSEnv:EnableRDP}
[string]$EnableICMP = ${TSEnv:EnableICMP}

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

Write-Host "Network settings updated."
write-host "==================================================================="