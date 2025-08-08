# Script to extract Windows 10 and 11 driver pack MSI URLs from Surface download pages

function Get-SurfaceDriverPackMSIUrls {
    param(
        [string]$CombinedDataPath = (Join-Path $PSScriptRoot "SurfaceDeviceDetails.json")
    )
    
    Write-Host "`nSurface Driver Pack MSI URL Extractor" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    
    # Load the combined data
    if (-not (Test-Path $CombinedDataPath)) {
        Write-Error "Combined data file not found: $CombinedDataPath"
        Write-Host "Please run MSSurface.ps1 first" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Loading combined Surface data..." -ForegroundColor Yellow
    $combinedData = Get-Content $CombinedDataPath | ConvertFrom-Json
    
    # Filter to only devices with download URLs
    $devicesWithUrls = $combinedData | Where-Object { $_.MsiDownloadUrl }
    Write-Host "Found $($devicesWithUrls.Count) devices with download URLs" -ForegroundColor Green
    
    $results = @()
    $processedUrls = @{}  # Cache to avoid processing the same URL multiple times
    
    foreach ($device in $devicesWithUrls) {
        # Skip if we've already processed this URL
        if ($processedUrls.ContainsKey($device.MsiDownloadUrl)) {
            Write-Host "  Using cached data for: $($device.Device)" -ForegroundColor DarkGray
            
            # Create result object with cached data
            $cachedData = $processedUrls[$device.MsiDownloadUrl]
            $resultObj = [PSCustomObject]@{
                Device = $device.Device
                ShortDevice = $device.ShortDevice
                SystemSKU = $device.SystemSKU
                DownloadPageUrl = $device.MsiDownloadUrl
                DownloadId = $device.DownloadId
                Windows11Url = $cachedData.Windows11Url
                Windows11FileName = $cachedData.Windows11FileName
                Windows11FileSize = $cachedData.Windows11FileSize
                Windows10Url = $cachedData.Windows10Url
                Windows10FileName = $cachedData.Windows10FileName
                Windows10FileSize = $cachedData.Windows10FileSize
                LastUpdated = $cachedData.LastUpdated
                Status = $cachedData.Status
            }
            $results += $resultObj
            continue
        }
        
        Write-Host "`nProcessing: $($device.Device)" -ForegroundColor Yellow
        Write-Host "  URL: $($device.MsiDownloadUrl)" -ForegroundColor DarkGray
        
        try {
            # Fetch the download page
            $response = Invoke-WebRequest -Uri $device.MsiDownloadUrl -UseBasicParsing
            $content = $response.Content
            
            # Initialize variables
            $windows11Url = $null
            $windows11FileName = $null
            $windows11FileSize = $null
            $windows10Url = $null
            $windows10FileName = $null
            $windows10FileSize = $null
            $lastUpdated = $null
            
            # Microsoft download pages contain links to MSI files in different formats
            # Let's look for all .msi links first
            $msiUrls = @()
            
            # Pattern 1: Direct MSI links in href attributes
            $hrefPattern = 'href="([^"]+\.msi)"'
            $hrefMatches = [regex]::Matches($content, $hrefPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $hrefMatches) {
                $msiUrls += $match.Groups[1].Value
            }
            
            # Pattern 2: MSI links in JavaScript or data attributes
            $jsPattern = '["''](https?://[^"'']+\.msi)["'']'
            $jsMatches = [regex]::Matches($content, $jsPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $jsMatches) {
                $msiUrls += $match.Groups[1].Value
            }
            
            # Pattern 3: Look for download.microsoft.com URLs
            $downloadPattern = '(https?://download\.microsoft\.com/[^"''<>\s]+\.msi)'
            $downloadMatches = [regex]::Matches($content, $downloadPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $downloadMatches) {
                $msiUrls += $match.Groups[1].Value
            }
            
            # Remove duplicates
            $msiUrls = $msiUrls | Select-Object -Unique
            
            Write-Host "  Found $($msiUrls.Count) MSI URLs" -ForegroundColor DarkGray
            
            # Categorize the MSI URLs
            foreach ($url in $msiUrls) {
                $fileName = Split-Path $url -Leaf
                
                # Check for Windows 11
                if ($fileName -match 'Win11|Windows.*11|_11_|Win11_|22000|22621|22631|226\d\d') {
                    if (-not $windows11Url) {
                        $windows11Url = $url
                        $windows11FileName = $fileName
                        Write-Host "    Windows 11: $fileName" -ForegroundColor Green
                    }
                }
                # Check for Windows 10
                elseif ($fileName -match 'Win10|Windows.*10|_10_|Win10_|19041|19042|19043|19044|19045|190\d\d|17763|18362|18363') {
                    if (-not $windows10Url) {
                        $windows10Url = $url
                        $windows10FileName = $fileName
                        Write-Host "    Windows 10: $fileName" -ForegroundColor Green
                    }
                }
            }
            
            # Look for file sizes if available
            # Microsoft sometimes shows file sizes in the page
            if ($windows11FileName) {
                $sizePattern = [regex]::Escape($windows11FileName) + '.*?(\d+(?:\.\d+)?\s*[MG]B)'
                $sizeMatch = [regex]::Match($content, $sizePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($sizeMatch.Success) {
                    $windows11FileSize = $sizeMatch.Groups[1].Value
                }
            }
            
            if ($windows10FileName) {
                $sizePattern = [regex]::Escape($windows10FileName) + '.*?(\d+(?:\.\d+)?\s*[MG]B)'
                $sizeMatch = [regex]::Match($content, $sizePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($sizeMatch.Success) {
                    $windows10FileSize = $sizeMatch.Groups[1].Value
                }
            }
            
            # Look for last updated date
            $datePatterns = @(
                'Date Published:?\s*</[^>]+>\s*([^<]+)',
                'Last Updated:?\s*([^<]+)',
                'Release Date:?\s*([^<]+)',
                '(\d{1,2}/\d{1,2}/\d{4})'
            )
            
            foreach ($pattern in $datePatterns) {
                $dateMatch = [regex]::Match($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($dateMatch.Success) {
                    $lastUpdated = $dateMatch.Groups[1].Value.Trim()
                    break
                }
            }
            
            # Create result object
            $resultObj = [PSCustomObject]@{
                Device = $device.Device
                ShortDevice = $device.ShortDevice
                SystemSKU = $device.SystemSKU
                DownloadPageUrl = $device.MsiDownloadUrl
                DownloadId = $device.DownloadId
                Windows11Url = $windows11Url
                Windows11FileName = $windows11FileName
                Windows11FileSize = $windows11FileSize
                Windows10Url = $windows10Url
                Windows10FileName = $windows10FileName
                Windows10FileSize = $windows10FileSize
                LastUpdated = $lastUpdated
                Status = if ($windows11Url -or $windows10Url) { "Found" } else { "Not Found" }
            }
            
            # Cache the result
            $processedUrls[$device.MsiDownloadUrl] = $resultObj
            $results += $resultObj
            
            # Status update
            $foundCount = 0
            if ($windows11Url) { $foundCount++ }
            if ($windows10Url) { $foundCount++ }
            
            if ($foundCount -gt 0) {
                Write-Host "  Status: Found $foundCount driver pack(s)" -ForegroundColor Green
            } else {
                Write-Host "  Status: No MSI files found" -ForegroundColor Yellow
            }
            
            # Be nice to the server
            Start-Sleep -Milliseconds 500
        }
        catch {
            Write-Error "  Failed to process $($device.Device): $_"
            
            # Add error result
            $resultObj = [PSCustomObject]@{
                Device = $device.Device
                ShortDevice = $device.ShortDevice
                SystemSKU = $device.SystemSKU
                DownloadPageUrl = $device.MsiDownloadUrl
                DownloadId = $device.DownloadId
                Windows11Url = $null
                Windows11FileName = $null
                Windows11FileSize = $null
                Windows10Url = $null
                Windows10FileName = $null
                Windows10FileSize = $null
                LastUpdated = $null
                Status = "Error: $_"
            }
            $results += $resultObj
        }
    }
    
    # Export results
    $outputPath = Join-Path $PSScriptRoot "SurfaceDriverPackDownloadList.json"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Host "`nExported MSI list to: $outputPath" -ForegroundColor Green
    
    # Show summary
    Write-Host "`nSummary:" -ForegroundColor Yellow
    $foundCount = ($results | Where-Object { $_.Status -eq "Found" }).Count
    $notFoundCount = ($results | Where-Object { $_.Status -eq "Not Found" }).Count
    $errorCount = ($results | Where-Object { $_.Status -like "Error*" }).Count
    
    Write-Host "  Found driver packs: $foundCount" -ForegroundColor Green
    Write-Host "  Not found: $notFoundCount" -ForegroundColor Yellow
    Write-Host "  Errors: $errorCount" -ForegroundColor Red
    
    # Show devices with both Windows 10 and 11
    $bothVersions = $results | Where-Object { $_.Windows11Url -and $_.Windows10Url }
    Write-Host "`nDevices with both Windows 10 and 11 drivers: $($bothVersions.Count)" -ForegroundColor Cyan
    if ($bothVersions.Count -gt 0 -and $bothVersions.Count -le 10) {
        $bothVersions | ForEach-Object {
            Write-Host "  - $($_.Device)" -ForegroundColor Gray
        }
    }
    
    # Show devices with only one version
    $onlyWin11 = $results | Where-Object { $_.Windows11Url -and -not $_.Windows10Url }
    $onlyWin10 = $results | Where-Object { $_.Windows10Url -and -not $_.Windows11Url }
    
    if ($onlyWin11.Count -gt 0) {
        Write-Host "`nDevices with only Windows 11 drivers: $($onlyWin11.Count)" -ForegroundColor Yellow
    }
    
    if ($onlyWin10.Count -gt 0) {
        Write-Host "`nDevices with only Windows 10 drivers: $($onlyWin10.Count)" -ForegroundColor Yellow
    }
    
    return $results
}

# Main execution

#Build Required Files:

# Trigger Process to build Required Files by calling the other PowerShell Scripts

# Trigger Build-MSSurfaceSKUList.ps1
Write-Host "`nRunning Build-MSSurfaceSKUList.ps1..." -ForegroundColor Yellow
$skuScriptPath = Join-Path $PSScriptRoot "Build-MSSurfaceSKUList.ps1"
if (Test-Path $skuScriptPath) {
    & $skuScriptPath
} else {
    Write-Error "Build-MSSurfaceSKUList.ps1 not found in $PSScriptRoot"
    return
}
start-sleep -Seconds 1
# Trigger Build-MSSurfaceURLList.ps1 to combine the data
Write-Host "`nRunning Build-MSSurfaceURLList.ps1 to combine data..." -ForegroundColor Yellow
$surfaceScriptPath = Join-Path $PSScriptRoot "Build-MSSurfaceURLList.ps1"
if (Test-Path $surfaceScriptPath) {
    & $surfaceScriptPath
} else {
    Write-Error "Build-MSSurfaceURLList.ps1 not found in $PSScriptRoot"
    return
}
start-sleep -Seconds 1
# Trigger Build-MSSurfaceDeviceDetails.ps1
Write-Host "`nRunning Build-MSSurfaceDeviceDetails.ps1..." -ForegroundColor Yellow
$driverScriptPath = Join-Path $PSScriptRoot "Build-MSSurfaceDeviceDetails.ps1"
if (Test-Path $driverScriptPath) {
    & $driverScriptPath
} else {
    Write-Error "Build-MSSurfaceDeviceDetails.ps1 not found in $PSScriptRoot"
    return
}
start-sleep -Seconds 1


try {
    $msiList = Get-SurfaceDriverPackMSIUrls
    
    if ($msiList) {
        Write-Host "`nDriver pack MSI list created successfully!" -ForegroundColor Green
        Write-Host "Check SurfaceDriverPackMSIList.json for the complete list." -ForegroundColor Cyan
    }
}
catch {
    Write-Error "Failed to extract MSI URLs: $_"
}