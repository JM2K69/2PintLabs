#Pull Vars from TS:
try {
    Import-Module DeployR.Utility
}
catch {}



# Get the provided variables
if (Get-Module -name "DeployR.Utility"){
    $CRMinMemory = ${TSEnv:CRMinMemory}
    $CRMinFreeStorage = ${TSEnv:CRMinFreeStorage}
    $CRCurrentOS = ${TSEnv:CRCurrentOS}
    $CRMinOSVer = ${TSEnv:CRMinOSVer}
    $CRTPM2 = ${TSEnv:CRTPM2}
    $CRMinWin11 = ${TSEnv:CRMinWin11}
    $HostValueMemory = ${TSEnv:Memory}
    $HostValueOSType = if (${TSEnv:IsServerOS} -eq "true") { "Server" } else { "Client" }
}
else{
    $CRMinMemory = "4"
    $CRMinFreeStorage = "20"
    $CRCurrentOS = "26100"
    $CRMinOSVer = "19045"
    $CRTPM2 = "true"
    $CRMinWin11 = "true"
    $HostValueMemory = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory) / 1GB, 2)
    $HostValueOSType = if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 1) { "Client" } else { "Server" }
}



#Get Host Values That aren't in TS Vars
#Free Space in GB
$HostValueFreeStorage = [math]::Round((Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -ExpandProperty FreeSpace) / 1GB, 2)
#Current OS Build
$HostValueCurrentBuild = (Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Version).split(".") | Select-Object -Last 1
#TPM 2
$TPMRAW = (Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion
if ($null -ne $TPMRAW) {
    if ($TPMRAW -like "2.*") {
        $HostValueTPM2 = $true
    }
    else {
        $HostValueTPM2 = $false
    }
}
else {
    $HostValueTPM2 = $false
}



