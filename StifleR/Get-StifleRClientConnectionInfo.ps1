#The following script will only report machines which are actively connected to the StifleR Server.
$ConnectedClients = Get-CimInstance -Namespace "ROOT\StifleR" -Query "Select ComputerName,ClientIPAddress,UserFlags,NetworkGroupId,VPN from Connections"
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

    Write-Output "Processing connection record for ComputerName: $Computername."
    

    #Querying for Session information
    $Connection = Get-WmiObject -Namespace root\StifleR -Query "Select * from Connections where ComputerName = '$ComputerName'" -ErrorAction SilentlyContinue
    if ($Connection -ne $Null)
    {
        try{
            $Session = (Invoke-WmiMethod -Path $Connection.__PATH -Name QuerySessions -ErrorAction SilentlyContinue).ReturnValue 
        }
        catch {
            Write-Output "Failed to query sessions for $ComputerName. Error: $_"
            continue
        }
        try {
            $data = $Session | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Output "Failed to convert session data for $ComputerName. Error: $_"
            if ($Session)
            {
                Write-Output "Session data: $Session"
            }
            continue
        }
        
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
                    }
                    #$DeviceData
                    $DataArray += $DeviceData
                    $Output = "$ComputerName,$IPAddress,$userName,$ConsoleState,$VPNState,$NGName"
                    #Write-Output $Output
                    #$Output | Out-File D:\2Pint\Location\$(get-date -f yyyyMMdd)ConnectionsOutputA.csv -Append
                }
            }
        }
    }
}
$DataArray