#Script to test if Bitlocker is enabled, and if so, suspend bitlocker

$BitlockerStatus = Get-BitLockerVolume | Where-Object { $_.VolumeStatus -eq 'FullyEncrypted' }

if ($BitlockerStatus) {
    Suspend-BitLocker -MountPoint $BitlockerStatus.MountPoint -RebootCount 1
}