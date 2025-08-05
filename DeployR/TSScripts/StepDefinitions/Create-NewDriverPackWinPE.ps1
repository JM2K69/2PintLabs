
try {
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
    [int]$OSImageBuild = ${TSEnv:OSImageBuild}
}
catch {
    <#Do this if a terminating exception happens#>
    [String]$IncludeGraphics = "False"
    [String]$IncludeAudio = "False"
    [String]$TargetSystemDrive = "C:"
    [String]$LogPath = "C:\Windows\Temp\"
    [String]$UseStandardDriverPack = "False"
    [switch]$ApplyDrivers = $true
    $Gather = iex (irm gather.garytown.com)
    [String]$MakeAlias = $Gather.MakeAlias
    [String]$ModelAlias = $Gather.ModelAlias
    [int]$OSImageBuild = $Gather.OSCurrentBuild
}






# Validate the Device Manufacturer
if ($MakeAlias -ne "Dell" -and $MakeAlias -ne "Lenovo" -and $MakeAlias -ne "HP" -and $MakeAlias -ne "Panasonic Corporation") {
    Write-Host "MakeAlias must be Dell, Lenovo, Panasonic or HP. Exiting script."
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
<# I don't think I need this for what I'm doing
if ($MakeAlias -eq 'HP'){
write-host "Installing HPCMSL module if not already installed..."
if (-not (Get-Module -Name HPCMSL -ListAvailable)) {
Write-Host "HPCMSL module not found. Installing..."
Install-Module -Name HPCMSL -Force -SkipPublisherCheck -AcceptLicense
} else {
Write-Host "HPCMSL module already installed."
}
}
#>

#region functions
# Function to get Dell supported models
function Test-HPIASupport {
    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $Platforms = $XML.ImagePal.Platform.SystemID
    $MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    if ($MachinePlatform -in $Platforms){$HPIASupport = $true}
    else {$HPIASupport = $false}
    return $HPIASupport
}
function Get-HPOSSupport {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$Latest,
    [switch]$MaxOS,
    [switch]$MaxOSVer,
    [switch]$MaxOSNum
    )
    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $XMLPlatforms = $XML.ImagePal.Platform
    $OSList = ($XMLPlatforms | Where-Object {$_.SystemID -match $MachinePlatform}).OS | Select-Object -Property OSReleaseIdDisplay, OSBuildId, OSDescription
    
    if ($Latest){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        [String]$MaxOSVerion = (($OSList | Where-Object {$_.OSDescription -eq "$MaxOSSupported"}).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
        return "$MaxOSSupported $MaxOSVerion"
        break
    }
    if ($MaxOS){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        if ($MaxOSSupported -Match "11"){[String]$MaxOSName = "Win11"}
        else {[String]$MaxOSName = "Win10"}
        return "$MaxOSName"
        break
    }
    if ($MaxOSVer){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        [String]$MaxOSVersion = (($OSList | Where-Object {$_.OSDescription -eq "$MaxOSSupported"}).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
        return "$MaxOSVersion"
        break
    }
    if ($MaxOSNum){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        if ($MaxOSSupported -Match "11"){[String]$MaxOSNumber = "11.0"}
        else {[String]$MaxOSNumber = "10.0"}
        return "$MaxOSNumber"
        break
    }
    return $OSList
}

function Get-HPSoftpaqListLatest {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$SystemInfo,
    [switch]$MaxOSVer,
    [switch]$MaxOSNum
    )
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"){
        $Arch = '64'
    }
    
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $OSNum = Get-HPOSSupport -MaxOSNum -Platform $MachinePlatform
    $ReleaseID = Get-HPOSSupport -MaxOSVer -Platform $MachinePlatform
    $BaseURL = ("https://hpia.hpcloud.hp.com/ref/$($MachinePlatform)/$($MachinePlatform)_$($Arch)_$($OSNum).$($ReleaseID).cab").ToLower()
    #https://hpia.hpcloud.hp.com/ref/83b2/83b2_64_11.0.23h2.cab
    $CabPath = "$env:TEMP\HPIA.cab"
    $XMLPath = "$env:TEMP\HPIA.xml"
    Write-Verbose "Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing"
    Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $SoftpaqList = $XML.ImagePal.Solutions.UpdateInfo
    if ($SystemInfo){
        $SysInfo = $XML.ImagePal.SystemInfo.System
        return $SysInfo
        break
    }
    return $SoftpaqList
    
}

function Get-HPSoftPaqItems {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string] $Platform,
    [Parameter(Position=1,mandatory=$true)]
    [string] $osver,
    [Parameter(Position=2,mandatory=$true)]
    [ValidateSet("10.0","11.0")]
    [string] $os
    )
    
    
    
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"){$Arch = '64'}
    $CabPath = "$env:TEMP\HPIA.cab"
    $XMLPath = "$env:TEMP\HPIA.xml"
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    
    #Test Passed Parameters
    $OSList = Get-HPOSSupport -Platform $MachinePlatform
    if ($OS -eq "11.0"){
        $OK = $OSList | Where-Object {$_.OSDescription -match "Windows 11"}
        if ($null -eq $OK){
            Write-Error "Your option of OS: $OS is not valid, This platform does not support Windows 11"
            break
        }
    }
    if ($OS -eq "10.0"){
        $OK = $OSList | Where-Object {$_.OSDescription -match "Windows 10"}
        if ($null -eq $OK){
            Write-Error "Your option of OS: $OS is not valid, This platform does not support Windows 10"
            break
        }
    }
    $SupportedOSVers = $OSList.OSReleaseIdDisplay
    if ($osver -notin $SupportedOSVers){
        Write-Host -ForegroundColor red "Selected Release $OSVer is not supported by this Platform: $MachinePlatform"
        Write-Error " Use Get-HPOSSupport to find list of options"
        break
    }
    $BaseURL = ("https://hpia.hpcloud.hp.com/ref/$($MachinePlatform)/$($MachinePlatform)_$($Arch)_$($os).$($osver).cab").ToLower()
    Write-Verbose "Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing"
    Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $SoftpaqList = $XML.ImagePal.Solutions.UpdateInfo
    
    return $SoftpaqList
    
}

function Get-HPDriverPackLatest {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$URL,
    [switch]$download
    )
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $OSList = Get-HPOSSupport -Platform $MachinePlatform
    if (($OSList.OSDescription) -contains "Microsoft Windows 11"){
        $OS = "11.0"
        #Get the supported Builds for Windows 11 so we can loop through them
        $SupportedWinXXBuilds = ($OSList| Where-Object {$_.OSDescription -match "11"}).OSReleaseIdDisplay | Sort-Object -Descending
        if ($SupportedWinXXBuilds){
            write-Verbose "Checking for Win $OS Driver Pack"
            [int]$Loop_Index = 0
            do {
                Write-Verbose "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
                $DriverPack = Get-HPSoftPaqItems -osver $($SupportedWinXXBuilds[$loop_index]) -os $OS -Platform $MachinePlatform | Where-Object {$_.Category -match "Driver Pack"}
                #$DriverPack = Get-SoftpaqList -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win11" -ErrorAction SilentlyContinue
                
                if (!($DriverPack)){$Loop_Index++;}
                if ($DriverPack){
                    Write-Verbose "Windows 11 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
                }
            }
            while ($null -eq $DriverPack -and $loop_index -lt $SupportedWinXXBuilds.Count)
        }
    }
    
    if (!($DriverPack)){ #If no Win11 Driver Pack found, check for Win10 Driver Pack
        if (($OSList.OSDescription) -contains "Microsoft Windows 10"){
            $OS = "10.0"
            #Get the supported Builds for Windows 10 so we can loop through them
            $SupportedWinXXBuilds = ($OSList| Where-Object {$_.OSDescription -match "10"}).OSReleaseIdDisplay | Sort-Object -Descending
            if ($SupportedWinXXBuilds){
                write-Verbose "Checking for Win $OS Driver Pack"
                [int]$Loop_Index = 0
                do {
                    Write-Verbose "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
                    $DriverPack = Get-HPSoftPaqItems -osver $($SupportedWinXXBuilds[$loop_index]) -os $OS  -Platform $MachinePlatform | Where-Object {$_.Category -match "Driver Pack"}
                    #$DriverPack = Get-SoftpaqList -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win10" -ErrorAction SilentlyContinue
                    if (!($DriverPack)){$Loop_Index++;}
                    if ($DriverPack){
                        Write-Verbose "Windows 10 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
                    }
                }
                while ($null-eq $DriverPack  -and $loop_index -lt $SupportedWinXXBuilds.Count)
            }
        }
    }
    if ($DriverPack){
        Write-Verbose "Driver Pack Found: $($DriverPack.Name) for Platform: $Platform"
        if($PSBoundParameters.ContainsKey('Download')){
            Save-WebFile -SourceUrl "https://$($DriverPack.URL)" -DestinationName "$($DriverPack.id).exe" -DestinationDirectory "C:\Drivers"
        }
        else{
            if($PSBoundParameters.ContainsKey('URL')){
                return "https://$($DriverPack.URL)"
            }
            else {
                return $DriverPack
            }
        }
    }
    else {
        Write-Verbose "No Driver Pack Found for Platform: $Platform"
        return $false
    }
}
function Get-DellSupportedModels {
    [CmdletBinding()]
    
    $CabPathIndex = "$env:ProgramData\EMPS\DellCabDownloads\CatalogIndexPC.cab"
    $DellCabExtractPath = "$env:ProgramData\EMPS\DellCabDownloads\DellCabExtract"
    
    # Pull down Dell XML CAB used in Dell Command Update ,extract and Load
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Dell Cab"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $null = New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml
    
    Write-Verbose "Loading Dell Catalog XML.... can take awhile"
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml"
    
    
    $SupportedModels = $XMLIndex.ManifestIndex.GroupManifest
    $SupportedModelsObject = @()
    foreach ($SupportedModel in $SupportedModels){
        $SPInventory = New-Object -TypeName PSObject
        $SPInventory | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($SupportedModel.SupportedSystems.Brand.Model.systemID)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($SupportedModel.SupportedSystems.Brand.Model.Display.'#cdata-section')"  -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "URL" -Value "$($SupportedModel.ManifestInformation.path)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Date" -Value "$($SupportedModel.ManifestInformation.version)" -Force		
        $SupportedModelsObject += $SPInventory 
    }
    return $SupportedModelsObject
}
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
    [string]$ID,
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
    $destFile = Request-DeployRCustomContent -ContentName $ID -ContentFriendlyName $Name -URL $URL
    # Invoke-WebRequest -Uri $driverPack.Url -OutFile $destFile
    $GetItemOutFile = Get-Item $destFile
    
    # Expand
    $ExpandFile = $GetItemOutFile.FullName
    Write-Verbose -Message "DriverPack: $ExpandFile"
    Write-Progress -Activity "Expanding Driver Pack" -Status "Expanding $ExpandFile" -PercentComplete 50
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
        return
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
                try {
                    Start-Process -FilePath $ExpandFile -ArgumentList "/s /e=`"$DestinationPath`"" -Wait                
                } catch {
                    Write-Error "Failed to extract Dell driver pack: $ExpandFile"
                }
                
            }
            return
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
                try {
                    & "$ToolsPath\7za.exe" -y x "$ExpandFile" -o"$DestinationPath" | Out-Host
                }
                catch {
                    Write-Error "Failed to extract HP driver pack: $ExpandFile"
                }
                
            }
            return
        }
    }
    #=================================================
    #   Lenovo
    #=================================================
    if ($GetItemOutFile.Extension -eq '.exe') {
        if (($GetItemOutFile.VersionInfo.FileDescription -match 'Lenovo') -or ($GetItemOutFile.Name -match 'tc_') -or ($GetItemOutFile.Name -match 'tp_') -or ($GetItemOutFile.Name -match 'ts_') -or ($GetItemOutFile.Name -match '500w') -or ($GetItemOutFile.Name -match 'sccm_') -or ($GetItemOutFile.Name -match 'm710e') -or ($GetItemOutFile.Name -match 'tp10') -or ($GetItemOutFile.Name -match 'tp8') -or ($GetItemOutFile.Name -match 'yoga')) {
            Write-Verbose -Message "FileDescription: $($GetItemOutFile.VersionInfo.FileDescription)"
            Write-Verbose -Message "ProductVersion: $($GetItemOutFile.VersionInfo.ProductVersion)"
            
            #$DestinationPath = Join-Path $dest $GetItemOutFile.BaseName
            $computer = Get-CimInstance -Class "Win32_ComputerSystemProduct" -Namespace "root/cimv2"
            $MachineType = $computer.Name.Substring(0, 4)
            $DestinationPath = Join-Path $dest $MachineType
            if (-NOT (Test-Path "$DestinationPath")) {
                Write-Verbose -Verbose "Expanding Lenovo Driver Pack to $DestinationPath"
                try {
                    & "$ToolsPath\innoextract.exe" -e -d "$DestinationPath" "$ExpandFile" | Out-Host
                } catch {
                    Write-Error "Failed to extract Lenovo driver pack: $ExpandFile"
                }
                return
                <# This doesn't work as the extracted folder name is too long to even extract to, so this is too late to help.
                #Rename the extracted folder to "Lenovo"
                Get-ChildItem -Path "$DestinationPath" -Directory | ForEach-Object {
                    $newName = Join-Path $DestinationPath "Lenovo"
                    if (-not (Test-Path $newName)) {
                        Rename-Item -Path $_.FullName -NewName "Lenovo" -Force
                    } else {
                        Write-Warning "Destination folder already exists: $newName"
                    }
                }
                #>
            }
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
        return
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
        return
    }
    #=================================================
    #   Everything Else
    #=================================================
    Write-Warning "Unable to expand $ExpandFile"
}

function Migrate-WinPEDrivers {
    [CmdletBinding()]
    param(
    [string]$OfflineOSPath
    )
    
    $startTime = Get-Date
    $WindowsPath = $OfflineOSPath
    
    function timeDuration() {
        $totalSeconds = [int]$args[0]
        if ($totalSeconds -gt 0) { $time = New-TimeSpan -Seconds $totalSeconds }
        else { $time = New-TimeSpan -Seconds 600 }
        if ($time.Hours -gt 0) {
            if ($time.Hours -eq 1) { $output += "$($time.Hours) Hour" }
            else { $output += "$($time.Hours) Hours" }
        }
        if ($time.Minutes -gt 0) { 
            if ($time.Minutes -eq 1) { $output += " $($time.Minutes) Minute" } 
            else { $output += " $($time.Minutes) Minutes" }
        }
        if ($time.Seconds -gt 0) { 
            if ($time.Seconds -eq 1) { $output += " $($time.Seconds) Second" }
            else { $output += " $($time.Seconds) Seconds" }
        } 
        $output
    }
    
    Write-Host "Grabbing all the drivers..."
    $windrivers = Get-WindowsDriver -Online
    $runningDrivers = Get-CimInstance -ClassName win32_systemdriver | Where-Object State -eq 'Running'
    Write-Host "Found $($windrivers.Count) imported drivers and $($runningDrivers.Count) running drivers"
    
    $matchedDrivers = [System.Collections.Generic.List[PSCustomObject]]::new()
    Write-Host "Starting match driver process..."
    foreach ($run in $runningDrivers) {
        $runName = $run.Name                       # e.g. "iaStorVD"
        $runPath = $run.PathName                   # e.g. X:\Windows\System32\drivers\iaStorVD.sys
        $baseNoExt = [IO.Path]::GetFileNameWithoutExtension($runPath)
        
        # get the hash of the running .sys file
        $runHash = (Get-FileHash -Path $runPath -Algorithm SHA256).Hash
        
        # Find all packages for this driver base name
        $candidates = $windrivers | Where-Object {
            [IO.Path]::GetFileNameWithoutExtension($_.CatalogFile) -ieq $baseNoExt
        }
        $foundOne = $false
        foreach ($pkg in $candidates) {
            # Derive the driver‐store folder from the INF path
            $storeFolder = Split-Path -Path $pkg.OriginalFileName
            
            # Build the path to the .sys in that folder
            $candidateSys = Join-Path $storeFolder ("$baseNoExt.sys")
            if (-not (Test-Path $candidateSys)) {
                Write-Host "Skipping $($pkg.CatalogFile) - no SYS file at $candidateSys" -Severity 2
                continue
            }
            
            try {
                $candHash = (Get-FileHash -Path $candidateSys -Algorithm SHA256).Hash
            }
            catch {
                Write-Host "ERROR: Could not hash $candidateSys : $_" -Severity 3
                continue
            }
            
            
            if (Test-Path $candidateSys) {
                $candHash = (Get-FileHash -Path $candidateSys -Algorithm SHA256).Hash
                #We are doing a hash match as different versions of the same driver can be imported
                if ($candHash -eq $runHash) {
                    # WOW! (hubble reference)
                    $matchedDrivers.Add([PSCustomObject]@{
                        DriverName       = $runName
                        DriverPath       = $runPath
                        CatalogFile      = $pkg.CatalogFile
                        OriginalFileName = $pkg.OriginalFileName
                        ClassName        = $pkg.ClassName
                        ClassGuid        = $pkg.ClassGuid
                    })
                    Write-Host "Matched $runName -> $($pkg.CatalogFile) (store = $storeFolder)"
                    $foundOne = $true
                    break
                }
            }
        }
        # You can uncomment this line for extreme verbose messages, but typically not needed
        # if (-not $foundOne) {
        #     Write-Host "WARNING: No hash match found for $runName among $($candidates.Count) candidates" -Severity 2
        # }
    }
    if ($matchedDrivers.Count -eq 0) {
        Write-Host "ERROR: No matched drivers at all. Exiting script." -Severity 3
        exit 0
    }
    Write-Host "Completing matching imported and running drivers. Found $($matchedDrivers.count) matched drivers total."
    # set up drivers folder
    $exportRoot = "$($env:SystemDrive)\ExportedDrivers"
    
    # create it if it doesn't already exist
    if (-not (Test-Path $exportRoot)) {
        Write-Host "Creating $exportRoot to export drivers"
        New-Item -Path $exportRoot -ItemType Directory | Out-Null
    }
    Write-Host "Starting export process for injection"
    foreach ($m in $matchedDrivers) {
        # OriginalFileName is the path to the .inf in its DriverStore folder
        $storeFolder = Split-Path -Path $m.OriginalFileName
        
        # pull just the leaf folder name (i.e. "iastorvd.inf_amd64_da06297c4b8e9167")
        $leafName = Split-Path -Path $storeFolder -Leaf
        $destFolder = Join-Path $exportRoot $leafName
        
        # copy the entire folder 
        Copy-Item -Path $storeFolder -Destination $destFolder -Recurse -Force
        Write-Host "Copied $storeFolder -> $destFolder"
    }
    
    Write-Host "Starting DISM injection: /Image:$WindowsPath /Add-Driver /Driver:$exportRoot /Recurse"
    $Output = "$env:systemdrive\_2p\Logs\DISMMigrateDriversOutput.txt"
    $DISM = Start-Process DISM.EXE -ArgumentList "/image:$($WindowsPath)\ /Add-Driver /driver:$exportRoot /recurse" -PassThru -NoNewWindow -RedirectStandardOutput $Output
    #& Dism /Image:$WindowsPath /Add-Driver /Driver:$exportRoot /Recurse
    $SameLastLine = $null
    do {  #Continous loop while DISM is running
        Start-Sleep -Milliseconds 300
        
        #Read in the DISM Logfile
        $Content = Get-Content -Path $Output -ReadCount 1
        $LastLine = $Content | Select-Object -Last 1
        if ($LastLine){
            if ($SameLastLine -ne $LastLine){ #Only continue if DISM log has changed
                $SameLastLine = $LastLine
                Write-Output $LastLine
                if ($LastLine -match "Searching for driver packages to install..."){
                    #Write-Output $LastLine
                    Write-Progress -Activity "Migrating Drivers" -Status $LastLine -PercentComplete 5
                }
                elseif ($LastLine -match "Installing"){
                    #Write-Output $LastLine
                    $Message = $Content | Where-Object {$_ -match "Installing"} | Select-Object -Last 1
                    if ($Message){
                        $ToRemove = $Message.Split(':') | Select-Object -Last 1
                        $Message = $Message.Replace(":$($ToRemove)","")
                        $Message = $Message.Replace($exportRoot,"")
                        $Total = (($Message.Split("-")[0]).Split("of") | Select-Object -Last 1).replace(" ","")
                        $Counter = ((($Message.Split("-")[0]).Split("of") | Select-Object -First 1).replace(" ","")).replace("Installing","")
                        if ($Counter -eq "0"){$Counter = 1}
                        $Total = $Total + 1 #So that when it gets to 3 of 3, it doesn't show 100% complete while it is still installing
                        $PercentComplete = [math]::Round(($Counter / $Total) * 100)
                        Write-Progress -Activity "Migrating Drivers" -Status $LastLine -PercentComplete $PercentComplete
                        
                    }
                }
                elseif ($LastLine -match "The operation completed successfully."){
                    Write-Progress -Activity "Migrating Drivers" -Status $LastLine -Completed
                }
                else{
                    Write-Progress -Activity "Migrating Drivers" -Status $LastLine -Completed
                }
            }
        }
        
    }
    until (!(Get-Process -Name DISM -ErrorAction SilentlyContinue))
    
    Write-Output "Dism Step Complete"
    Write-Output "See DISM log for more Details: $Output"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: DISM exited with $LASTEXITCODE" -Severity 3
    }
    else {
        Write-Host "DISM injection completed successfully."
    }
    $endTime = Get-Date
    $ScriptDuration = timeDuration $((New-TimeSpan -Start $startTime -End $endTime).TotalSeconds)
    $ScriptDuration = $ScriptDuration.Trim()
    Write-Output "Total export process took: $ScriptDuration"
    
}
#endregion

Write-Host "Attempting to Migrate WInPE Drivers to Offline OS as fallback"
Migrate-WinPEDrivers -OfflineOSPath "$($TargetSystemDrive)\"
write-host "=============================================================="
write-host "Continuing with OEM Feeds to Get Drivers"
#Confirm compatibility with HP Model if HP Device
if ($MakeAlias -eq "HP"){
    if (Test-HPIASupport){
        Write-Host "This Platform is supported by HPIA"
    }
    else {
        Write-Host "This Platform is not supported by HPIA"
        exit 0
    }
}


if ($MakeAlias -eq "Panasonic Corporation"){
    $PanasonicCatalogURL = "https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/Catalog/Panasonic.json"
    $JSONCatalog = Invoke-RestMethod -Uri $PanasonicCatalogURL
    $PanasonicDriverPacks = $JSONCatalog.PanasonicModels.$ModelAlias
    if ($null -eq $PanasonicDriverPacks) {
        Write-Host "No Panasonic Driver Packs found for the specified model $ModelAlias."
        exit 0
    }
    if ($OSImageBuild -lt 22000){
        $PanasonicDriverPack = $PanasonicDriverPacks.URL10
    }
    else {
        $PanasonicDriverPack = $PanasonicDriverPacks.URL11
    }
}
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
$DownloadContentPath = "$TargetSystemDrive\Drivers\Dls"
if (!(Test-Path -Path $DownloadContentPath)) {
    New-Item -ItemType Directory -Path $DownloadContentPath -Force | Out-Null
}
$ExtractedDriverLocation = "$TargetSystemDrive\Drivers\Ex"
if (!(Test-Path -Path $ExtractedDriverLocation)) {
    New-Item -ItemType Directory -Path $ExtractedDriverLocation -Force | Out-Null
}

#Using the Traditional Driver Pack from the OEM
#Panasonic Corporation is a special case, as it does not have a Driver Update Catalog Option yet, but rather a single driver download
if ($UseStandardDriverPack -eq "true" -or $MakeAlias -eq "Panasonic Corporation") {
    Write-Host "Using Standard Driver Pack for WinPE"
    if ($MakeAlias -eq "Lenovo"){
        $DriverPack = Find-LnvDriverPack -MachineType (Get-LnvMachineType) -Latest
        if ($null -ne $DriverPack) {
            $URL = $DriverPack.'#text'
            $Name = ($DriverPack.'#text').split("/") | Select-Object -last 1
            $ID = (Get-LnvMachineType)
        }
    }
    if ($MakeAlias -eq "HP"){
        $DriverPack = Get-HPDriverPackLatest
        if ($null -ne $DriverPack) {
            $URL = "http://$($DriverPack.url)"
            $Name = $DriverPack.Name
            $ID = $DriverPack.id
        }
    }
    if ($MakeAlias -eq "Dell"){
        
        $DriverPack = Get-DellDeviceDriverPack | Select-Object -first 1
        if ($null -ne $DriverPack) {
            $URL = $DriverPack.URL
            $Name = $DriverPack.FileName
            $ID = $DriverPack.ReleaseID
        }
    }
    if ($MakeAlias -eq "Panasonic Corporation"){
        
        $DriverPack = $PanasonicDriverPack
        if ($null -ne $DriverPack) {
            $URL = $DriverPack
            $NameChunks = (($DriverPack.split("/") | Select-Object -last 1).split("_") | select-object -first 2)
            $Name = $NameChunks -join "_"
            $ID = $ModelAlias
        }
    }    
    if ($null -ne $DriverPack) {
        Write-Host "Found Driver Pack"
        Write-Output $DriverPack
        Write-Host "Downloading and extracting  Driver Pack to $ExtractedDriverLocation"
        write-host "Invoke-DriverDownloadExpand -URL $URL -Name $Name -ID $ID -ToolsPath $ToolsPath -DestinationPath $ExtractedDriverLocation"
        Invoke-DriverDownloadExpand -URL $URL -Name $Name -ID $ID -ToolsPath $ToolsPath -DestinationPath $ExtractedDriverLocation
    } else {
        Write-Host "No Driver Pack found for the specified model."
        exit 0
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
        $Drivers = Get-HPSoftpaqListLatest | where-object {$_.Category -match "Driver" -and $_.Category -notmatch "Firmware" -and $_.Category -notmatch "Manageability" -and $_.Category -notmatch "Enabling"}
        if ($IncludeGraphics -eq $false) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Graphics"}
        }
        if ($IncludeAudio -eq $false) {
            $Drivers = $Drivers | Where-Object {$_.Name -notmatch "Audio"}
        }
        Write-Host "Found $($Drivers.Count) drivers to process after Cleanup"
    }
    if ($MakeAlias -eq "Lenovo") {
        $Drivers = Find-LnvUpdate -MachineType (Get-LnvMachineType) -ListAll -WindowsVersion 11
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
            $Name = $Driver.Name
            $URL = $Driver.Path
            $ID = $Driver.PackageID
        }
        if ($MakeAlias -eq "HP") {
            $Name = $Driver.Name
            $URL = $Driver.Url
            $ID = $Driver.Id
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
                try {
                    Start-Process -FilePath $ExpandFile -ArgumentList "/s /e=`"$ExtractedDriverPath`"" -Wait -NoNewWindow -PassThru
                } catch {
                    try {
                        Write-Host "Failed to expand Dell driver, trying with 7zip" -ForegroundColor Yellow
                        Start-Process -FilePath $SevenZipPath -ArgumentList "x $ExpandFile -o$ExtractedDriverPath -y" -Wait -NoNewWindow -PassThru
                    } catch {
                        Write-Host "Failed to expand Dell driver with Inno" -ForegroundColor Red
                        Start-Process -FilePath $InnoExtractPath -ArgumentList "-e -d $ExtractedDriverPath $ExpandFile" -Wait -NoNewWindow -PassThru
                    }
                }
                #Start-Process -FilePath $ExpandFile -ArgumentList "/s /e=`"$ExtractedDriverPath`"" -Wait -NoNewWindow -PassThru
                #Start-Process -FilePath $SevenZipPath -ArgumentList "x $ExpandFile -o$ExtractedDriverPath -y" -Wait -NoNewWindow -PassThru
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
    
    #& Dism /Image:"$($TargetSystemDrive)\" /Add-Driver /Driver:$ExtractedDriverLocation /Recurse
    $Output = "$env:systemdrive\_2p\Logs\DISMApplyDriversOutput.txt"
    try {
        $DISM = Start-Process DISM.EXE -ArgumentList "/image:$($TargetSystemDrive)\ /Add-Driver /driver:$ExtractedDriverLocation /recurse" -PassThru -NoNewWindow -RedirectStandardOutput $Output
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
    
    
    #& Dism /Image:$WindowsPath /Add-Driver /Driver:$exportRoot /Recurse
    $SameLastLine = $null
    do {  #Continous loop while DISM is running
        Start-Sleep -Milliseconds 300
        
        #Read in the DISM Logfile
        $Content = Get-Content -Path $Output -ReadCount 1
        $LastLine = $Content | Select-Object -Last 1
        if ($LastLine){
            if ($SameLastLine -ne $LastLine){ #Only continue if DISM log has changed
                $SameLastLine = $LastLine
                Write-Output $LastLine
                if ($LastLine -match "Searching for driver packages to install..."){
                    #Write-Output $LastLine
                    Write-Progress -Activity "Applying Drivers" -Status $LastLine -PercentComplete 5
                }
                elseif ($LastLine -match "Installing"){
                    #Write-Output $LastLine
                    $Message = $Content | Where-Object {$_ -match "Installing"} | Select-Object -Last 1
                    if ($Message){
                        $ToRemove = $Message.Split(':') | Select-Object -Last 1
                        $Message = $Message.Replace(":$($ToRemove)","")
                        $Message = $Message.Replace($ExtractedDriverLocation,"")
                        $Total = (($Message.Split("-")[0]).Split("of") | Select-Object -Last 1).replace(" ","")
                        [int]$Counter = ((($Message.Split("-")[0]).Split("of") | Select-Object -First 1).replace(" ","")).replace("Installing","")
                        if ([int]$Counter -eq "0"){[int]$Counter = 1}
                        [int]$Total = [int]$Total + 1 #So that when it gets to 3 of 3, it doesn't show 100% complete while it is still installing
                        $PercentComplete = [math]::Round(($Counter / $Total) * 100)
                        Write-Progress -Activity "Applying Drivers" -Status $LastLine -PercentComplete $PercentComplete
                        
                    }
                }
                elseif ($LastLine -match "The operation completed successfully."){
                    Write-Progress -Activity "Migrating Drivers" -Status $LastLine -Completed
                }
                else{
                    Write-Progress -Activity "Migrating Drivers" -Status $LastLine -Completed
                }
            }
        }
        
    }
    until (!(Get-Process -Name DISM -ErrorAction SilentlyContinue))
    exit 0
    
}
