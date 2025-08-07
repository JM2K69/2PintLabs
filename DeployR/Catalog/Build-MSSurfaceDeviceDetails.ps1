# Script to combine Surface SKU data with Driver Pack URLs

function Match-SurfaceData {
    param(
        [string]$SkuJsonPath = (Join-Path $PSScriptRoot "SurfaceSKUs.json"),
        [string]$DriverJsonPath = (Join-Path $PSScriptRoot "SurfaceDriverURLs.json")
    )
    
    Write-Host "`nSurface Data Matcher" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    
    # Load the JSON files
    if (-not (Test-Path $SkuJsonPath)) {
        Write-Error "SKU JSON file not found: $SkuJsonPath"
        Write-Host "Please run MSSurfaceSKU.ps1 first" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $DriverJsonPath)) {
        Write-Error "Driver JSON file not found: $DriverJsonPath"
        Write-Host "Please run MSSurfaceDriverPack.ps1 first" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Loading SKU data..." -ForegroundColor Yellow
    $skuData = Get-Content $SkuJsonPath | ConvertFrom-Json
    
    Write-Host "Loading Driver Pack data..." -ForegroundColor Yellow
    $driverData = Get-Content $DriverJsonPath | ConvertFrom-Json
    
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
    $outputPath = Join-Path $PSScriptRoot "SurfaceCombinedData.json"
    $combinedData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Host "`nExported combined data to: $outputPath" -ForegroundColor Green
    
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
    
    return $combinedData
}

# Main execution
try {
    $combinedData = Match-SurfaceData
    
    if ($combinedData) {
        Write-Host "`nCombined data successfully created!" -ForegroundColor Green
        Write-Host "Use the SurfaceCombinedData.json file for further processing." -ForegroundColor Cyan
    }
}
catch {
    Write-Error "Failed to combine Surface data: $_"
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}