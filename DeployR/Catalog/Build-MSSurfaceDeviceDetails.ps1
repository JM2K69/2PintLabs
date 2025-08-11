# Script to combine Surface SKU data with Driver Pack URLs
function Build-MSSurfaceSKUList {
    <#
    .SYNOPSIS
    Builds a list of Microsoft Surface SKUs from the GitHub repository
    
    .DESCRIPTION
    This function fetches the Surface SKU data from the Microsoft Docs GitHub repository,
    parses it, and returns a structured list of Surface devices with their system models and SKUs.
    
    .PARAMETER OutputPath
    Optional path to save the JSON output
    
    .EXAMPLE
    $skuData = Build-MSSurfaceSKUList
    Build-MSSurfaceSKUList -OutputPath ".\SurfaceSkus.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter] $OutputJSON
    )
    


function Get-SurfaceSkuFromGitHub {
    <#
    .SYNOPSIS
    Extracts Surface device information from the Microsoft Docs GitHub repository
    
    .DESCRIPTION
    Parses the raw markdown file from GitHub containing Surface SKU reference information
    and returns a PowerShell object with Device, System Model, and System SKU
    
    .PARAMETER OutputPath
    Optional path to save the JSON output
    
    .EXAMPLE
    $skuData = Get-SurfaceSkuFromGitHub
    Get-SurfaceSkuFromGitHub -OutputPath ".\SurfaceSkus.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    try {
        Write-Host "Fetching Surface SKU data from Microsoft Learn..." -ForegroundColor Cyan
        
        $url = "https://learn.microsoft.com/en-us/surface/surface-system-sku-reference"
        
        # Use proper headers to avoid blocking
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
            'Accept-Language' = 'en-US,en;q=0.5'
            'Accept-Encoding' = 'gzip, deflate'
            'Cache-Control' = 'no-cache'
        }
        
        # Fetch the content
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing
            $content = $response.Content
        }
        catch {
            Write-Warning "Failed to fetch with headers, trying basic request: $_"
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
            $content = $response.Content
        }
        
        Write-Host "Successfully fetched page content ($(($content.Length / 1024).ToString('F1')) KB)" -ForegroundColor Green
        
        $devices = @()
        
        # Since we're now fetching HTML content instead of markdown, we need to parse HTML tables
        Write-Host "Parsing HTML content for Surface SKU tables..." -ForegroundColor Yellow
        
        # Look for HTML tables containing Surface device information
        $tableMatches = [regex]::Matches($content, '<table[^>]*>.*?</table>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($tableMatches.Count -eq 0) {
            Write-Warning "No HTML tables found, trying to parse as markdown..."
            
            # Fallback to markdown parsing if no HTML tables found
            $lines = $content -split "`n"
            $inTable = $false
            $headerFound = $false
            
            foreach ($line in $lines) {
                $line = $line.Trim()
                
                # Skip empty lines
                if (-not $line) {
                    continue
                }
                
                # Check if we're entering a table
                if ($line -match '^\|.*\|$') {
                    # Check if this is the header row we want
                    if ($line -match 'Device.*System\s+Model.*System\s+SKU' -or 
                        $line -match 'Device.*System Model.*System SKU') {
                        $inTable = $true
                        $headerFound = $true
                        Write-Host "  Found table header" -ForegroundColor DarkGray
                        continue
                    }
                    
                    # Skip the separator line (|---|---|---|)
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
                        
                        # We expect at least 3 cells (Device, System Model, System SKU)
                        if ($cells.Count -ge 3) {
                            $device = $cells[0].Trim()
                            $systemModel = $cells[1].Trim()
                            $systemSku = $cells[2].Trim()
                            
                            # Only add if we have a Surface device
                            if ($device -match 'Surface' -and $device -notmatch '^\s*$') {
                                $devices += @{
                                    Device = $device
                                    SystemModel = $systemModel
                                    SystemSKU = $systemSku
                                }
                                
                                Write-Host "  Found: $device" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
        }
        else {
            Write-Host "Found $($tableMatches.Count) HTML table(s), parsing..." -ForegroundColor Green
            
            foreach ($tableMatch in $tableMatches) {
                $tableHtml = $tableMatch.Value
                
                # Check if this table contains Surface device information
                if ($tableHtml -match 'Surface' -and ($tableHtml -match 'System.*Model' -or $tableHtml -match 'System.*SKU')) {
                    Write-Host "Processing Surface device table..." -ForegroundColor Cyan
                    
                    # Parse HTML table rows
                    $rowMatches = [regex]::Matches($tableHtml, '<tr[^>]*>(.*?)</tr>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    
                    $isHeaderProcessed = $false
                    
                    foreach ($rowMatch in $rowMatches) {
                        $rowHtml = $rowMatch.Groups[1].Value
                        
                        # Extract cell contents
                        $cellMatches = [regex]::Matches($rowHtml, '<t[hd][^>]*>(.*?)</t[hd]>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        
                        if ($cellMatches.Count -ge 3) {
                            $device = [System.Web.HttpUtility]::HtmlDecode($cellMatches[0].Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' '
                            $systemModel = [System.Web.HttpUtility]::HtmlDecode($cellMatches[1].Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' '
                            $systemSku = [System.Web.HttpUtility]::HtmlDecode($cellMatches[2].Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' '
                            
                            # Skip header row
                            if ($device -match 'Device' -and $systemModel -match 'Model' -and $systemSku -match 'SKU') {
                                $isHeaderProcessed = $true
                                continue
                            }
                            
                            # Only process data rows after header
                            if ($isHeaderProcessed -and $device -match 'Surface' -and $device -notmatch '^\s*$') {
                                # Clean up the values
                                $device = $device.Trim()
                                $systemModel = $systemModel.Trim()
                                $systemSku = $systemSku.Trim()
                                
                                # Skip Consumer devices
                                if ($device -match 'Consumer') {
                                    Write-Verbose "Skipping Consumer device: $device"
                                    continue
                                }
                                
                                # Skip Surface 3 devices
                                if ($device -match '^Surface 3\b') {
                                    Write-Verbose "Skipping Surface 3 device: $device"
                                    continue
                                }
                                
                                # Create device object
                                $shortDeviceName = Get-ShortDeviceName -DeviceName $device
                                
                                # Skip if Get-ShortDeviceName returns null (for excluded devices)
                                if ($null -eq $shortDeviceName) {
                                    Write-Verbose "Skipping excluded device: $device"
                                    continue
                                }
                                
                                $deviceObj = [PSCustomObject]@{
                                    Device = $device
                                    SystemModel = if ($systemModel -and $systemModel -ne '-' -and $systemModel -ne 'N/A') { $systemModel } else { "N/A" }
                                    SystemSKU = if ($systemSku -and $systemSku -ne '-' -and $systemSku -ne 'N/A') { $systemSku } else { "N/A" }
                                    ShortDevice = $shortDeviceName
                                }
                                
                                $devices += $deviceObj
                                Write-Host "  Found: $device" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
        }
        
        # Remove duplicates based on all three properties
        $uniqueDevices = $devices | Sort-Object Device, SystemModel, SystemSKU -Unique
        
        Write-Host "`nTotal unique devices found: $($uniqueDevices.Count)" -ForegroundColor Yellow
        
        # Display summary by device type
        $deviceTypes = $uniqueDevices | Group-Object { ($_.Device -split ' ')[0..1] -join ' ' } | Sort-Object Name
        Write-Host "`nDevice Summary:" -ForegroundColor Cyan
        foreach ($type in $deviceTypes) {
            Write-Host "  $($type.Name): $($type.Count) models" -ForegroundColor Gray
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
        Write-Error "Failed to get Surface SKU data from Microsoft Learn: $_"
        return $null
    }
}

# Function to display the data in a nice table format
function Show-SurfaceSkuTable {
    <#
    .SYNOPSIS
    Displays Surface SKU data in a formatted table
    
    .PARAMETER SkuData
    The SKU data array from Get-SurfaceSkuFromGitHub
    
    .PARAMETER DeviceFilter
    Optional filter for specific device types (e.g., "Surface Pro", "Surface Laptop")
    
    .EXAMPLE
    Show-SurfaceSkuTable -SkuData $skuData
    Show-SurfaceSkuTable -SkuData $skuData -DeviceFilter "Surface Pro"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$SkuData,
        
        [Parameter(Mandatory = $false)]
        [string]$DeviceFilter
    )
    
    $displayData = $SkuData
    
    if ($DeviceFilter) {
        $displayData = $SkuData | Where-Object { $_.Device -like "*$DeviceFilter*" }
        Write-Host "Filtering for: $DeviceFilter" -ForegroundColor Yellow
    }
    
    $displayData | Format-Table -AutoSize
}

# Function to export to CSV
function Export-SurfaceSkuToCsv {
    <#
    .SYNOPSIS
    Exports Surface SKU data to CSV file
    
    .PARAMETER SkuData
    The SKU data array from Get-SurfaceSkuFromGitHub
    
    .PARAMETER Path
    Path to save the CSV file
    
    .EXAMPLE
    Export-SurfaceSkuToCsv -SkuData $skuData -Path ".\SurfaceSkus.csv"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$SkuData,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $SkuData | Export-Csv -Path $Path -NoTypeInformation
        Write-Host "Data exported to CSV: $Path" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to export to CSV: $_"
    }
}

# Add this function before the Main execution section
function Get-ShortDeviceName {
    <#
    .SYNOPSIS
    Creates a shortened, normalized device name
    
    .DESCRIPTION
    Removes inch specifications (13.5", 15", etc.), standardizes processor names,
    removes the word "Commercial", and adds parentheses around LTE/Wi-Fi.
    Special handling for Surface Laptop 7th Edition and Surface Pro 11th Edition.
    
    .PARAMETER DeviceName
    The original device name
    
    .EXAMPLE
    Get-ShortDeviceName "Surface Laptop 5 13.5" Intel"
    Returns: "Surface Laptop 5 with Intel processor"
    
    .EXAMPLE
    Get-ShortDeviceName "Surface Go 2 Commercial"
    Returns: "Surface Go 2"
    
    .EXAMPLE
    Get-ShortDeviceName "Surface Go 3 LTE"
    Returns: "Surface Go 3 (LTE)"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceName
    )
    
    # Skip Surface Pro 12-inch 1st Edition devices
    if ($DeviceName -match 'Surface Pro 12-inch 1st Edition') {
        return $null
    }
    
    # Skip Surface Hub devices
    if ($DeviceName -match 'Surface Hub') {
        return $null
    }
    
    $shortName = $DeviceName
    
    # Remove inch specifications (handles various formats)
    $shortName = $shortName -replace '\s*\d+(\.\d+)?["″]\s*', ' '
    $shortName = $shortName -replace '\s*\(\d+(\.\d+)?["″]\)\s*', ' '
    
    # Remove "Commercial" from the name
    $shortName = $shortName -replace '\s*Commercial\s*', ' '
    
    # Handle Surface Go 2, 3, and 4 specifically
    if ($shortName -match 'Surface Go 2') {
        $shortName = 'Surface Go 2'
    }
    elseif ($shortName -match 'Surface Go 3') {
        $shortName = 'Surface Go 3'
    }
    elseif ($shortName -match 'Surface Go 4') {
        $shortName = 'Surface Go 4'
    }
    # Handle Surface Pro 10 with 5G specifically
    elseif ($shortName -match '^Surface Pro 10 with 5G') {
        $shortName = 'Surface Pro 10 with 5G'
    }
    # Handle Surface Pro with 5G, 11th Edition specifically
    elseif ($shortName -match 'Surface Pro with 5G,?\s*11th Edition') {
        $shortName = 'Surface Pro 11th Edition, Intel processor'
    }
    # Handle Surface Pro 9 with 5G specifically
    elseif ($shortName -match '^Surface Pro 9 with 5G') {
        $shortName = 'Surface Pro 9 with Intel processor'
    }
    # Handle Surface Pro 9 specifically (not with 5G)
    elseif ($shortName -match '^Surface Pro 9\s*$') {
        $shortName = 'Surface Pro 9 with Intel processor'
    }
    # Handle Surface Laptop 7th Edition specifically
    elseif ($shortName -match 'Surface Laptop.*7th Edition') {
        if ($shortName -match 'Intel') {
            $shortName = 'Surface Laptop 7th Edition, Intel processor'
        }
        elseif ($shortName -match 'Snapdragon') {
            $shortName = 'Surface Laptop 7th Edition, Snapdragon processor'
        }
    }
    # Handle Surface Pro 11th Edition specifically
    elseif ($shortName -match 'Surface Pro 11') {
        if ($shortName -match 'Intel') {
            $shortName = 'Surface Pro 11th Edition, Intel processor'
        }
        elseif ($shortName -match 'Snapdragon') {
            $shortName = 'Surface Pro 11th Edition, Snapdragon processor'
        }
    }
    # Handle other devices with standard processor naming
    else {
        # Standardize processor names
        if ($shortName -match '\s+Intel\s*$') {
            $shortName = $shortName -replace '\s+Intel\s*$', ' with Intel processor'
        }
        elseif ($shortName -match '\s+AMD\s*$') {
            $shortName = $shortName -replace '\s+AMD\s*$', ' with AMD processor'
        }
        elseif ($shortName -match '\s+Intel\s+') {
            $shortName = $shortName -replace '\s+Intel\s+', ' with Intel processor '
        }
        elseif ($shortName -match '\s+AMD\s+') {
            $shortName = $shortName -replace '\s+AMD\s+', ' with AMD processor '
        }
    }
    
    # Add parentheses around LTE and Wi-Fi
    if ($shortName -match '\s+LTE\s*$') {
        $shortName = $shortName -replace '\s+LTE\s*$', ' (LTE)'
    }
    elseif ($shortName -match '\s+LTE\s+') {
        $shortName = $shortName -replace '\s+LTE\s+', ' (LTE) '
    }
    
    if ($shortName -match '\s+Wi-Fi\s*$') {
        $shortName = $shortName -replace '\s+Wi-Fi\s*$', ' (Wi-Fi)'
    }
    elseif ($shortName -match '\s+Wi-Fi\s+') {
        $shortName = $shortName -replace '\s+Wi-Fi\s+', ' (Wi-Fi) '
    }
    
    # Clean up extra spaces
    $shortName = $shortName -replace '\s+', ' '
    $shortName = $shortName.Trim()
    
    # Remove double "processor processor" if it exists (from the JSON example)
    $shortName = $shortName -replace 'processor processor', 'processor'
    
    return $shortName
}

# Main execution
Write-Host "Surface SKU Reference Parser" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# Get the SKU data
$skuData = Get-SurfaceSkuFromGitHub

if ($skuData) {
    # Save the SKU data to JSON
    $jsonPath = Join-Path $PSScriptRoot "SurfaceSKUs.json"
    if ($OutputJSON) {
        $skuData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
        Write-Host "`nExported SKU data to: $jsonPath" -ForegroundColor Green
    }
    Write-Host "`nSKU data exported to JSON: $jsonPath" -ForegroundColor Green
    
    # Display summary
    Write-Host "`nTotal devices found: $($skuData.Count)" -ForegroundColor Yellow
    
    # Show sample data
    Write-Host "`nSample data:" -ForegroundColor Cyan
    $skuData | Select-Object -First 5 | Format-Table Device, SystemModel, SystemSKU, ShortDevice -AutoSize
    
    # Usage examples
    Write-Host "`nUse these commands to work with the data:" -ForegroundColor Yellow
    Write-Host '  $skuData | Format-Table -AutoSize' -ForegroundColor White
    Write-Host '  $skuData | Where-Object { $_.Device -like "*Surface Go*" }' -ForegroundColor White
    Write-Host '  $skuData | Export-Csv -Path ".\SurfaceSkus.csv" -NoTypeInformation' -ForegroundColor White
    Write-Host '  Show-SurfaceSkuTable -SkuData $skuData -DeviceFilter "Surface Pro"' -ForegroundColor White
}
else {
    Write-Error "Failed to retrieve Surface SKU data"
}

    return $skuData
}

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
function Match-SurfaceData {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $OutputJSON,
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $extradebug,
    [Parameter(Mandatory = $false)]
    [PSObject]$SkuData,
    [Parameter(Mandatory = $false)]
    [PSObject]$URLData
    )
    
    Write-Host "Loading SKU data..." -ForegroundColor Yellow
    if ($SkuData) {
        $skuData = $SkuData
    }
    else {
        $skuData = Build-MSSurfaceSKUList
    }
    $skuData = Build-MSSurfaceSKUList
    
    Write-Host "Loading Driver Pack data..." -ForegroundColor Yellow
    if ($URLData) {
        $driverData = $URLData
    }
    else {
        $URLData = Build-MSSurfaceURLList
    }

    Write-Host "Found $($skuData.Count) SKUs and $($URLData.Count) driver packs" -ForegroundColor Green
    
    # Create a lookup table for driver packs
    $driverLookup = @{}
    foreach ($driver in $URLData) {
        # Skip if device name is null or empty
        if ([string]::IsNullOrWhiteSpace($driver.Device)) {
            Write-Warning "Skipping driver entry with no device name"
            continue
        }
        
        # Create multiple keys for better matching
        $keys = @()
        
        # Add the full device name as a key
        $keys += $driver.Device
        
        # Add simplified version without parentheses content
        $simplifiedName = $driver.Device -replace '\s*\([^)]+\)', ''
        if (-not [string]::IsNullOrWhiteSpace($simplifiedName)) {
            $keys += $simplifiedName
        }
        
        # Add version without "Surface" prefix for partial matching
        $withoutSurface = $driver.Device -replace '^Surface\s+', ''
        if (-not [string]::IsNullOrWhiteSpace($withoutSurface)) {
            $keys += $withoutSurface
        }
        
        foreach ($key in $keys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
            if (-not $driverLookup.ContainsKey($key)) {
                $driverLookup[$key] = $driver
            }
        }
    }
    
    Write-Host "Created lookup table with $($driverLookup.Count) entries" -ForegroundColor Green
    
    # Function to find best matching driver pack
    function Find-MatchingDriverPack {
        param($skuDevice, $shortDevice)
        
        # Validate inputs
        if ([string]::IsNullOrWhiteSpace($skuDevice)) {
            return $null
        }
        
        # Try exact match first
        if ($driverLookup.ContainsKey($skuDevice)) {
            return $driverLookup[$skuDevice]
        }
        
        # Try short device name
        if (-not [string]::IsNullOrWhiteSpace($shortDevice) -and $driverLookup.ContainsKey($shortDevice)) {
            return $driverLookup[$shortDevice]
        }
        
        # Try partial matching
        $potentialMatches = @()
        
        foreach ($key in $driverLookup.Keys) {
            # Check if SKU device contains driver key or vice versa
            if ($skuDevice -like "*$key*" -or $key -like "*$skuDevice*") {
                $potentialMatches += $driverLookup[$key]
            }
            elseif (-not [string]::IsNullOrWhiteSpace($shortDevice) -and 
            ($shortDevice -like "*$key*" -or $key -like "*$shortDevice*")) {
                $potentialMatches += $driverLookup[$key]
            }
        }
        
        # Return the first match if any found
        if ($potentialMatches.Count -gt 0) {
            return $potentialMatches[0]
        }
        
        # Special case matching for common patterns
        $patterns = @{
            'Pro 11' = 'Pro 11th Edition'
            'Pro 10' = 'Pro 10'
            'Pro 9' = 'Pro 9'
            'Pro 8' = 'Pro 8'
            'Pro 7\+' = 'Pro 7+'
            'Pro 7' = 'Pro 7'
            'Pro 6' = 'Pro 6'
            'Pro 5' = 'Pro 5'
            'Pro 4' = 'Pro 4'
            'Pro 3' = 'Pro 3'
            'Laptop 7' = 'Laptop 7th Edition'
            'Laptop 6' = 'Laptop 6'
            'Laptop 5' = 'Laptop 5'
            'Laptop 4' = 'Laptop 4'
            'Laptop 3' = 'Laptop 3'
            'Laptop 2' = 'Laptop 2'
            'Laptop Go 3' = 'Laptop Go 3'
            'Laptop Go 2' = 'Laptop Go 2'
            'Laptop Go' = 'Laptop Go'
            'Laptop Studio 2' = 'Laptop Studio 2'
            'Laptop Studio' = 'Laptop Studio'
            'Book 3' = 'Book 3'
            'Book 2' = 'Book 2'
            'Book' = 'Book'
            'Go 4' = 'Go 4'
            'Go 3' = 'Go 3'
            'Go 2' = 'Go 2'
            'Go' = 'Go'
            'Studio 2\+' = 'Studio 2+'
            'Studio 2' = 'Studio 2'
            'Studio' = 'Studio'
            'Hub 2S' = 'Hub 2S'
            'Hub 3' = 'Hub 3'
        }
        
        foreach ($pattern in $patterns.Keys) {
            if ($skuDevice -match $pattern -or (-not [string]::IsNullOrWhiteSpace($shortDevice) -and $shortDevice -match $pattern)) {
                $searchKey = "Surface " + $patterns[$pattern]
                if ($driverLookup.ContainsKey($searchKey)) {
                    return $driverLookup[$searchKey]
                }
                
                # Try variations
                foreach ($key in $driverLookup.Keys) {
                    if ($key -like "*$($patterns[$pattern])*") {
                        return $driverLookup[$key]
                    }
                }
            }
        }
        
        return $null
    }
    
    # Combine the data
    $combinedData = @()
    $matchedCount = 0
    $unmatchedCount = 0
    
    foreach ($sku in $skuData) {
        # Skip invalid SKU entries
        if ([string]::IsNullOrWhiteSpace($sku.Device)) {
            Write-Warning "Skipping SKU entry with no device name"
            continue
        }
        
        $matchingDriver = Find-MatchingDriverPack -skuDevice $sku.Device -shortDevice $sku.ShortDevice
        
        if ($matchingDriver) {
            $matchedCount++
            $matchStatus = "Matched"
        } else {
            $unmatchedCount++
            $matchStatus = "No Match"
        }
        
        $combinedObj = [PSCustomObject]@{
            # SKU Information
            Device = $sku.Device
            ShortDevice = $sku.ShortDevice
            SystemModel = $sku.SystemModel
            SystemSKU = $sku.SystemSKU
            
            # Driver Pack Information
            DriverPackDevice = if ($matchingDriver) { $matchingDriver.Device } else { $null }
            MsiDownloadUrl = if ($matchingDriver) { $matchingDriver.MsiDownloadUrl } else { $null }
            DownloadId = if ($matchingDriver) { $matchingDriver.DownloadId } else { $null }
            
            # Match Status
            MatchStatus = $matchStatus
        }
        
        $combinedData += $combinedObj
    }
    
    Write-Host "`nMatching Results:" -ForegroundColor Yellow
    Write-Host "  Matched: $matchedCount SKUs" -ForegroundColor Green
    Write-Host "  Unmatched: $unmatchedCount SKUs" -ForegroundColor Red
    
    # Export combined data
    if ($OutputJSON) {
        Write-Host "Exporting combined data to JSON..." -ForegroundColor Yellow
        $outputPath = Join-Path $PSScriptRoot "SurfaceDeviceDetails.json"
        $combinedData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
        Write-Host "`nExported combined data to: $outputPath" -ForegroundColor Green
    } else {
        Write-Host "Use -OutputJSON to export the combined data to a JSON file" -ForegroundColor Yellow
    }
    if ($extradebug) {
        # Show summary by device type
        Write-Host "`nSummary by Device Type:" -ForegroundColor Yellow
        $deviceGroups = $combinedData | ForEach-Object {
            $deviceType = if ($_.Device -match 'Surface (Pro|Laptop|Book|Go|Studio|Hub)') { $Matches[1] } else { "Other" }
            [PSCustomObject]@{
                DeviceType = $deviceType
                Device = $_
            }
        }
        
        $deviceGroups | Group-Object DeviceType | Sort-Object Name | ForEach-Object {
            $matched = ($_.Group | Where-Object { $_.Device.MatchStatus -eq "Matched" }).Count
            $total = $_.Count
            $percentage = if ($total -gt 0) { [math]::Round(($matched / $total) * 100, 1) } else { 0 }
            Write-Host "  Surface $($_.Name): $matched/$total matched ($percentage%)" -ForegroundColor Cyan
        }
        
        # Show unmatched SKUs
        $unmatched = $combinedData | Where-Object { $_.MatchStatus -eq "No Match" }
        if ($unmatched.Count -gt 0) {
            Write-Host "`nUnmatched SKUs (first 20):" -ForegroundColor Yellow
            $unmatched | Select-Object -First 20 | ForEach-Object {
                Write-Host "  - $($_.Device) [$($_.ShortDevice)]" -ForegroundColor Red
            }
            if ($unmatched.Count -gt 20) {
                Write-Host "  ... and $($unmatched.Count - 20) more" -ForegroundColor Red
            }
        }
        
        # Show matched examples
        Write-Host "`nMatched Examples:" -ForegroundColor Yellow
        $combinedData | Where-Object { $_.MsiDownloadUrl } | Select-Object -First 5 | ForEach-Object {
            Write-Host "  SKU: $($_.Device)" -ForegroundColor Green
            Write-Host "    Short Name: $($_.ShortDevice)" -ForegroundColor DarkGray
            Write-Host "    → Driver: $($_.DriverPackDevice)" -ForegroundColor DarkGray
            Write-Host "    → URL: $($_.MsiDownloadUrl)" -ForegroundColor DarkGray
        }
    }
    return $combinedData
}
