
Get-Service -name StifleRBeacon | Start-Service
Get-Service -name StifleRServer | Stop-Service

$instancePath = "\\.\ROOT\StifleR:Beacons.id='8cbf0400-befd-4f2a-be8e-cb8db460a968'"
$namespace = "ROOT\StifleR"
$classname = "Beacons"
$newHostname = "Testing"

try {
    # Retrieve the instance
    $instance = Get-WmiObject -Namespace $namespace -Class $classname -Filter "id='8cbf0400-befd-4f2a-be8e-cb8db460a968'"
    if ($instance) {
        # Display current hostname to verify
        Write-Host "Current hostname: $($instance.Hostname)"
        
        # Update the hostname
        $instance.Hostname = $newHostname
        $result = $instance.Put()
        Write-Host "Update result: $result"
        
        # Verify the change
        $updatedInstance = Get-WmiObject -Namespace $namespace -Class $classname -Filter "id='8cbf0400-befd-4f2a-be8e-cb8db460a968'"
        Write-Host "New hostname: $($updatedInstance.Hostname)"
    } else {
        Write-Host "Instance not found."
    }
} catch {
    Write-Host "Error: $_"
}
Get-Service -name StifleRBeacon | Restart-Service
Get-Service -name StifleRServer | Start-Service