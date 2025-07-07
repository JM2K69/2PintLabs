$BackupLocation = "D:\Backups"
$DateStamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
Import-Module 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
Set-DeployRHost "http://localhost:7282"


# Ensure the backup directory exists
if (-not (Test-Path -Path $BackupLocation)) {New-Item -Path $BackupLocation -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp")) {New-Item -Path "$BackupLocation\$DateStamp" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\ContentItems")) {New-Item -Path "$BackupLocation\$DateStamp\ContentItems" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\StepDefinitions")) {New-Item -Path "$BackupLocation\$DateStamp\StepDefinitions" -ItemType Directory | Out-Null}
if (-not (Test-Path -Path "$BackupLocation\$DateStamp\TaskSequences")) {New-Item -Path "$BackupLocation\$DateStamp\TaskSequences" -ItemType Directory | Out-Null}

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

<# for Import Reference
dir c:\temp\ContentBackup -File | Import-DeployRContentItem 
dir c:\temp\StepDefinitionBackup -File | Import-DeployRStepDefinition 
dir c:\temp\TaskSequenceBackup -File | Import-DeployRTaskSequence
#>