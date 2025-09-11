# Deploy R - Gary's Build List

List of items I'd like to build for DeployR.  This list is not in order of priority or any order at all, just thrown together based on random ideas that pop in my head.

## Not Started

- Defender Updates
- WinRE Driver Injection (Full OS Stage) - Work with Terrill
- OEM Tools Offline Mode (offline repo for updates)


- PowerShell Functions

## In Progress

- PowerShell Functions
  - PowerShell Function to import Driver Packs in Automated Process
    - Think "Modern Driver Management" - Scans the Catalogs pops dialog and then downloads and imports
      - Panasonic - Created Function to get ALL models at once, need to make a bit more dynamic
      - Dell - Can import based on model
     
        
- create step to enable Features like HyperV with option to reboot.
  - CLIENT OS | COMPLETE
  - SERVER OS | NOT STARTED


## Completed

- Updated Format Step with additional customizations and Drive control.
- Create script for easy import and overwrite of updated steps and content for sharing
  - MVP Created: <https://github.com/gwblok/2PintLabs/blob/main/DeployR/ServerSideScripts/DeployR-ImportFromGithub.ps1>

- Company Branding - Registered to: etc
  - COMPLETED
  - <https://github.com/gwblok/2PintLabs/blob/main/DeployR/TSScripts/StepDefinitions/Set-WindowsSettings.ps1>

- Build Step Definition for Apply Time zone | Drop down menu of time zone (Configure Initial Variables Step)
  - COMPLETED - 25.8.4
    - This step also provides drop downs for the different Language / locale settings.
  - or check a box to enable location services (should this be it's own setting somewhere else)
  - Created: <https://github.com/gwblok/2PintLabs/blob/main/DeployR/TSScripts/StepDefinitions/Set-TimeZoneStep.ps1>
  - Should add more logic around this for WinPE vs Full OS

- OSD Stamp
  - COMPLETED - 25.8.4
    - Requires Running the Configure Initial Variable Step to be placed at the start of the TS to capture the start time and WinPE Info
  - TS ID:                  TSID
  - DeployR Server:         DEPLOYRHOST
  - OS Build Media UBR:     OSIMAGEVERSION
  - OS Edition:             OSIMAGENAME
  - Computer Name:          $env:ComputerName
  - WinPE Info?             Info Generated in Set Initial Variables Step
  - Start | Finish Times    Start Info Generated in Set Initial Variables Step

## Not Doing | Just doesn't work

- Test custom actions scripts in Windows, see if I can leverage that for customizations.
  - After much testing, Custom Action Scripts do not get triggered in OSD

## NOTES FOR Step Defs
Filter: Add Type Application
Include Type Application for auto updates.
