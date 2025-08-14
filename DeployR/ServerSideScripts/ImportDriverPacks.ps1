


function Import-PanasonicDriverPacks {
    param (
    [string]$SourceFolder = "C:\DeployR\DriverPacks\Source",
    [string]$DeployRModulePath ='C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
    )
    Write-Host "Importing Panasonic Driver Packs" -ForegroundColor Green
    #Ensure Source Folder exists
    if (-not (Test-Path $SourceFolder)) {
        New-Item -Path $SourceFolder -ItemType Directory -Force | Out-Null
    }
    #Get the Panasonic Driver Pack Catalog JSON
    
    
    Import-Module $DeployRModulePath
    $PanasonicCatalogURL = "https://pna-b2b-storage-mkt.s3.amazonaws.com/computer/software/apps/Panasonic.json"
    $JSONCatalog = Invoke-RestMethod -Uri $PanasonicCatalogURL
    $PanasonicDriverPacks = $JSONCatalog.PanasonicModels
    $Manufacturer = "Panasonic"
    $ItemManufacturer = "Panasonic Corporation"
    
    $TotalModels = (($PanasonicDriverPacks.PSObject.Properties).Count).Count
    Write-Host "Total Panasonic Models to process: $TotalModels" -ForegroundColor Magenta
    $CurrentCount = 0
    foreach ($modelKey in $PanasonicDriverPacks.PSObject.Properties.Name) {
        $CurrentCount++
        Write-Host "Processing model $CurrentCount of $TotalModels" -ForegroundColor Cyan
        $model = $PanasonicDriverPacks.$modelKey
        $ModelAlias = $modelKey
        Write-Host " Processing $Manufacturer - $ModelAlias" -ForegroundColor Cyan
        if ($Model.URL10) {
            $OSVer = 'Win10'
            $Win10URL = $model.URL10
            $DriverPackFileName = $Win10URL.Split("/")[-1]
            #Version from URL File Name, part that starts with V
            $DriverPackVersion = $DriverPackFileName.Split("_") | Where-Object { $_ -like "V*" }
            Write-Host "  Processing Windows 10: $Win10URL" -foregroundColor Green
            $DriverPackSourcePath = "$SourceFolder\$Manufacturer\$ModelAlias\$OSVer"
            Write-Host "  Source Path: $DriverPackSourcePath"
            if (Get-DeployRContentItem | Where-Object {$_.Name -eq "Driver Pack - $Manufacturer - $ModelAlias - $OSVer" -and $_.description -match "$DriverPackFileName"}){
                Write-Host "  Driver Pack Content Item already exists for $Manufacturer - $ModelAlias - $OSVer with file $DriverPackFileName" -ForegroundColor Yellow
            }
            else {
                #Create Source Folder Structure
                New-Item -Path "$DriverPackSourcePath\Extracted" -ItemType Directory -Force | Out-Null
                #Download the Driver Pack
                if (Test-Path "$DriverPackSourcePath\$DriverPackFileName") {
                    Write-Host "  Driver Pack already downloaded: $DriverPackFileName"
                }
                else {
                    write-Host "  Downloading Driver Pack to $DriverPackSourcePath\$DriverPackFileName"
                    Start-BitsTransfer -Source $Win10URL -Destination "$DriverPackSourcePath\$DriverPackFileName" -RetryInterval 60 -RetryTimeout 3600
                }
                
                #Extract the Driver Pack
                write-Host "  Extracting Driver Pack to $DriverPackSourcePath\Extracted"
                Expand-Archive -Path "$DriverPackSourcePath\$DriverPackFileName" -DestinationPath "$DriverPackSourcePath\Extracted" -Force
                #Create DeployR Content Item for the Driver Pack
                
                $NewCI = New-DeployRContentItem -Name "Driver Pack - $Manufacturer - $ModelAlias - $OSVer" -Type Folder -Purpose DriverPack -Description "File: $DriverPackFileName"
                $ContentId = $NewCI.id
                $NewVersion = New-DeployRContentItemVersion -ContentItemId $ContentId -Description "Source: $DriverPackSourcePath" -DriverManufacturer $ItemManufacturer -DriverModel $ModelAlias -SourceFolder "$DriverPackSourcePath\Extracted"
                $ContentVersion = $NewVersion.versionNo
                #Upload the extracted driver pack to the DeployR Content Item
                write-Host "  Uploading extracted Driver Pack to DeployR Content Item"
                $ciVersion = update-DeployRContentItemContent -ContentId $ContentId -ContentVersion $ContentVersion -SourceFolder "$DriverPackSourcePath\Extracted"
            }
        }
        if ($Model.URL11) {
            $OSVer = 'Win11'
            $Win11URL = $model.URL11
            $DriverPackFileName = $Win11URL.Split("/")[-1]
            #Version from URL File Name, part that starts with V
            $DriverPackVersion = $DriverPackFileName.Split("_") | Where-Object { $_ -like "V*" }
            Write-Host "  Processing Windows 11: $Win11URL" -foregroundColor Green
            $DriverPackSourcePath = "$SourceFolder\$Manufacturer\$ModelAlias\$OSVer"
            Write-Host "  Source Path: $DriverPackSourcePath"
            #Create Source Folder Structure
            
            if (Get-DeployRContentItem | Where-Object {$_.Name -eq "Driver Pack - $Manufacturer - $ModelAlias - $OSVer" -and $_.description -match "$DriverPackFileName"}){
                Write-Host "  Driver Pack Content Item already exists for $Manufacturer - $ModelAlias - $OSVer with file $DriverPackFileName" -ForegroundColor Yellow
            }
            else {
                New-Item -Path "$DriverPackSourcePath\Extracted" -ItemType Directory -Force | Out-Null
                #Download the Driver Pack
                if (Test-Path "$DriverPackSourcePath\$DriverPackFileName") {
                    Write-Host "  Driver Pack already downloaded: $DriverPackFileName"
                }
                else {
                    write-Host "  Downloading Driver Pack to $DriverPackSourcePath\$DriverPackFileName"
                    Start-BitsTransfer -Source $Win11URL -Destination "$DriverPackSourcePath\$DriverPackFileName" -RetryInterval 60 -RetryTimeout 3600
                }
                
                #Extract the Driver Pack
                write-Host "  Extracting Driver Pack to $DriverPackSourcePath\Extracted"
                Expand-Archive -Path "$DriverPackSourcePath\$DriverPackFileName" -DestinationPath "$DriverPackSourcePath\Extracted" -Force
                #Create DeployR Content Item for the Driver Pack
                
                $NewCI = New-DeployRContentItem -Name "Driver Pack - $Manufacturer - $ModelAlias - $OSVer" -Type Folder -Purpose DriverPack -Description "File: $DriverPackFileName"
                $ContentId = $NewCI.id
                $NewVersion = New-DeployRContentItemVersion -ContentItemId $ContentId -Description "Source: $DriverPackSourcePath" -DriverManufacturer $ItemManufacturer -DriverModel $ModelAlias -SourceFolder "$DriverPackSourcePath\Extracted"
                $ContentVersion = $NewVersion.versionNo
                #Upload the extracted driver pack to the DeployR Content Item
                write-Host "  Uploading extracted Driver Pack to DeployR Content Item"
                $ciVersion = update-DeployRContentItemContent -ContentId $ContentId -ContentVersion $ContentVersion -SourceFolder "$DriverPackSourcePath\Extracted"
            }
        }
    }
}