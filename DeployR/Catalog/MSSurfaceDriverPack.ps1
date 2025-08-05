function Get-SurfaceDriverInfoFromGitHub {
    <#
    .SYNOPSIS
    Extracts Surface driver and firmware information from the Microsoft Docs GitHub repository
    
    .DESCRIPTION
    Parses the raw markdown file from GitHub containing Surface driver and firmware update information
    and returns a PowerShell object with Device and Download Link information
    
    .PARAMETER OutputPath
    Optional path to save the JSON output
    
    .EXAMPLE
    $driverData = Get-SurfaceDriverInfoFromGitHub
    Get-SurfaceDriverInfoFromGitHub -OutputPath ".\SurfaceDrivers.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    try {
        Write-Host "Fetching Surface driver info from GitHub..." -ForegroundColor Cyan
        
        $url = "https://raw.githubusercontent.com/microsoftdocs/devices-docs/public/surface/manage-surface-driver-and-firmware-updates.md"
        
        # Fetch the markdown content
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $content = $response.Content
        
        # Split content into lines
        $lines = $content -split "`n"
        
        $devices = @()
        $inTable = $false
        $headerFound = $false
        $currentCategory = $null
        
        Write-Host "Parsing markdown content..." -ForegroundColor Yellow
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            # Skip empty lines
            if (-not $line) {
                continue
            }
            
            # Check if we're entering a table
            if ($line -match '^\|.*\|$') {
                # Check if this is a header row we want
                if ($line -match 'Surface\s+device.*Downloadable.*msi' -or 
                    $line -match 'Device.*Download' -or
                    $line -match 'Model.*Link') {
                    $inTable = $true
                    $headerFound = $true
                    Write-Host "  Found table header" -ForegroundColor DarkGray
                    continue
                }
                
                # Skip the separator line (|---|---|)
                if ($headerFound -and $line -match '^\|[\s\-:]+\|') {
                    continue
                }
                
                # Parse data rows
                if ($inTable) {
                    # Exit table if we hit an empty line or non-table content
                    if (-not ($line -match '^\|.*\|$')) {
                        $inTable = $false
                        $headerFound = $false
                        continue
                    }
                    
                    # Split the line by pipes and clean up
                    $cells = $line -split '\|' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
                    
                    if ($cells.Count -ge 2) {
                        $firstCell = $cells[0].Trim()
                        $secondCell = $cells[1].Trim()
                        
                        # Check if first cell is a category header (Surface Pro, Surface Laptop, etc.)
                        if ($firstCell -match '^Surface\s+\w+$' -and 
                            ($secondCell -match '^\s*-' -or $secondCell -match 'Surface')) {
                            $currentCategory = $firstCell
                            Write-Host "  Category: $currentCategory" -ForegroundColor DarkGray
                        }
                        
                        # Parse device entries from the second cell
                        if ($secondCell -match 'Surface' -or $secondCell -match '^\s*-') {
                            # Extract devices from bullet lists
                            $deviceLines = $secondCell -split '<br>' | ForEach-Object { $_.Trim() }
                            
                            foreach ($deviceLine in $deviceLines) {
                                # Clean up the line
                                $deviceLine = $deviceLine -replace '^\s*-\s*', '' -replace '\*', ''
                                $deviceLine = [System.Web.HttpUtility]::HtmlDecode($deviceLine)
                                
                                # Extract device name and link
                                if ($deviceLine -match '\[([^\]]+)\]\(([^\)]+)\)') {
                                    $deviceName = $Matches[1].Trim()
                                    $downloadLink = $Matches[2].Trim()
                                    
                                    # Fix relative links
                                    if ($downloadLink -notmatch '^https?://') {
                                        if ($downloadLink -match '^/') {
                                            $downloadLink = "https://www.microsoft.com" + $downloadLink
                                        }
                                    }
                                    
                                    # Clean up the link
                                    $downloadLink = $downloadLink -replace '&amp;', '&'
                                    
                                    $deviceObj = [PSCustomObject]@{
                                        Category = if ($currentCategory) { $currentCategory } else { "Other" }
                                        Device = $deviceName
                                        DownloadLink = $downloadLink
                                        DownloadID = if ($downloadLink -match 'id=(\d+)') { $Matches[1] } else { "N/A" }
                                    }
                                    
                                    $devices += $deviceObj
                                    Write-Host "    Found: $deviceName" -ForegroundColor Green
                                }
                                # Handle plain text entries (no link)
                                elseif ($deviceLine -match 'Surface' -and $deviceLine.Length -gt 5) {
                                    $deviceObj = [PSCustomObject]@{
                                        Category = if ($currentCategory) { $currentCategory } else { "Other" }
                                        Device = $deviceLine
                                        DownloadLink = "Not Available"
                                        DownloadID = "N/A"
                                    }
                                    
                                    $devices += $deviceObj
                                    Write-Host "    Found (no link): $deviceLine" -ForegroundColor Yellow
                                }
                            }
                        }
                    }
                }
            }
            # Also check for device links outside of tables
            elseif ($line -match '\[([^\]]*Surface[^\]]+)\]\(([^\)]+)\)') {
                $deviceName = $Matches[1].Trim()
                $downloadLink = $Matches[2].Trim()
                
                # Fix relative links
                if ($downloadLink -notmatch '^https?://') {
                    if ($downloadLink -match '^/') {
                        $downloadLink = "https://www.microsoft.com" + $downloadLink
                    }
                }
                
                # Clean up the link
                $downloadLink = $downloadLink -replace '&amp;', '&'
                
                # Only add if it's a download link
                if ($downloadLink -match 'download|id=\d+') {
                    $deviceObj = [PSCustomObject]@{
                        Category = "Other"
                        Device = $deviceName
                        DownloadLink = $downloadLink
                        DownloadID = if ($downloadLink -match 'id=(\d+)') { $Matches[1] } else { "N/A" }
                    }
                    
                    # Check if already exists
                    $exists = $devices | Where-Object { $_.Device -eq $deviceName }
                    if (-not $exists) {
                        $devices += $deviceObj
                        Write-Host "  Found (outside table): $deviceName" -ForegroundColor Green
                    }
                }
            }
        }
        
        # Remove duplicates
        $uniqueDevices = $devices | Sort-Object Category, Device -Unique
        
        Write-Host "`nTotal unique devices found: $($uniqueDevices.Count)" -ForegroundColor Yellow
        
        # Display summary by category
        $categories = $uniqueDevices | Group-Object Category | Sort-Object Name
        Write-Host "`nDevice Summary by Category:" -ForegroundColor Cyan
        foreach ($cat in $categories) {
            Write-Host "  $($cat.Name): $($cat.Count) models" -ForegroundColor Gray
        }
        
        # Convert to JSON if output path specified
        if ($OutputPath) {
            $jsonOutput = $uniqueDevices | ConvertTo-Json -Depth 10
            $jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "`nData saved to: $OutputPath" -ForegroundColor Green
        }
        
        return $uniqueDevices
    }
    catch {
        Write-Error "Failed to get Surface driver info from GitHub: $_"
        return $null
    }
}

# Function to display the data in a nice table format
function Show-SurfaceDriverTable {
    <#
    .SYNOPSIS
    Displays Surface driver data in a formatted table
    
    .PARAMETER DriverData
    The driver data array from Get-SurfaceDriverInfoFromGitHub
    
    .PARAMETER CategoryFilter
    Optional filter for specific device categories (e.g., "Surface Pro", "Surface Laptop")
    
    .EXAMPLE
    Show-SurfaceDriverTable -DriverData $driverData
    Show-SurfaceDriverTable -DriverData $driverData -CategoryFilter "Surface Pro"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DriverData,
        
        [Parameter(Mandatory = $false)]
        [string]$CategoryFilter
    )
    
    $displayData = $DriverData
    
    if ($CategoryFilter) {
        $displayData = $DriverData | Where-Object { $_.Category -like "*$CategoryFilter*" }
        Write-Host "Filtering for: $CategoryFilter" -ForegroundColor Yellow
    }
    
    $displayData | Format-Table -AutoSize
}

# Function to get MSI download URLs
function Get-SurfaceMsiDownloadUrls {
    <#
    .SYNOPSIS
    Fetches actual MSI download URLs from the driver pages
    
    .PARAMETER DriverData
    The driver data array from Get-SurfaceDriverInfoFromGitHub
    
    .PARAMETER OutputPath
    Optional path to save the results
    
    .EXAMPLE
    $msiUrls = Get-SurfaceMsiDownloadUrls -DriverData $driverData
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DriverData,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    $results = @()
    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    Write-Host "Fetching MSI download URLs..." -ForegroundColor Cyan
    
    foreach ($device in $DriverData) {
        if ($device.DownloadLink -eq "Not Available") {
            $result = [PSCustomObject]@{
                Category = $device.Category
                Device = $device.Device
                DownloadLink = $device.DownloadLink
                MsiUrl = "Not Available"
                MsiFileName = "N/A"
            }
            $results += $result
            continue
        }
        
        Write-Host "Processing: $($device.Device)" -ForegroundColor Yellow
        
        try {
            # Try confirmation page approach for Microsoft download links
            if ($device.DownloadID -ne "N/A") {
                $confirmUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=$($device.DownloadID)"
                $response = Invoke-WebRequest -Uri $confirmUrl -UseBasicParsing -Headers $headers -TimeoutSec 15
                
                # Look for MSI download link
                if ($response.Content -match 'https://download\.microsoft\.com/download/[^"]+\.msi') {
                    $msiUrl = $Matches[0]
                    $msiFileName = Split-Path -Leaf $msiUrl
                    
                    $result = [PSCustomObject]@{
                        Category = $device.Category
                        Device = $device.Device
                        DownloadLink = $device.DownloadLink
                        MsiUrl = $msiUrl
                        MsiFileName = $msiFileName
                    }
                    $results += $result
                    Write-Host "  Found MSI: $msiFileName" -ForegroundColor Green
                }
                else {
                    $result = [PSCustomObject]@{
                        Category = $device.Category
                        Device = $device.Device
                        DownloadLink = $device.DownloadLink
                        MsiUrl = "Not Found"
                        MsiFileName = "N/A"
                    }
                    $results += $result
                    Write-Host "  No MSI found" -ForegroundColor Yellow
                }
            }
            
            Start-Sleep -Milliseconds 500
        }
        catch {
            Write-Warning "  Failed to process: $_"
            $result = [PSCustomObject]@{
                Category = $device.Category
                Device = $device.Device
                DownloadLink = $device.DownloadLink
                MsiUrl = "Error"
                MsiFileName = "N/A"
            }
            $results += $result
        }
    }
    
    if ($OutputPath) {
        $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "`nResults saved to: $OutputPath" -ForegroundColor Green
    }
    
    return $results
}

# Main execution
Write-Host "Surface Driver Reference Parser" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Get the driver data
$driverData = Get-SurfaceDriverInfoFromGitHub

if ($driverData) {
    Write-Host "`nData retrieved successfully!" -ForegroundColor Green
    Write-Host "Use the following commands to work with the data:" -ForegroundColor Yellow
    Write-Host "  `$driverData | Format-Table -AutoSize" -ForegroundColor White
    Write-Host "  `$driverData | Where-Object { `$_.Category -eq 'Surface Pro' }" -ForegroundColor White
    Write-Host "  `$driverData | Export-Csv -Path '.\SurfaceDrivers.csv' -NoTypeInformation" -ForegroundColor White
    Write-Host "  Show-SurfaceDriverTable -DriverData `$driverData -CategoryFilter 'Surface Laptop'" -ForegroundColor White
    Write-Host "  `$msiUrls = Get-SurfaceMsiDownloadUrls -DriverData `$driverData" -ForegroundColor White
    
    # Display first 10 entries as sample
    Write-Host "`nSample data (first 10 entries):" -ForegroundColor Cyan
    $driverData | Select-Object -First 10 | Format-Table -AutoSize
}

