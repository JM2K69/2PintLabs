$BackupLocation = "D:\Backups"
$TempLocation = "$BackupLocation\Temp"
$DateStamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
Import-Module 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
#Set-DeployRHost "http://localhost:7282"




# Create Variable that is the FQDN of the Machine:
function Get-ConnectionSpecificDNSSuffix {
    param (
    [string]$AdapterDescription = "Microsoft Hyper-V Network Adapter"
    )
    $config = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE AND Description='$AdapterDescription'"
    if ($config.DNSDomain) {
        return $config.DNSDomain
    } else {
        $ipconfig = ipconfig /all
        $suffix = ($ipconfig | Select-String "Connection-specific DNS Suffix").Line -replace ".*:\s*",""
        return $suffix
    }
}

# Usage
$Suffix = Get-ConnectionSpecificDNSSuffix | Select-Object -First 1
$ComputerFQDN = "$env:COMPUTERNAME.$Suffix"
#Only Do SYnc Backups from the OnPrem DeployR Server
if ($ComputerFQDN -eq "214-DEPLOYR.2p.garytown.com") {
    $EnableBackup2GitHub = $true
}
#GitHubLocation, always overwrite with the latest version during a backup.
#$EnableBackup2GitHub = $false
if ($EnableBackup2GitHub) {
    $GitHubCustomSteps = "D:\GitHub\2PintLabs\DeployR\CustomSteps"
    $GitHubCustomStepsReferencedContent = "D:\GitHub\2PintLabs\DeployR\CustomSteps\ReferencedContent"
    $GitHubCustomTaskSequenceModules = "D:\GitHub\2PintLabs\DeployR\CustomTaskSequenceModules"
    if (-not (Test-Path -Path $GitHubCustomSteps)) {New-Item -Path $GitHubCustomSteps -ItemType Directory | Out-Null}
    if (-not (Test-Path -Path $GitHubCustomStepsReferencedContent)) {New-Item -Path $GitHubCustomStepsReferencedContent -ItemType Directory | Out-Null}
    if (-not (Test-Path -Path $GitHubCustomTaskSequenceModules)) {New-Item -Path $GitHubCustomTaskSequenceModules -ItemType Directory | Out-Null}
}

#OneDriveBackup
$OneDriveBackupPath = "C:\Users\gary.blok\OneDrive - garytown\DeployR-Sync\$ComputerFQDN"

# Ensure the backup directory exists
if (-not (Test-Path -Path $BackupLocation)) {New-Item -Path $BackupLocation -ItemType Directory | Out-Null}
if (-not (Test-Path -Path $TempLocation)) {New-Item -Path $TempLocation -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp")) {New-Item -Path "$BackupLocation\$DateStamp" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\ContentItems")) {New-Item -Path "$BackupLocation\$DateStamp\ContentItems" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\StepDefinitions")) {New-Item -Path "$BackupLocation\$DateStamp\StepDefinitions" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\TaskSequences")) {New-Item -Path "$BackupLocation\$DateStamp\TaskSequences" -ItemType Directory | Out-Null}


Write-Host "Starting DeployR backup at $DateStamp" -ForegroundColor Green
#Backup DeployR content items
Write-Host "Backing up DeployR content items..." -ForegroundColor Yellow
$ContentItems = Get-DeployRContentItem | Where-Object {$_.id -notlike '00000000-0000-0000-0000-*'} | Where-Object {$_.contentItemPurpose -match "Other"}
$ContentItems | ForEach-Object {
    write-host "Backing up content item: $($_.name) | $($_.id)" -ForegroundColor Cyan
    Export-DeployRContentItem -Id $_.id -DestinationFolder "$BackupLocation\$DateStamp\ContentItems\$($_.name)-$($_.id)"
}

#Backup DeployR step definitions
Write-Host "Backing up DeployR step definitions..." -ForegroundColor Yellow
$Steps = (Get-DeployRMetadata -Type StepDefinition | Where-Object {$_.id -notlike '0000*'})
$Steps | ForEach-Object {
    write-host "Backing up step definition: $($_.name) | $($_.id)" -ForegroundColor Cyan
    Export-DeployRStepDefinition -Id $_.id -DestinationFolder "$BackupLocation\$DateStamp\StepDefinitions\$($_.name)-$($_.id)"
}

#Backup DeployR task sequences
Write-Host "Backing up DeployR task sequences..." -ForegroundColor Yellow
(Get-DeployRMetadata -Type TaskSequence | Where-Object {$_.id -notlike '0000*'}) | ForEach-Object {
    write-host "Backing up task sequence: $($_.name) | $($_.id)" -ForegroundColor Cyan
    Export-DeployRTaskSequence -Id $_.id -DestinationFolder "$BackupLocation\$DateStamp\TaskSequences\$($_.name)-$($_.id)"
}

#Grab the latest DeployR Backup and COpy to OneDrive
$LatestBackup = Get-ChildItem -Path $BackupLocation -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($LatestBackup) {
    Write-Host "Copying latest backup to OneDrive: $($LatestBackup.FullName)" -ForegroundColor Green
    $DestinationPath = Join-Path -Path $OneDriveBackupPath -ChildPath "DeployR-Backup-$($LatestBackup.Name)"
    if (Test-Path -Path $DestinationPath) {
        Write-Host "Removing existing folder: $DestinationPath" -ForegroundColor Yellow
        Remove-Item -Path $DestinationPath -Recurse -Force
    }
    Write-Host "Backing up to destination folder: $DestinationPath" -ForegroundColor Cyan
    Copy-Item -Path $LatestBackup.FullName -Destination $DestinationPath -Recurse
} else {
    Write-Host "No backups found in $BackupLocation" -ForegroundColor Red
}

if ($EnableBackup2GitHub -and $GitHubCustomSteps -and $GitHubCustomStepsReferencedContent) {
    
    #Backup DeployR Task Sequence Modules
    Write-Host "Exporting DeployR task sequence modules to GitHub..." -ForegroundColor Yellow
    if (Test-Path -Path $GitHubCustomTaskSequenceModules) {
        Write-Host "Removing existing folder: $GitHubCustomTaskSequenceModules" -ForegroundColor Yellow
        Remove-Item -Path "$GitHubCustomTaskSequenceModules\*" -Recurse -Force
        Start-Sleep -Milliseconds 200
    }

    #Get all task sequences except the built-in ones
    write-host "Getting all task sequence modules..." -ForegroundColor Yellow
    (Get-DeployRMetadata -Type TaskSequence | Where-Object {$_.id -notlike '0000*' -and $_.name -match "Module"}) | ForEach-Object {
        write-host "Backing up task sequence: $($_.name) | $($_.id)" -ForegroundColor Cyan
        $ExportFolderName = "$($_.name)-$($_.id)"
        if (Test-Path -Path "$GitHubCustomTaskSequenceModules\$ExportFolderName") {
            Write-Host "Removing existing folder: $GitHubCustomTaskSequenceModules\$ExportFolderName" -ForegroundColor Yellow
            Remove-Item -Path "$GitHubCustomTaskSequenceModules\$ExportFolderName" -Recurse -Force
        }
        New-Item -Path "$GitHubCustomTaskSequenceModules\$ExportFolderName" -ItemType Directory -Force | Out-Null
        write-host "Exporting step definition to: $GitHubCustomTaskSequenceModules\$ExportFolderName" -ForegroundColor Cyan
        Export-DeployRTaskSequence -Id $_.id -DestinationFolder "$GitHubCustomTaskSequenceModules\$ExportFolderName"
    }

    #Backup DeployR step definitions for GitHub Custom Steps
    Write-Host "Exporting DeployR step definitions to GitHub..." -ForegroundColor Yellow
    write-host "Cleanup $GitHubCustomSteps and $GitHubCustomStepsReferencedContent first" -ForegroundColor Yellow
    if (Test-Path -Path $GitHubCustomSteps) {
        Write-Host "Removing existing folder: $GitHubCustomSteps" -ForegroundColor Yellow
        Remove-Item -Path "$GitHubCustomSteps\*" -Recurse -Force
        Start-Sleep -Milliseconds 200
    }
    if (Test-Path -Path $GitHubCustomStepsReferencedContent) {
        Write-Host "Removing existing folder: $GitHubCustomStepsReferencedContent" -ForegroundColor Yellow
        Remove-Item -Path "$GitHubCustomStepsReferencedContent\*" -Recurse -Force
        Start-Sleep -Milliseconds 200
    }
    #Get all step definitions except the built-in ones
    write-host "Getting all step definitions..." -ForegroundColor Yellow
    $StepDefinitions = Get-DeployRMetadata -Type StepDefinition | Where-Object {$_.id -notlike '0000*'}
    foreach ($stepDef in $StepDefinitions) {
        write-host "Backing up step definition: $($stepDef.name) | $($stepDef.id)" -ForegroundColor Cyan
        $ExportFolderName = "$($stepDef.name)-$($stepDef.id)"
        if (Test-Path -Path "$GitHubCustomSteps\$ExportFolderName") {
            Write-Host "Removing existing folder: $GitHubCustomSteps\$ExportFolderName" -ForegroundColor Yellow
            Remove-Item -Path "$GitHubCustomSteps\$ExportFolderName" -Recurse -Force
        }
        New-Item -Path "$GitHubCustomSteps\$ExportFolderName" -ItemType Directory -Force | Out-Null
        write-host "Exporting step definition to: $GitHubCustomSteps\$ExportFolderName" -ForegroundColor Cyan
        Export-DeployRStepDefinition -Id $stepDef.id -DestinationFolder "$GitHubCustomSteps\$ExportFolderName"
        $versions = $stepDef.versions
        foreach ($version in $versions) {
            $Options = $version.options
            $ContentID = (($Options | Where-Object {$_.type -eq "Content"}).defaultValue).split(':') | Select-Object -first 1
            $ContentItemInfo = Get-DeployRContentItem | Where-Object {$_.id -eq $ContentID}
            write-host "Backing up content item: $($ContentItemInfo.name) | $($ContentItemInfo.id)" -ForegroundColor Cyan
            $ExportContentFolderName = "$($ContentItemInfo.name)-$($ContentItemInfo.id)"
            if (Test-Path -Path "$GitHubCustomStepsReferencedContent\$ExportContentFolderName") {
                #Write-Host "Removing existing folder: $GitHubCustomStepsReferencedContent\$ExportContentFolderName" -ForegroundColor Yellow
                #Remove-Item -Path "$GitHubCustomStepsReferencedContent\$ExportContentFolderName" -Recurse -Force
                Start-Sleep -Milliseconds 200
            }
            Write-Host "Exporting content item to: $GitHubCustomStepsReferencedContent\$ExportContentFolderName" -ForegroundColor Cyan
            Export-DeployRContentItem -Id $ContentItemInfo.id -DestinationFolder "$GitHubCustomStepsReferencedContent\$ExportContentFolderName"
        }
    }
}
<# for Import Reference
dir c:\temp\ContentBackup -File | Import-DeployRContentItem 
dir c:\temp\StepDefinitionBackup -File | Import-DeployRStepDefinition 
dir c:\temp\TaskSequenceBackup -File | Import-DeployRTaskSequence
#>

#Create Duplicate of Sample Step Definition with new GUID
Function Duplicate-DeployRStepDefinition {
    param (
    [Parameter(Mandatory = $true)]
    [string]$StepDefinitionId,
    [string]$TempLocation,
    [string]$NewNameSuffix = "-Copy",
    [string]$NewCIName
    )
    if ($null -eq $TempLocation -or $TempLocation -eq "") {
        Write-Host "No TempLocation specified, setting it to C:\Windows\Temp" -ForegroundColor Yellow
        $TempLocation = "C:\Windows\Temp"
    }
    if (-not (Test-Path -Path $TempLocation)) {
        Write-Host "Temp location $TempLocation does not exist. Creating it." -ForegroundColor Yellow
        New-Item -Path $TempLocation -ItemType Directory | Out-Null
    }
    $Sample = (Get-DeployRMetadata -Type StepDefinition | Where-Object {$_.id -eq $StepDefinitionId})
    if ($null -eq $Sample) {
        Write-Host "Step Definition with ID $StepDefinitionId not found." -ForegroundColor Red
        return
    }
    [System.Guid]$NewStepGuid = New-Guid
    [System.Guid]$NewVersionGuid = New-Guid
    $Sample.id = $NewStepGuid
    if ($NewCIName) {
        $Sample.name = $NewCIName
    }
    else {
        $Sample.name = "$($Sample.name)$NewNameSuffix"
    }
    $SampleVersions = $Sample.versions
    $SampleVersions[0].id = $NewVersionGuid
    $SampleVersions[0].StepDefinitionId = $NewStepGuid
    $TempFilePath = "$TempLocation\TempDuplicateStepDef.json"
    $Sample | ConvertTo-Json -Depth 10 | Out-File $TempFilePath -Force
    Import-DeployRStepDefinition -SourceFile $TempFilePath
    Write-Host "Duplicated Step Definition as $($Sample.name) with ID $NewStepGuid" -ForegroundColor Green
}

#THIS DOES NOT WORKING.... Still messing around
Function Duplicate-DeployRTaskSequence {
    param (
    [Parameter(Mandatory = $true)]
    [string]$TempLocation,
    [string]$TaskSequenceId,
    [string]$NewNameSuffix = "-Copy",
    [string]$NewCIName
    )
    $Sample = (Get-DeployRMetadata -Type TaskSequence | Where-Object {$_.id -eq $TaskSequenceId})
    if ($null -eq $Sample) {
        Write-Host "Task Sequence with ID $TaskSequenceId not found." -ForegroundColor Red
        return
    }
    [System.Guid]$NewItemGuid = New-Guid
    [System.Guid]$NewVersionGuid = New-Guid
    $Sample.id = $NewItemGuid
    if ($NewCIName) {
        $Sample.name = $NewCIName
    }
    else {
        $Sample.name = "$($Sample.name)$NewNameSuffix"
    }
    $SampleVersions = $Sample.versions
    $SampleVersions[0].id = $NewVersionGuid
    $SampleVersions[0].taskSequenceId = $NewItemGuid
    
    $TempFilePath = "$TempLocation\TempDuplicateTaskSeq.json"
    $Sample | ConvertTo-Json -Depth 50 | Out-File $TempFilePath -Force
    Import-DeployRTaskSequence -SourceFile $TempFilePath
    Write-Host "Duplicated Task Sequence as $($Sample.name) with ID $NewGuid" -ForegroundColor Green
}


<# Testing of Importing of Steps to Overwrite.
Duplicate a step so you can modify it and re-import it (to avoid messing with prod steps)

#This will duplicate your step and add it back to DeployR under the new name, and leave the JSON in the templocation
Duplicate-DeployRStepDefinition -StepDefinitionId ce8e43c9-27a9-431a-a25b-eae716ac601a -NewCIName "1 TESTING OVERWRITE" -TempLocation "C:\Windows\Temp"

# Now edit the file C:\Windows\Temp\TempDuplicateStepDef.json to make changes
# Then import it back to DeployR    
Import-DeployRStepDefinition -SourceFile "C:\Windows\Temp\TempDuplicateStepDef.json" -Force

#Go and confirm the changes you made in JSON are now in the step definition in the Console.


#>