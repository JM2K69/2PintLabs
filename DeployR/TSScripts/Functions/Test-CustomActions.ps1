<#  GARYTOWN.COM / @gwblok

Custom Actions in the Setup Process
    This script creates each of the 6 batch files, along with associated powershell files.
    It then populates the Batch file to call the PS File
    It then populates the PS File with the command to create a time stamp.
    Note, assumes several task sequence variables (SMSTS_BUILD & RegistryPath) as the location to write the data to

    Goal: Confirm when the Scripts run and compare to other logs

    Docs: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-enable-custom-actions
    
#>

# THIS DOES NOTHING WHEN RUNNING IN OSD.  Only useful for IPU.

write-host "=========================================================================="
write-host "                 Creating Custom Actions Test Script"
write-host "=========================================================================="




#Mount Offline Software Hive
# Define paths
$offlineHivePath = "S:\Windows\System32\config\SOFTWARE"
$mountPoint = "HKLM\OfflineSoftware"

# Check if the hive file exists
if (Test-Path $offlineHivePath) {
    # Load the offline registry hive
    reg load $mountPoint $offlineHivePath

    if ($?) {
        Write-Host "SOFTWARE hive successfully mounted to $mountPoint"
    } else {
        Write-Host "Failed to mount SOFTWARE hive" -ForegroundColor Red
    }
} else {
    Write-Host "SOFTWARE hive not found at $offlineHivePath" -ForegroundColor Red
}

$OfflineRegistryPath = "$mountPoint\2Pint Software\OSD\CustomActions"
Write-Host "Offline Registry Path:  $OfflineRegistryPath"

if (-not(Test-Path -Path $OfflineRegistryPath)){New-Item -Path $OfflineRegistryPath -ItemType Directory -Force}
else {Write-Host "Registry Path already exists: $OfflineRegistryPath"}

reg unload $mountPoint

$RunOncePath = "S:\Windows\System32\update\runonce"
$RunPath = "S:\Windows\System32\update\run"

if (!(Test-Path -Path $RunOncePath)) { New-Item -Path $RunOncePath -ItemType Directory -Force }
if (!(Test-Path -Path $RunPath)) { New-Item -Path $RunPath -ItemType Directory -Force }

#Custom Action Table (CA = CustomAction)
$RunScriptTable = @(
    #RunOnePath
    @{ Script = "CA_PreInstall"; BatFile = 'preinstall.cmd'; ps1file = 'preinstall.ps1';Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_PreCommit"; BatFile = 'precommit.cmd'; ps1file = 'precommit.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_Failure"; BatFile = 'failure.cmd'; ps1file = 'failure.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_PostUninstall"; BatFile = 'postuninstall.cmd'; ps1file = 'postuninstall.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_Success"; BatFile = 'success.cmd'; ps1file = 'success.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
        
    #RunPath
    @{ Script = "CA_PreInstall"; BatFile = 'preinstall.cmd'; ps1file = 'preinstall.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_PreCommit"; BatFile = 'precommit.cmd'; ps1file = 'precommit.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_Failure"; BatFile = 'failure.cmd'; ps1file = 'failure.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_PostUninstall"; BatFile = 'postuninstall.cmd'; ps1file = 'postuninstall.ps1'; Type = 'RunOnce'; Path = "$RunPath"}
    @{ Script = "CA_Success"; BatFile = 'success.cmd'; ps1file = 'success.ps1'; Type = 'RunOnce'; Path = "$RunPath"}
        
)



$ScriptGUID = New-Guid
$registryPath = "HKLM:\SOFTWARE\2Pint Software\OSD\CustomActions"
ForEach ($RunScript in $RunScriptTable)
    {
    Write-Output $RunScript.Script

    $BatFilePath = "$($RunScript.Path)\$($ScriptGUID)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($ScriptGUID)\$($RunScript.ps1File)"
        
    #Create Batch File to Call PowerShell File
    Write-Host "Creating Batch File: $BatFilePath"
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File')
    [void]$CustomActionContent.Append(" $PSFilePath")
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()
    Test-Path -Path $BatFilePath | Out-Null
    Write-Host "Created Batch File: $BatFilePath"

    #Create PowerShell File to do actions
    Write-Host "Creating PowerShell File: $PSFilePath"    
    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -Path $PSFilePath  '$TimeStamp = Get-Date -f s'
    $CustomActionContentPS = New-Object system.text.stringbuilder
    [void]$CustomActionContentPS.Append('$RegistryPath = ') 
    [void]$CustomActionContentPS.Append("""$RegistryPath""")
    Add-Content -Path $PSFilePath -Value $CustomActionContentPS.ToString()
    $CustomActionContentPS = New-Object system.text.stringbuilder
    [void]$CustomActionContentPS.Append('$keyname = ') 
    [void]$CustomActionContentPS.Append("""$($RunScript.Script)_$($RunScript.Type)""")
    Add-Content -Path $PSFilePath -Value $CustomActionContentPS.ToString()
    Add-Content -Path $PSFilePath -Value 'New-ItemProperty -Path $registryPath -Name $keyname -Value $TimeStamp -Force'
    Test-Path -Path $PSFilePath | Out-Null
    Write-Host "Created PowerShell File: $PSFilePath"
}