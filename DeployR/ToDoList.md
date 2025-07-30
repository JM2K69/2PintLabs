# Deploy R - Gary's Build List

List of items I'd like to build for DeployR.  This list is not in order of priority or any order at all, just thrown together based on random ideas that pop in my head.

## Not Started

- Language stuff

- Defender Updates
- OEM Tools Offline Mode (offline repo for updates)



## In Progress

- Build Step Definition for Apply Time zone | Drop down menu of time zone
  - or check a box to enable location services (should this be it's own setting somewhere else)
  - Created: <https://github.com/gwblok/2PintLabs/blob/main/DeployR/TSScripts/StepDefinitions/Set-TimeZoneStep.ps1>
  - Should add more logic around this for WinPE vs Full OS

- create step to enable Features like HyperV with option to reboot.
  - CLIENT OS | COMPLETE
  - SERVER OS | NOT STARTED

- Create script for easy import and overwrite of updated steps and content for sharing
  - MVP Created: <https://github.com/gwblok/2PintLabs/blob/main/DeployR/ServerSideScripts/DeployR-ImportFromGithub.ps1>
  - Overwrite doesn't seem to work, this is a Dev side issue I'm waiting on.
  - Works good on new setups, but after I've modifed them the new changes don't import into other systems.

- OSD Stamp
  - TS ID:                  TSID
  - DeployR Server:         DEPLOYRHOST
  - OS Build Media UBR:     OSIMAGEVERSION
  - OS Edition:             OSIMAGENAME
  - Computer Name:          $env:ComputerName
  - WinPE Info?             Info Generated in Set Initial Variables Step
  - Start | Finish Times    Start Info Generated in Set Initial Variables Step

## Completed

- Company Branding - Registered to: etc
  - COMPLETED
  - <https://github.com/gwblok/2PintLabs/blob/main/DeployR/TSScripts/StepDefinitions/Set-WindowsSettings.ps1>

## Not Doing | Just doesn't work

- Test custom actions scripts in Windows, see if I can leverage that for customizations.
  - After much testing, Custom Action Scripts do not get triggered in OSD
