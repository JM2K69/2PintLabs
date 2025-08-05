# Surface Driver MSI Catalog Builder
# Purpose: Build a comprehensive catalog of Surface devices with their actual MSI download URLs

# Import or source the MSSurfaceDriverPack.ps1 if it exists
$driverPackScript = Join-Path $PSScriptRoot "MSSurfaceDriverPack.ps1"
if (Test-Path $driverPackScript) {
    . $driverPackScript
}

function Get-MsiUrlFromDownloadPage {
    <#
    .SYNOPSIS
    Extracts the actual MSI download URLs (Win10 and Win11) from a Microsoft download page
    
    .PARAMETER DownloadPageUrl
    The URL of the Microsoft download page
    
    .PARAMETER DeviceName
    The name of the device (for logging purposes)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadPageUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$DeviceName = "Unknown Device"
    )
    
    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    }
    
    try {
        # Handle "Not Available" links
        if ($DownloadPageUrl -eq "Not Available") {
            return @{
                Win10MsiUrl = "Not Available"
                Win10MsiFileName = "N/A"
                Win10Version = "N/A"
                Win11MsiUrl = "Not Available"
                Win11MsiFileName = "N/A"
                Win11Version = "N/A"
                DatePublished = "N/A"
                Status = "No download link"
            }
        }
        
        Write-Verbose "Processing download page for: $DeviceName"
        
        # Initialize results
        $results = @{
            Win10MsiUrl = "Not Found"
            Win10MsiFileName = "N/A"
            Win10Version = "N/A"
            Win11MsiUrl = "Not Found"
            Win11MsiFileName = "N/A"
            Win11Version = "N/A"
            DatePublished = "N/A"
            Status = ""
        }
        
        # Extract download ID if present
        $downloadId = $null
        if ($DownloadPageUrl -match 'id=(\d+)') {
            $downloadId = $Matches[1]
        }
        
        # Get the download page to extract metadata
        $pageContent = $null
        try {
            $pageResponse = Invoke-WebRequest -Uri $DownloadPageUrl -UseBasicParsing -Headers $headers -TimeoutSec 20
            $pageContent = $pageResponse.Content
            
            # Extract Date Published
            $datePatterns = @(
                'Date\s*Published:\s*</[^>]+>\s*([^<]+)',
                'Published\s*Date:\s*</[^>]+>\s*([^<]+)',
                'Release\s*Date:\s*</[^>]+>\s*([^<]+)',
                '<span[^>]*>Date\s*Published:</span>\s*<span[^>]*>([^<]+)</span>',
                'data-date="([^"]+)"',
                '"datePublished":\s*"([^"]+)"'
            )
            
            foreach ($pattern in $datePatterns) {
                if ($pageContent -match $pattern) {
                    $dateStr = $Matches[1].Trim()
                    # Clean up the date
                    $dateStr = $dateStr -replace '&#x2F;', '/'
                    $dateStr = $dateStr -replace '&nbsp;', ' '
                    $results.DatePublished = $dateStr
                    Write-Verbose "Found Date Published: $dateStr"
                    break
                }
            }
            
            # Extract Version information
            $versionPatterns = @(
                'Version:\s*</[^>]+>\s*([^<]+)',
                'File\s*Version:\s*</[^>]+>\s*([^<]+)',
                '<span[^>]*>Version:</span>\s*<span[^>]*>([^<]+)</span>',
                '"version":\s*"([^"]+)"',
                'data-version="([^"]+)"'
            )
            
            $versionFound = $false
            foreach ($pattern in $versionPatterns) {
                if ($pageContent -match $pattern) {
                    $version = $Matches[1].Trim()
                    # This is a general version, we'll try to get specific ones later
                    if (-not $versionFound) {
                        $results.Win10Version = $version
                        $results.Win11Version = $version
                        $versionFound = $true
                        Write-Verbose "Found Version: $version"
                    }
                    break
                }
            }
        }
        catch {
            Write-Verbose "Failed to get page metadata: $_"
        }
        
        # Method 1: Try confirmation page directly
        if ($downloadId) {
            $confirmUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=$downloadId"
            Write-Verbose "Trying confirmation page: $confirmUrl"
            
            try {
                $response = Invoke-WebRequest -Uri $confirmUrl -UseBasicParsing -Headers $headers -TimeoutSec 20
                
                # Look for all MSI download links
                $msiPattern = 'https://download\.microsoft\.com/download/[^"]+\.msi'
                $msiMatches = [regex]::Matches($response.Content, $msiPattern)
                
                foreach ($match in $msiMatches) {
                    $msiUrl = $match.Value
                    $msiFileName = Split-Path -Leaf $msiUrl
                    
                    # Try to extract version from filename
                    $fileVersion = "N/A"
                    if ($msiFileName -match '(\d+\.\d+\.\d+\.\d+)' -or 
                        $msiFileName -match '(\d+\.\d+\.\d+)' -or 
                        $msiFileName -match '_(\d+\.\d+)_') {
                        $fileVersion = $Matches[1]
                    }
                    
                    # Determine if it's Win10 or Win11 based on filename or context
                    $isWin10 = $false
                    $isWin11 = $false
                    
                    # Check filename patterns
                    if ($msiFileName -match 'Win10|Windows10|_10_|W10') {
                        $isWin10 = $true
                    }
                    elseif ($msiFileName -match 'Win11|Windows11|_11_|W11') {
                        $isWin11 = $true
                    }
                    else {
                        # Check surrounding context in HTML
                        $contextStart = [Math]::Max(0, $match.Index - 200)
                        $contextLength = [Math]::Min(400, $response.Content.Length - $contextStart)
                        $context = $response.Content.Substring($contextStart, $contextLength)
                        
                        if ($context -match 'Windows\s*10|Win\s*10') {
                            $isWin10 = $true
                        }
                        elseif ($context -match 'Windows\s*11|Win\s*11') {
                            $isWin11 = $true
                        }
                        else {
                            # Default to Win10 if only one file found or unclear
                            if ($msiMatches.Count -eq 1) {
                                $isWin10 = $true
                            }
                        }
                    }
                    
                    # Store the results
                    if ($isWin10 -and $results.Win10MsiUrl -eq "Not Found") {
                        $results.Win10MsiUrl = $msiUrl
                        $results.Win10MsiFileName = $msiFileName
                        if ($fileVersion -ne "N/A") {
                            $results.Win10Version = $fileVersion
                        }
                    }
                    elseif ($isWin11 -and $results.Win11MsiUrl -eq "Not Found") {
                        $results.Win11MsiUrl = $msiUrl
                        $results.Win11MsiFileName = $msiFileName
                        if ($fileVersion -ne "N/A") {
                            $results.Win11Version = $fileVersion
                        }
                    }
                    elseif (-not $isWin10 -and -not $isWin11) {
                        # If we can't determine, store in Win10 if empty, otherwise Win11
                        if ($results.Win10MsiUrl -eq "Not Found") {
                            $results.Win10MsiUrl = $msiUrl
                            $results.Win10MsiFileName = $msiFileName
                            if ($fileVersion -ne "N/A") {
                                $results.Win10Version = $fileVersion
                            }
                        }
                        elseif ($results.Win11MsiUrl -eq "Not Found") {
                            $results.Win11MsiUrl = $msiUrl
                            $results.Win11MsiFileName = $msiFileName
                            if ($fileVersion -ne "N/A") {
                                $results.Win11Version = $fileVersion
                            }
                        }
                    }
                }
                
                if ($results.Win10MsiUrl -ne "Not Found" -or $results.Win11MsiUrl -ne "Not Found") {
                    $results.Status = "Found via confirmation page"
                }
            }
            catch {
                Write-Verbose "Confirmation page failed: $_"
            }
        }
        
        # Method 2: Try the original download page if we haven't found both
        if ($results.Win10MsiUrl -eq "Not Found" -or $results.Win11MsiUrl -eq "Not Found") {
            Write-Verbose "Trying original page: $DownloadPageUrl"
            try {
                $response = Invoke-WebRequest -Uri $DownloadPageUrl -UseBasicParsing -Headers $headers -TimeoutSec 20
                
                # Look for all MSI links
                $msiPattern = 'https://download\.microsoft\.com/download/[^"]+\.msi'
                $msiMatches = [regex]::Matches($response.Content, $msiPattern)
                
                # If no direct MSI links found, try other patterns
                if ($msiMatches.Count -eq 0) {
                    Write-Verbose "No direct MSI links found, trying alternative patterns..."
                    
                    # Pattern for download links that might redirect to MSI
                    $downloadPatterns = @(
                        'href="([^"]+)"[^>]*>Download</a>',
                        'href="([^"]+)"[^>]*>\s*Download\s*</a>',
                        'class="[^"]*download[^"]*"[^>]*href="([^"]+)"',
                        'data-bi-name="downloadbutton"[^>]*href="([^"]+)"',
                        '<a[^>]+href="([^"]+)"[^>]*>[^<]*Download[^<]*</a>'
                    )
                    
                    foreach ($pattern in $downloadPatterns) {
                        if ($response.Content -match $pattern) {
                            $downloadLink = $Matches[1]
                            Write-Verbose "Found download link: $downloadLink"
                            
                            # Fix relative URLs
                            if ($downloadLink -notmatch '^https?://') {
                                $uri = [System.Uri]$DownloadPageUrl
                                $downloadLink = "$($uri.Scheme)://$($uri.Host)$downloadLink"
                            }
                            
                            # Follow the download link
                            Write-Verbose "Following download link..."
                            $dlResponse = Invoke-WebRequest -Uri $downloadLink -UseBasicParsing -Headers $headers -TimeoutSec 20 -MaximumRedirection 5
                            
                            # Check if the response is an MSI file
                            if ($dlResponse.Headers['Content-Type'] -match 'application/.*msi' -or 
                                $dlResponse.Headers['Content-Disposition'] -match '\.msi') {
                                # This is the MSI file
                                $msiUrl = $downloadLink
                                $msiFileName = "Unknown.msi"
                                
                                # Try to get filename from Content-Disposition
                                if ($dlResponse.Headers['Content-Disposition'] -match 'filename="?([^"]+\.msi)"?') {
                                    $msiFileName = $Matches[1]
                                }
                                
                                # Store in appropriate slot
                                if ($results.Win10MsiUrl -eq "Not Found") {
                                    $results.Win10MsiUrl = $msiUrl
                                    $results.Win10MsiFileName = $msiFileName
                                    $results.Status = "Found via download button redirect"
                                }
                                
                                break
                            }
                            # Check response content for MSI links
                            elseif ($dlResponse.Content -match $msiPattern) {
                                $msiMatches = [regex]::Matches($dlResponse.Content, $msiPattern)
                                # Process matches...
                            }
                        }
                    }
                    
                    # Also check for file listings in tables or lists
                    if ($results.Win10MsiUrl -eq "Not Found") {
                        # Look for MSI files in any context
                        $filePatterns = @(
                            '([^">\s]+\.msi)',
                            'href="([^"]+)"[^>]*>([^<]+\.msi)</a>',
                            '<td[^>]*>([^<]+\.msi)</td>'
                        )
                        
                        foreach ($pattern in $filePatterns) {
                            if ($response.Content -match $pattern) {
                                $msiRef = $Matches[1]
                                if ($msiRef -match '\.msi$') {
                                    # Build full URL if needed
                                    if ($msiRef -notmatch '^https?://') {
                                        $msiRef = "https://download.microsoft.com/download/" + $msiRef.TrimStart('/')
                                    }
                                    
                                    $results.Win10MsiUrl = $msiRef
                                    $results.Win10MsiFileName = Split-Path -Leaf $msiRef
                                    $results.Status = "Found MSI reference on page"
                                    break
                                }
                            }
                        }
                    }
                }
                else {
                    # Process the MSI matches we found
                    foreach ($match in $msiMatches) {
                        $msiUrl = $match.Value
                        $msiFileName = Split-Path -Leaf $msiUrl
                        
                        # Skip if we already have this file
                        if ($msiUrl -eq $results.Win10MsiUrl -or $msiUrl -eq $results.Win11MsiUrl) {
                            continue
                        }
                        
                        # Determine Windows version
                        $isWin10 = $false
                        $isWin11 = $false
                        
                        if ($msiFileName -match 'Win10|Windows10|_10_|W10') {
                            $isWin10 = $true
                        }
                        elseif ($msiFileName -match 'Win11|Windows11|_11_|W11') {
                            $isWin11 = $true
                        }
                        else {
                            # Check context
                            $contextStart = [Math]::Max(0, $match.Index - 200)
                            $contextLength = [Math]::Min(400, $response.Content.Length - $contextStart)
                            $context = $response.Content.Substring($contextStart, $contextLength)
                            
                            if ($context -match 'Windows\s*10|Win\s*10') {
                                $isWin10 = $true
                            }
                            elseif ($context -match 'Windows\s*11|Win\s*11') {
                                $isWin11 = $true
                            }
                            else {
                                # Default to Win10 for older devices like Surface 3
                                $isWin10 = $true
                            }
                        }
                        
                        # Store results
                        if ($isWin10 -and $results.Win10MsiUrl -eq "Not Found") {
                            $results.Win10MsiUrl = $msiUrl
                            $results.Win10MsiFileName = $msiFileName
                        }
                        elseif ($isWin11 -and $results.Win11MsiUrl -eq "Not Found") {
                            $results.Win11MsiUrl = $msiUrl
                            $results.Win11MsiFileName = $msiFileName
                        }
                    }
                    
                    if ($results.Status -eq "" -and ($results.Win10MsiUrl -ne "Not Found" -or $results.Win11MsiUrl -ne "Not Found")) {
                        $results.Status = "Found on download page"
                    }
                }
            }
            catch {
                Write-Verbose "Original page failed: $_"
            }
        }
        
        # Set final status
        if ($results.Status -eq "") {
            if ($results.Win10MsiUrl -eq "Not Found" -and $results.Win11MsiUrl -eq "Not Found") {
                $results.Status = "No MSI found on page"
            }
        }
        else {
            # Append info about what was found
            $found = @()
            if ($results.Win10MsiUrl -ne "Not Found") { $found += "Win10" }
            if ($results.Win11MsiUrl -ne "Not Found") { $found += "Win11" }
            $results.Status += " (" + ($found -join " & ") + ")"
        }
        
        return $results
    }
    catch {
        Write-Warning "Failed to process $DeviceName : $_"
        return @{
            Win10MsiUrl = "Error"
            Win10MsiFileName = "N/A"
            Win10Version = "N/A"
            Win11MsiUrl = "Error"
            Win11MsiFileName = "N/A"
            Win11Version = "N/A"
            DatePublished = "N/A"
            Status = "Error: $_"
        }
    }
}

function Build-SurfaceMsiCatalog {
    <#
    .SYNOPSIS
    Builds a complete catalog of Surface devices with their MSI download information
    
    .DESCRIPTION
    Uses functions from MSSurfaceDriverPack.ps1 to get device info and then 
    follows all download links to find actual MSI files
    
    .PARAMETER OutputPath
    Optional path to save the catalog
    
    .PARAMETER SkipMsiLookup
    Skip the MSI lookup phase (useful for testing)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\SurfaceMsiCatalog_$(Get-Date -Format 'yyyyMMdd_HHmmss').json",
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipMsiLookup
    )
    
    Write-Host "Surface MSI Catalog Builder" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Get driver information from GitHub
    Write-Host "Step 1: Getting Surface driver information from GitHub..." -ForegroundColor Yellow
    
    try {
        $driverData = Get-SurfaceDriverInfoFromGitHub
        
        if (-not $driverData -or $driverData.Count -eq 0) {
            Write-Error "No driver data retrieved from GitHub"
            return $null
        }
        
        Write-Host "Found $($driverData.Count) Surface devices" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to get driver data: $_"
        return $null
    }
    
    # Step 2: Process each device to get MSI URLs
    if (-not $SkipMsiLookup) {
        Write-Host "`nStep 2: Following download links to find MSI files..." -ForegroundColor Yellow
        Write-Host "This may take several minutes..." -ForegroundColor DarkGray
        
        $catalog = @()
        $processedUrls = @{}
        $counter = 0
        
        foreach ($device in $driverData) {
            $counter++
            $percentComplete = [int](($counter / $driverData.Count) * 100)
            Write-Progress -Activity "Processing Surface devices" -Status "$counter of $($driverData.Count)" -PercentComplete $percentComplete -CurrentOperation $device.Device
            
            Write-Host "`n[$counter/$($driverData.Count)] Processing: $($device.Device)" -ForegroundColor Cyan
            
            # Check if we've already processed this URL
            if ($processedUrls.ContainsKey($device.DownloadLink)) {
                $msiInfo = $processedUrls[$device.DownloadLink]
                Write-Host "  Using cached result" -ForegroundColor DarkGray
            }
            else {
                # Get MSI information
                $msiInfo = Get-MsiUrlFromDownloadPage -DownloadPageUrl $device.DownloadLink -DeviceName $device.Device
                $processedUrls[$device.DownloadLink] = $msiInfo
                
                # Rate limiting
                Start-Sleep -Milliseconds 500
            }
            
            # Build catalog entry
            $entry = [PSCustomObject]@{
                Device = $device.Device
                DownloadPageUrl = $device.DownloadLink
                DownloadID = $device.DownloadID
                DatePublished = $msiInfo.DatePublished
                Win10MsiUrl = $msiInfo.Win10MsiUrl
                Win10MsiFileName = $msiInfo.Win10MsiFileName
                Win10Version = $msiInfo.Win10Version
                Win11MsiUrl = $msiInfo.Win11MsiUrl
                Win11MsiFileName = $msiInfo.Win11MsiFileName
                Win11Version = $msiInfo.Win11Version
                Status = $msiInfo.Status
                ProcessedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $catalog += $entry
            
            # Display result
            if ($msiInfo.Win10MsiUrl -eq "Not Available" -and $msiInfo.Win11MsiUrl -eq "Not Available") {
                Write-Host "  No download available" -ForegroundColor DarkGray
            }
            elseif ($msiInfo.Win10MsiUrl -eq "Not Found" -and $msiInfo.Win11MsiUrl -eq "Not Found") {
                Write-Host "  No MSI found on page" -ForegroundColor Yellow
            }
            elseif ($msiInfo.Win10MsiUrl -eq "Error" -or $msiInfo.Win11MsiUrl -eq "Error") {
                Write-Host "  Error processing page" -ForegroundColor Red
            }
            else {
                if ($msiInfo.DatePublished -ne "N/A") {
                    Write-Host "  Date Published: $($msiInfo.DatePublished)" -ForegroundColor DarkGray
                }
                if ($msiInfo.Win10MsiUrl -ne "Not Found" -and $msiInfo.Win10MsiUrl -ne "Error") {
                    Write-Host "  Found Win10: $($msiInfo.Win10MsiFileName) (v$($msiInfo.Win10Version))" -ForegroundColor Green
                }
                if ($msiInfo.Win11MsiUrl -ne "Not Found" -and $msiInfo.Win11MsiUrl -ne "Error") {
                    Write-Host "  Found Win11: $($msiInfo.Win11MsiFileName) (v$($msiInfo.Win11Version))" -ForegroundColor Green
                }
            }
        }
        
        Write-Progress -Activity "Processing Surface devices" -Completed
    }
    else {
        # Skip MSI lookup - just use driver data
        $catalog = $driverData | ForEach-Object {
            [PSCustomObject]@{
                Device = $_.Device
                DownloadPageUrl = $_.DownloadLink
                DownloadID = $_.DownloadID
                DatePublished = "Skipped"
                Win10MsiUrl = "Skipped"
                Win10MsiFileName = "Skipped"
                Win10Version = "Skipped"
                Win11MsiUrl = "Skipped"
                Win11MsiFileName = "Skipped"
                Win11Version = "Skipped"
                Status = "MSI lookup skipped"
                ProcessedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
    
    # Step 3: Summary and output
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    $summary = $catalog | Group-Object { 
        if ($_.Win10MsiUrl -eq "Not Available" -and $_.Win11MsiUrl -eq "Not Available") { "No Download Link" }
        elseif ($_.Win10MsiUrl -eq "Not Found" -and $_.Win11MsiUrl -eq "Not Found") { "No MSI Found" }
        elseif ($_.Win10MsiUrl -eq "Error" -or $_.Win11MsiUrl -eq "Error") { "Error" }
        elseif ($_.Win10MsiUrl -eq "Skipped" -and $_.Win11MsiUrl -eq "Skipped") { "Skipped" }
        elseif ($_.Win10MsiUrl -ne "Not Found" -and $_.Win10MsiUrl -ne "Error" -and $_.Win10MsiUrl -ne "Not Available" -and 
                $_.Win11MsiUrl -ne "Not Found" -and $_.Win11MsiUrl -ne "Error" -and $_.Win11MsiUrl -ne "Not Available") { "Both Win10 & Win11 Found" }
        elseif ($_.Win10MsiUrl -ne "Not Found" -and $_.Win10MsiUrl -ne "Error" -and $_.Win10MsiUrl -ne "Not Available") { "Only Win10 Found" }
        elseif ($_.Win11MsiUrl -ne "Not Found" -and $_.Win11MsiUrl -ne "Error" -and $_.Win11MsiUrl -ne "Not Available") { "Only Win11 Found" }
        else { "Unknown" }
    }
    
    foreach ($group in $summary | Sort-Object Name) {
        $color = switch ($group.Name) {
            "Both Win10 & Win11 Found" { "Green" }
            "Only Win10 Found" { "Green" }
            "Only Win11 Found" { "Green" }
            "No Download Link" { "DarkGray" }
            "No MSI Found" { "Yellow" }
            "Error" { "Red" }
            "Skipped" { "Cyan" }
            default { "White" }
        }
        Write-Host "$($group.Name): $($group.Count) devices" -ForegroundColor $color
    }
    
    Write-Host "`nTotal devices processed: $($catalog.Count)" -ForegroundColor Yellow
    
    # Save to file
    $catalog | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`nCatalog saved to: $OutputPath" -ForegroundColor Green
    
    # Also save as CSV for easy viewing
    $csvPath = $OutputPath -replace '\.json$', '.csv'
    $catalog | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "CSV version saved to: $csvPath" -ForegroundColor Green
    
    return $catalog
}

# Function to display catalog in a nice format
function Show-SurfaceMsiCatalog {
    <#
    .SYNOPSIS
    Displays the Surface MSI catalog in a formatted table
    
    .PARAMETER Catalog
    The catalog array from Build-SurfaceMsiCatalog
    
    .PARAMETER Filter
    Optional filter (e.g., "Surface Pro", "MSI Found", etc.)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Catalog,
        
        [Parameter(Mandatory = $false)]
        [string]$Filter
    )
    
    $displayData = $Catalog
    
    if ($Filter) {
        $displayData = $Catalog | Where-Object { 
            $_.Device -like "*$Filter*" -or 
            $_.Status -like "*$Filter*" 
        }
        Write-Host "Filtering for: $Filter" -ForegroundColor Yellow
    }
    
    $displayData | Select-Object Device, DatePublished, Win10Version, Win11Version, Status | Format-Table -AutoSize
}

function Merge-SurfaceCatalogWithSKU {
    <#
    .SYNOPSIS
    Merges Surface MSI catalog with SKU information to add System Model and System SKU
    
    .DESCRIPTION
    Cross-references the device names from the MSI catalog with SKU data to enrich
    the catalog with System Model and System SKU information
    
    .PARAMETER MsiCatalog
    The MSI catalog from Build-SurfaceMsiCatalog
    
    .PARAMETER SkuData
    The SKU data from Get-SurfaceSkuFromGitHub
    
    .PARAMETER OutputPath
    Optional path to save the merged catalog
    
    .EXAMPLE
    $skuData = Get-SurfaceSkuFromGitHub
    $mergedCatalog = Merge-SurfaceCatalogWithSKU -MsiCatalog $catalog -SkuData $skuData
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$MsiCatalog,
        
        [Parameter(Mandatory = $true)]
        [array]$SkuData,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\SurfaceMergedCatalog_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    )
    
    Write-Host "Merging Surface MSI Catalog with SKU Information..." -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Cyan
    
    $mergedCatalog = @()
    $matchedCount = 0
    $unmatchedDevices = @()
    
    foreach ($device in $MsiCatalog) {
        # Skip non-device entries
        if ($device.Device -match "Manage Windows updates|Surface Hub|Thunderbolt|Dock") {
            Write-Verbose "Skipping non-device entry: $($device.Device)"
            
            # Create entry without SKU info
            $mergedEntry = [PSCustomObject]@{
                Device = $device.Device
                SystemModel = "N/A"
                SystemSKU = "N/A"
                DownloadPageUrl = $device.DownloadPageUrl
                DownloadID = $device.DownloadID
                DatePublished = $device.DatePublished
                Win10MsiUrl = $device.Win10MsiUrl
                Win10MsiFileName = $device.Win10MsiFileName
                Win10Version = $device.Win10Version
                Win11MsiUrl = $device.Win11MsiUrl
                Win11MsiFileName = $device.Win11MsiFileName
                Win11Version = $device.Win11Version
                Status = $device.Status
                ProcessedDate = $device.ProcessedDate
            }
            
            $mergedCatalog += $mergedEntry
            continue
        }
        
        # Initialize as not found
        $systemModel = "Not Found"
        $systemSKU = "Not Found"
        $matched = $false
        
        # Clean device name for matching
        $cleanDeviceName = $device.Device -replace '\s*\(.*?\)\s*', ' ' -replace '\s+', ' '
        $cleanDeviceName = $cleanDeviceName.Trim()
        
        Write-Verbose "Looking for SKU match for: $($device.Device)"
        
        # Try exact match first
        $skuMatch = $SkuData | Where-Object { $_.Device -eq $device.Device }
        
        if (-not $skuMatch) {
            # Try various matching strategies
            
            # Strategy 1: Remove everything in parentheses and match
            $skuMatch = $SkuData | Where-Object { 
                $cleanSku = $_.Device -replace '\s*\(.*?\)\s*', ' ' -replace '\s+', ' '
                $cleanSku.Trim() -eq $cleanDeviceName
            }
            
            # Strategy 2: Match based on core device name
            if (-not $skuMatch) {
                # Extract core device name (e.g., "Surface Pro 9" from "Surface Pro 9 with Intel processor")
                if ($cleanDeviceName -match '^(Surface\s+\w+\s*\d*\+?)') {
                    $coreDeviceName = $Matches[1].Trim()
                    
                    $skuMatch = $SkuData | Where-Object { 
                        $_.Device -like "$coreDeviceName*" -or $_.Device -eq $coreDeviceName
                    }
                }
            }
            
            # Strategy 3: Handle special cases
            if (-not $skuMatch) {
                switch -Regex ($device.Device) {
                    "Surface Pro (\d+)" {
                        $version = $Matches[1]
                        $skuMatch = $SkuData | Where-Object { 
                            $_.Device -match "Surface Pro $version(?!\d)" -and 
                            $_.Device -notmatch "Surface Pro $version\+"
                        }
                    }
                    "Surface Laptop (\d+)" {
                        $version = $Matches[1]
                        $skuMatch = $SkuData | Where-Object { 
                            $_.Device -match "Surface Laptop $version(?!\d)"
                        }
                    }
                    "Surface Book (\d+)" {
                        $version = $Matches[1]
                        $skuMatch = $SkuData | Where-Object { 
                            $_.Device -match "Surface Book $version(?!\d)"
                        }
                    }
                    "Surface Go (\d+)" {
                        $version = $Matches[1]
                        $skuMatch = $SkuData | Where-Object { 
                            $_.Device -match "Surface Go $version(?!\d)"
                        }
                    }
                    "Surface Studio (\d+\+?)" {
                        $version = $Matches[1]
                        $skuMatch = $SkuData | Where-Object { 
                            $_.Device -match "Surface Studio $version"
                        }
                    }
                    # Handle versioned editions
                    "(\d+)(st|nd|rd|th) Edition" {
                        $edition = $Matches[1]
                        if ($device.Device -match "Surface Pro") {
                            $skuMatch = $SkuData | Where-Object { 
                                $_.Device -match "Surface Pro $edition(?!\d)"
                            }
                        }
                        elseif ($device.Device -match "Surface Laptop") {
                            $skuMatch = $SkuData | Where-Object { 
                                $_.Device -match "Surface Laptop $edition(?!\d)"
                            }
                        }
                    }
                }
            }
            
            # Strategy 4: Handle LTE/WiFi/5G variants
            if (-not $skuMatch -and $device.Device -match "(LTE|Wi-Fi|5G)") {
                $baseDevice = $device.Device -replace '\s*\(.*?\)\s*', ''
                $skuMatch = $SkuData | Where-Object { 
                    $_.Device -like "$baseDevice*"
                }
            }
        }
        
        # If we found matches, use the first one (or handle multiple)
        if ($skuMatch) {
            if ($skuMatch.Count -gt 1) {
                Write-Verbose "Multiple SKU matches found for $($device.Device): $($skuMatch.Count) matches"
                # Use the most specific match (usually the one with the exact same name)
                $bestMatch = $skuMatch | Where-Object { $_.Device -eq $device.Device } | Select-Object -First 1
                if (-not $bestMatch) {
                    $bestMatch = $skuMatch | Select-Object -First 1
                }
                $skuMatch = $bestMatch
            }
            
            $systemModel = $skuMatch.SystemModel
            $systemSKU = $skuMatch.SystemSKU
            $matched = $true
            $matchedCount++
            
            Write-Host "  Matched: $($device.Device) -> Model: $systemModel, SKU: $systemSKU" -ForegroundColor Green
        }
        else {
            $unmatchedDevices += $device.Device
            Write-Host "  No match found for: $($device.Device)" -ForegroundColor Yellow
        }
        
        # Create merged entry
        $mergedEntry = [PSCustomObject]@{
            Device = $device.Device
            SystemModel = $systemModel
            SystemSKU = $systemSKU
            DownloadPageUrl = $device.DownloadPageUrl
            DownloadID = $device.DownloadID
            DatePublished = $device.DatePublished
            Win10MsiUrl = $device.Win10MsiUrl
            Win10MsiFileName = $device.Win10MsiFileName
            Win10Version = $device.Win10Version
            Win11MsiUrl = $device.Win11MsiUrl
            Win11MsiFileName = $device.Win11MsiFileName
            Win11Version = $device.Win11Version
            Status = $device.Status
            ProcessedDate = $device.ProcessedDate
        }
        
        $mergedCatalog += $mergedEntry
    }
    
    # Summary
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "Merge Summary:" -ForegroundColor Cyan
    Write-Host "Total devices processed: $($MsiCatalog.Count)" -ForegroundColor Yellow
    Write-Host "Successfully matched: $matchedCount" -ForegroundColor Green
    Write-Host "Unmatched devices: $($unmatchedDevices.Count)" -ForegroundColor Red
    
    if ($unmatchedDevices.Count -gt 0) {
        Write-Host "`nUnmatched devices:" -ForegroundColor Yellow
        $unmatchedDevices | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    
    # Save merged catalog
    $mergedCatalog | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`nMerged catalog saved to: $OutputPath" -ForegroundColor Green
    
    # Also save as CSV
    $csvPath = $OutputPath -replace '\.json$', '.csv'
    $mergedCatalog | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "CSV version saved to: $csvPath" -ForegroundColor Green
    
    return $mergedCatalog
}

# Main execution
Write-Host "Loading Surface MSI Catalog Builder..." -ForegroundColor Cyan

# Check if driver pack script functions are available
if (-not (Get-Command Get-SurfaceDriverInfoFromGitHub -ErrorAction SilentlyContinue)) {
    Write-Warning "MSSurfaceDriverPack.ps1 functions not found. Please ensure the script is loaded."
    Write-Host "You can source it using: . .\MSSurfaceDriverPack.ps1" -ForegroundColor Yellow
    return
}

# Check if SKU script functions are available
$skuScriptPath = Join-Path $PSScriptRoot "MSSurfaceSKU.ps1"
if (Test-Path $skuScriptPath) {
    . $skuScriptPath
}

if (-not (Get-Command Get-SurfaceSkuFromGitHub -ErrorAction SilentlyContinue)) {
    Write-Warning "MSSurfaceSKU.ps1 functions not found. SKU merging will not be available."
    Write-Host "You can source it using: . .\MSSurfaceSKU.ps1" -ForegroundColor Yellow
}

# Build the catalog
$catalog = Build-SurfaceMsiCatalog

if ($catalog) {
    Write-Host "`nCatalog built successfully!" -ForegroundColor Green
    
    # Try to get SKU data and merge if available
    if (Get-Command Get-SurfaceSkuFromGitHub -ErrorAction SilentlyContinue) {
        Write-Host "`nFetching SKU information..." -ForegroundColor Yellow
        $skuData = Get-SurfaceSkuFromGitHub
        
        if ($skuData) {
            Write-Host "`nMerging with SKU data..." -ForegroundColor Yellow
            $mergedCatalog = Merge-SurfaceCatalogWithSKU -MsiCatalog $catalog -SkuData $skuData
            
            Write-Host "`nUse these commands to work with the merged catalog:" -ForegroundColor Yellow
            Write-Host '  $mergedCatalog | Format-Table Device, SystemModel, SystemSKU, Status -AutoSize' -ForegroundColor White
            Write-Host '  $mergedCatalog | Where-Object { $_.SystemModel -ne "Not Found" }' -ForegroundColor White
            Write-Host '  $mergedCatalog | Export-Excel -Path ".\SurfaceMergedCatalog.xlsx" -AutoSize' -ForegroundColor White
            
            # Show sample
            Write-Host "`nSample merged data:" -ForegroundColor Cyan
            $mergedCatalog | Where-Object { $_.SystemModel -ne "Not Found" -and $_.SystemModel -ne "N/A" } | 
                Select-Object Device, SystemModel, SystemSKU, Status -First 5 | Format-Table -AutoSize
        }
        else {
            Write-Warning "Failed to get SKU data"
        }
    }
    else {
        Write-Host "`nSKU data not available. Use the following commands to work with the catalog:" -ForegroundColor Yellow
        Write-Host '  $catalog | Format-Table -AutoSize' -ForegroundColor White
        Write-Host '  $catalog | Where-Object { $_.Win10MsiUrl -ne "Not Found" -or $_.Win11MsiUrl -ne "Not Found" }' -ForegroundColor White
        Write-Host '  Show-SurfaceMsiCatalog -Catalog $catalog -Filter "Surface Pro"' -ForegroundColor White
        Write-Host '  $catalog | Export-Excel -Path ".\SurfaceCatalog.xlsx" -AutoSize' -ForegroundColor White
        
        # Show sample
        Write-Host "`nSample data (devices with MSI found):" -ForegroundColor Cyan
        $catalog | Where-Object { ($_.Win10MsiUrl -notmatch "Not Found|Not Available|Error" -or $_.Win11MsiUrl -notmatch "Not Found|Not Available|Error") } | 
            Select-Object -First 5 | Format-Table -AutoSize
    }
}