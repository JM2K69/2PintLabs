# Sample Script to move an existing network to a new network group and new location
#
# Note: Before running the script, configure the server config file to not create networks 
# automatically (via script or via AutoAddLocations), and restart the service. 
# Revert the changes when script is completed.


#region --------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = 'SilentlyContinue'

#Import Modules & Snap-ins
#endregion
#region ---------------------------------------------------[Declarations]----------------------------------------------------------

#Any Global Declarations go here
$maxlogfilesize = 5Mb
#$Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent

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
function Add-Location($LocationName, $LocationDescription) {
    $class = "Locations"
    $method = "AddLocation"
    if ($verbose) { Write-Log -message "Processing $method" }
    $params = @{ Name = $LocationName; Description = $LocationDescription };
    
    $result = Compare-StifleRMethodParameters $class $method $params
    
    if ($result -ne 0) {
        Write-Error "Failed to verify Parameters to $class"
        return 1
    }
    else {
        #Add out location
        if ($verbose) { Write-Log -message "Calling Invoke-CimMethod to $class $method" }
        $ret = Invoke-CimMethod -Namespace root\StifleR -ClassName $class -Name $method -Arguments $params
        
        $locationid = $ret.ReturnValue
        #Dont be this guy! This calls the enumerator for each call, if we have the ID, whe dont need to query!
        #$Location = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$locationid'"
        
        #This is MUCH faster, and does not slow down with larget lists. Key here is the -ClientOnly
        $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $locationid } -Key Id -ClientOnly
        $Location = Get-CimInstance -CimInstance $x

        return , $Location
    }
}

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

function Add-NetworkGroupToLocation([System.Object]$Location, $NetworkGroupName, $NetworkGroupDescription) {
    write-debug "incoming object is type ($Location.GetType())"

    write-debug "##########################"
    $method = "AddNetworkGroupToLocation"
    $class = "NetworkGroups"
    write-debug "Processing $method"
    $params = @{ Name = $NetworkGroupName ; Description = $NetworkGroupDescription }
    $result = Compare-StifleRMethodParameters $class $method $params
    if ($result -ne 0) {
        Write-Error "Failed to verify Parameters to $class"
        return 1
    }
    else {
    
        #Add location on the actual object in the location object just created using non static method
        write-debug "Calling Invoke-CimMethod on LocationInstance $Location.id"
        $ret = Invoke-CimMethod -InputObject $Location -MethodName $method -Arguments $params

        $netGrpId = $ret.ReturnValue
        #$netGrp = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$netGrpId'"
        
        $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $netGrpId } -Key Id -ClientOnly
        Start-Sleep -Seconds 1
        $netGrp = Get-CimInstance -CimInstance $x
		
        return $netGrp

        #You can also call the static methods to add on the class NetworkGroups
        #write-debug "Calling Invoke-CimMethod to $class $method"
        #$args = @{ Name = 'Name' ; Description = 'Description'; LocationId=<guid>}
        #$netGrp = Invoke-CimMethod -Namespace root\StifleR -ClassName $class -Name $method -Arguments $args
    }
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

#First Get all Network Groups with more than 1 Network
$NetworkGroups = Get-CimInstance -Namespace root\StifleR -ClassName NetworkGroups | Where-Object { (($_.NetworksIds).count -gt 1)}

If ($NetworkGroups.count -eq 0) {
    Write-Warning "No Network Groups with more than 1 network found, aborting script..."
    Break
}
Write-Host "Starting to move all networks to a new network group and new location" -ForegroundColor Magenta
Foreach ($NetworkGroup in $NetworkGroups) {
    Write-Host "Network Group: $($NetworkGroup.Name) has $($NetworkGroup.NetworksIds.count) networks" -ForegroundColor Magenta
    $CurrentTemplate = $NetworkGroup.Template
    $TemplateDetails = Get-CimInstance -Namespace root\StifleR -ClassName NetworkGroupTemplates | Where-Object { $_.id -eq $CurrentTemplate }
    Write-Host "Network Group currently has template: $($TemplateDetails.Name) | $CurrentTemplate assigned" -ForegroundColor Magenta
    foreach ($NetworkIdToMove in $NetworkGroup.NetworksIds) {
        # Define new location and network group details
        $NetworkDetails = Get-CimInstance -Namespace root\StifleR -ClassName Networks -Filter "id = '$NetworkIdToMove'"
        $LocationName = "Location for $($NetworkDetails.NetworkID)"
        $LocationDescription = "Auto created location for network $($NetworkDetails.NetworkID)"
        $NetworkGroupName = "NetGrp for $($NetworkDetails.NetworkID)"
        $NetworkGroupDescription = "Auto created network group for network $($NetworkDetails.NetworkID)"
        Write-Host " Processing Network: $($NetworkDetails.NetworkID) | $($NetworkDetails.id)" -ForegroundColor Green
        Write-Host " Creating Location: $LocationName with description: $LocationDescription" -ForegroundColor Green

        #Creating a New Location and New Network Group for each network to move
        # Create new location
        [System.Object]$NewLocation = Add-Location $LocationName $LocationDescription

        Write-Host " Creating Network Group: $NetworkGroupName with description: $NetworkGroupDescription" -ForegroundColor Green
        # Create new network group
        [System.Object]$NewNetworkGroup = Add-NetworkGroupToLocation $NewLocation $NetworkGroupName $NetworkGroupDescription
        # Assign a template to the new network group
        $Arguments = @{
            TemplateId = $CurrentTemplate 
        }
        
        Write-host " Assigning Template: $($TemplateDetails.Name) | $CurrentTemplate to new Network Group: $($NewNetworkGroup.Name)" -ForegroundColor Green
        $Invoke = Invoke-CimMethod -InputObject $NewNetworkGroup -MethodName SetTemplate -Arguments $Arguments
        Write-Host " Moving Network: $($NetworkDetails.NetworkID) to new Network Group: $($NewNetworkGroup.Name)" -ForegroundColor Cyan
        $Arguments = @{
            NetworkGroupId = $NewNetworkGroup.id
        }
        $Invoke = Invoke-CimMethod -InputObject $NetworkDetails -MethodName MoveToNewNetworkGroup -Arguments $Arguments
    }
}
