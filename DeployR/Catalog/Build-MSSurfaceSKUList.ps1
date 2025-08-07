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
    $skuData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
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