#https://learn.microsoft.com/en-us/surface/manage-surface-driver-and-firmware-updates
#https://learn.microsoft.com/en-us/surface/surface-system-sku-reference

function Get-SurfaceDriverInfo {
    <#
    .SYNOPSIS
    Retrieves Surface driver information including Model Name, SKU, and MSI download URLs
    
    .DESCRIPTION
    This function creates a table of Surface devices with their model names, SKUs, and driver MSI download URLs
    
    .PARAMETER OutputPath
    Optional path to export the results to a CSV file
    
    .EXAMPLE
    Get-SurfaceDriverInfo
    
    .EXAMPLE
    Get-SurfaceDriverInfo -OutputPath "C:\Temp\SurfaceDrivers.csv"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    try {
        # Step 1: Get all Surface models and SKUs from the SKU reference page
        Write-Host "Step 1: Fetching Surface models and SKUs..." -ForegroundColor Cyan
        
        $SkuUrl = "https://learn.microsoft.com/en-us/surface/surface-system-sku-reference"
        $SkuRequest = Invoke-WebRequest -Uri $SkuUrl -UseBasicParsing
        $SkuContent = $SkuRequest.Content
        
        $SurfaceModels = @()
        
        # Parse SKU tables to extract model names and SKUs
        $TablePattern = '<table[^>]*>.*?</table>'
        $Tables = [regex]::Matches($SkuContent, $TablePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        foreach ($Table in $Tables) {
            $TableContent = $Table.Value
            
            # Look for rows containing Surface models and SKUs
            $RowPattern = '<tr[^>]*>.*?</tr>'
            $Rows = [regex]::Matches($TableContent, $RowPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            
            foreach ($Row in $Rows) {
                $RowContent = $Row.Value
                
                # Skip header rows
                if ($RowContent -match '<th[^>]*>') {
                    continue
                }
                
                # Extract cell data
                $CellPattern = '<td[^>]*>(.*?)</td>'
                $Cells = [regex]::Matches($RowContent, $CellPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
                
                if ($Cells.Count -ge 2) {
                    $ModelName = $null
                    $Sku = $null
                    
                    # Extract model name and SKU from cells
                    foreach ($i in 0..($Cells.Count - 1)) {
                        $CellContent = [System.Web.HttpUtility]::HtmlDecode($Cells[$i].Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' '
                        $CellContent = $CellContent.Trim()
                        
                        # Look for Surface model names
                        if ($CellContent -match 'Surface\s+[^,\r\n]+') {
                            $ModelName = $Matches[0].Trim()
                        }
                        
                        # Look for SKU patterns (alphanumeric codes, typically 4-10 characters)
                        if ($CellContent -match '\b[A-Z0-9]{4,10}\b' -and $CellContent -notmatch 'Surface|Windows|Intel|AMD|GB|TB|MHz|GHz') {
                            $Sku = $CellContent
                        }
                    }
                    
                    # Add to our collection if we have both model and SKU
                    if ($ModelName -and $Sku) {
                        $SurfaceInfo = [PSCustomObject]@{
                            ModelName = $ModelName
                            SKU = $Sku
                            DriverMsiUrl = $null  # Will be filled in Step 2
                        }
                        
                        $SurfaceModels += $SurfaceInfo
                        Write-Host "Found: $ModelName - SKU: $Sku" -ForegroundColor Green
                    }
                }
            }
        }
        
        Write-Host "Found $($SurfaceModels.Count) Surface model/SKU combinations" -ForegroundColor Yellow
        
        # Step 2: Get driver download URLs from the driver management page
        Write-Host "`nStep 2: Fetching driver download URLs..." -ForegroundColor Cyan
        
        $DriverUrl = "https://learn.microsoft.com/en-us/surface/manage-surface-driver-and-firmware-updates"
        $DriverRequest = Invoke-WebRequest -Uri $DriverUrl -UseBasicParsing
        $DriverContent = $DriverRequest.Content
        
        # Create a mapping of model names to download URLs
        $ModelToUrlMapping = @{
        }
        
        # Parse driver page for download links
        $TablePattern = '<table[^>]*>.*?</table>'
        $Tables = [regex]::Matches($DriverContent, $TablePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        foreach ($Table in $Tables) {
            $TableContent = $Table.Value
            
            # Look for rows containing Surface models and download links
            $RowPattern = '<tr[^>]*>.*?</tr>'
            $Rows = [regex]::Matches($TableContent, $RowPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            
            foreach ($Row in $Rows) {
                $RowContent = $Row.Value
                
                # Skip header rows
                if ($RowContent -match '<th[^>]*>') {
                    continue
                }
                
                # Extract cell data
                $CellPattern = '<td[^>]*>(.*?)</td>'
                $Cells = [regex]::Matches($RowContent, $CellPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
                
                $ModelName = $null
                $DownloadUrl = $null
                
                foreach ($Cell in $Cells) {
                    $CellContent = $Cell.Groups[1].Value
                    
                    # Extract model name
                    $CleanContent = [System.Web.HttpUtility]::HtmlDecode($CellContent) -replace '<[^>]+>', '' -replace '\s+', ' '
                    $CleanContent = $CleanContent.Trim()
                    
                    if ($CleanContent -match 'Surface\s+[^,\r\n]+') {
                        $ModelName = $Matches[0].Trim()
                    }
                    
                    # Look for download links
                    $LinkPattern = 'href="([^"]+)"'
                    $Links = [regex]::Matches($CellContent, $LinkPattern)
                    
                    foreach ($Link in $Links) {
                        $Url = $Link.Groups[1].Value
                        
                        # Check if this looks like a download page
                        if ($Url -match 'microsoft\.com.*download' -or $Url -match 'download\.microsoft\.com') {
                            $DownloadUrl = $Url
                            
                            # Convert relative URLs to absolute
                            if ($DownloadUrl -match '^/') {
                                $DownloadUrl = "https://learn.microsoft.com" + $DownloadUrl
                            }
                            break
                        }
                    }
                }
                
                # Store the mapping
                if ($ModelName -and $DownloadUrl) {
                    Write-Host "Found download link for: $ModelName" -ForegroundColor Green
                    $ModelToUrlMapping[$ModelName] = $DownloadUrl
                }
            }
        }
        
        # Step 3: Follow download links to get actual MSI URLs
        Write-Host "`nStep 3: Following download links to get MSI URLs..." -ForegroundColor Cyan
        
        $ModelToMsiMapping = @{
        }
        
        foreach ($ModelName in $ModelToUrlMapping.Keys) {
            $DownloadPageUrl = $ModelToUrlMapping[$ModelName]
            
            try {
                Write-Host "Processing download page for: $ModelName" -ForegroundColor Yellow
                
                $Headers = @{
                    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
                
                $DownloadPageRequest = Invoke-WebRequest -Uri $DownloadPageUrl -UseBasicParsing -TimeoutSec 15 -Headers $Headers
                
                # Look for MSI download links
                $MsiPattern = 'https://download\.microsoft\.com/[^"\s]+\.msi'
                $MsiMatches = [regex]::Matches($DownloadPageRequest.Content, $MsiPattern)
                
                if ($MsiMatches.Count -gt 0) {
                    $MsiUrl = $MsiMatches[0].Value
                    $ModelToMsiMapping[$ModelName] = $MsiUrl
                    Write-Host "✓ Found MSI for $ModelName" -ForegroundColor Green
                } else {
                    Write-Warning "No MSI found for $ModelName"
                    $ModelToMsiMapping[$ModelName] = "No MSI found"
                }
            }
            catch {
                Write-Warning "Could not process download page for $ModelName : $($_.Exception.Message)"
                $ModelToMsiMapping[$ModelName] = "Error retrieving MSI"
            }
        }
        
        # Step 4: Match SKUs with MSI URLs using fuzzy matching
        Write-Host "`nStep 4: Matching SKUs with MSI URLs..." -ForegroundColor Cyan
        
        foreach ($Surface in $SurfaceModels) {
            $BestMatch = $null
            
            # Try exact match first
            if ($ModelToMsiMapping.ContainsKey($Surface.ModelName)) {
                $Surface.DriverMsiUrl = $ModelToMsiMapping[$Surface.ModelName]
                continue
            }
            
            # Try fuzzy matching
            foreach ($DriverModelName in $ModelToMsiMapping.Keys) {
                # Clean up model names for comparison
                $CleanSurfaceModel = $Surface.ModelName -replace '[^\w\s]', '' -replace '\s+', ' '
                $CleanDriverModel = $DriverModelName -replace '[^\w\s]', '' -replace '\s+', ' '
                
                # Check for partial matches
                if ($CleanSurfaceModel -like "*$CleanDriverModel*" -or $CleanDriverModel -like "*$CleanSurfaceModel*") {
                    $BestMatch = $DriverModelName
                    break
                }
                
                # Check for core model name matches (e.g., "Surface Pro" matches "Surface Pro 7")
                $CoreSurfaceModel = ($CleanSurfaceModel -split '\s+')[0..1] -join ' '
                $CoreDriverModel = ($CleanDriverModel -split '\s+')[0..1] -join ' '
                
                if ($CoreSurfaceModel -eq $CoreDriverModel) {
                    $BestMatch = $DriverModelName
                    break
                }
            }
            
            if ($BestMatch) {
                $Surface.DriverMsiUrl = $ModelToMsiMapping[$BestMatch]
                Write-Host "Matched $($Surface.ModelName) with $BestMatch" -ForegroundColor Cyan
            } else {
                $Surface.DriverMsiUrl = "No matching driver found"
                Write-Warning "No matching driver found for $($Surface.ModelName)"
            }
        }
        
        # Display results
        Write-Host "`n=== Surface Driver Catalog ===" -ForegroundColor Cyan
        Write-Host "Found $($SurfaceModels.Count) Surface model/SKU combinations" -ForegroundColor Green
        
        # Display results table
        $SurfaceModels | Format-Table -Property ModelName, SKU, DriverMsiUrl -AutoSize
        
        # Export to CSV if requested
        if ($OutputPath) {
            try {
                $SurfaceModels | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to export to CSV: $($_.Exception.Message)"
            }
        }
        
        return $SurfaceModels
    }
    catch {
        Write-Error "Failed to retrieve Surface driver information: $($_.Exception.Message)"
        return $null
    }
}

# Execute the function
Write-Host "Surface Driver Information Retrieval Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$SurfaceData = Get-SurfaceDriverInfo

Write-Host "`nScript completed. Use -OutputPath parameter to export to CSV." -ForegroundColor Yellow