$DeployRSyncFolder = "C:\Users\gary.blok\OneDrive - garytown\DeployR-Sync"

#Get Latest Backup From Sync Folder
$LatestBackup = Get-ChildItem -Path $DeployRSyncFolder -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($LatestBackup) {
    #Importing COntent
    Write-Host "Restoring DeployR from backup: $($LatestBackup.FullName)" -ForegroundColor Green
    
    if (Test-Path -Path "$($LatestBackup.FullName)\ContentItems") {
        Get-ChildItem -Path "$($LatestBackup.FullName)\ContentItems" -Directory  | ForEach-Object {
            $StepFolder = $_.FullName
            Write-Host "Importing Custom Step from: $StepFolder" -ForegroundColor Cyan
            Get-ChildItem -path $StepFolder -File | Where-Object {$_.Extension -eq ".json"} | ForEach-Object {
                $StepFile = $_.FullName
                Write-Host "Importing step definition from file: $StepFile" -ForegroundColor Yellow
                $StepJSON = Get-Content -Path $StepFile -Raw | ConvertFrom-Json
                try {
                    $AlreadyExist = Get-DeployRContentItem -Id $StepJSON.id -ErrorAction SilentlyContinue
                }
                catch {
                    <#Do this if a terminating exception happens#>
                }
                if ($AlreadyExist) {
                    Write-Host "Content item already exists: $($StepJSON.name) | $($StepJSON.id)" -ForegroundColor Yellow
                    $SourcePath = Join-Path -Path $StepFolder -ChildPath (Get-ChildItem $StepFolder -Directory).Name
                    $ContentVersions = Get-ChildItem -Path $SourcePath -Directory
                    foreach ($version in $ContentVersions) {
                        Write-Host "Updating content item version: $($version.Name)" -ForegroundColor Cyan
                        Update-DeployRContentItemContent -ContentId $StepJSON.id -SourceFolder $version.FullName -ContentVersion $version.Name
                    }
                } else {
                    Import-DeployRContentItem -SourceFile $StepFile
                }
            }
        }
    }
    #Doing Steps NOw
    Get-ChildItem -Path "$($LatestBackup.FullName)\StepDefinitions" -Directory | Where-Object {$_.Name -ne "ReferencedContent"} | ForEach-Object {
        $StepFolder = $_.FullName
        Write-Host "Importing Custom Step from: $StepFolder" -ForegroundColor Cyan
        Get-ChildItem -path $StepFolder -File | Where-Object {$_.Extension -eq ".json"} | ForEach-Object {
            $StepFile = $_.FullName
            Write-Host "Importing step definition from file: $StepFile" -ForegroundColor Yellow
            Import-DeployRStepDefinition -SourceFile $StepFile
        }
    }

    #Now Task Sequences
    Get-ChildItem -Path "$($LatestBackup.FullName)\TaskSequences" -Directory | ForEach-Object {
        $Folder = $_.FullName
        Write-Host "Importing Custom Step from: $Folder" -ForegroundColor Cyan
        Get-ChildItem -path $Folder -File  | ForEach-Object {
            $File = $_.FullName
            Write-Host "Importing step definition from file: $File" -ForegroundColor Yellow
                Import-DeployRTaskSequence -SourceFile $File
        }
    }


} else {
    Write-Host "No backups found in $DeployRSyncFolder" -ForegroundColor Red
}