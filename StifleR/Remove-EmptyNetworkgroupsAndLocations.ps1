# This will remove all network groups without networks and locations without networkgroups

$class = "NetworkGroups"
$NetworkGroups = Get-CimInstance -Namespace root\StifleR -Query "SELECT * FROM $class"
$counter = 0
foreach($ng in $NetworkGroups)
{
    if($($ng.NetworksIds).Count -eq 0)
    {
        $counter ++
        try {
        $method = "RemoveNetworkGroupUsingId"
        $params = @{  
        Force = [bool]$true
        NetworkGroupId= [string]($ng.Id) 
        }
        Write-Host "Removing Network Group: $($ng.Name)"
        $ret = Invoke-CimMethod -ClassName $class  -Namespace root\StifleR -MethodName $method -Arguments $params
        } catch {}
    }
}
Write-Host "Cleaned up $Counter Network Groups"


$class = "Locations"
$Locations = Get-CimInstance -Namespace root\StifleR -Query "SELECT * FROM $class"
$counter = 0
foreach($loc in $Locations)
{
    if($($loc.NetworkGroups).Count -eq 0)
    {
        $counter ++
        try {
        $method = "RemoveLocationUsingId"
        $params = @{  
        Force = [bool]$true
        LocationId= [string]($loc.Id) 
        }
        Write-Host "Removing Location: $($loc.id)"
        $ret = Invoke-CimMethod -ClassName $class  -Namespace root\StifleR -MethodName $method -Arguments $params
        } catch {}
    }
}
Write-Host "Cleaned up $Counter Locations"
