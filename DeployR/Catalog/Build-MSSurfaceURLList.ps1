# Script to parse Surface device MSI download URLs from Microsoft documentation

function Build-MSSurfaceURLList {
    <#
    .SYNOPSIS
    Builds a list of Microsoft Surface download URLs from Microsoft Learn
    
    .DESCRIPTION
    This function fetches the Surface download URL data from Microsoft Learn documentation,
    parses it, and returns a structured list of Surface devices with their download URLs.
    
    .PARAMETER OutputJSON
    Switch to export the data to a JSON file
    
    .EXAMPLE
    $urlData = Build-MSSurfaceURLList
    Build-MSSurfaceURLList -OutputJSON
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter] $OutputJSON
    )
    
    function Get-SurfaceDriverTable {
        Write-Host "Fetching Surface driver documentation from Microsoft Learn..." -ForegroundColor Yellow
        
        $url = "https://learn.microsoft.com/en-us/surface/manage-surface-driver-and-firmware-updates"
        
        try {
            # Use proper headers to avoid blocking
            $headers = @{
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
                'Accept-Language' = 'en-US,en;q=0.5'
                'Accept-Encoding' = 'gzip, deflate'
                'Cache-Control' = 'no-cache'
            }
            
            $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing
            $content = $response.Content
        }
        catch {
            Write-Error "Failed to fetch content from Microsoft Learn: $_"
            Write-Host "Trying alternative approach..." -ForegroundColor Yellow
            
            # Try without custom headers
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing
                $content = $response.Content
            }
            catch {
                Write-Error "Alternative approach failed: $_"
                return $null
            }
        }
        
        Write-Host "Successfully fetched page content ($(($content.Length / 1024).ToString('F1')) KB)" -ForegroundColor Green
        
        $devices = @()
        
        # Parse HTML content to find the table
        Write-Host "`nSearching for Surface device table..." -ForegroundColor Yellow
        
        # Look for table patterns in the HTML
        # Microsoft Learn pages often have tables with specific classes or structures
        $tableMatches = [regex]::Matches($content, '<table[^>]*>.*?</table>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($tableMatches.Count -eq 0) {
            Write-Warning "No tables found in the page content"
            Write-Host "Looking for markdown-style tables..." -ForegroundColor Yellow
            
            # Split into lines and look for markdown tables
            $lines = $content -split "`r?`n"
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                
                # Look for table headers that might contain "Surface device" and download info
                if ($line -match 'Surface device.*\|' -or 
                    $line -match '\|\s*Surface device\s*\|' -or
                    $line -match '\|\s*Device\s*\|.*download' -or
                    $line -match 'Device.*MSI') {
                    
                    Write-Host "Found potential table header at line $i" -ForegroundColor Green
                    Write-Host "Header: $($line.Substring(0, [Math]::Min(100, $line.Length)))..." -ForegroundColor DarkGray
                    
                    # Skip separator line if present
                    $i++
                    if ($i -lt $lines.Count -and $lines[$i] -match '^\|[\s-]+\|') {
                        $i++
                    }
                    
                    # Process table rows
                    while ($i -lt $lines.Count) {
                        $row = $lines[$i]
                        
                        # Check if we're still in the table
                        if ($row -notmatch '^\|' -or $row.Trim() -eq '') {
                            Write-Host "End of table at line $i" -ForegroundColor Yellow
                            break
                        }
                        
                        # Parse cells
                        $cells = $row -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                        
                        if ($cells.Count -ge 2) {
                            $firstCell = $cells[0]
                            $secondCell = $cells[1]
                            
                            # Clean up markdown formatting
                            $firstCell = $firstCell -replace '\*\*', '' -replace '\*', ''
                            
                            # Check if this is a Surface device category
                            if ($firstCell -match 'Surface\s+(Pro|Laptop|Book|Go|Studio|Hub|3)') {
                                $currentCategory = $firstCell
                                Write-Host "`nProcessing category: $currentCategory" -ForegroundColor Cyan
                                
                                # Parse devices and URLs from the second cell
                                $devices += Parse-DeviceCell -CategoryName $currentCategory -CellContent $secondCell
                            }
                        }
                        
                        $i++
                    }
                    
                    break
                }
            }
        }
        else {
            Write-Host "Found $($tableMatches.Count) HTML table(s), parsing..." -ForegroundColor Green
            
            foreach ($tableMatch in $tableMatches) {
                $tableHtml = $tableMatch.Value
                
                # Check if this table contains Surface device information
                if ($tableHtml -match 'Surface' -and ($tableHtml -match 'download' -or $tableHtml -match 'MSI')) {
                    Write-Host "Processing Surface device table..." -ForegroundColor Cyan
                    
                    # Parse HTML table rows
                    $rowMatches = [regex]::Matches($tableHtml, '<tr[^>]*>(.*?)</tr>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    
                    foreach ($rowMatch in $rowMatches) {
                        $rowHtml = $rowMatch.Groups[1].Value
                        
                        # Extract cell contents
                        $cellMatches = [regex]::Matches($rowHtml, '<t[hd][^>]*>(.*?)</t[hd]>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        
                        if ($cellMatches.Count -ge 2) {
                            $firstCell = [System.Web.HttpUtility]::HtmlDecode($cellMatches[0].Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' '
                            $secondCell = $cellMatches[1].Groups[1].Value
                            
                            # Check if this is a Surface device category
                            if ($firstCell -match 'Surface\s+(Pro|Laptop|Book|Go|Studio|Hub|3)') {
                                $currentCategory = $firstCell.Trim()
                                Write-Host "`nProcessing category: $currentCategory" -ForegroundColor Cyan
                                
                                # Parse devices and URLs from the second cell
                                $devices += Parse-DeviceCell -CategoryName $currentCategory -CellContent $secondCell
                            }
                        }
                    }
                }
            }
        }
        
        return $devices
    }
    
    function Parse-DeviceCell {
        param(
            [string]$CategoryName,
            [string]$CellContent
        )
        
        $deviceList = @()
        
        # Remove HTML tags and decode entities
        $cleanContent = [System.Web.HttpUtility]::HtmlDecode($CellContent) -replace '<[^>]+>', ''
        
        Write-Host "  Parsing devices from: $($cleanContent.Substring(0, [Math]::Min(100, $cleanContent.Length)))..." -ForegroundColor DarkGray
        
        # Look for device links in format [Device Name](URL) or <a href="URL">Device Name</a>
        $linkMatches = [regex]::Matches($CellContent, '<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($linkMatches.Count -eq 0) {
            # Try markdown format
            $linkMatches = [regex]::Matches($CellContent, '\[([^\]]+)\]\(([^\)]+)\)')
        }
        
        if ($linkMatches.Count -gt 0) {
            Write-Host "    Found $($linkMatches.Count) linked devices" -ForegroundColor Green
            
            foreach ($match in $linkMatches) {
                $deviceName = $match.Groups[2].Value.Trim()
                $url = $match.Groups[1].Value.Trim()
                
                # Clean up device name
                $deviceName = [System.Web.HttpUtility]::HtmlDecode($deviceName) -replace '\s+', ' '
                
                # Handle relative URLs
                if ($url -notmatch '^https?://') {
                    if ($url -match '^/') {
                        $url = "https://www.microsoft.com$url"
                    }
                }
                
                # Extract download ID
                $downloadId = $null
                if ($url -match 'id=(\d+)') {
                    $downloadId = $Matches[1]
                }
                
                $deviceObj = [PSCustomObject]@{
                    Category = $CategoryName
                    Device = $deviceName
                    MsiDownloadUrl = $url
                    DownloadId = $downloadId
                }
                
                $deviceList += $deviceObj
                Write-Host "    Added: $deviceName" -ForegroundColor Gray
            }
        }
        
        # Look for plain text devices (without links)
        $plainTextDevices = [regex]::Matches($cleanContent, '(?:^|\n|\r)\s*[-•]\s*([^-•\n\r]+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        
        foreach ($match in $plainTextDevices) {
            $deviceName = $match.Groups[1].Value.Trim()
            
            # Skip if already added as linked device or too short
            if (($deviceList | Where-Object { $_.Device -eq $deviceName }) -or $deviceName.Length -lt 5) {
                continue
            }
            
            # Skip if it looks like a URL or other metadata
            if ($deviceName -match '^https?://' -or $deviceName -match '^\d+$') {
                continue
            }
            
            $deviceObj = [PSCustomObject]@{
                Category = $CategoryName
                Device = $deviceName
                MsiDownloadUrl = $null
                DownloadId = $null
            }
            
            $deviceList += $deviceObj
            Write-Host "    Added (no URL): $deviceName" -ForegroundColor DarkGray
        }
        
        return $deviceList
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
            
            # Export all devices to JSON if requested
            if ($OutputJSON) {
                $jsonPath = Join-Path $PSScriptRoot "SurfaceURLs.json"
                $surfaceDevices | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
                Write-Host "`nExported to: $jsonPath" -ForegroundColor Green
            }
            else {
                Write-Host "Use -OutputJSON to export the data to a JSON file" -ForegroundColor Yellow
            }
            
            # Show summary by category
            Write-Host "`nSummary by category:" -ForegroundColor Yellow
            $surfaceDevices | Group-Object Category | Sort-Object Name | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Count) devices" -ForegroundColor Cyan
            }
            
            # Show sample devices
            Write-Host "`nSample devices found:" -ForegroundColor Yellow
            $surfaceDevices | Group-Object Category | ForEach-Object {
                Write-Host "`n$($_.Name):" -ForegroundColor Cyan
                $_.Group | Select-Object -First 3 | ForEach-Object {
                    $urlStatus = if($_.MsiDownloadUrl) { "✓" } else { "✗" }
                    Write-Host "  [$urlStatus] $($_.Device)" -ForegroundColor Gray
                }
                if ($_.Group.Count -gt 3) {
                    Write-Host "  ... and $($_.Group.Count - 3) more" -ForegroundColor DarkGray
                }
            }
        }
        else {
            Write-Warning "No Surface devices found in the documentation"
        }
    }
    catch {
        Write-Error "Failed to parse Surface driver table: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Always return the data for use by other scripts
    return $surfaceDevices
}

# If run directly (not dot-sourced), execute the function
if ($MyInvocation.InvocationName -ne '.') {
    Build-MSSurfaceURLList @PSBoundParameters
}
