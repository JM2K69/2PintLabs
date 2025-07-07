# This just "imports" The PSDGather module and runs the Get-PSDLocalInfo function so you can see the defaults that would be created during PSD / DeployR execution.
# Gather local system information and return it as a PowerShell object.
iex (irm https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/PSDGather/PSDGather.psm1)
Get-PSDLocalInfo -Passthru