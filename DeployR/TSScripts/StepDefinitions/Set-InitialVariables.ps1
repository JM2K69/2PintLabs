
<#  
This should be one of the very first steps in the Task Sequence, before you even apply the image.

#>
Import-Module DeployR.Utility

#Set the initial variables for the DeployR Task Sequence environment
#This is in UTC, so it can be used for logging and other purposes
${TSEnv:OSDStartTime} = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Get the provided variables
[String]$SetTimeZoneName = ${TSEnv:SetTimeZoneName}

#Report Variables:
Write-Output "Var SetTimeZoneName: $SetTimeZoneName"



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

#Function to get full OS Build & UBR
function Get-WinPEBuildInfo {
    if ($env:SystemDrive -eq "X:") {
        try {
            $Build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
            $UBR = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
            $buildinfo = "$Build.$UBR"
            return $buildInfo
        } catch {
            Write-Output "Failed to retrieve OS Build Info | $_"
            return "Unknown"
        }
    }
    else{
        write-host "Running in Full Windows Environment, skipping WinPE Build Info"
        return $null
    }

}


${TSEnv:WinPEBuildInfo} = Get-WinPEBuildInfo
