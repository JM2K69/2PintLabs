#Ensure Several things are installed, as well as configurations are done to help troubleshoot DeployR installations

#PowerShell Table of Pre-Req Applications:
$PreReqApps = @(
    [PSCustomObject]@{Title = 'Microsoft .NET Runtime'; Installed = $false}
    [PSCustomObject]@{Title = 'Microsoft Windows Desktop Runtime'; Installed = $false}
    [PSCustomObject]@{Title = 'Microsoft ASP.NET Core'; Installed = $false}
    [PSCustomObject]@{Title = 'Windows Assessment and Deployment Kit'; Installed = $false}
    [PSCustomObject]@{Title = 'Windows Assessment and Deployment Kit Windows Preinstallation Environment'; Installed = $false}
    [PSCustomObject]@{Title = 'PowerShell 7-x64'; Installed = $false}
    [PSCustomObject]@{Title = 'Microsoft SQL Server'; Installed = $false}
    [PSCustomObject]@{Title = 'SQL Server Management Studio'; Installed = $false}
    [PSCustomObject]@{Title = '2Pint Software DeployR'; Installed = $false}
    [PSCustomObject]@{Title = '2Pint Software StifleR Server'; Installed = $false}
    [PSCustomObject]@{Title = '2Pint Software StifleR Dashboards'; Installed = $false}
    [PSCustomObject]@{Title = '2Pint Software StifleR WmiAgent'; Installed = $false}
)


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
function Test-Url {
    param (
        [string]$Url
    )
    
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"  # Uses HEAD to check status without downloading content
        $request.Timeout = 5000   # 5 second timeout
        
        $response = $request.GetResponse()
        $status = [int]$response.StatusCode
        
        if ($status -eq 200) {
            #Write-Output "URL is active: $Url"
            return $true
        }
        else {
            #Write-Output "URL responded with status code $status $Url"
            return $false
        }
        $response.Close()
    }
    catch {
        Write-Output "URL is not accessible: $Url - Error: $_"
    }
}
function Test-SQLConnection {
    param(
    [Parameter(Mandatory=$true)]
    [string]$ConnectionString
)

try {
    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $connection.Open()
    Write-Host "Connection successful!" -ForegroundColor Green
    $connection.Close()
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
}
}


# Executing Script
Write-Host "=========================================================================" -ForegroundColor DarkGray
#Test if Applications are installed
$installedApps = Get-InstalledApps
Write-Host "Checking for Pre-Requisite Applications..." -ForegroundColor Cyan
foreach ($app in $PreReqApps) {
    $found = $installedApps | Where-Object { 
        $_.DisplayName -match [regex]::Escape($app.Title) -or
        $_.DisplayName -like "*$($app.Title)*"
    }
    
    if ($found) {
        $app.Installed = $true
        New-Variable -Name "Installed_$($app.Title.Replace(' ', '_'))" -Value $true -Scope Global -Force
    }
    else {
        New-Variable -Name "Installed_$($app.Title.Replace(' ', '_'))" -Value $false -Scope Global -Force
    }
}

# Display results
$PreReqApps | Format-Table -AutoSize
Write-Host "=========================================================================" -ForegroundColor DarkGray
write-Host "Checking for Services..." -ForegroundColor Cyan
#Test Services if App Installed
#Test SQL Express
if ($Installed_Microsoft_SQL_Server){
    $SQLService = Get-Service -Name 'MSSQL$SQLEXPRESS'
    if ($SQLService.Status -eq 'Running') {
        Write-Host "Microsoft SQL Server service is running." -ForegroundColor Green
        $Global:SQLServiceRunning = $true
    }
    else {
        Write-Host "Microsoft SQL Server service is NOT running." -ForegroundColor Red
        $Global:SQLServiceRunning = $false
    }
}
#Test StifleR Service
if ($Installed_2Pint_Software_StifleR_Server){
    $StifleRService = Get-Service -Name '2Pint Software StifleR Server'
    if ($StifleRService.Status -eq 'Running') {
        Write-Host "2Pint StifleR Server service is running." -ForegroundColor Green
        $Global:StifleRServiceRunning = $true
    }
    else {
        Write-Host "2Pint StifleR Server service is NOT running." -ForegroundColor Red
        $Global:StifleRServiceRunning = $false
    }
}
#Test DeployR Service
if ($Installed_2Pint_Software_DeployR){
    $DeployRService = Get-Service -Name '2Pint Software DeployR Service'
    if ($DeployRService.Status -eq 'Running') {
        Write-Host "2Pint DeployR service is running." -ForegroundColor Green
        $Global:DeployRServiceRunning = $true
    }
    else {
        Write-Host "2Pint DeployR service is NOT running." -ForegroundColor Red
        $Global:DeployRServiceRunning = $false
    }
}

#Confirm StifleR Registry Settings
if ($Installed_2Pint_Software_StifleR_Server){
    Write-Host "=========================================================================" -ForegroundColor DarkGray
    Write-Host "Testing StifleR Registry Settings..." -ForegroundColor Cyan
    $StifleRRegPath = "HKLM:\SOFTWARE\2Pint Software\StifleR\Server\GeneralSettings"
    $StifleRRegData = Get-ItemProperty -Path $StifleRRegPath -ErrorAction SilentlyContinue

    if ($StifleRRegData -and $StifleRRegData.DeployRUrl) {
        Write-Host "DeployR API URL: $($StifleRRegData.DeployRUrl)" -ForegroundColor Green
    }
    else {
        Write-Host "DeployR API URL is NOT configured." -ForegroundColor Red
    }
    $StifleRCertThumbprint = $StifleRRegData.WSCertificateThumbprint
    Write-Host "Stifle R Using Certificate with Thumbprint: $($StifleRCertThumbprint)" -ForegroundColor Cyan
    #Get Certificate from Local Machine Store that matches
    $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My  | Where-Object { $_.Thumbprint -match $StifleRCertThumbprint }
    if ($CertThumbprint) {
        Write-Host "Found certificate in local store: $($CertThumbprint.Thumbprint)" -ForegroundColor Green
    }
    else {
        Write-Host "Certificate NOT found." -ForegroundColor Red
    }
}

#Confirm DeployR Registry Settings
if ($Installed_2Pint_Software_DeployR){
    Write-Host "=========================================================================" -ForegroundColor DarkGray
    
    $RegPath = "HKLM:\SOFTWARE\2Pint Software\DeployR\GeneralSettings"
    $DeployRRegData = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue

    if ($DeployRRegData -and $DeployRRegData.ConnectionString) {
        Write-Host "Testing SQL Connection... " -ForegroundColor Cyan
        write-host " $($DeployRRegData.ConnectionString)"
        Test-SQLConnection -ConnectionString $DeployRRegData.ConnectionString
    }
    Write-Host "=========================================================================" -ForegroundColor DarkGray
    Write-Host "Testing DeployR Certificate..." -ForegroundColor Cyan
    #Test Certificate
    $CertThumbprintRegValue = $DeployRRegData.CertificateThumbprint
    Write-Host "Deploy R Using Certificate with Thumbprint: $($CertThumbprintRegValue)" -ForegroundColor Cyan
    #Get Certificate from Local Machine Store that matches
    $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My  | Where-Object { $_.Thumbprint -match $CertThumbprintRegValue }
    if ($CertThumbprint) {
        Write-Host "Found certificate in local store: $($CertThumbprint.Thumbprint)" -ForegroundColor Green
    }
    else {
        Write-Host "Certificate NOT found." -ForegroundColor Red
    }
Write-Host "=========================================================================" -ForegroundColor DarkGray
    #Test StifleR Server URL
    Write-Host "Testing Network Connections..." -ForegroundColor Cyan
    #StifleR Server URL = $DeployRRegData.StifleRServerApiUrl without Port Number
    $StifleRServerURL = $DeployRRegData.StifleRServerApiUrl
    $StifleRServerURL = $StifleRServerURL.Split(':')[0..1] -join ':'
    $StifleRServerName = $StifleRServerURL.Split('/')[2]
    $DeployRURL = $DeployRRegData.ClientURL
    $DeployRURL = $DeployRURL.Split(':')[0..1] -join ':'
    $DeployRServerName = $DeployRURL.Split('/')[2]



    Write-Host "Testing StifleR Server URL... $($StifleRServerURL)" -ForegroundColor Cyan
    $StifleRTest = Test-Url -Url $StifleRServerURL
    if ($StifleRTest) {
        Write-Host "StifleR Server URL is accessible." -ForegroundColor Green
        $Test443 = Test-NetConnection -ComputerName $StifleRServerName -Port 443
        if ($Test443) {
            Write-Host "StifleR Server Port 443 is accessible." -ForegroundColor Green
        }
        $Test9000 = Test-NetConnection -ComputerName $StifleRServerName -Port 9000
        if ($Test9000) {
            Write-Host "StifleR Server Port 9000 is accessible." -ForegroundColor Green
        }
    }
    else {
        Write-Host "StifleR Server URL is NOT accessible." -ForegroundColor Red
    }
    Write-Host "Testing DeployR Server URL... $($DeployRURL)" -ForegroundColor Cyan
    $DeployRTest = Test-Url -Url $DeployRURL
    if ($DeployRTest) {
        Write-Host "DeployR Server URL is accessible." -ForegroundColor Green
        $Test7281 = Test-NetConnection -ComputerName $DeployRServerName -Port 7281
        if ($Test7281) {
            Write-Host "DeployR Server Port 7281 is accessible." -ForegroundColor Green
        }
        $Test7282 = Test-NetConnection -ComputerName $DeployRServerName -Port 7282
        if ($Test7282) {
            Write-Host "DeployR Server Port 7282 is accessible." -ForegroundColor Green
        }
    }
    else {
        Write-Host "DeployR Server URL is NOT accessible." -ForegroundColor Red
    }

}
Write-Host "=========================================================================" -ForegroundColor DarkGray
write-host "Checking Certificate... on Ports 443 & 9000" -ForegroundColor Cyan
# Get the certificate hash from the HTTP.SYS binding for port 443
$certHash = netsh http show sslcert ipport=0.0.0.0:443 | Select-String "Certificate Hash" | ForEach-Object { ($_ -split ": ")[1].Trim() }

if ($certHash) {
    Write-Host  "Certificate Thumbprint for HTTPS (port 443): $certHash" -ForegroundColor Green
    if ($certHash -eq $CertThumbprintRegValue) {
        Write-Host "The certificate hash matches the DeployR configuration." -ForegroundColor Green
    }
    else {
        Write-Host "The certificate hash does NOT match the DeployR configuration." -ForegroundColor Red
    }
} else {
    Write-Host  "No SSL binding found for port 443. Trying all IPs..." -ForegroundColor Yellow
    # Fallback: Scan common IPs (adjust as needed)
    $ips = @("0.0.0.0", "*")  # Add specific IPs if known, e.g., "192.168.1.100"
    $found = $false
    foreach ($ip in $ips) {
        $hash = netsh http show sslcert ipport="$ip`:443" | Select-String "Certificate Hash" | ForEach-Object { ($_ -split ": ")[1].Trim() }
        if ($hash) {
            Write-Host "Certificate Thumbprint for HTTPS (port 443) on $ip`: $hash" -ForegroundColor Yellow
            $found = $true
            break
        }
    }
    if (-not $found) { Write-Host "No binding found." -ForegroundColor Red }
}
$certHash = netsh http show sslcert ipport=0.0.0.0:9000 | Select-String "Certificate Hash" | ForEach-Object { ($_ -split ": ")[1].Trim() }

if ($certHash) {
    Write-Host  "Certificate Thumbprint for HTTPS (port 9000): $certHash" -ForegroundColor Green
    if ($certHash -eq $CertThumbprintRegValue) {
        Write-Host "The certificate hash matches the DeployR configuration." -ForegroundColor Green
    }
    else {
        Write-Host "The certificate hash does NOT match the DeployR configuration." -ForegroundColor Red
    }
} else {
    Write-Host  "No SSL binding found for port 443. Trying all IPs..." -ForegroundColor Yellow
    # Fallback: Scan common IPs (adjust as needed)
    $ips = @("0.0.0.0", "*")  # Add specific IPs if known, e.g., "192.168.1.100"
    $found = $false
    foreach ($ip in $ips) {
        $hash = netsh http show sslcert ipport="$ip`:443" | Select-String "Certificate Hash" | ForEach-Object { ($_ -split ": ")[1].Trim() }
        if ($hash) {
            Write-Host "Certificate Thumbprint for HTTPS (port 443) on $ip`: $hash" -ForegroundColor Yellow
            $found = $true
            break
        }
    }
    if (-not $found) { Write-Host "No binding found." -ForegroundColor Red }
}

if ($Installed_2Pint_Software_StifleR_WmiAgent) {
    Write-Host "=========================================================================" -ForegroundColor DarkGray
    write-host "Checking for StifleR Infrastructure Approval for DeployR" -ForegroundColor Cyan
    $InfraServices = Get-CimInstance -ClassName "InfrastructureServices" -Namespace root\stifler
    if ($InfraServices) {
        $DeployR = $InfraServices | Where-Object {$_.Type -eq "DeployR"}
        if ($DeployR){
            Write-Host "StifleR Infrastructure for DeployR found." -ForegroundColor Green
            if ($DeployR.Status -eq "IsApproved") {
                Write-Host "DeployR Status: Approved" -ForegroundColor Green
            } else {
                Write-Host "DeployR Status: NOT Approved" -ForegroundColor Red
            }
        }
        else{
            Write-Host "No StifleR Infrastructure for DeployR found." -ForegroundColor Red
        }
    } else {
        Write-Host "StifleR Infrastructure Services are NOT available." -ForegroundColor Red
    }
}