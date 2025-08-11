# Download & Install Panasonic PCHub

try {Import-Module DeployR.Utility}
catch {}


if (Get-Module -name DeployR.Utility){
    [String]$InstallFromCloud = ${TSEnv:InstallFromCloud}
    [String]$TargetSystemDrive = ${TSEnv:OSDTARGETSYSTEMDRIVE}    
}
else {
    [String]$TargetSystemDrive = "C:"
    [String]$InstallFromCloud = "True"
}

#PCHub Installer URL
$URL = 'https://dl-pc-support.connect.panasonic.com/public/soft_first/store_app/mei-ppchubinstaller-3.1.1100.0-w10w11-nologo-Multi-d20254311.exe'
$DownloadContentPath = "$TargetSystemDrive\_2P\content\PCHub"

#Report the variables
Write-Host "==================================================================="
Write-Host "Panasonic PCHub Installation Script"
Write-Host "Reporting Variables:"
Write-Host "InstallFromCloud: $InstallFromCloud"
Write-Host "TargetSystemDrive: $TargetSystemDrive"
Write-Host "PCHub Installer URL: $URL"
Write-Host "Download Content Path: $DownloadContentPath"
Write-Host "==================================================================="


#region functions

function Get-InstalledApps
{
    if (![Environment]::Is64BitProcess) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

#endregion


$PCHubInstalled = Get-InstalledApps | Where-Object { $_.DisplayName -like "*Panasonic PCHub*" }
if ($PCHubInstalled) {
    Write-Host "Panasonic PCHub is already installed. Skipping installation." -ForegroundColor Green
    
}
else {
    Write-Host "Panasonic PCHub is not installed." -ForegroundColor Yellow
    
    if ($InstallFromCloud -eq "True") {
        Write-Host "Option to Install from Cloud is enabled, continuing with download..." -ForegroundColor Cyan
        
        if (!(Test-Path -Path $DownloadContentPath)) {
            New-Item -ItemType Directory -Path $DownloadContentPath -Force | Out-Null
        }
        try {
            $destFile = Request-DeployRCustomContent -ContentName "PCHub" -ContentFriendlyName "PCHub" -URL $URL -DestinationPath $DownloadContentPath -ErrorAction SilentlyContinue
            $GetItemOutFile = Get-Item $destFile
        }
        catch {
            Start-BitsTransfer -Source $URL -Destination $DownloadContentPath -ErrorAction Stop
            $GetItemOutFile = Get-ChildItem -Path $DownloadContentPath -Filter "*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        
        if ($GetItemOutFile -and $GetItemOutFile.Exists) {
            Write-Host "PCHub Installer downloaded to $DownloadContentPath"
        } else {
            Write-Host "Failed to download PCHub Installer from $URL" -ForegroundColor Red
            exit 1
        }
        
        Start-Process -FilePath $GetItemOutFile.FullName -ArgumentList "-silent" -Wait -NoNewWindow -PassThru

        #Get the Subdirectory in c:\util2
        Write-Host "Checking for Panasonic PCHub installation in C:\util2"  
        $util2SubDirs = Get-ChildItem -Path "C:\util2" -Directory -ErrorAction SilentlyContinue
        if ($util2SubDirs) {
            Write-Host "Found the following subdirectories in C:\util2:" -ForegroundColor Green
            $util2SubDirs | ForEach-Object {
                Write-Host "  - $($_.Name)"
                Move-Item -Path $_.FullName -Destination "$DownloadContentPath\$($_.Name)" -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "No subdirectories found in C:\util2 or directory does not exist" -ForegroundColor Yellow
        }

        # Search for Setup.exe in the DownloadContentPath
        $setupFile = Get-ChildItem -Path $DownloadContentPath -Filter "Setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($setupFile) {
            Set-Location -Path $setupFile.DirectoryName
            Start-Process -FilePath $setupFile.FullName -ArgumentList "-s" -Wait -NoNewWindow -PassThru
        }
    }
    else {
        Write-Host "Option to Install from Cloud is disabled, skipping download." -ForegroundColor Yellow
        Write-Host "Please ensure Panasonic PCHub is installed manually." -ForegroundColor Red
        exit 1
    }
}

