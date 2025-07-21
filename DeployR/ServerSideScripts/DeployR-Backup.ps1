$BackupLocation = "D:\Backups"
$TempLocation = "$BackupLocation\Temp"
$DateStamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
Import-Module 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
Set-DeployRHost "http://localhost:7282"

#GitHubLocation, always overwrite with the latest version during a backup.
$GitHubCustomSteps = "D:\GitHub\2PintLabs\DeployR\CustomSteps"
$GitHubCustomStepsReferencedContent = "D:\GitHub\2PintLabs\DeployR\CustomSteps\ReferencedContent"

#OneDriveBackup
$OneDriveBackupPath = "C:\Users\gary.blok\OneDrive - garytown\DeployR-Sync"

# Ensure the backup directory exists
if (-not (Test-Path -Path $BackupLocation)) {New-Item -Path $BackupLocation -ItemType Directory | Out-Null}
if (-not (Test-Path -Path $TempLocation)) {New-Item -Path $TempLocation -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp")) {New-Item -Path "$BackupLocation\$DateStamp" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\ContentItems")) {New-Item -Path "$BackupLocation\$DateStamp\ContentItems" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\StepDefinitions")) {New-Item -Path "$BackupLocation\$DateStamp\StepDefinitions" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\TaskSequences")) {New-Item -Path "$BackupLocation\$DateStamp\TaskSequences" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path $GitHubCustomSteps)) {New-Item -Path $GitHubCustomSteps -ItemType Directory | Out-Null}
if (-not (Test-Path -Path $GitHubCustomStepsReferencedContent)) {New-Item -Path $GitHubCustomStepsReferencedContent -ItemType Directory | Out-Null}

Write-Host "Starting DeployR backup at $DateStamp" -ForegroundColor Green
#Backup DeployR content items
Write-Host "Backing up DeployR content items..." -ForegroundColor Yellow
Get-DeployRContentItem | Where-Object {$_.id -notlike '00000000-0000-0000-0000-*'} | Where-Object {$_.contentItemPurpose -match "Other"} | ForEach-Object {
    write-host "Backing up content item: $($_.name) | $($_.id)" -ForegroundColor Cyan
    Export-DeployRContentItem -Id $_.id -DestinationFolder "$BackupLocation\$DateStamp\ContentItems\$($_.name)-$($_.id)"
}

#Backup DeployR step definitions
Write-Host "Backing up DeployR step definitions..." -ForegroundColor Yellow
(Get-DeployRMetadata -Type StepDefinition | Where-Object {$_.id -notlike '0000*'}) | ForEach-Object {
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
    Copy-Item -Path $LatestBackup.FullName -Destination $DestinationPath -Recurse
} else {
    Write-Host "No backups found in $BackupLocation" -ForegroundColor Red
}

#Backup DeployR step definitions for GitHub Custom Steps
Write-Host "Exporting DeployR step definitions to GitHub..." -ForegroundColor Yellow
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
            Write-Host "Removing existing folder: $GitHubCustomStepsReferencedContent\$ExportContentFolderName" -ForegroundColor Yellow
            Remove-Item -Path "$GitHubCustomStepsReferencedContent\$ExportContentFolderName" -Recurse -Force
            Start-Sleep -Milliseconds 100
        }
        Write-Host "Exporting content item to: $GitHubCustomStepsReferencedContent\$ExportContentFolderName" -ForegroundColor Cyan
        Export-DeployRContentItem -Id $ContentItemInfo.id -DestinationFolder "$GitHubCustomStepsReferencedContent\$ExportContentFolderName"
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
        [string]$NewNameSuffix = "-Copy",
        [string]$NewCIName
    )
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
