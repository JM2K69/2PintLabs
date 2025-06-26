<#Gary Blok - @gwblok - GARYTOWN.COM

DISCLAIMER: THIS IS NOT AN OFFICIAL DELL SCRIPT. I DO NOT WORK FOR DELL. 
USE AT YOUR OWN RISK. I TAKE NO RESPONSIBILITY FOR ANYTHING THIS SCRIPT DOES. TEST IN A LAB FIRST.
ALL INFORMATION IS PUBLICLY AVAILABLE ON THE INTERNET. I JUST CONSOLIDATED IT INTO ONE SCRIPT.


#https://dl.dell.com/content/manual13608255-dell-command-update-version-5-x-reference-guide.pdf?language=en-us

# Summary of Functions:


#>
#Pull Vars from TS:
Import-Module DeployR.Utility

# Get the provided variables
$updateTypeBIOSFirmware = ${TSEnv:updateTypeBIOSFirmware}
$updateTypeDrivers = ${TSEnv:updateTypeDrivers}
$updateTypeApplications = ${TSEnv:updateTypeApplications}
$ScanOnly = ${TSEnv:ScanOnly}

if ($updateTypeBIOSFirmware -eq "true") {[bool]$updateTypeBIOSFirmware = $true} 
else {[bool]$updateTypeBIOSFirmware = $false}
if ($updateTypeDrivers -eq "true") {[bool]$updateTypeDrivers = $true} 
else {[bool]$updateTypeDrivers = $false}
if ($updateTypeApplications -eq "true") {[bool]$updateTypeApplications = $true} 
else {[bool]$updateTypeApplications = $false}
if ($ScanOnly -eq "true") {[bool]$ScanOnly = $true} 
else {[bool]$ScanOnly = $false}


Write-Host "=============================================================================="
Write-Host "Current DCU Settings selected from Task Sequence" 
    Write-Host "updateTypeBIOSFirmware: $updateTypeBIOSFirmware"
    Write-Host "updateTypeDrivers: $updateTypeDrivers"
    Write-Host "updateTypeApplications: $updateTypeApplications"
    Write-Host "ScanOnly: $ScanOnly"

if ($updateTypeBIOSFirmware-eq $false -and $updateTypeDrivers -eq $false -and $updateTypeApplications -eq $false){
    Write-Host "!!Since no boxes are checked, running all updates!!"
    Write-Host "This is totally logical, ok! It's based on the DCU documentation."
}
Write-Host "=============================================================================="


#region functions
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

Function Get-DCUVersion {
    $DCU=(Get-ItemProperty "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings" -ErrorVariable err -ErrorAction SilentlyContinue)
    if ($err.Count -eq 0) {
        $DCU = $DCU.ProductVersion
    }else{
        $DCU = $false
    }
    return $DCU
}
Function Get-DCUInstallDetails {
    #Declare Variables for Universal app if RegKey AppCode is Universal or if Regkey AppCode is Classic and declares their variables otherwise reports not installed
    If((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Universal"){
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion -ErrorAction SilentlyContinue
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue
        #Add DCU-CLI.exe as Environment Variable for Universal app type
        $DCUPath = 'C:\Program Files\Dell\CommandUpdate\'
    }
    ElseIf((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Classic"){
        
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode
        #Add DCU-CLI.exe as Environment Variable for Classic app type
        $DCUPath = 'C:\Program Files (x86)\Dell\CommandUpdate\'
    }
    Else{
        $DCU =  "DCU is not installed"
    }
    if ($Version){
        $DCU = [PSCustomObject]@{
            Version = $Version
            AppType = $AppType
            DCUPath = $DCUPath
        }
    }
    return $DCU
}



# Run the check


#https://www.dell.com/support/manuals/en-us/command-update/dellcommandupdate_rg/command-line-interface-error-codes?guid=guid-fbb96b06-4603-423a-baec-cbf5963d8948&lang=en-us
Function Get-DCUExitInfo {
    [CmdletBinding()]
    param(
        [ValidateRange(0,4000)]
        [int]$DCUExit
    )
    $DCUExitInfo = @(
        @{ExitCode = 2; Description = "None"; Resolution = "None"}
        # Generic application return codes
        @{ExitCode = 0; Description = "Success"; Resolution = "The operation completed successfully."}
        @{ExitCode = 1; Description = "A reboot was required from the execution of an operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 2; Description = "An unknown application error has occurred."; Resolution = "None"}
        @{ExitCode = 3; Description = "The current system manufacturer is not Dell."; Resolution = "Dell Command | Update can only be run on Dell systems."}
        @{ExitCode = 4; Description = "The CLI was not launched with administrative privilege"; Resolution = "Invoke the Dell Command | Update CLI with administrative privileges"}
        @{ExitCode = 5; Description = "A reboot was pending from a previous operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 6; Description = "Another instance of the same application (UI or CLI) is already running."; Resolution = "Close any running instance of Dell Command | Update UI or CLI and retry the operation."}
        @{ExitCode = 7; Description = "The application does not support the current system model."; Resolution = "Contact your administrator if the current system model in not supported by the catalog."}
        @{ExitCode = 8; Description = "No update filters have been applied or configured."; Resolution = "Supply at least one update filter."}
        # Return codes while evaluating various input validations
        @{ExitCode = 100; Description = "While evaluating the command line parameters, no parameters were detected."; Resolution = "A command must be specified on the command line."}
        @{ExitCode = 101; Description = "While evaluating the command line parameters, no commands were detected."; Resolution = "Provide a valid command and options."}
        @{ExitCode = 102; Description = "While evaluating the command line parameters, invalid commands were detected."; Resolution = "Provide a command along with the supported options for that command"}
        @{ExitCode = 103; Description = "While evaluating the command line parameters, duplicate commands were detected."; Resolution = "Remove any duplicate commands and rerun the command."}
        @{ExitCode = 104; Description = "While evaluating the command line parameters, the command syntax was incorrect."; Resolution = "Ensure that you follow the command syntax: /<command name>. "}
        @{ExitCode = 105; Description = "While evaluating the command line parameters, the option syntax was incorrect."; Resolution = "Ensure that you follow the option syntax: -<option name>."}
        @{ExitCode = 106; Description = "While evaluating the command line parameters, invalid options were detected."; Resolution = "Ensure to provide all required or only supported options."}
        @{ExitCode = 107; Description = "While evaluating the command line parameters, one or more values provided to the specific option was invalid."; Resolution = "Provide an acceptable value."}
        @{ExitCode = 108; Description = "While evaluating the command line parameters, all mandatory options were not detected."; Resolution = "If a command requires mandatory options to run, provide them."}
        @{ExitCode = 109; Description = "While evaluating the command line parameters, invalid combination of options were detected."; Resolution = "Remove any mutually exclusive options and rerun the command."}
        @{ExitCode = 110; Description = "While evaluating the command line parameters, multiple commands were detected."; Resolution = "Except for /help and /version, only one command can be specified in the command line."}
        @{ExitCode = 111; Description = "While evaluating the command line parameters, duplicate options were detected."; Resolution = "Remove any duplicate options and rerun the command"}
        @{ExitCode = 112; Description = "An invalid catalog was detected."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions. "}
        @{ExitCode = 113; Description = "While evaluating the command line parameters, one or more values provided exceeds the length limit."; Resolution = "Ensure to provide the values of the options within the length limit."}
        # Return codes while running the /scan command
        @{ExitCode = 500; Description = "No updates were found for the system when a scan operation was performed."; Resolution = "The system is up to date or no updates were found for the provided filters. Modify the filters and rerun the commands."}
        @{ExitCode = 501; Description = "An error occurred while determining the available updates for the system, when a scan operation was performed."; Resolution = "Retry the operation."}
        @{ExitCode = 502; Description = "The cancellation was initiated, Hence, the scan operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 503; Description = "An error occurred while downloading a file during the scan operation."; Resolution = "Check your network connection, ensure there is Internet connectivity and Retry the command."}
        # Return codes while running the /applyUpdates command
        @{ExitCode = 1000; Description = "An error occurred when retrieving the result of the apply updates operation."; Resolution = "Retry the operation."}
        @{ExitCode = 1001; Description = "The cancellation was initiated, Hence, the apply updates operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 1002; Description = "An error occurred while downloading a file during the apply updates operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        # Return codes while running the /configure command
        @{ExitCode = 1505; Description = "An error occurred while exporting the application settings."; Resolution = "Verify that the folder exists or have permissions to write to the folder."}
        @{ExitCode = 1506; Description = "An error occurred while importing the application settings."; Resolution = "Verify that the imported file is valid."}
        # Return codes while running the /driverInstall command
        @{ExitCode = 2000; Description = "An error occurred when retrieving the result of the Advanced Driver Restore operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2001; Description = "The Advanced Driver Restore process failed."; Resolution = "Retry the operation."}
        @{ExitCode = 2002; Description = "Multiple driver CABs were provided for the Advanced Driver Restore operation."; Resolution = "Ensure that you provide only one driver CAB file."}
        @{ExitCode = 2003; Description = "An invalid path for the driver CAB was provided as in input for the driver install command."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions"}
        @{ExitCode = 2004; Description = "The cancellation was initiated, Hence, the driver install operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 2005; Description = "An error occurred while downloading a file during the driver install operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        @{ExitCode = 2006; Description = "Indicates that the Advanced Driver Restore feature is disabled."; Resolution = "Enable the feature using /configure -advancedDriverRestore=enable"}
        @{ExitCode = 2007; Description = "Indicates that the Advanced Diver Restore feature is not supported."; Resolution = "Disable FIPS mode on the system."}
        # Return codes while evaluating the inputs for password encryption
        @{ExitCode = 2500; Description = "An error occurred while encrypting the password during the generate encrypted password operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2501; Description = "An error occurred while encrypting the password with the encryption key provided."; Resolution = "Provide a valid encryption key and Retry the operation. "}
        @{ExitCode = 2502; Description = "The encrypted password provided does not match the current encryption method."; Resolution = "The provided encrypted password used an older encryption method. Reencrypt the password."}
        # Return codes if there are issues with the Dell Client Management Service
        @{ExitCode = 3000; Description = "The Dell Client Management Service is not running."; Resolution = "Start the Dell Client Management Service in the Windows services if stopped."}
        @{ExitCode = 3001; Description = "The Dell Client Management Service is not installed."; Resolution = "Download and install the Dell Client Management Service from the Dell support site."}
        @{ExitCode = 3002; Description = "The Dell Client Management Service is disabled."; Resolution = "Enable the Dell Client Management Service from Windows services if disabled."}
        @{ExitCode = 3003; Description = "The Dell Client Management Service is busy."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3004; Description = "The Dell Client Management Service has initiated a self-update install of the application."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3005; Description = "The Dell Client Management Service is installing pending updates."; Resolution = "Wait until the service is available to process new requests."}
    )
    $DCUExitInfo | Where-Object {$_.ExitCode -eq $DCUExit}
}
#https://www.dell.com/support/kbdoc/en-us/000148745/dup-bios-updates
Function Get-DUPExitInfo {
    [CmdletBinding()]
    param(
        [ValidateRange(0,4000)]
        [int]$DUPExit
    )
    $DUPExitInfo = @(
        # Generic application return codes
        @{ExitCode = -1; DisplayName = "Unsuccessful"; Description = "DCU terminating the BIOS execution due to timeout."}
        @{ExitCode = 0; DisplayName = "Success"; Description = "The operation completed successfully."}
        @{ExitCode = 1; DisplayName = "Unsuccessful"; Description = "An error occurred during the update process; the update was not successful."}
        @{ExitCode = 2; DisplayName = "Reboot required"; Description = "Reboot the system to complete the operation."}
        @{ExitCode = 3; DisplayName = "Soft dependency error"; Description = "You attempted to update to the same version of the software or You tried to downgrade to a previous version of the software."}
        @{ExitCode = 4; DisplayName = "Hard dependency error"; Description = "The required prerequisite software was not found on your computer."}
        @{ExitCode = 5; DisplayName = "Qualification error"; Description = "A QUAL_HARD_ERROR cannot be suppressed by using the /f switch."}
        @{ExitCode = 6; DisplayName = "Rebooting computer"; Description = "The computer is being rebooted."}
        @{ExitCode = 7; DisplayName = "Password validation error"; Description = "Password not provided or incorrect password provided for BIOS execution"}
        @{ExitCode = 8; DisplayName = "Requested Downgrade is not allowed."; Description = "Downgrading the BIOS to the version run is not allowed."}
        @{ExitCode = 8; DisplayName = "RPM verification has failed"; Description = "The Linux DUP framework uses RPM verification to ensure the security of all DUP-dependent Linux utilities. If security is compromised, the framework displays a message and an RPM Verify Legend, and then exits with exit code 9."}
        @{ExitCode = 8; DisplayName = "Some other error"; Description = "This exit code is for all errors that have not been specified in BIOS exit codes 0-9. That is, battery error, EC error, HW failure, so forth."}
        )
    $DUPExitInfo | Where-Object {$_.ExitCode -eq $DUPExit}
}

Function Get-DCUAppUpdates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [switch]$Latest,
        [switch]$Install,
        [switch]$UseWebRequest
    )
    
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    $temproot = "$env:windir\temp"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    
    $Apps = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType application | Select-Object -Property PackageID, Name, ReleaseDate, DellVersion, VendorVersion, Path
    $CommandUpdateApps = $Apps | Where-Object {$_.Name -like "*Command | Update*"} | Sort-Object -Property VendorVersion
    $CommandUpdateAppsLatest = $CommandUpdateApps | Select-Object -Last 1
    if ($CommandUpdateAppsLatest){
        if ($Install){
            [Version]$DCUVersion = $CommandUpdateAppsLatest.vendorVersion
            Write-Output "Found DCU Version $DCUVersion"
            $DCUVersionInstalled = Get-DCUVersion
            If ($DCUVersionInstalled -ne $false){[Version]$CurrentVersion = $DCUVersionInstalled}
            Else {[Version]$CurrentVersion = 0.0.0.0}
            if ($DCUVersion -gt $CurrentVersion){
                $temproot = "$env:windir\temp"
                $DellCabDownloadsPath = "$temproot\DellCabDownloads"
                if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
                $LogFilePath = "$env:ProgramData\EMPS\Logs"
                $TargetFileName = ($CommandUpdateAppsLatest.path).Split("/") | Select-Object -Last 1
                $TargetLink = $CommandUpdateAppsLatest.path
                $TargetFilePathName = "$($DellCabDownloadsPath)\$($TargetFileName)"
                if ($UseWebRequest){
                    Write-Output "Using WebRequest to download the file"
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                else{
                    Write-Output "Using BITS to download the file"
                    Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Description "Downloading Dell Command Update" -ErrorAction SilentlyContinue
                }
                
                if (!(Test-Path $TargetFilePathName)){
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                #Confirm Download
                if (Test-Path $TargetFilePathName){
                    $LogFileName = ($TargetFilePathName.replace(".exe",".log")).Replace(".EXE",".log")
                    $Arguments = "/s /l=$LogFileName"
                    Write-Output "Starting DCU Install"
                    write-output "Log file = $LogFileName"
                    $Process = Start-Process "$TargetFilePathName" $Arguments -Wait -PassThru
                    write-output "Update Complete with Exitcode: $($Process.ExitCode)"
                    If($Process -ne $null -and $Process.ExitCode -eq '2'){
                        Write-Verbose "Reboot Required"
                    }
                }
                else{
                    Write-Verbose " FAILED TO DOWNLOAD DCU"
                }
            }
            else{
                Write-Output "Installed DCU: $CurrentVersion, Skipping Install"

            }
        }
        else{
            if ($Latest){
                Return $CommandUpdateAppsLatest
            }
            else{
                return $CommandUpdateApps
            }
        }
    }
    else{
        return "No DCU Found"
    }

}


function Invoke-DCU {
    [CmdletBinding()]
    
    param (

    #[ValidateSet('bios','firmware','driver','application','others')]
    #[String[]]$updateType,
    [ValidateSet('audio','video','network','chipset','storage','input','others')]
    [String[]]$updateDeviceCategory,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$reboot = 'Disable',
    [ValidateSet('Enable','Disable')]
    [string]$forceupdate = 'Disable',
    [switch]$updateTypeBIOSFirmware,
    [switch]$updateTypeDrivers,
    [Switch]$updateTypeApplications,
    [switch]$ScanOnly
    )
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    #$LogPath = "$env:SystemDrive\Users\Dell\EMPS\Logs"
    $LogPath = "$env:SystemDrive\_2P\Logs"
    #Build Argument Strings for each parameter
    if ($updateSeverity){
        [String]$updateSeverity = $($updateSeverity -join ",").ToString()
        $updateSeverityVar = "-updateSeverity=$updateSeverity"
    }
    if (get-variable | Where-Object {$_.Name -match "updateType" -and $_.Value -eq $true}){
        $updateTypeVar = "-updateType=`""
        if ($updateTypeBIOSFirmware){
            $updateTypeVar += "bios,"
            $updateTypeVar += "firmware,"
        }
        if ($updateTypeDrivers){
            $updateTypeVar += "driver,"
        }
        if ($updateTypeApplications){
            $updateTypeVar += "application,"
        }
        if ($updateType -and $updateType -ne 'others'){
            $updateTypeVar += ($updateType -join ",") + ","
        }
        $updateTypeVar = $updateTypeVar.TrimEnd(",")
        $updateTypeVar += "`""
    }
    else {
        $updateTypeVar = ""
    }

    if ($updateDeviceCategory){
        [String]$updateDeviceCategory = $($updateDeviceCategory -join ",").ToString()
        $updateDeviceCategoryVar = "-updateDeviceCategory=$updateDeviceCategory"
    }

    #Pick Action, Scan or ApplyUpdates if both are selected, ApplyUpdates will be the action, if neither are selected, Scan will be the action
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if ($scanOnly){
        $ActionVar = "/scan -report=$LogPath"
        $Action = "Scan"
    }
    else{
        $ActionVar = "/applyUpdates"
        $Action = "ApplyUpdates"
    }
    

    #Create Arugment List for Dell Command Update CLI
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`""
    Write-Verbose $ArgList
    $DCUApply = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
    if ($DCUApply.ExitCode -ne 0){
        $ExitInfo = Get-DCUExitInfo -DCUExit $DCUApply.ExitCode
        Write-Verbose "Exit: $($DCUApply.ExitCode)"
        Write-Verbose "Description: $($ExitInfo.Description)"
        Write-Verbose "Resolution: $($ExitInfo.Resolution)"
    }
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

#Future Enahncements, see if I can add a column for the OS's that Dell Supports on the specific hardware model - This assumes they releases driver packs for the OS supported.
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

#Add feature to download the driver pack, and have it default to the OS of the device it's running on, or allow the user to specify the OS they want to download the driver pack for.
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

#Function to get a list of BIOS updates for a SKU, install, or download
#Similar to the Get-HPBIOSUpdate function in HPCMSL
Function Get-DellBIOSUpdates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [switch]$Latest,
        [switch]$Check, #This will find the latest BIOS update and compare it to the current BIOS version
        [switch]$Flash,
        [string]$Password,
        [string]$DownloadPath

    )
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems, or please provide a SKU"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    
    if ($Check){
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        else{
            [Version]$CurrentBIOSVersion = (Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion
            $LatestBIOS = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest | Sort-Object -Property ReleaseDate -Descending
            if ($LatestBIOS.count -gt 1){
                $LatestBIOS = $LatestBIOS | Select-Object -First 1
            }
            [version]$LatestVersion = ($LatestBIOS).DellVersion

            if ($CurrentBIOSVersion -lt $LatestVersion){
                Write-Verbose "Current BIOS Version: $CurrentBIOSVersion"
                Write-Verbose "Latest BIOS Version: $LatestVersion"
                Write-Verbose "New BIOS Update Available"
                return $false
            }
            else {
                Write-Verbose "Current BIOS Version: $CurrentBIOSVersion"
                Write-Verbose "Latest BIOS Version: $LatestVersion"
                Write-Verbose "No New BIOS Update Available"
                return $true
            }
        }
    }
    if ($Flash){
        #Test for Bitlocker
        $BitlockerStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive
        if ($BitlockerStatus -ne $null){
            if ($BitlockerStatus.ProtectionStatus -eq "On"){
                Write-Host "Bitlocker is On, Please Suspend Bitlocker before Flashing BIOS"
                return
            }
        }
        #https://www.dell.com/support/kbdoc/en-us/000136752/command-line-switches-for-dell-bios-updates
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
        $Update = $Updates | Select-Object -First 1
        $UpdatePath = $Update.Path
        $UpdateFileName = $UpdatePath -split "/" | Select-Object -Last 1
        $UpdateLocalPath = "$env:windir\temp\$UpdateFileName"
        Start-BitsTransfer -DisplayName $UpdateFileName -Source $UpdatePath -Destination $UpdateLocalPath -Description "Downloading $UpdateFileName" -RetryInterval 60 #-CustomHeaders "User-Agent:Bob" 
        if (Test-Path -Path $UpdateLocalPath){
            Write-Host "Installing $UpdateFileName, logfile: $($UpdateLocalPath).log"
            if ($Password){
                $BIOSArgs = "/s /l=$UpdateLocalPath.log /p=$Password"
            }
            else {
                $BIOSArgs = "/s /l=$UpdateLocalPath.log"
            }
            $InstallUpdate = Start-Process -FilePath $UpdateLocalPath -ArgumentList $BIOSArgs -Wait -PassThru
            Write-Host "Exit Code: $($InstallUpdate.ExitCode)"
            if ($InstallUpdate.ExitCode -ne 0){
                $ExitInfo = Get-DUPExitInfo -DUPExit $InstallUpdate.ExitCode
                Write-Host "Exit: $($InstallUpdate.ExitCode)"
                Write-Host "Code Name: $($ExitInfo.DisplayName)"
                Write-Host "Description: $($ExitInfo.Description)"
            }
            return
        }
        else {
            Write-Host "File Not Found: $UpdateFileName"
            return
        }
    }
    if ($DownloadPath){
        [void][System.IO.Directory]::CreateDirectory($DownloadPath)
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
        $Update = $Updates | Select-Object -First 1
        $UpdatePath = $Update.Path
        $UpdateFileName = $UpdatePath -split "/" | Select-Object -Last 1
        $UpdateLocalPath = "$DownloadPath\$UpdateFileName"
        Start-BitsTransfer -DisplayName $UpdateFileName -Source $UpdatePath -Destination $UpdateLocalPath -Description "Downloading $UpdateFileName" -RetryInterval 60 #-CustomHeaders "User-Agent:Bob"
        return $UpdateLocalPath
    }
    if ($Latest){
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
    }
    else {
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS
    }
    return $Updates |Select-Object -Property "PackageID","Name","ReleaseDate","DellVersion" | Sort-Object -Property ReleaseDate -Descending
}
# Function to check for Windows Desktop Runtime
function Test-WindowsDesktopRuntime {
    # Registry paths where .NET Runtime info is typically stored
    $registryPaths = @(
        "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App",
        "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x86\sharedfx\Microsoft.WindowsDesktop.App"
    )

    $runtimesFound = $false
    $installedVersions = @()

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            # Get all version subkeys
            $versions = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | 
                ForEach-Object { $_.PSChildName }
            
            foreach ($version in $versions) {
                $runtimesFound = $true
                $installedVersions += $version
            }
        }
    }

    # Check via Get-WmiObject as alternative method
    $wmiApps = Get-WmiObject -Class Win32_Product | 
        Where-Object { $_.Name -like "*Microsoft Windows Desktop Runtime*" }

    if ($wmiApps) {
        $runtimesFound = $true
        $wmiVersions = $wmiApps | ForEach-Object { 
            [PSCustomObject]@{
                Version = $_.Version
                Name = $_.Name
            }
        }
        $installedVersions += $wmiVersions
    }

    # Output results
    if ($runtimesFound) {
        Write-Host "Microsoft Windows Desktop Runtime is installed." -ForegroundColor Green
        Write-Host "Found versions:"
        $installedVersions | Sort-Object -Unique | ForEach-Object {
            if ($_ -is [PSCustomObject]) {
                Write-Host "- $($_).Name ($($_).Version)"
            }
            else {
                Write-Host "- Version $_"
            }
        }
    }
    else {
        Write-Host "Microsoft Windows Desktop Runtime is not installed." -ForegroundColor Red
    }

    return $runtimesFound
}
#endregion functions

# Do the Stuff

$DCU = Get-DCUAppUpdates -Latest

#Write-Host "=============================================================================="
Write-Host "Check for Desktop Runtime Dependencies"
$RunTimeInstalled = Test-WindowsDesktopRuntime

if (!$RunTimeInstalled) {
    Write-Host "Microsoft Windows Desktop Runtime is not installed, please install it before running Dell Command Update" -ForegroundColor Red
    exit 1
}

Write-Host "Installing Dell Command Update"
$DCU

try {
    Get-DCUAppUpdates -Install -Verbose
    Write-Host "Dell Command Update Installed Successfully"
    $DCUVersion = Get-DCUVersion
    Write-Host "Dell Command Update Version: $DCUVersion"
}
catch {
    Write-Host "One More Try to Install Dell Command Update"
    Get-DCUAppUpdates -Install -UseWebRequest -Verbose
}

if ((Get-DCUVersion) -eq "false"){
    Write-Host "Dell Command Update is not getting installed, do some extra testing.."
    exit ($DCU.VendorVersion).replace(".","")
}
else {

    Write-Host "=============================================================================="
    Write-Host "Invoke Dell Command Update"
    write-host "Invoke-DCU -updateTypeBIOSFirmware:$updateTypeBIOSFirmware -updateTypeDrivers:$updateTypeDrivers -updateTypeApplications:$updateTypeApplications -ScanOnly:$ScanOnly"
    Invoke-DCU -updateTypeBIOSFirmware:$updateTypeBIOSFirmware -updateTypeDrivers:$updateTypeDrivers -updateTypeApplications:$updateTypeApplications -ScanOnly:$ScanOnly
    Write-Host "Run Dell Command Update Step Complete"
    Write-Host "=============================================================================="
}

