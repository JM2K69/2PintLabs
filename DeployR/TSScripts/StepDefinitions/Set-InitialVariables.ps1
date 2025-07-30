Import-Module DeployR.Utility

#Set the initial variables for the DeployR Task Sequence environment
${TSEnv:OSDStartTime} = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
Write-Host "Setting OSDStartTime to: ${TSEnv:OSDStartTime}" -ForegroundColor Green

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
