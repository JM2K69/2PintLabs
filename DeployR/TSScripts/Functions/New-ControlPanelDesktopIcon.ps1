
#Gary Blok | @gwblok | GARYTOWN
#Create ConfigMgr Control Panel Shortcut & Software Center Shortcut on Desktop

function New-ControlPanelDesktopIcon {
    [CmdletBinding()]
    param ()
    
    #Build ShortCut Information - Control Panel
    $SourceExe = "$env:windir\system32\control.exe"
    $DestinationPath = "$env:Public\Desktop\Control Panel.lnk"
    $ArgumentsToSourceExe = $Null
    if (!(Test-Path -Path $DestinationPath)){
        #Create Shortcut
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($DestinationPath)
        $Shortcut.IconLocation = "C:\Windows\System32\SHELL32.dll, 21"
        $Shortcut.TargetPath = $SourceExe
        $Shortcut.Arguments = $ArgumentsToSourceExe
        $Shortcut.Save()
        write-output "Creating Control Panel Icon on Desktop"
    }
}