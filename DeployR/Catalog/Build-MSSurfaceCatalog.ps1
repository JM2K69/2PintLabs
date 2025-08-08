#region Functions

#Script to combine Surface SKU data with Driver Pack URLs
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
            Write-Host "Fetching Surface SKU data from GitHub..." -ForegroundColor Cyan
            
            $url = "https://raw.githubusercontent.com/microsoftdocs/devices-docs/public/surface/surface-system-sku-reference.md"
            
            # Fetch the markdown content
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
            $content = $response.Content
            
            # Split content into lines
            $lines = $content -split "`n"
            
            $devices = @()
            $inTable = $false
            $headerFound = $false
            
            Write-Host "Parsing markdown content..." -ForegroundColor Yellow
            
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
                                # Clean up the values
                                $device = $device -replace '\*', '' -replace '\s+', ' '
                                $systemModel = $systemModel -replace '\*', '' -replace '\s+', ' '
                                $systemSku = $systemSku -replace '\*', '' -replace '\s+', ' '
                                
                                # Handle special characters and formatting
                                $device = [System.Web.HttpUtility]::HtmlDecode($device)
                                $systemModel = [System.Web.HttpUtility]::HtmlDecode($systemModel)
                                $systemSku = [System.Web.HttpUtility]::HtmlDecode($systemSku)
                                
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
                # Also check for tables that might not have proper markdown formatting
                elseif ($line -match 'Surface\s+\w+.*\d{4}') {
                    # Try to parse lines that look like they contain Surface device info
                    if ($line -match '(Surface[^|]+)\s+([^|]+)\s+(\d{4})') {
                        $device = $Matches[1].Trim()
                        $systemModel = $Matches[2].Trim()
                        $systemSku = $Matches[3].Trim()
                        
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
                        
                        $deviceObj = [PSCustomObject]@{
                            Device = $device
                            SystemModel = $systemModel
                            SystemSKU = $systemSku
                            ShortDevice = Get-ShortDeviceName -DeviceName $device
                        }
                        
                        $devices += $deviceObj
                        Write-Host "  Found (alt format): $device" -ForegroundColor Green
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
            Write-Error "Failed to get Surface SKU data from GitHub: $_"
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
    Builds a list of Microsoft Surface download URLs from the GitHub repository
    
    .DESCRIPTION
    This function fetches the Surface download URL data from the Microsoft Docs GitHub repository,
    parses it, and returns a structured list of Surface devices with their download URLs.
    
    .PARAMETER OutputPath
    Optional path to save the JSON output
    
    .EXAMPLE
    $urlData = Build-MSSurfaceURLList
    Build-MSSurfaceURLList -OutputPath ".\SurfaceURLs.json"
    #>
    
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $OutputJSON
    )
    
    
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
            if (-not $OutputJSON) {
                Write-Host "Use -OutputJSON to export the data to a JSON file" -ForegroundColor Yellow
            }
            else{
                $jsonPath = Join-Path $PSScriptRoot "SurfaceURLs.json"
                $surfaceDevices | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
                Write-Host "`nExported to: $jsonPath" -ForegroundColor Green
            }
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
    
    return $surfaceDevices
}
function Match-SurfaceData {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $OutputJSON,
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $extradebug
    )
    
    Write-Host "Loading SKU data..." -ForegroundColor Yellow
    $skuData = Build-MSSurfaceSKUList
    
    Write-Host "Loading Driver Pack data..." -ForegroundColor Yellow
    $driverData = Build-MSSurfaceURLList
    
    Write-Host "Found $($skuData.Count) SKUs and $($driverData.Count) driver packs" -ForegroundColor Green
    
    # Create a lookup table for driver packs
    $driverLookup = @{}
    foreach ($driver in $driverData) {
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

#endregion

function Get-SurfaceDriverPackMSIUrls {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $OutputJSON,
    [Parameter(Mandatory = $false)]
    [string]$outputPath
    )
    
    Write-Host "`nSurface Driver Pack MSI URL Extractor" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    
    
    Write-Host "Loading combined Surface data..." -ForegroundColor Yellow
    $combinedData = Match-SurfaceData
    
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
    if (-not $OutputJSON) {
        Write-Host "Use -OutputJSON to export the results to a JSON file" -ForegroundColor Yellow
        return $results
    }
    else {
        Write-Host "Exporting results to JSON..." -ForegroundColor Yellow
        if (-not $outputPath) {
            $outputPath = Join-Path $PSScriptRoot "Surface.json"
        }
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Host "`nExported MSI list to: $outputPath" -ForegroundColor Green
    }

    
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



try {
    $msiList = Get-SurfaceDriverPackMSIUrls -OutputJSON
    
    if ($msiList) {
        Write-Host "`nDriver pack MSI list created successfully!" -ForegroundColor Green
        Write-Host "Check SurfaceDriverPackMSIList.json for the complete list." -ForegroundColor Cyan
    }
}
catch {
    Write-Error "Failed to extract MSI URLs: $_"
}