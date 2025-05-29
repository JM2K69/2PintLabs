#The following script will only report machines which are actively connected to the StifleR Server.
function  Get-StifleRClientConnectionInfo{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $false)]
        [String]$CSVExportFolderPath = "$Env:programdata\2Pint Software\Manual Exports\$(get-date -f yyyyMMdd)ConnectionsOutput.csv",
        [Parameter(Mandatory = $false)]
        [String]$JSONExportFolderPath = "$Env:programdata\2Pint Software\Manual Exports\$(get-date -f yyyyMMdd)ConnectionsOutput.json",
        [Parameter(Mandatory = $false)]
        [Switch]$ShowOutput,
        [Switch]$CSVAutoPath = $false,
        [Switch]$JSONAutoPath = $false
    )
    if ($CSVAutoPath -eq $true){
        $CSVExportFolderPath = "$Env:programdata\2Pint Software\Manual Exports"
        if (-not (Test-Path -Path $CSVExportFolderPath))
        {
            New-Item -ItemType Directory -Path $CSVExportFolderPath -Force | Out-Null
        }
        $CSVExportPath = Join-Path -Path $CSVExportFolderPath -ChildPath "$(get-date -f yyyyMMdd)StifleRConnectionsOutput.csv"
    }

    if ($JSONAutoPath -eq $true){
        $JSONExportFolderPath = "$Env:programdata\2Pint Software\Manual Exports"
        if (-not (Test-Path -Path $JSONExportFolderPath))
        {
            New-Item -ItemType Directory -Path $JSONExportFolderPath -Force | Out-Null
        }
        $JSONExportPath = Join-Path -Path $JSONExportFolderPath -ChildPath "$(get-date -f yyyyMMdd)StifleRConnectionsOutput.json"
    }

    $ConnectedClients = Get-CimInstance -Namespace "ROOT\StifleR" -ClassName "Connections" -ErrorAction SilentlyContinue | Where-Object {$_.CimClass -notmatch "Server"}
    $DataArray = @()
    foreach ($ConnectedClient in $ConnectedClients)
    {
        [String]$ComputerName = $ConnectedClient.ComputerName
        [String]$IPAddress = $ConnectedClient.ClientIPAddress
        [String]$UserFlags = $ConnectedClient.UserFlags
        [String]$NetworkGroupID = $ConnectedClient.NetworkGroupId
        [String]$VPN = $ConnectedClient.VPN

        $ConsoleisUnlocked = 137438953472
        $ConsoleisLocked = 67108864
        #$ConsoleLockUnknown = 274877906944

        $NGName = (Get-CimInstance -Namespace root\StifleR -Query "Select Name from NetworkGroups Where id = '$NetworkGroupID'" -ErrorAction SilentlyContinue).Name

        Write-Verbose "Processing connection record for ComputerName: $Computername."
        

        #Querying for Session information
        $Connection = Get-WmiObject -Namespace root\StifleR -Query "Select * from Connections where ComputerName = '$ComputerName'" -ErrorAction SilentlyContinue
        if ($Connection -ne $Null)
        {
            try{
                $Session = (Invoke-WmiMethod -Path $Connection.__PATH -Name QuerySessions -ErrorAction SilentlyContinue).ReturnValue 
            }
            catch {
                Write-Verbose "Failed to query sessions for $ComputerName. Error: $_"
                continue
            }
            try {
                $data = $Session | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "Failed to convert session data for $ComputerName. Error: $_"
                if ($Session)
                {
                    Write-Verbose "Session data: $Session"
                }
                continue
            }
            [String]$ConnectionID = $Connection.ConnectionID
            [String]$MachineGuid = $Connection.MachineGuid
            # Loop through each item and extract the UserName
            foreach ($Session in $data.PSObject.Properties) 
            {
                [String]$SessionState = $Session.value.State
                [String]$WinStation = $Session.Value.WinStation
                [String]$userName = $Session.Value.UserName
                [String]$ConsoleState = $NULL
                [String]$VPNState = $NULL
                if ($SessionState -eq "WTSActive")
                {
                    if ($WinStation -eq "Console")
                    {
                        if ($userflags -band $ConsoleisUnlocked) 
                        {
                            $ConsoleState = "Unlocked"
                        }
                        if ($userflags -band $ConsoleisLocked) 
                        {
                            $ConsoleState = "Locked"
                        }
                        if ($VPN -eq $False)
                        {
                            $VPNState = "NoVPN"
                        }
                        if ($VPN -eq $True)
                        {
                            $VPNState = "YesVPN"
                        }
                        $DeviceData = New-Object -TypeName PSObject -Property @{
                            ComputerName = $ComputerName
                            IPAddress = $IPAddress
                            UserName = $userName
                            ConsoleState = $ConsoleState
                            VPNState = $VPNState
                            NetworkGroupName = $NGName
                            ConnectionID = $ConnectionID
                            MachineGuid = $MachineGuid
                        }
                        #$DeviceData
                        $DataArray += $DeviceData
                        $Output = "$ComputerName,$IPAddress,$userName,$ConsoleState,$VPNState,$NGName"
                        #Write-Output $Output
                        if ($CSVExportFolderPath -ne $Null)
                        {
                            $Output | Out-File $CSVExportPath -Append
                        }
                    }
                }
            }
        }
    }
    if ($JSONExportFolderPath -ne $Null){
        $DataArray | ConvertTo-Json | Out-File $JSONExportPath
    }
    if ($ShowOutput -eq $True){
        $DataArray | Format-Table -AutoSize
    }
    else {
        Write-Output "Use the -ShowOutput switch to display the output in the console."
    }
}