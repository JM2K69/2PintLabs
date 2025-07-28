<#
.SYNOPSIS
    RUN FROM ON YOUR STIFLER SERVER
    Moves (OR CREATES) a StifleR network to a different group within the StifleR management system.

.DESCRIPTION
    This script facilitates the reassignment of a specified StifleR network to a different group. 
    It connects to the StifleR server, locates the target network, and updates its group membership 
    according to the provided parameters. This is useful for reorganizing network groupings or 
    implementing changes in network management structure.

.PARAMETER NetworkIdToMove
    [String] The name of the StifleR network to be moved. ex: 192.168.10.1 

.PARAMETER DestinationNetworkGroupName
    [String] The name of the group to which the network should be moved. ex "VPN Networks Chicago"

.PARAMETER DestinationNetworkGroupID
    [String] The address or hostname of the StifleR server to connect to. ex c44bc7a8-25c2-4c5d-973f-d480ba4dd741
    I RECOMMEND USING THE NAME INSTEAD OF THE the NAME, you can have multiple groups with the same name, but not the same ID.

.OUTPUTS
    None. The script performs the move operation and writes status messages to the output.

.EXAMPLE
    .\Move-StifleRNetworkToDifferentGroup.ps1 NetworkIdToMove "192.168.155.0" DestinationNetworkGroupID c44bc7a8-25c2-4c5d-973f-d480ba4dd741
    Moves the "192.168.155.0" network to the "c44bc7a8-25c2-4c5d-973f-d480ba4dd741" group on the specified StifleR server.

.NOTES
    Author: Gary Blok
    Date: 2024-06-08
    Notes: Ensure you have the necessary permissions to modify network groups on the StifleR server. 


    Changes:
    2025.07.29 - Added logic to prompt for network mask when creating a new network if the move network does not exist.


#>

function Move-StifleRNetworkToDifferentGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$NetworkIdToMove,
        
        
        [Parameter(Mandatory = $false)]
        [string]$DestinationNetworkGroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$DestinationNetworkGroupID
    )

    # Sample Script to move an existing network to a new network group and new location
    #
    # Note: Before running the script, configure the server config file to not create networks 
    # automatically (via script or via AutoAddLocations), and restart the service. 
    # Revert the changes when script is completed.

    # Set network to move (subnet)
    #$NetworkIdToMove = "192.168.26.0"

    # Define new location settings
    #$LocationName = "Seattle"
    #$LocationDescription = "2Pint Lab Seattle"

    # Define new network group settings
    #$NetworkGroupName = "Seattle"
    #$NetworkGroupDescription = "2Pint Lab Seattle"
    #$TemplateName = "2Pint Lab  - 155 mbit/s"


    #region --------------------------------------------------[Initialisations]--------------------------------------------------------

    #Set Error Action to Silently Continue
    #$ErrorActionPreference = 'SilentlyContinue'

    #Import Modules & Snap-ins
    #endregion
    #region ---------------------------------------------------[Declarations]----------------------------------------------------------

    #Any Global Declarations go here
    $maxlogfilesize = 5Mb
    $Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent

    #endregion
    #region ---------------------------------------------------[Functions]------------------------------------------------------------

    #region Logging: Functions used for Logging, do not edit!

    Function Start-Log {
        [CmdletBinding()]
        param (
            [ValidateScript({ Split-Path $_ -Parent | Test-Path })]
            [string]$FilePath
        )

        try {
            if (!(Test-Path $FilePath)) {
                ## Create the log file
                New-Item $FilePath -Type File | Out-Null
            }
    
            ## Set the global variable to be used as the FilePath for all subsequent Write-Log
            ## calls in this session
            $global:ScriptLogFilePath = $FilePath
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }

    Function Write-Log {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,
    
            [Parameter()]
            [ValidateSet(1, 2, 3)]
            [int]$LogLevel = 1
        )    
        $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    
        if ($MyInvocation.ScriptName) {
            $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
        }
        else {
            #if the script havn't been saved yet and does not have a name this will state unknown.
            $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "Unknown", $LogLevel
        }
        $Line = $Line -f $LineFormat

        If ($Verbose) {
            switch ($LogLevel) {
                2 { $TextColor = "Yellow" }
                3 { $TextColor = "Red" }
                Default { $TextColor = "Gray" }
            }
            Write-Host -nonewline -f $TextColor "$Message`r`n" 
        }

        #Make sure the logfile do not exceed the $maxlogfilesize
        if (Test-Path $ScriptLogFilePath) { 
            if ((Get-Item $ScriptLogFilePath).length -ge $maxlogfilesize) {
                If (Test-Path "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_") {
                    Remove-Item -path "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_" -Force
                }
                Rename-Item -Path $ScriptLogFilePath -NewName "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_" -Force
            }
        }

        Add-Content -Value $Line -Path $ScriptLogFilePath -Encoding UTF8

    }
    #endregion

    # Function to create a new location


    Function Compare-StifleRMethodParameters($WMIClass, $Method, $CALLINGParams) {

        $Class = Get-CimClass -Namespace root\StifleR -ClassName "$WMIClass"
        $Class_Params = $Class.CimClassMethods[$Method].Parameters

        ForEach ($entry in $Class_Params) {
            if ($verbose) { Write-Log -message "Processing $($entry.Name) of type: $($entry.CimType)" }
            if ($CALLINGParams.ContainsKey($entry.Name)) {
                if ($verbose) { Write-Log -message "Found valid parameter: $($entry.Name) of type: $($entry.CimType)" }
            
                $othertype = $CALLINGParams[$entry.Name].GetType()

                if ($othertype.Name -ne $entry.CimType) {
                    Write-Log -Message "$($CALLINGParams[$entry.Name].GetType())  does not match  $($entry.CimType)" -LogLevel 3 -Verbose
                    return 1
                }
                else {
                    if ($verbose) { Write-Log -message "Input matches the parameter type!" }
                }
            }
            else {
                if ($verbose) { Write-Log -message $entry.Name }
                Write-Log -Message "Missing valid parameter $($entry.Name) on call to $Method on $WMIClass" -LogLevel 3 -Verbose
                return 1
            }
        }
        return 0
    }


    function Add-NetworkToNetworkGroup([System.Object]$NetGrp, $NetworkId, $NetworkMask, $GatewayMAC) {
        
        write-debug "##########################"
        $class = "Networks"
        $method = "AddNetworkToNetworkGroup"
        write-debug "Processing $method"
        $params = @{ Network = $NetworkId ; NetworkMask = $NetworkMask; GatewayMAC = $GatewayMAC };
        $result = Compare-StifleRMethodParameters $class $method $params
        if ($result -ne 0) {
            Write-Error "Failed to verify Parameters to $class"
            return 1
        }
        else {
            #Add out location
            write-debug "Calling Invoke-CimMethod on newly create network group"
        

            #Add location on the actual object in the location object just created using non static method
            $ret = Invoke-CimMethod -InputObject $NetGrp -MethodName AddNetworkToNetworkGroup -Arguments $params

            $NetworkId = $ret.ReturnValue
            #$Network = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$NetworkId'"
            
            $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $NetworkId } -Key Id -ClientOnly
            $Network = Get-CimInstance -CimInstance $x
            
            return $Network
        }
    }


    #-----------------------------------------------------------[Execution]------------------------------------------------------------

    # Get network settings from the network to move, needed later
    # Abort if the network does not exist, no point in continuing
    $NetworkToMove = Get-CimInstance -Namespace root\StifleR -ClassName Networks -Filter "NetworkId = '$NetworkIdToMove'"
    If ($NetworkToMove){
        $NetworkMask = $NetworkToMove.SubnetMask
        $NetworkGatewayMAC = $NetworkToMove.GatewayMAC
        $Id = $NetworkToMove.id
    }
    Else {
        #Ask in the COnsole if the user would like to create the network first, Y or N
        $answer = Read-Host "Network with NetworkId: $NetworkIdToMove cannot be found. Would you like to create it? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToUpper() -eq 'Y') {
            Write-Host "User chose to create the network.. additional info required..."
            $NetworkMask = Read-Host "Please enter the network mask (e.g., 255.255.255.0)"
            while (-not ($NetworkMask -match '^(\d{1,3}\.){3}\d{1,3}$')) {
                $NetworkMask = Read-Host "Invalid format. Please enter the network mask in the form of 255.255.255.0"
            }
            write-host "Planning to ad Network $NetworkToMove with Mask set to: $NetworkMask"
            #Network doesn't exist, Set Variable to Skip Deletion Later
            $NetworkToMoveSkipDeletion = $true
        } else {
            Write-Warning "User chose not to create the network. Aborting script..."
            break
        }
    }
    if ($DestinationNetworkGroupName){
        $NetworkGroupToJoin = Get-CimInstance -Namespace root\StifleR -ClassName NetworkGroups -Filter "Name = '$DestinationNetworkGroupName'"
        If ($NetworkGroupToJoin){
            $NetworkGroupId = $NetworkGroupToJoin.id
        }
        Else {
            Write-Warning "NetworkGroup with GroupID: $NetworkGroupId can not be found, aborting script..."
            Break
        }
    }
    if ($DestinationNetworkGroupID){
        $NetworkGroupToJoin = Get-CimInstance -Namespace root\StifleR -ClassName NetworkGroups -Filter "ID = '$DestinationNetworkGroupID'"
        If ($NetworkGroupToJoin){
            $NetworkGroupId = $NetworkGroupToJoin.id
        }
        Else {
            Write-Warning "NetworkGroup with GroupID: $NetworkGroupId can not be found, aborting script..."
            Break
        }
    }
    if ($NetworkToMove.NetworkGroupId -eq $NetworkGroupId) {
        Write-Warning "Network with NetworkId: $NetworkIdToMove is already in NetworkGroup with GroupID: $NetworkGroupId, aborting attempt to move..."
        Break
    }
    # Delete the existing network (requirement in 2.10)
    $Arguments = @{
        Force = $true
        NetworkId = $id # The GUID id
    }
    if ($NetworkToMoveSkipDeletion -eq $true){
        #Skip deletion, network does not exist
    }
    else {
        $RemoveNetworkusingIdResult = Invoke-CimMethod -InputObject $NetworkToMove -MethodName RemoveNetworkusingId -Arguments $Arguments
    }
    

    # Create the new network 
    If ($RemoveNetworkusingIdResult.ReturnValue -eq 0 -or $NetworkToMoveSkipDeletion -eq $true) {
        # Deletion successful, creating the new network
        [System.Object]$Network = Add-NetworkToNetworkGroup $NetworkGroupToJoin $NetworkIdToMove $NetworkMask $NetworkGatewayMAC
        If ($Network) {
            Write-Host "========================================================================" -ForegroundColor DarkGray
            Write-Host "SUCCESS:Network $NetworkIdToMove moved to Network Group Name $($NetworkGroupToJoin.Name) | ID: $($NetworkGroupId)" -ForegroundColor Green

        }
        Else {
            Write-Warning "Could not create the network. Script failed..."
        }
    }
    Else {
        Write-Warning "Could not delete the network. Script failed..."
    }

}