if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}
#Pull Vars from TS:
try {
    Import-Module DeployR.Utility
}
catch {}


#region functions
#region: CMTraceLog Function formats logging in CMTrace style
function Write-CMTraceLog {
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory=$false)]
    $Message,
    
    [Parameter(Mandatory=$false)]
    $ErrorMessage,
    
    [Parameter(Mandatory=$false)]
    $Component = "M365",
    
    [Parameter(Mandatory=$false)]
    [int]$Type,
    
    [Parameter(Mandatory=$false)]
    $LogFile = "C:\windows\temp\M365_Install.log"
    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
    $Time = Get-Date -Format "HH:mm:ss.ffffff"
    $Date = Get-Date -Format "MM-dd-yyyy"
    
    $LogFileFolderPath = Split-Path -Path $LogFile -Parent
    if (!(Test-Path -Path $LogFileFolderPath)) {
        New-Item -ItemType Directory -Path $LogFileFolderPath -Force | Out-Null
    }
    
    if ($ErrorMessage -ne $null) {$Type = 3}
    if ($Component -eq $null) {$Component = " "}
    if ($Type -eq $null) {$Type = 1}
    
    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

#Used to set Exit Code in way that CM registers
function ExitWithCode
{
    param
    (
    $exitcode
    )
    
    $host.SetShouldExit($exitcode)
    exit
}
#endregion functions



# Get the provided variables
if (Get-Module -name "DeployR.Utility"){
    $Access = ${TSEnv:M365Access}
    $Project = ${TSEnv:M365Project}
    $Visio = ${TSEnv:M365Visio}
    #$ProjectPro = ${TSEnv:M365ProjectPro}
    #$VisioPro = ${TSEnv:M365VisioPro}
    #$ProjectStd = ${TSEnv:M365ProjectStd}
    #$VisioStd = ${TSEnv:M365VisioStd}
    $AccessRuntime = ${TSEnv:M365AccessRuntime}
    $ExcludePublisher = ${TSEnv:M365ExcludePublisher}
    $ExcludeOneNote = ${TSEnv:M365ExcludeOneNote}
    $ExcludeSkype = ${TSEnv:M365ExcludeSkype}
    $ExcludeOutlook = ${TSEnv:M365ExcludeOutlook}
    $ExcludePowerPoint = ${TSEnv:M365ExcludePowerPoint}
    $ExcludeBing = ${TSEnv:M365ExcludeBing}
    $SharedComputerLicensing = ${TSEnv:M365SharedComputerLicensing}
    $AUTOACTIVATE = ${TSEnv:M365AUTOACTIVATE}
    $PinIconsToTaskbar = ${TSEnv:M365PinIconsToTaskbar}
    $DeviceBasedLicensing = ${TSEnv:M365DeviceBasedLicensing}
    $Channel = ${TSEnv:M365Channel}
    $Language = ${TSEnv:M365Language}
    $SetLanguageDefault = ${TSEnv:M365SetLanguageDefault}
    $CompanyValue = ${TSEnv:M365CompanyValue}
    $OfficeDeployToolKitURL = ${TSEnv:M365OfficeDeployToolKitURL}

}
else{
    $Access = "false"
    $Project = "standard"
    $Visio = "professional"
    $AccessRuntime = "false"
    $ExcludePublisher = "true"
    $ExcludeOneNote = "false"
    $ExcludeSkype = "true"
    $ExcludeOutlook = "false"
    $ExcludePowerPoint = "false"
    $ExcludeBing = "true"
    $SharedComputerLicensing = "false"
    $AUTOACTIVATE = "true"
    $PinIconsToTaskbar = "true"
    $DeviceBasedLicensing = "false"
    $Channel = "Current"
    $Language = "en-us"
    $SetLanguageDefault = "false"
    $CompanyValue = "2PintLabs"
    $OfficeDeployToolKitURL = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_19029-20136.exe"
}

if ($Project -eq "professional"){
    $ProjectPro = "true"
    $ProjectStd = "false"
}elseif ($Project -eq "standard") {
    $ProjectPro = "false"
    $ProjectStd = "true"
}
else{
    $ProjectPro = "false"
    $ProjectStd = "false"
}

if ($Visio -eq "professional") {
    $VisioPro = "true"
    $VisioStd = "false"
} elseif ($Visio -eq "standard") {
    $VisioPro = "false"
    $VisioStd = "true"
} else {
    $VisioPro = "false"
    $VisioStd = "false"
}

#Download Office Deployment ToolKit & Extract
$tempDownloadPath = "C:\Windows\Temp"
Write-CMTraceLog -Message "Downloading Office Deployment ToolKit from $OfficeDeployToolKitURL to $tempDownloadPath" -Type 1 -Component "o365script"
try {
    $destFile = Request-DeployRCustomContent -ContentName "M365" -ContentFriendlyName "Office Deployment ToolKit" -URL $URL -DestinationPath $tempDownloadPath -ErrorAction SilentlyContinue
    $GetItemOutFile = Get-Item $destFile
    $ToolKitFile = $GetItemOutFile.FullName
    
} catch {
    $ToolKitFile = "$tempDownloadPath\officedeploymenttool.exe"
    Invoke-WebRequest -Uri $OfficeDeployToolKitURL -OutFile $ToolKitFile -ErrorAction SilentlyContinue
}

Write-CMTraceLog -Message "Extracting Office Deployment ToolKit to $M365Cache" -Type 1 -Component "o365script"
Start-Process -FilePath $ToolKitFile -ArgumentList "/quiet /extract:$M365Cache" -Wait -NoNewWindow


$SourceDir = Get-Location
$M365Cache = "C:\ProgramData\M365_Cache"
$RegistryPath = "HKLM:\SOFTWARE\2Pint Software\DeployR\M365" #Sets Registry Location used for Toast Notification
$ScriptVer = "25.08.26.01"






Write-CMTraceLog -Message "=====================================================" -Type 1 -Component "o365script"
Write-CMTraceLog -Message "Starting Script version $ScriptVer..." -Type 1 -Component "o365script"
Write-CMTraceLog -Message "=====================================================" -Type 1 -Component "o365script"




#Create XML (Configuration.XML) if Install Mode (Not PreCache Mode)

[XML]$XML = @"
<Configuration Host="cm">
    <Info Description="Customized Office 365" />
    <Add OfficeClientEdition="64" Channel="SemiAnnual" OfficeMgmtCOM="TRUE" ForceUpgrade="TRUE">
    <Product ID="O365ProPlusRetail">
    <Language ID="en-us" />
    <ExcludeApp ID="Groove" />
    <ExcludeApp ID="OneDrive" />
    <ExcludeApp ID="Teams" />
    </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="PinIconsToTaskbar" Value="FALSE" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="AUTOACTIVATE" Value="1" />
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <RemoveMSI />
    <AppSettings>
    <Setup Name="Company" Value="Your Company Here" />
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
    </AppSettings>
    <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@




#Change Channel
$xml.Configuration.Add.SetAttribute("Channel","$Channel")
Write-CMTraceLog -Message "Setting Office Channel to $Channel" -Type 1 -Component "o365script"

$XML.Configuration.AppSettings.Setup.SetAttribute("Value", "$CompanyValue")
Write-CMTraceLog -Message "Setting Setup Company name to $CompanyValue" -Type 1 -Component "o365script"

if ($SharedComputerLicensing)
{
    #Change SharedComputerLicensing to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "SharedComputerLicensing"}).SetAttribute("Value","1")
}

if ($AUTOACTIVATE)
{
    #Change AUTOACTIVATE to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "AUTOACTIVATE"}).SetAttribute("Value","1")
}

if ($PinIconsToTaskbar)
{
    #Change PinIconsToTaskbar to TRUE
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "PinIconsToTaskbar"}).SetAttribute("Value","TRUE")
}

if ($DeviceBasedLicensing)
{
    #Change DeviceBasedLicensing to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "DeviceBasedLicensing"}).SetAttribute("Value","1")
}

#Add Project Pro to XML if Previously Installed or Called from Param
if ($ProjectPro -eq "true")
{
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
    $newProductApp.SetAttribute("PIDKEY","B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")    
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
    Write-CMTraceLog -Message "Adding Project Pro to Install XML" -Type 1 -Component "o365script"
}  

#Add Visio Pro to XML if Previously Installed or Called from Param
if ($VisioPro -eq "true")
{
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","VisioPro2019Volume")
    $newProductApp.SetAttribute("PIDKEY","9BGNQ-K37YR-RQHF2-38RQ3-7VCBB")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")     
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
    Write-CMTraceLog -Message "Adding Visio Pro to Install XML" -Type 1 -Component "o365script"
}
#Add Project Standard to XML if Previously Installed or Called from Param
if ($ProjectStd -eq "true")
{
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","ProjectStd2019Volume")
    $newProductApp.SetAttribute("PIDKEY","C4F7P-NCP8C-6CQPT-MQHV9-JXD2M")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")   
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
    Write-CMTraceLog -Message "Adding Project Standard to Install XML" -Type 1 -Component "o365script"
}  

#Add Visio Standard to XML if Previously Installed or Called from Param
if ($VisioStd -eq "true")
{
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","VisioStd2019Volume")
    $newProductApp.SetAttribute("PIDKEY","7TQNQ-K3YQQ-3PFH7-CCPPM-X4VQ2")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")   
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
    Write-CMTraceLog -Message "Adding Visio Standard to Install XML" -Type 1 -Component "o365script"
}

#Add Access Runtime if Called from Param - Changed to ALWAYS append this.
if ($AccessRuntime -eq "true")
{
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","AccessRuntimeRetail")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")    
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")    
    Write-CMTraceLog -Message "Adding Access Runtime to Install XML" -Type 1 -Component "o365script"
}  

#Don't Remove Access from XML if Previously Installed or Called from Param
if ($Access -eq "false")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Access")
    }
    Write-CMTraceLog -Message "Removing Access from Install XML" -Type 1 -Component "o365script"
}
else{Write-CMTraceLog -Message "Adding Access To Install XML" -Type 1 -Component "o365script"}

#If Exclude OneNote
if ($ExcludeOneNote -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","OneNote")
    }
    Write-CMTraceLog -Message "Removing OneNote from Install XML" -Type 1 -Component "o365script"
}

#If Exclude Skype
if ($ExcludeSkype -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","lync")
    }
    Write-CMTraceLog -Message "Removing Skype from Install XML" -Type 1 -Component "o365script"
}
#If Exclude Publisher
if ($ExcludePublisher -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Publisher")
    }
    Write-CMTraceLog -Message "Removing Publisher from Install XML" -Type 1 -Component "o365script"
}

#If Exclude Outlook
if ($ExcludeOutlook -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Outlook")
    }
    Write-CMTraceLog -Message "Removing Outlook from Install XML" -Type 1 -Component "o365script"
}
#If Exclude PowerPoint
if ($ExcludePowerPoint -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","PowerPoint")
    }
    Write-CMTraceLog -Message "Removing PowerPoint from Install XML" -Type 1 -Component "o365script"
}
#If Exclude Bing
if ($ExcludeBing -eq "true")
{
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
    {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Bing")
    }
    Write-CMTraceLog -Message "Removing BIng from Install XML" -Type 1 -Component "o365script"
}          
#Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
if ($ProjectStd -eq "true") #If Choosing to Install Project Standard, Added XML to Remove Project Pro
{
    $XMLRemove=$XML.CreateElement("Remove")
    $XML.Configuration.appendChild($XMLRemove)
    $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
    $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
}  

#Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
if ($VisioStd -eq "true") #If Choosing to Install Visio Standard, Added XML to Remove Visio Pro
{
    $XMLRemove=$XML.CreateElement("Remove")
    $XML.Configuration.appendChild($XMLRemove)
    $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
    $newProductApp.SetAttribute("ID","VisioPro2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
}

#Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
if ($ProjectPro -eq "true") #If Choosing to Install Project Pro, Added XML to Remove Project Standard
{
    $XMLRemove=$XML.CreateElement("Remove")
    $XML.Configuration.appendChild($XMLRemove)
    $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
    $newProductApp.SetAttribute("ID","ProjectStd2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
}  

#Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
if ($VisioPro -eq "true") #If Choosing to Install Visio Pro, Added XML to Remove Visio 
{
    $XMLRemove=$XML.CreateElement("Remove")
    $XML.Configuration.appendChild($XMLRemove)
    $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
    $newProductApp.SetAttribute("ID","VisioStd2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
}


<#add additional languages to download
In the install command, if you leave out -Language, it will default to en-us
If you pick a different language like fr-fr, it will set that as default, but still include en-us
#>
if ($Language)
{
    Write-CMTraceLog -Message "Language Param detected, added $Language to XML" -Type 1 -Component "o365script"
    if ($SetLanguageDefault)#Set Default language to the Language Specified
    {
        Write-CMTraceLog -Message " LanguageDefault Param detected, set $Language to Default" -Type 1 -Component "o365script"
        $CurrentProductAttributeLang = $xml.Configuration.Add.Product
        foreach ($currentproduct in $CurrentProductAttributeLang)
        {
            $newXmlNameElement = $currentproduct.Language
            $newXmlNameElement.SetAttribute("ID","$Language")
        }
        #Include English in the install if you picked a different language as your default
        if (!($Language -eq "en-us"))
        {
            Write-CMTraceLog -Message " LanguageDefault Param detected, appending en-us to XML" -Type 1 -Component "o365script"
            $newProductAttributeLang = $xml.Configuration.Add.Product
            foreach ($newproduct in $newProductAttributeLang)
            {
                $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("Language"))
                $newXmlNameElement.SetAttribute("ID","en-us")
            }
        }
    }
    else #Append Language, leaving English as Default
    {
        Write-CMTraceLog -Message " LanguageDefault Param NOT detected, appending $Language to XML" -Type 1 -Component "o365script"
        $newProductAttributeLang = $xml.Configuration.Add.Product
        foreach ($newproduct in $newProductAttributeLang)
        {
            $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("Language"))
            $newXmlNameElement.SetAttribute("ID","$Language")
        }
    }
}



Write-CMTraceLog -Message "Creating XML file: $("$M365Cache\configuration.xml")" -Type 1 -Component "o365script"
$xml.Save("$M365Cache\configuration.xml")


Write-CMTraceLog -Message "Starting Office 365 Install" -Type 1 -Component "o365script"
$InstallOffice = Start-Process -FilePath $M365Cache\setup.exe -ArgumentList "/configure $M365Cache\configuration.xml" -Wait -PassThru -WindowStyle Hidden
$OfficeInstallCode = $InstallOffice.ExitCode
Write-CMTraceLog -Message "Finished Office Install with code: $OfficeInstallCode" -Type 1 -Component "o365script"


#endregion


