
<#  
This should be one of the very first steps in the Task Sequence, before you even apply the image.

#>
Import-Module DeployR.Utility


Write-Host "================================================================================"
#Set the initial variables for the DeployR Task Sequence environment
#This is in UTC, so it can be used for logging and other purposes

# Get the provided variables
[String]$SetTimeZoneName = ${TSEnv:SetTimeZoneName}
[String]$TimeZoneDropDown = ${TSEnv:TimeZoneDropDown}
[String]$InitialProgressTimeout = ${TSEnv:InitialProgressTimeout}
[String]$InitialPeering = ${TSEnv:InitialPeering}
[String]$InitialFinishAction = ${TSEnv:InitialFinishAction}

[String]$InitialSystemLocale = ${TSEnv:InitialSystemLocale}
[String]$InitialUserLocale = ${TSEnv:InitialUserLocale}
[String]$InitialUILanguage = ${TSEnv:InitialUILanguage}
[String]$InitialInputLocale = ${TSEnv:InitialInputLocale}



Write-Host "Recording initial variables for the Task Sequence environment"
#Report Variables:
Write-Output "Var SetTimeZoneName: $SetTimeZoneName"
Write-Output "Var TimeZoneDropDown: $TimeZoneDropDown"
Write-Output "Var InitialProgressTimeout: $InitialProgressTimeout"
Write-Output "Var InitialPeering: $InitialPeering"
Write-Output "Var InitialFinishAction: $InitialFinishAction"
Write-Output "Var InitialSystemLocale: $InitialSystemLocale"
Write-Output "Var InitialUserLocale: $InitialUserLocale"
Write-Output "Var InitialUILanguage: $InitialUILanguage"
Write-Output "Var InitialInputLocale: $InitialInputLocale"
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
if ($TimeZoneDropDown -ne "") {
    Write-Output "Setting Time Zone Name to: $TimeZoneDropDown"
    ${TSEnv:TimeZone} = $TimeZoneDropDown
    if ($env:SystemDrive -eq "X:") {
        Write-Output "Running in WinPE, set TIMEZONE Variable for DeployR to add to unattended.xml"
    }
    else {
        try {
            Set-TimeZone -Id $TimeZoneDropDown
        } catch {
            Write-Output "Failed to set Time Zone Name $TimeZoneDropDown | $_"
        }
    }
} else {
    Write-Output "No Time Zone Drop Down provided. Skipping time zone drop down setting."
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

if ($InitialSystemLocale -ne "") {
    Write-Output "Setting System Locale to: $InitialSystemLocale"
    ${TSEnv:SystemLocale} = $InitialSystemLocale
}
else {
    Write-Output "No System Locale provided. Skipping system locale setting."
}
if ($InitialUserLocale -ne "") {
    Write-Output "Setting User Locale to: $InitialUserLocale"
    ${TSEnv:UserLocale} = $InitialUserLocale
}
else {
    Write-Output "No User Locale provided. Skipping user locale setting."
}
if ($InitialUILanguage -ne "") {
    Write-Output "Setting UI Language to: $InitialUILanguage"
    ${TSEnv:UILanguage} = $InitialUILanguage
}
else {
    Write-Output "No UI Language provided. Skipping UI language setting."
}
if ($InitialInputLocale -ne "") {
    $InitialInputLocale = ($InitialInputLocale.Split('-')[1]).TrimStart()
    Write-Output "Setting Input Locale to: $InitialInputLocale"
    ${TSEnv:InputLocale} = $InitialInputLocale
}
else {
    Write-Output "No Input Locale provided. Skipping input locale setting."
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
