# Script to parse Surface device MSI download URLs from Microsoft documentation

function Get-SurfaceDriverTable {
    Write-Host "Fetching Surface driver documentation..." -ForegroundColor Yellow
    
    $url = "https://raw.githubusercontent.com/microsoftdocs/devices-docs/public/surface/manage-surface-driver-and-firmware-updates.md"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $content = $response.Content
    }
    catch {
        Write-Error "Failed to fetch content: $_"
        return $null
    }
    
    # Split into lines
    $lines = $content -split "`r?`n"
    
    Write-Host "Document has $($lines.Count) lines" -ForegroundColor Yellow
    
    $devices = @()
    
    # Look for the table
    Write-Host "`nSearching for device table..." -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Look for table header
        if ($line -match 'Surface device.*\|.*Downloadable' -or 
            $line -match '\|\s*Surface device\s*\|') {
            Write-Host "Found table header at line $i" -ForegroundColor Green
            Write-Host "Header: $line" -ForegroundColor DarkGray
            
            # Skip separator line
            $i++
            if ($lines[$i] -match '^\|[\s-]+\|') {
                $i++
            }
            
            # Process table rows
            while ($i -lt $lines.Count) {
                $row = $lines[$i]
                
                # Check if we're still in the table
                if ($row -notmatch '^\|') {
                    Write-Host "End of table at line $i" -ForegroundColor Yellow
                    break
                }
                
                # Parse cells - don't trim the pipe characters first
                $cells = $row -split '\|' | Where-Object { $_ -ne '' }
                
                if ($cells.Count -ge 2) {
                    $firstCell = $cells[0].Trim()
                    $secondCell = $cells[1].Trim()
                    
                    # Clean up the category name
                    $firstCell = $firstCell -replace '\*\*', ''  # Remove bold markdown
                    
                    # Check if this is a category row
                    if ($firstCell -match '^Surface\s+(Pro|Laptop|Book|Go|Studio|Hub|3)(?:\s+Go|Studio)?$') {
                        $currentCategory = $firstCell
                        Write-Host "`nProcessing category: $currentCategory" -ForegroundColor Cyan
                        Write-Host "Cell 2 content: $($secondCell.Substring(0, [Math]::Min(100, $secondCell.Length)))..." -ForegroundColor DarkGray
                        
                        # Parse all devices from the second cell
                        # The devices are in format: - [Device Name](URL)
                        # Split by the pattern "- [" which starts each device
                        $deviceMatches = [regex]::Matches($secondCell, '-\s*\[([^\]]+)\]\(([^\)]+)\)')
                        
                        if ($deviceMatches.Count -gt 0) {
                            Write-Host "Found $($deviceMatches.Count) devices with links" -ForegroundColor Green
                            
                            foreach ($match in $deviceMatches) {
                                $deviceName = $match.Groups[1].Value.Trim()
                                $msiUrl = $match.Groups[2].Value.Trim()
                                
                                # Handle relative URLs
                                if ($msiUrl -notmatch '^https?://') {
                                    if ($msiUrl -match '^/') {
                                        $msiUrl = "https://www.microsoft.com$msiUrl"
                                    }
                                }
                                
                                # Extract download ID
                                $downloadId = $null
                                if ($msiUrl -match 'id=(\d+)') {
                                    $downloadId = $Matches[1]
                                }
                                
                                # Create device object
                                $deviceObj = [PSCustomObject]@{
                                    Category = $currentCategory
                                    Device = $deviceName
                                    MsiDownloadUrl = $msiUrl
                                    DownloadId = $downloadId
                                }
                                
                                $devices += $deviceObj
                                Write-Host "  Added: $deviceName" -ForegroundColor DarkGray
                            }
                        }
                        
                        # Also look for devices without links (just plain text)
                        # These would be in format: - Device Name
                        $plainDevices = [regex]::Matches($secondCell, '-\s+([^-\[]+?)(?=\s*-|\s*$)')
                        foreach ($match in $plainDevices) {
                            $deviceName = $match.Groups[1].Value.Trim()
                            
                            # Skip if this was already captured as a linked device
                            if ($devices | Where-Object { $_.Device -eq $deviceName -and $_.Category -eq $currentCategory }) {
                                continue
                            }
                            
                            # Skip if too short
                            if ($deviceName.Length -lt 5) {
                                continue
                            }
                            
                            # Create device object without URL
                            $deviceObj = [PSCustomObject]@{
                                Category = $currentCategory
                                Device = $deviceName
                                MsiDownloadUrl = $null
                                DownloadId = $null
                            }
                            
                            $devices += $deviceObj
                            Write-Host "  Added (no URL): $deviceName" -ForegroundColor DarkGray
                        }
                    }
                }
                
                $i++
            }
            
            break  # Exit the outer for loop
        }
    }
    
    return $devices
}

# Main execution
Write-Host "`nSurface Driver URL Parser" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

try {
    # Get the data
    $surfaceDevices = Get-SurfaceDriverTable
    
    if ($surfaceDevices -and $surfaceDevices.Count -gt 0) {
        Write-Host "`nFound $($surfaceDevices.Count) total Surface devices" -ForegroundColor Green
        
        # Count devices with and without URLs
        $devicesWithUrls = $surfaceDevices | Where-Object { $_.MsiDownloadUrl }
        $devicesWithoutUrls = $surfaceDevices | Where-Object { -not $_.MsiDownloadUrl }
        
        Write-Host "  - $($devicesWithUrls.Count) devices with download URLs" -ForegroundColor Green
        Write-Host "  - $($devicesWithoutUrls.Count) devices without download URLs" -ForegroundColor Yellow
        
        # Export all devices to JSON
        $jsonPath = Join-Path $PSScriptRoot "SurfaceDriverURLs.json"
        $surfaceDevices | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
        Write-Host "`nExported to: $jsonPath" -ForegroundColor Green
        
        # Show summary by category
        Write-Host "`nSummary by category:" -ForegroundColor Yellow
        $surfaceDevices | Group-Object Category | Sort-Object Name | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) devices" -ForegroundColor Cyan
        }
        
        # Show all devices
        Write-Host "`nAll devices found:" -ForegroundColor Yellow
        $surfaceDevices | Group-Object Category | ForEach-Object {
            Write-Host "`n$($_.Name):" -ForegroundColor Cyan
            $_.Group | ForEach-Object {
                $urlStatus = if($_.MsiDownloadUrl) { "✓" } else { "✗" }
                Write-Host "  [$urlStatus] $($_.Device)" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Warning "No Surface devices found in the documentation"
    }
}
catch {
    Write-Error "Failed to parse Surface driver table: $_"
}