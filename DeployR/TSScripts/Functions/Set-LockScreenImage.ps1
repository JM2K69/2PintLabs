<# Set Lock Screen

Replaces Default Windows Lock Screen with your own

DeployR
#>


Function Set-LockScreenImage {
 <#
 .SYNOPSIS
    Sets the Lock Screen Image to a custom image.
 .DESCRIPTION
    This function sets the lock screen image to a custom image, typically downloaded from a URL.
 .PARAMETER exitcode
    The exit code to return after execution.
 .EXAMPLE
    Set-LockScreenImage 
 #>
[CmdletBinding()]
 param(
  [String]$ImageURL,
  [String]$ImageFileName #ASSUMES THIS IMAGE IS IN THE SAME PACKAGE AS THE SCRIPT, OTHERWISE USE THE URL PARAMETER
 )

if ($ImageFileName){
    if (Test-Path .\$ImageFileName){
        Copy-item -Path .\$ImageFileName -Destination "$env:TEMP\lockscreen.jpg" -Force -Verbose
    }
    else{
        Write-Output "Did not find $ImageFileName in current directory - Please confirm ImageFileName is correct."
    }
}
else{
    if ($ImageURL){
        $LockScreenURL = $ImageURL
    }
    else{
        $LockScreenURL = "https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/2PintImages/2pint-desktop-stripes-dark-1920x1080.png"
    }
    Write-Output "Downloading Lock Screen Image from $LockScreenURL"
    #Download the image from the URL
    Invoke-WebRequest -UseBasicParsing -Uri $LockScreenURL -OutFile "$env:TEMP\lockscreen.jpg"
}


#Copy the 2 files into place
if (Test-Path -Path "$env:TEMP\lockscreen.jpg"){
    Write-Output "Running Command: Copy-Item $($env:TEMP)\lockscreen.jpg C:\windows\web\Screen\img100.jpg -Force -Verbose"
    Copy-Item "$env:TEMP\lockscreen.jpg" C:\windows\web\Screen\img100.jpg -Force -Verbose
    Write-Output "Running Command: Copy-Item $($env:TEMP)\lockscreen.jpg C:\windows\web\Screen\img105.jpg -Force -Verbose"
    Copy-Item "$env:TEMP\lockscreen.jpg" C:\windows\web\Screen\img105.jpg -Force -Verbose
    }
else
    {
    Write-Output "Did not find lockscreen.jpg in temp folder - Please confirm URL or ImageFileName is correct."
    }
}

