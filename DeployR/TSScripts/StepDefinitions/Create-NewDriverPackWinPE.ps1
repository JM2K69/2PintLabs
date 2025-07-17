
Import-Module DeployR.Utility

# Get the provided variables
[String]$IncludeGraphics = ${TSEnv:IncludeGraphics}
[String]$IncludeAudio = ${TSEnv:IncludeAudio}
[String]$TargetSystemDrive = ${TSEnv:OSDTARGETSYSTEMDRIVE}
[String]$LogPath = ${TSEnv:_DEPLOYRLOGS}
[String]$UseStandardDriverPack = ${TSEnv:UseStandardDriverPack}
[switch]$ApplyDrivers = $true
[String]$MakeAlias = ${TSEnv:MakeAlias}
[String]$ModelAlias = ${TSEnv:ModelAlias}



# Validate the Device Manufacturer
if ($MakeAlias -ne "Dell" -and $MakeAlias -ne "Lenovo" -and $MakeAlias -ne "HP") {
    Write-Host "MakeAlias must be Dell, Lenovo or HP. Exiting script."
    Exit 0
}



if ($env:SystemDrive -eq "X:") {
    $dest = "S:\_2P\Content\DriverPacks"
} else {
    $dest = "C:\_2P\Content\DriverPacks"
}
if (!(Test-Path -Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}

write-host "==================================================================="
write-host "Creating Driver Pack for WinPE for $MakeAlias $ModelAlias Devices"
write-host "Reporting Variables:"
write-host "IncludeGraphics: $IncludeGraphics"
write-host "IncludeAudio: $IncludeAudio"
write-host "UseStandardDriverPack: $UseStandardDriverPack"

#OEM Modules:
# Install Lenovo.Client.Scripting module
if ($MakeAlias -eq "Lenovo") {
    write-host "Installing Lenovo.Client.Scripting module if not already installed..."
    if (-not (Get-Module -Name Lenovo.Client.Scripting -ListAvailable)) {
        Write-Host "Lenovo.Client.Scripting module not found. Installing..."
        Install-Module -Name Lenovo.Client.Scripting -Force -SkipPublisherCheck
    } else {
        Write-Host "Lenovo.Client.Scripting module already installed."
    }
}

if ($MakeAlias -eq 'HP'){
    write-host "Installing HPCMSL module if not already installed..."
    if (-not (Get-Module -Name HPCMSL -ListAvailable)) {
        Write-Host "HPCMSL module not found. Installing..."
        Install-Module -Name HPCMSL -Force -SkipPublisherCheck -AcceptLicense
    } else {
        Write-Host "HPCMSL module already installed."
    }
}


#region functions
# Function to get Dell supported models
function Get-DCUUpdateList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [ValidateSet('bios','firmware','driver','application')]
        [String[]]$updateType,
        [ValidateSet('audio','video','network','chipset','storage','BIOS','Application')]
        [String[]]$updateDeviceCategory,
        [switch]$RAWXML,
        [switch]$Latest,
        [switch]$TLDR
    )

    
    $temproot = "$env:windir\temp"
    #$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    
    
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    if (!($DellSKU)){
        return "System SKU not found"
    }
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    

    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellSKU.URL)" -OutFile $CabPathIndexModel -UseBasicParsing
    if (Test-Path $CabPathIndexModel){
        $null = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
        [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml"
        
        #DCUAppsAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "APAC"}
        #$AppNames = $DCUAppsAvailable.name.display.'#cdata-section' | Select-Object -Unique
        $BaseURL = "https://$($XMLIndexCAB.Manifest.baseLocation)"
        $Components = $XMLIndexCAB.Manifest.SoftwareComponent
        if ($RAWXML){
            return $Components
        }
        $ComponentsObject = @()
        foreach ($Component in $Components){
            $Item = New-Object -TypeName PSObject
            $Item | Add-Member -MemberType NoteProperty -Name "PackageID" -Value "$($Component.packageID)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Category" -Value "$($Component.Category.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Type" -Value "$($component.ComponentType.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($Component.Name.Display.'#cdata-section')" -Force
            $Item | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value $([DateTime]($Component.releaseDate)) -Force
            $Item | Add-Member -MemberType NoteProperty -Name "DellVersion" -Value "$($Component.dellVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "VendorVersion" -Value "$($Component.vendorVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "PackageType" -Value "$($Component.packageType)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Path" -Value "$BaseURL/$($Component.path)" -Force		
            $Item | Add-Member -MemberType NoteProperty -Name "Description" -Value "$($component.Description.Display.'#cdata-section')" -Force		
            $ComponentsObject += $Item 
        }
        if ($updateType){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Type -in $updateType}
        }
        if ($updateDeviceCategory){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Category -in $updateDeviceCategory}
        }
        if ($TLDR) {
            $ComponentsObject = $ComponentsObject | Select-Object -Property Name,ReleaseDate,DellVersion,Path
        }
        if ($Latest){
            $ComponentsObject = $ComponentsObject | Sort-Object -Property ReleaseDate -Descending
            $hash = @{}
            foreach ($ComponentObject in $ComponentsObject) {
                if (-not $hash.ContainsKey($ComponentObject.Name)) {
                    $hash[$ComponentObject.Name] = $ComponentObject
                }
            }
            $ComponentsObject = $hash.Values 
        }
        return $ComponentsObject
    }
}
function Get-DellDeviceDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [string]$ModelLike
    )
    
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    
    
    if ((!($SystemSKUNumber)) -and (!($ModelLike))) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems, or please provide a SKU"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    <#
    if (!($ModelLike)){
        $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    }
    else {
        $DellSKU = Get-DellSupportedModels | Where-Object { $_.Model -match $ModelLike}
    }
    
    return $DellSKU | Select-Object -Property SystemID,Model
    #>
    $MoreData = Get-DellDriverPackXML
    if (!($ModelLike)){
        $DrillDown = $MoreData.DriverPackManifest.DriverPackage.SupportedSystems.brand.model | Where-Object {$_.systemid -eq $SystemSKUNumber} | Select-Object -First 1
        $RDSDate = [DATETIME]"$($DrillDown.rtsDate)"
        $DeviceOutput = New-Object -TypeName PSObject
        $DeviceOutput | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($DrillDown.systemID)" -Force
        $DeviceOutput | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($DrillDown.name)"  -Force
        $DeviceOutput | Add-Member -MemberType NoteProperty -Name "RTSDate" -Value $([DATETIME]$RDSDate) -Force
        return $DeviceOutput		
    }
    else{
        $DrillDown = $MoreData.DriverPackManifest.DriverPackage.SupportedSystems.brand.model | Where-Object {$_.name -match $ModelLike}
        if ($DrillDown.count -gt 1){
            $SystemIDs = $DrillDown.systemID | Select-Object -Unique
            $DeviceOutputObject = @()
            foreach ($SystemID in $SystemIDs){
                $DrillDown = $MoreData.DriverPackManifest.DriverPackage.SupportedSystems.brand.model | Where-Object {$_.systemid -eq $SystemID}| Select-Object -First 1
                $RDSDate = [DATETIME]"$($DrillDown.rtsDate)"
                $DeviceOutput = New-Object -TypeName PSObject
                $DeviceOutput | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($DrillDown.systemID)" -Force
                $DeviceOutput | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($DrillDown.name)"  -Force
                $DeviceOutput | Add-Member -MemberType NoteProperty -Name "RTSDate" -Value $([DATETIME]$RDSDate) -Force
                $DeviceOutputObject += $DeviceOutput 
            }
            return $DeviceOutputObject | Sort-Object -Property RTSDate
        }
    }
}

function Get-DellDriverPackXML {
    [CmdletBinding()]
    
    $CabPathIndex = "$env:ProgramData\EMPS\DellCabDownloads\CatalogIndexPC.cab"
    $DellCabExtractPath = "$env:ProgramData\EMPS\DellCabDownloads\DellCabExtract"
    
    # Pull down Dell XML CAB used in Dell Command Update ,extract and Load
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Dell Cab"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/DriverPackCatalog.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $null = New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand $CabPathIndex $DellCabExtractPath\DriverPackCatalog.xml
    
    Write-Verbose "Loading Dell Catalog XML.... can take awhile"
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\DriverPackCatalog.xml"
    
    return $XMLIndex
}

function Get-DellDeviceDriverPack {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [ValidateSet('Windows10','Windows11')]
        [string]$OSVer
    )
    
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    
    
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems, or please provide a SKU"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }

    $MoreData = Get-DellDriverPackXML
    $DriverPacks = $MoreData.DriverPackManifest.DriverPackage | Where-Object {$_.SupportedSystems.brand.model.systemid -eq $SystemSKUNumber}
    $DeviceDetails = $MoreData.DriverPackManifest.DriverPackage.SupportedSystems.brand.model | Where-Object {$_.systemid -eq $SystemSKUNumber} | Select-Object -First 1
    $DriverPacksOBject = @()
    foreach ($DriverPack in $DriverPacks){
        $URL = "http://$($MoreData.DriverPackManifest.baseLocation)/$($DriverPack.path)"
        $FileName = $DriverPack.path -split "/" | Select-Object -Last 1
        $DeviceDriverPack = New-Object -TypeName PSObject
        $MetaDataVersion = $MoreData.DriverPackManifest.version
        $SizeinMB = [Math]::Round($DriverPack.size/1MB,2)
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($DeviceDetails.systemID)" -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($DeviceDetails.name)"  -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "MetaDataVersion" -Value "$MetaDataVersion"  -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "FileName" -Value "$FileName"  -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "ReleaseID" -Value "$($DriverPack.releaseID)"  -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "URL" -Value "$URL"  -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "DateTime" -Value $([DATETIME]$DriverPack.dateTime) -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "hashMD5" -Value $($DriverPack.hashMD5) -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "SizeinMB" -Value $SizeinMB -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "OSSupported" -Value $($DriverPack.SupportedOperatingSystems.OperatingSystem.osCode) -Force
        $DeviceDriverPack | Add-Member -MemberType NoteProperty -Name "OsArch" -Value $($DriverPack.SupportedOperatingSystems.OperatingSystem.osArch) -Force
        $DriverPacksOBject += $DeviceDriverPack 
    }
    
    if ($OSVer){
        $DriverPacksOBject = $DriverPacksOBject | Where-Object {$_.OSSupported -match $OSVer}
    }
    
    return $DriverPacksOBject 

}

function Invoke-DriverDownloadExpand {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$URL,
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [Parameter(Mandatory=$true)]
    [string]$ToolsPath,
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath
)
    if ($DestinationPath){
        $dest = $DestinationPath
    }
    else {
        if ($env:SystemDrive -eq "X:") {
            $dest = "S:\_2P\Content\DriverPacks"
        } else {
            $dest = "C:\_2P\Content\DriverPacks"
        }
    }
    if (!(Test-Path -Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    Write-Host "Downloading: $URL"
    $destFile = Request-DeployRCustomContent -ContentName $Name -ContentFriendlyName $Name -URL $URL
    # Invoke-WebRequest -Uri $driverPack.Url -OutFile $destFile
    $GetItemOutFile = Get-Item $destFile

    # Expand
    $ExpandFile = $GetItemOutFile.FullName
    Write-Verbose -Message "DriverPack: $ExpandFile"
    #=================================================
    #   Cab
    #=================================================
    if ($GetItemOutFile.Extension -eq '.cab') {
        $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
        
        if (-NOT (Test-Path "$DestinationPath")) {
            New-Item $DestinationPath -ItemType Directory -Force -ErrorAction Ignore | Out-Null
    
            Write-Verbose -Verbose "Expanding CAB Driver Pack to $DestinationPath"
            Expand -R "$ExpandFile" -F:* "$DestinationPath" | Out-Null
        }
        Continue
}
    #=================================================
    #   Dell
    #=================================================
    if ($GetItemOutFile.Extension -eq '.exe') {
        if ($GetItemOutFile.VersionInfo.FileDescription -match 'Dell') {
            Write-Verbose -Verbose "FileDescription: $($GetItemOutFile.VersionInfo.FileDescription)"
            Write-Verbose -Verbose "ProductVersion: $($GetItemOutFile.VersionInfo.ProductVersion)"
    
            $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
    
            if (-NOT (Test-Path "$DestinationPath")) {
                Write-Verbose -Verbose "Expanding Dell Driver Pack to $DestinationPath"
                $null = New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Ignore | Out-Null
                Start-Process -FilePath $ExpandFile -ArgumentList "/s /e=`"$DestinationPath`"" -Wait
            }
            Continue
        }
    }
    #=================================================
    #   HP
    #=================================================
    if ($GetItemOutFile.Extension -eq '.exe') {
        if (($GetItemOutFile.VersionInfo.InternalName -match 'hpsoftpaqwrapper') -or ($GetItemOutFile.VersionInfo.OriginalFilename -match 'hpsoftpaqwrapper.exe') -or ($GetItemOutFile.VersionInfo.FileDescription -like "HP *")) {
            Write-Verbose -Message "FileDescription: $($GetItemOutFile.VersionInfo.FileDescription)"
            Write-Verbose -Message "InternalName: $($GetItemOutFile.VersionInfo.InternalName)"
            Write-Verbose -Message "OriginalFilename: $($GetItemOutFile.VersionInfo.OriginalFilename)"
            Write-Verbose -Message "ProductVersion: $($GetItemOutFile.VersionInfo.ProductVersion)"
                        
            $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
    
            if (-NOT (Test-Path "$DestinationPath")) {
                Write-Verbose -Verbose "Expanding HP Driver Pack to $DestinationPath"
                & "$ToolsPath\7za.exe" -y x "$ExpandFile" -o"$DestinationPath" | Out-Host
            }
            Continue
        }
    }
    #=================================================
    #   Lenovo
    #=================================================
    if ($GetItemOutFile.Extension -eq '.exe') {
        if (($GetItemOutFile.VersionInfo.FileDescription -match 'Lenovo') -or ($GetItemOutFile.Name -match 'tc_') -or ($GetItemOutFile.Name -match 'tp_') -or ($GetItemOutFile.Name -match 'ts_') -or ($GetItemOutFile.Name -match '500w') -or ($GetItemOutFile.Name -match 'sccm_') -or ($GetItemOutFile.Name -match 'm710e') -or ($GetItemOutFile.Name -match 'tp10') -or ($GetItemOutFile.Name -match 'tp8') -or ($GetItemOutFile.Name -match 'yoga')) {
            Write-Verbose -Message "FileDescription: $($GetItemOutFile.VersionInfo.FileDescription)"
            Write-Verbose -Message "ProductVersion: $($GetItemOutFile.VersionInfo.ProductVersion)"
    
            $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
    
            if (-NOT (Test-Path "$DestinationPath")) {
                Write-Verbose -Verbose "Expanding Lenovo Driver Pack to $DestinationPath"
                & "$ToolsPath\innoextract.exe" -e -d "$DestinationPath" "$ExpandFile" | Out-Host
            }
            Continue
        }
    }
    #=================================================
    #   MSI
    #=================================================
    if ($GetItemOutFile.Extension -eq '.msi') {
        $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
    
        if (-NOT (Test-Path "$DestinationPath")) {
            Write-Verbose -Verbose "Extracting MSI file to $DestinationPath"
            & "$ToolsPath\ExtractMSI\TwoPint.DeployR.ExtractMSI.exe" "$ExpandFile" "$DestinationPath" | Out-Host
        }
        Continue
    }
    #=================================================
    #   Zip
    #=================================================
    if ($GetItemOutFile.Extension -eq '.zip') {
        $DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
    
        if (-NOT (Test-Path "$DestinationPath")) {
            Write-Verbose -Verbose "Expanding ZIP Driver Pack to $DestinationPath"
            Expand-Archive -Path $ExpandFile -DestinationPath $DestinationPath -Force
        }
        Continue
    }
    #=================================================
    #   Everything Else
    #=================================================
    Write-Warning "Unable to expand $ExpandFile"
}
#endregion

#Find 7za.exe
if (Test-path -Path "X:\_2P\content\00000000-0000-0000-0000-000000000002\Tools\x64"){
    $ToolsPath = "X:\_2P\content\00000000-0000-0000-0000-000000000002\Tools\x64"
    $SevenZipPath = "$ToolsPath\7za.exe"
    $InnoExtractPath = "$ToolsPath\innoextract.exe"
} else {
    Write-Host "Unable to find Tools Path, please ensure the Tools are available in the expected location."
    Exit 1
}


#Import DeployR.Utility module
if (-not (Get-Module -Name DeployR.Utility)) {
    Import-Module X:\_2P\Client\PSModules\DeployR.Utility\DeployR.Utility.psd1 -Force -ErrorAction Stop
}

#Build Download Content Location
$DownloadContentPath = "$TargetSystemDrive\Drivers\Downloads"
if (!(Test-Path -Path $DownloadContentPath)) {
    New-Item -ItemType Directory -Path $DownloadContentPath -Force | Out-Null
}
$ExtractedDriverLocation = "$TargetSystemDrive\Drivers\Extracted"
if (!(Test-Path -Path $ExtractedDriverLocation)) {
    New-Item -ItemType Directory -Path $ExtractedDriverLocation -Force | Out-Null
}

#Using the Traditional Driver Pack from the OEM
if ($UseStandardDriverPack -eq "true") {
    Write-Host "Using Standard Driver Pack for WinPE"
    if ($MakeAlias -eq "Lenovo"){
        $DriverPack = Find-LnvDriverPack -MachineType (Get-LnvMachineType) -Latest
        if ($null -ne $DriverPack) {
            $URL = $DriverPack.'#text'
            $Name = ($DriverPack.'#text').split("/") | Select-Object -last 1
        }
    }
    if ($MakeAlias -eq "HP"){
        $DriverPack = Get-HPDeviceDriverPack -OSVer Windows11
        if ($null -ne $DriverPack) {
            $URL = $DriverPack.'#text'
            $Name = ($DriverPack.'#text').split("/") | Select-Object -last 1
        }
    }
    if ($MakeAlias -eq "Dell"){
        $DriverPack = Get-DellDeviceDriverPack -OSVer Windows11
        if ($null -ne $DriverPack) {
            $URL = $DriverPack.URL
            $Name = $DriverPack.FileName
        }
    }

    if ($null -ne $DriverPack) {
        Write-Host "Found Driver Pack"
        Write-Output $DriverPack
        Write-Host "Downloading and extracting  Driver Pack to $ExtractedDriverLocation"
        Invoke-DriverDownloadExpand -URL $URL -Name $Name -ToolsPath $ToolsPath
    } else {
        Write-Host "No Driver Pack found for the specified model."
    }
}
#Downloading Driver Updates directly from the OEM, extracting and applying them to the Offline OS
else {
    Write-Host "Scanning for $MakeAlias Drivers to Apply to Offline OS"
    if ($MakeAlias -eq "Dell") {

        $Drivers = Get-DCUUpdateList -Latest -updateType driver
        #Prune Bluetooth, Wi-Fi, Firmware
        $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Bluetooth"}
        $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Wi-Fi"}
        $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Firmware"}
        Write-Host "Found $($Drivers.Count) drivers to process. [Including Graphics & Audio]"
        if ($IncludeGraphics -ne $true) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Graphics"}
        }
        if ($IncludeAudio -ne $true) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Audio"}
        }
        Write-Host "Found $($Drivers.Count) drivers to process after Cleanup"
    }
    if ($MakeAlias -eq "HP") {
        $Drivers = Get-HPDeviceDriverPack -OSVer Windows11 -ListAll
        $Drivers = $Drivers | Where-Object {$_.Name -notmatch "BIOS" -and $_.Name -notmatch "Firmware" -and $_.Name -notmatch "FW"}
        if ($IncludeGraphics -eq $false) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Graphics"}
        }
        if ($IncludeAudio -eq $false) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Audio"}
        }
        Write-Host "Found $($Drivers.Count) drivers to process after Cleanup"
    }
    if ($MakeAlias -eq "Lenovo") {
        Write-Host "Using Lenovo Driver Pack for WinPE"
        $Drivers = Get-LnvDriverPack -MachineType (Get-LnvMachineType) -WindowsVersion 11 -ListAll
        $Drivers = $Drivers | Where-Object {$_.Name -notmatch "BIOS" -and $_.Name -notmatch "Firmware" -and $_.Name -notmatch "FW"  -and $_.Name -notmatch "Lenovo Base Utility"  -and $_.Name -notmatch "WAN"}
        if ($IncludeGraphics -ne $true) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Graphics"}
        }
        if ($IncludeAudio -ne $true) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Audio"}
        }
    }
    if ($Drivers.Count -eq 0) {
        Write-Host "No drivers found for the specified criteria." -ForegroundColor Red
        exit 0
    }
    Write-Host "Found $($Drivers.Count) drivers to process."
    Write-Output $Drivers.Name

    
    Write-Host "Starting Downloading Drivers to $DownloadContentPath"
    Foreach ($Driver in $Drivers){
        #Generalize Variable Names
        if ($MakeAlias -eq "Dell") {
            $Name = $Driver.FileName
            $URL = $Driver.URL
            $ID = $Driver.ReleaseID
        }
        if ($MakeAlias -eq "HP") {
            $Driver.PackageExe = $Driver.URL
        }
        if ($MakeAlias -eq "Lenovo") {
            $Name = $Driver.Name
            $URL = $Driver.PackageExe
            $ID = $Driver.Id
        }

        Write-Host "Driver: $NAME" -ForegroundColor Magenta
        if ($null -ne $URL){
            
            
            Write-Host "Downloading Driver from: $URL" -ForegroundColor Cyan

            #Start-BitsTransfer -Source "https://$($Driver.PackageExe)" -Destination "$DownloadContentPath\$($Driver.id).exe" -DisplayName $Driver.Name -Description $Driver.Description -ErrorAction SilentlyContinue
            try {
                #Request-DeployRCustomContent -ContentName $($Driver.Id) -ContentFriendlyName $($Driver.Name) -URL "$($Driver.PackageExe)" -DestinationPath $DownloadContentPath -ErrorAction SilentlyContinue
                $destFile = Request-DeployRCustomContent -ContentName $ID -ContentFriendlyName $NAME -URL $URL -DestinationPath $DownloadContentPath -ErrorAction SilentlyContinue
                $GetItemOutFile = Get-Item $destFile
                $ExpandFile = $GetItemOutFile.FullName
                if (Test-Path -path $ExpandFile) {
                    Write-Host "Downloaded driver to: $ExpandFile" -ForegroundColor Green
                }
            } catch {
                Write-Host "Failed to download driver: $Name" -ForegroundColor red
                Write-Host "Going to try again with Invoke-WebRequest" -ForegroundColor Yellow
                $ExpandFile = Join-Path -Path $DownloadContentPath -ChildPath "$ID.exe"
                Invoke-WebRequest -Uri $URL -OutFile $ExpandFile -UseBasicParsing
            }
        }
        else {
            Write-Host "No URL found for this driver, skipping download."
        }
    }
    Write-Host "Starting Extracting Drivers to $ExtractedDriverLocation"
    $DriversDownloads = Get-ChildItem -Path $DownloadContentPath -Filter *.exe -Recurse
    if ($DriversDownloads) {
        foreach ($DriverDownload in $DriversDownloads) {
            Write-Host "Found Driver Download: $($DriverDownload.Name)"
            $FolderName = $DriverDownload.Name -replace '.exe',''
            $ExpandFile = $DriverDownload.FullName
            $ExtractedDriverPath = "$ExtractedDriverLocation\$FolderName"
            if (!(Test-Path -Path $ExtractedDriverPath)) {
                New-Item -ItemType Directory -Path $ExtractedDriverPath -Force | Out-Null
            }
            Write-Host "Expanding Driver to $ExtractedDriverPath"
            if ($MakeAlias -eq "Dell") {
                Start-Process -FilePath $SevenZipPath -ArgumentList "x $ExpandFile -o$ExtractedDriverPath -y" -Wait -NoNewWindow -PassThru
            }
            if ($MakeAlias -eq "HP") {
                Start-Process -FilePath $SevenZipPath -ArgumentList "x $ExpandFile -o$ExtractedDriverPath -y" -Wait -NoNewWindow -PassThru
            }
            if ($MakeAlias -eq "Lenovo") {
                Start-Process -FilePath $InnoExtractPath -ArgumentList "-e -d $ExtractedDriverPath $ExpandFile" -Wait -NoNewWindow -PassThru
            }
            
        }
    } 
    else {
        Write-Host "No Downloaded Driver EXE files Found" -ForegroundColor Red
    }
}
#Apply Drivers in ExtractedDriverLocation to Offline OS
if ($ApplyDrivers -eq $false){
    Write-Host "Skipping Driver Application to Offline OS"
    return
}
else {
    Write-Host -ForegroundColor Cyan "Applying Drivers to Offline OS at $TargetSystemDrive from $ExtractedDriverLocation"
    #Add-WindowsDriver -Path "$($TargetSystemDrive)\" -Driver "$ExtractedDriverLocation" -Recurse -ErrorAction SilentlyContinue -LogPath $LogPath\AddDrivers.log

    & Dism /Image:"$($TargetSystemDrive)\" /Add-Driver /Driver:$ExtractedDriverLocation /Recurse
}
