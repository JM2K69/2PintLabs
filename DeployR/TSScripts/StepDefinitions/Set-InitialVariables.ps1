
<#  
This should be one of the very first steps in the Task Sequence, before you even apply the image.

#>
Import-Module DeployR.Utility


Write-Host "================================================================================"
#Set the initial variables for the DeployR Task Sequence environment
#This is in UTC, so it can be used for logging and other purposes

# Get the provided variables
[String]$SetTimeZoneName = ${TSEnv:SetTimeZoneName}
[String]$InitialProgressTimeout = ${TSEnv:InitialProgressTimeout}
[String]$InitialPeering = ${TSEnv:InitialPeering}
[String]$InitialFinishAction = ${TSEnv:InitialFinishAction}

Write-Host "Recording initial variables for the Task Sequence environment"
#Report Variables:
Write-Output "Var SetTimeZoneName: $SetTimeZoneName"
Write-Output "Var InitialProgressTimeout: $InitialProgressTimeout"
Write-Output "Var InitialPeering: $InitialPeering"
Write-Output "Var InitialFinishAction: $InitialFinishAction"
Write-Host "================================================================================"
write-host "Doing the work...."

${TSEnv:OSDStartTime} = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
Write-Host "Setting OSDStartTime to: ${TSEnv:OSDStartTime}" -ForegroundColor Green

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

if ($InitialProgressTimeout -ne "") {
    Write-Output "Setting Progress Timeout to: $InitialProgressTimeout"
    ${TSEnv:ProgressTimeout} = $InitialProgressTimeout
}
else {
    Write-Output "No Progress Timeout provided. Skipping progress timeout setting."
}

if ($InitialPeering -eq "True") {
    Write-Output "Setting Peering to: $InitialPeering"
    #${TSEnv:Peering} = $InitialPeering - Don't need to set this, it is already set in the Task Sequence environment by default
}
else {
    Write-Output "Setting Peering to: $InitialPeering"
    ${TSEnv:Peering} = $InitialPeering
}

if ($InitialFinishAction -ne "") {
    if ($InitialFinishAction -eq "blank") {
        # Don't set this at all if left blank, don't even set it to null, that will break it too
        #${TSEnv:FinishAction} = $null
    } else {
        ${TSEnv:FinishAction} = $InitialFinishAction
    }
}
else {
    Write-Output "No Finish Action provided. Skipping finish action setting."
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

Write-Host "Setting WinPE Build Info"
${TSEnv:WinPEBuildInfo} = Get-WinPEBuildInfo
Write-Host "WinPE Build Info set to: ${TSEnv:WinPEBuildInfo}"
