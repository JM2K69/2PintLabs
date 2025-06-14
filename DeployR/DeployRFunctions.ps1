# Script to launch things that I find useful for DeployR

#Functions

Write-Host "Loading DeployR Functions" -ForegroundColor Cyan
write-host "Function: Get-DeployRGather" -ForegroundColor Green
function Get-DeployRGather {
    iex (irm "https://gather.garytown.com")
}

