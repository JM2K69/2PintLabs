# Script to launch things that I find useful for DeployR

#Functions

Write-Host "Loading DeployR Functions" -ForegroundColor Cyan
write-host "Function: Get-DeployRGather" -ForegroundColor Green
function Get-DeployRGather {
    iex (irm "https://gather.garytown.com")
}

function Get-CMOSDGather {
    $Script = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Josch62/Gather-Script-For-ConfigMgr-TS/refs/heads/main/Gather.ps1" -UseBasicParsing
    $Script | Out-File -FilePath "$env:temp\CMOSD-Gather.ps1" -Force -Encoding UTF8
    powershell.exe "$env:temp\CMOSD-Gather.ps1" -debug $true
}
write-host "Function: Invoke-DeployRTS" -ForegroundColor Green
write-host" Common Servers I Use:" -ForegroundColor magenta
write-host "  - 214-deployr.2p.garytown.com" -ForegroundColor Green
write-host "  - recover01.2pintsoftware.com" -ForegroundColor Green
write-host "  - dr.2pintlabs.com" -ForegroundColor Green
write-host "===================================================================="
function Invoke-DeployRTS{
    param(
        [string]$ServerName,
        [string]$TSID
    )


    Write-Host "Invoking DeployR TS" -ForegroundColor Cyan
    if (-not $ServerName) {
        Write-Host "ServerName is not provided, using default: 214-deployr.2p.garytown.com" -ForegroundColor Yellow
        $ServerName = "214-deployr.2p.garytown.com"
    }
    if (($ServerName) -and (-not $TSID)) {
        Write-Host "ServerName: $ServerName" -ForegroundColor Yellow
        iex (irm "https://$($ServerName):7281/v1/Service/Bootstrap")
    }
    if (($ServerName) -and ($TSID)) {
        Write-Host "ServerName: $ServerName" -ForegroundColor Yellow
        Write-Host "TSID: $TSID" -ForegroundColor Yellow
        iex (irm "https://$($ServerName):7281/v1/Service/Bootstrap?tsid=$($TSID):1")
    }
    # Add logic here to use $ServerName and $TSID as needed
}
