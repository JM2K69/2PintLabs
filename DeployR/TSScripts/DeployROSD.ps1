#Functions I want available during DeployR deployment.

#Get-HyperVName | Set-HyperVName
#Set-TimzeZoneFromIP

#Figure out what OS Customizations I want and make Functions for them.  Perhaps even make Step Definitions for them.

write-host -ForegroundColor DarkGray "========================================================="
write-host -ForegroundColor Cyan "Hyper-V Functions"
Write-Host -ForegroundColor Green "[+] Function Get-HyperVName"
function Get-HyperVName {
    [CmdletBinding()]
    param ()
    if ($env:SystemDrive -eq 'X:'){
        Write-host "Unable to get HyperV Name in WinPE"
    }
    else{
        if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation")){
            $HyperVName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        }
        return $HyperVName
    }
}

Write-Host -ForegroundColor Green "[+] Function Set-HyperVName"
function Set-HyperVName {
    [CmdletBinding()]
    param ()
    $HyperVName = Get-HyperVName
    Write-Output "Renaming Computer to $HyperVName"
    Rename-Computer -NewName $HyperVName -Force 
}

Write-Host -ForegroundColor DarkGray "========================================================="
write-host -ForegroundColor Cyan "OS Modification Functions"
Write-Host -ForegroundColor Green "[+] Function Set-ThisPCIconName"
Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/TSScripts/Functions/Set-ThisPCIconName.ps1")

Write-Host -ForegroundColor Green "[+] Function Set-TimeZoneFromIP"
Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/TSScripts/Functions/Set-TimeZoneFromIP.ps1")
Write-Host -ForegroundColor DarkGray "========================================================="
Write-Host ""
write-Host "Completed loading DeployR Functions" -ForegroundColor Cyan
Write-Host -ForegroundColor DarkGray "========================================================="
