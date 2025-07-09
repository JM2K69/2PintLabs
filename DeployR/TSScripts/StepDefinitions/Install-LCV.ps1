#Pull Vars from TS:
Import-Module DeployR.Utility
$LogPath = "$env:SystemDrive\_2P\Logs"

# Get the provided variables
$WarrantyInfoHide = ${TSEnv:LCVWarrantyInfoHide}
$MyDevicePageHide = ${TSEnv:LCVMyDevicePageHide}
$WiFiSecurityPageHide = ${TSEnv:LCVWiFiSecurityPageHide}
$HardwareScanPageHide = ${TSEnv:LCVHardwareScanPageHide}
$GiveFeedbackPageHide = ${TSEnv:LCVGiveFeedbackPageHide}
$TurnOffMicrophoneSettings = ${TSEnv:LCVTurnOffMicrophoneSettings}

function Install-LenovoVantage {
    [CmdletBinding()]
    param (
        [switch]$IncludeSUHelper = $true
    )
    # Define the URL and temporary file path - https://support.lenovo.com/us/en/solutions/hf003321-lenovo-vantage-for-enterprise
    #$url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2401.29.0.zip"
    $url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2501.15.0_v3.zip"
    $tempFilePath = "C:\Windows\Temp\lenovo_vantage.zip"
    $tempExtractPath = "C:\Windows\Temp\LenovoVantage"
    # Create a new BITS transfer job
    $bitsJob = Start-BitsTransfer -Source $url -Destination $tempFilePath -DisplayName "Downloading to $tempFilePath"

    # Wait for the BITS transfer job to complete
    while ($bitsJob.JobState -eq "Transferring") {
        Start-Sleep -Seconds 2
    }

    # Check if the transfer was successful
    if (Test-Path -Path $tempFilePath) {
        # Start the installation process
        Write-Host -ForegroundColor Green "Installation file downloaded successfully. Starting installation..."
        Write-Host -ForegroundColor Cyan " Extracting $tempFilePath to $tempExtractPath"
        if (test-path -path $tempExtractPath) {Remove-Item -Path $tempExtractPath -Recurse -Force}
        Expand-Archive -Path $tempFilePath -Destination $tempExtractPath

    } else {
        Write-Host "Failed to download the file."
        return
    }

    #Lenovo Vantage Service
    Write-Host -ForegroundColor Cyan " Installing Lenovo Vantage Service..."
    Invoke-Expression -command "$tempExtractPath\VantageService\Install-VantageService.ps1"

    #Lenovo Vantage Batch File
    write-host -ForegroundColor Cyan " Installing Lenovo Vantage...batch file..."
    $ArgumentList = "/c $($tempExtractPath)\setup-commercial-vantage.bat"
    $InstallProcess = Start-Process -FilePath "cmd.exe" -ArgumentList $ArgumentList -Wait -PassThru
    if ($InstallProcess.ExitCode -eq 0) {
        Write-Host -ForegroundColor Green "Lenovo Vantage completed successfully."
        $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
        New-Item -Path $RegistryPath -ItemType Directory -Force |Out-Null
        New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
    } else {
        Write-Host -ForegroundColor Red "Lenovo Vantage failed with exit code $($InstallProcess.ExitCode)."
    }

    if ($IncludeSUHelper){
        $InstallProcess = Start-Process -FilePath $tempExtractPath\SystemUpdate\SUHelperSetup.exe -ArgumentList "/VERYSILENT /NORESTART" -Wait -PassThru
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Host -ForegroundColor Green "Lenovo SU Helper completed successfully."
        } else {
            Write-Host -ForegroundColor Red "Lenovo SU Helper failed with exit code $($InstallProcess.ExitCode)."
        }
    }
}


function Set-LenovoVantage {
    [CmdletBinding()]
    param (
        [ValidateSet('True','False')]
        [string]$AcceptEULAAutomatically = 'True',
        [ValidateSet('True','False')]
        [string]$WarrantyInfoHide,
        [ValidateSet('True','False')]
        [string]$WarrantyWriteWMI = 'True',
        [ValidateSet('True','False')]
        [string]$MyDevicePageHide,
        [ValidateSet('True','False')]
        [string]$WiFiSecurityPageHide,
        [ValidateSet('True','False')]
        [string]$HardwareScanPageHide,
        [ValidateSet('True','False')]
        [string]$GiveFeedbackPageHide,
        [ValidateSet('True','False')]
        [string]$TurnOffMicrophoneSettings = 'True'    
    )

    
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    # Check if Lenovo Vantage is installed
    if (Test-Path "C:\Program Files (x86)\Lenovo\VantageService") {
        #Write-Host "Lenovo Vantage is already installed."
    } else {
        Write-Host "Lenovo Vantage is not installed. Installing..."
        Install-LenovoVantage
    }
    # Check if the registry path exists
    if (Test-Path $RegistryPath) {
        #Write-Host "Registry path already exists"
    } else {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    
    # Set the registry values
    if ($AcceptEULAAutomatically) {
        if ($AcceptEULAAutomatically -eq $true){
            Write-Host "Setting AcceptEULAAutomatically to 1"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AcceptEULAAutomatically to 0"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($WarrantyInfoHide) {
        if ($WarrantyInfoHide -eq $true){
            Write-Host "Setting WarrantyInfoHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyInfoHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($WarrantyWriteWMI) {
        if ($WarrantyWriteWMI -eq $true){
            Write-Host "Setting WarrantyWriteWMI to 1"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyWriteWMI to 0"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($MyDevicePageHide) {
        if ($MyDevicePageHide -eq $true){
            Write-Host "Setting MyDevicePageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting MyDevicePageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($WiFiSecurityPageHide) {
        if ($WiFiSecurityPageHide -eq $true){
            Write-Host "Setting WiFiSecurityPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WiFiSecurityPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($HardwareScanPageHide) {
        if ($HardwareScanPageHide -eq $true){
            Write-Host "Setting HardwareScanPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting HardwareScanPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($GiveFeedbackPageHide) {
        if ($GiveFeedbackPageHide -eq $true){
            Write-Host "Setting GiveFeedbackPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting GiveFeedbackPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($TurnOffMicrophoneSettings) {
        if ($TurnOffMicrophoneSettings -eq $true){
            Write-Host "Setting TurnOffMicrophoneSettings to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.device-settings.audio.microphone-settings" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting TurnOffMicrophoneSettings to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.device-settings.audio.microphone-settings" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }   
}

Install-LenovoVantage
Set-LenovoVantage -AcceptEULAAutomatically $true `
    -WarrantyInfoHide $WarrantyInfoHide `
    -WarrantyWriteWMI $true `
    -MyDevicePageHide $MyDevicePageHide `
    -WiFiSecurityPageHide $WiFiSecurityPageHide `
    -HardwareScanPageHide $HardwareScanPageHide `
    -GiveFeedbackPageHide $GiveFeedbackPageHide


