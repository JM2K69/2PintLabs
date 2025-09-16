$URL = 'https://www.acer.com/sccm/'

# Let's try multiple potential URLs for Acer's driver/SCCM pages
$PotentialURLs = @(
    'https://www.acer.com/sccm/',
    'https://www.acer.com/support/drivers-and-manuals',
    'https://www.acer.com/us-en/support/drivers-and-manuals',
    'https://global-download.acer.com/',
    'https://www.acer.com/support/',
    'https://www.acer.com/drivers/',
    'https://support.acer.com/'
)

function Test-URLAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$URLs
    )
    
    Write-Host "Testing multiple Acer URLs for accessibility..." -ForegroundColor Cyan
    
    foreach ($url in $URLs) {
        Write-Host "`nTesting: $url" -ForegroundColor Yellow
        
        try {
            # Try different methods to test connectivity
            
            # Method 1: Simple HEAD request
            try {
                $headRequest = [System.Net.WebRequest]::Create($url)
                $headRequest.Method = "HEAD"
                $headRequest.Timeout = 10000
                $headRequest.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                $headResponse = $headRequest.GetResponse()
                Write-Host "  ✓ HEAD request successful - Status: $($headResponse.StatusCode)" -ForegroundColor Green
                $headResponse.Close()
            }
            catch {
                Write-Host "  ✗ HEAD request failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Method 2: Test-NetConnection (if available)
            if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
                try {
                    $uri = [System.Uri]$url
                    $testConn = Test-NetConnection -ComputerName $uri.Host -Port 443 -InformationLevel Quiet
                    if ($testConn) {
                        Write-Host "  ✓ Network connection to $($uri.Host):443 successful" -ForegroundColor Green
                    } else {
                        Write-Host "  ✗ Network connection to $($uri.Host):443 failed" -ForegroundColor Red
                    }
                }
                catch {
                    Write-Host "  ✗ Network test failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            # Method 3: Try Invoke-WebRequest (simpler approach)
            try {
                $webResponse = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -ErrorAction Stop
                Write-Host "  ✓ Invoke-WebRequest successful - Status: $($webResponse.StatusCode)" -ForegroundColor Green
                return $url  # Return the first working URL
            }
            catch {
                Write-Host "  ✗ Invoke-WebRequest failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
        }
        catch {
            Write-Host "  ✗ General error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $null
}

function Get-AcerDriverCatalogSimple {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURL
    )
    
    try {
        Write-Host "Attempting to access: $BaseURL" -ForegroundColor Cyan
        
        # Use Invoke-WebRequest instead of WebRequest for better compatibility
        $webResponse = Invoke-WebRequest -Uri $BaseURL -TimeoutSec 30 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        Write-Host "✓ Successfully retrieved content" -ForegroundColor Green
        Write-Host "Status Code: $($webResponse.StatusCode)" -ForegroundColor Gray
        Write-Host "Content Length: $($webResponse.Content.Length) characters" -ForegroundColor Gray
        Write-Host "Content Type: $($webResponse.Headers['Content-Type'])" -ForegroundColor Gray
        
        # Save the content for inspection
        $debugPath = ".\AcerPageContent.html"
        $webResponse.Content | Out-File -FilePath $debugPath -Encoding UTF8
        Write-Host "Raw content saved to: $debugPath" -ForegroundColor Cyan
        
        # Look for common Acer driver patterns
        $content = $webResponse.Content
        
        Write-Host "`nAnalyzing content..." -ForegroundColor Yellow
        
        # Check if it's a valid HTML page
        if ($content -match '<html|<HTML') {
            Write-Host "✓ Valid HTML content detected" -ForegroundColor Green
        } else {
            Write-Host "⚠ Content may not be HTML" -ForegroundColor Yellow
        }
        
        # Look for driver-related keywords
        $driverKeywords = @('driver', 'download', 'support', 'bios', 'firmware', 'cab', 'zip', 'sccm', 'model')
        $foundKeywords = @()
        
        foreach ($keyword in $driverKeywords) {
            if ($content -match $keyword) {
                $foundKeywords += $keyword
            }
        }
        
        Write-Host "Driver-related keywords found: $($foundKeywords -join ', ')" -ForegroundColor White
        
        # Look for links
        $linkPattern = 'href="([^"]*)"'
        $links = [regex]::Matches($content, $linkPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        Write-Host "Total links found: $($links.Count)" -ForegroundColor White
        
        # Look for potential driver/download links
        $driverLinks = $links | Where-Object { 
            $_.Groups[1].Value -match '(driver|download|support|cab|zip|exe|sccm)' 
        }
        Write-Host "Potential driver/download links: $($driverLinks.Count)" -ForegroundColor White
        
        if ($driverLinks.Count -gt 0) {
            Write-Host "Sample driver links:" -ForegroundColor Gray
            $driverLinks | Select-Object -First 5 | ForEach-Object {
                Write-Host "  $($_.Groups[1].Value)" -ForegroundColor DarkGray
            }
        }
        
        # Show first few lines of content for manual inspection
        Write-Host "`nFirst 10 lines of content:" -ForegroundColor Yellow
        $contentLines = $content -split "`n"
        $contentLines | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor DarkGray
        }
        
        return @{
            URL = $BaseURL
            StatusCode = $webResponse.StatusCode
            ContentLength = $content.Length
            LinksFound = $links.Count
            DriverLinksFound = $driverLinks.Count
            KeywordsFound = $foundKeywords
            Content = $content
        }
        
    }
    catch {
        Write-Error "Failed to access $BaseURL`: $($_.Exception.Message)"
        
        # Additional debugging for network issues
        if ($_.Exception.Message -match "timeout|timed out") {
            Write-Host "Network timeout - try checking your internet connection or firewall" -ForegroundColor Red
        }
        elseif ($_.Exception.Message -match "SSL|TLS|certificate") {
            Write-Host "SSL/Certificate issue - the site may have certificate problems" -ForegroundColor Red
        }
        elseif ($_.Exception.Message -match "404|Not Found") {
            Write-Host "Page not found - the URL may be incorrect or the page may have moved" -ForegroundColor Red
        }
        elseif ($_.Exception.Message -match "403|Forbidden") {
            Write-Host "Access forbidden - the site may be blocking automated requests" -ForegroundColor Red
        }
        
        return $null
    }
}

function Get-AcerDriverCatalogEnhanced {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURL
    )
    
    try {
        Write-Host "Enhanced Acer catalog scraping from: $BaseURL" -ForegroundColor Cyan
        
        # Try different user agents - some sites block PowerShell's default
        $userAgents = @(
            $null,  # No user agent
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0",
            "curl/7.68.0",  # Simple curl-like agent
            "PowerShell"    # Explicit PowerShell
        )
        
        $successfulContent = $null
        $workingUserAgent = $null
        
        foreach ($userAgent in $userAgents) {
            Write-Host "`nTrying user agent: $($userAgent ?? 'None')" -ForegroundColor Yellow
            
            try {
                $requestParams = @{
                    Uri = $BaseURL
                    TimeoutSec = 30
                    ErrorAction = 'Stop'
                }
                
                if ($userAgent) {
                    $requestParams.UserAgent = $userAgent
                }
                
                $webResponse = Invoke-WebRequest @requestParams
                
                Write-Host "  ✓ Success with this user agent" -ForegroundColor Green
                Write-Host "  Content Length: $($webResponse.Content.Length) characters" -ForegroundColor Gray
                
                $successfulContent = $webResponse.Content
                $workingUserAgent = $userAgent
                break
            }
            catch {
                Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if (-not $successfulContent) {
            throw "All user agent attempts failed"
        }
        
        Write-Host "`nAnalyzing content from successful request..." -ForegroundColor Cyan
        Write-Host "Working User Agent: $($workingUserAgent ?? 'None')" -ForegroundColor Green
        
        # Save the content
        $debugPath = ".\AcerGlobalDownloadContent.html"
        $successfulContent | Out-File -FilePath $debugPath -Encoding UTF8
        Write-Host "Content saved to: $debugPath" -ForegroundColor Cyan
        
        # Look for JavaScript that might load driver data dynamically
        $jsPattern = '<script[^>]*>(.*?)</script>'
        $jsMatches = [regex]::Matches($successfulContent, $jsPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
        Write-Host "JavaScript blocks found: $($jsMatches.Count)" -ForegroundColor White
        
        # Look for AJAX endpoints or API calls in JavaScript
        $apiPatterns = @(
            'api[/"''](.*?)[/"'']',
            'ajax[/"''](.*?)[/"'']',
            'service[/"''](.*?)[/"'']',
            'data[/"''](.*?)[/"'']',
            'driver[/"''](.*?)[/"'']'
        )
        
        $apiEndpoints = @()
        foreach ($pattern in $apiPatterns) {
            $matches = [regex]::Matches($successfulContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $apiEndpoints += $match.Groups[1].Value
            }
        }
        
        if ($apiEndpoints.Count -gt 0) {
            Write-Host "Potential API endpoints found:" -ForegroundColor Yellow
            $apiEndpoints | Select-Object -Unique | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
        
        # Look for form elements that might lead to driver searches
        $formPattern = '<form[^>]*>(.*?)</form>'
        $formMatches = [regex]::Matches($successfulContent, $formPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
        Write-Host "Forms found: $($formMatches.Count)" -ForegroundColor White
        
        # Look for hidden or embedded data
        $dataPatterns = @{
            "JSON Data" = '\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
            "Model References" = '(Aspire|TravelMate|Veriton|Predator|Swift|Spin|Nitro|Extensa|Chromebook)[A-Z0-9\-\s]+'
            "Download URLs" = 'https?://[^\s"''<>]+\.(cab|zip|exe)'
            "Driver Keywords" = '(driver|bios|firmware|package|bundle)'
        }
        
        foreach ($patternName in $dataPatterns.Keys) {
            $matches = [regex]::Matches($successfulContent, $dataPatterns[$patternName], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            Write-Host "$patternName found: $($matches.Count)" -ForegroundColor White
            
            if ($matches.Count -gt 0 -and $matches.Count -le 10) {
                Write-Host "  Samples:" -ForegroundColor Gray
                $matches | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    $($_.Value)" -ForegroundColor DarkGray
                }
            }
        }
        
        return @{
            URL = $BaseURL
            WorkingUserAgent = $workingUserAgent
            ContentLength = $successfulContent.Length
            Content = $successfulContent
            JSBlocks = $jsMatches.Count
            FormsFound = $formMatches.Count
            PotentialAPIEndpoints = $apiEndpoints
        }
        
    }
    catch {
        Write-Error "Enhanced catalog scraping failed: $($_.Exception.Message)"
        return $null
    }
}

function Test-AlternativeAcerURLs {
    Write-Host "Testing alternative Acer driver URLs..." -ForegroundColor Cyan
    
    # More specific Acer driver URLs to try
    $alternativeURLs = @(
        'https://global-download.acer.com/GDFiles/Application/Acer%20Driver%20and%20Application%20Installation%20Disc%20for%20Windows%2010%20and%20Windows%2011/Acer%20Driver%20Installation%20Disc%20for%20Windows%2010%20and%20Windows%2011_Acer_1.0.3013_A.zip',
        'https://global-download.acer.com/GDFiles/',
        'https://www.acer.com/ac/en/US/content/drivers',
        'https://www.acer.com/support',
        'https://community.acer.com/',
        'https://www.acer.com/ac/en/US/content/support',
        'https://global-download.acer.com/GDFiles/BIOS/',
        'https://global-download.acer.com/GDFiles/Driver/',
        'https://global-download.acer.com/GDFiles/Application/'
    )
    
    $workingURLs = @()
    
    foreach ($url in $alternativeURLs) {
        Write-Host "`nTesting: $url" -ForegroundColor Yellow
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 15 -ErrorAction Stop
            Write-Host "  ✓ Accessible - Status: $($response.StatusCode)" -ForegroundColor Green
            $workingURLs += $url
        }
        catch {
            Write-Host "  ✗ Failed: $($_.Exception.Message.Split('.')[0])" -ForegroundColor Red
        }
    }
    
    return $workingURLs
}

function Try-AcerDirectoryListing {
    param([string]$BaseURL)
    
    Write-Host "`nAttempting to get directory listing from: $BaseURL" -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $BaseURL -TimeoutSec 30
        $content = $response.Content
        
        # Look for directory listing patterns
        $directoryPatterns = @(
            '<a href="([^"]+/)">[^<]+</a>',  # Apache-style directory listing
            'href="([^"]+\.(?:cab|zip|exe))"'  # Direct file links
        )
        
        $foundItems = @()
        foreach ($pattern in $directoryPatterns) {
            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $foundItems += $match.Groups[1].Value
            }
        }
        
        if ($foundItems.Count -gt 0) {
            Write-Host "Found $($foundItems.Count) items:" -ForegroundColor Green
            $foundItems | Select-Object -First 10 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor White
            }
        } else {
            Write-Host "No directory listing or files found" -ForegroundColor Yellow
        }
        
        return $foundItems
        
    }
    catch {
        Write-Host "Directory listing failed: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Main execution
Write-Host "=== Enhanced Acer Driver Catalog Builder ===" -ForegroundColor Magenta

# Test the working URL with enhanced analysis
$workingURL = "https://global-download.acer.com/"
$result = Get-AcerDriverCatalogEnhanced -BaseURL $workingURL

if ($result) {
    Write-Host "`nEnhanced analysis completed!" -ForegroundColor Green
    $result | ConvertTo-Json -Depth 3 | Out-File -FilePath ".\AcerEnhancedAnalysis.json" -Encoding UTF8
}

# Test alternative URLs
Write-Host "`n" + "="*60 -ForegroundColor Magenta
$alternativeURLs = Test-AlternativeAcerURLs

if ($alternativeURLs.Count -gt 0) {
    Write-Host "`nFound $($alternativeURLs.Count) working alternative URLs:" -ForegroundColor Green
    $alternativeURLs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    # Try to get directory listings from working URLs
    foreach ($url in $alternativeURLs) {
        if ($url -like "*GDFiles*") {
            $items = Try-AcerDirectoryListing -BaseURL $url
            if ($items.Count -gt 0) {
                Write-Host "`nFound content at $url" -ForegroundColor Green
                break
            }
        }
    }
}

Write-Host "`nRecommendations:" -ForegroundColor Yellow
Write-Host "1. The main Acer site (www.acer.com) has timeouts - likely heavy JavaScript" -ForegroundColor White
Write-Host "2. global-download.acer.com works but may need specific paths" -ForegroundColor White
Write-Host "3. Try browser automation (Selenium) for JavaScript-heavy sites" -ForegroundColor White
Write-Host "4. Check the HTML files generated to see actual content structure" -ForegroundColor White
