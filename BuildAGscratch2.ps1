Import-Module SQLPS -DisableNameChecking
$AGName = 'TestAG1'
$PrimaryNode = 'SQLNODE1'
$FailoverNode = 'SQLNODE2'
$IPs = @('10.152.18.25/255.255.255.0','10.152.19.160/255.255.255.0','10.152.20.119/255.255.255.0')

$replicas = @()

$cname = (Get-Cluster -name $PrimaryNode).name 
$nodes = (get-clusternode -Cluster $cname).name 

foreach($node in $nodes){
    if($node -eq $PrimaryNode -or $node -eq $FailoverNode){
        $failover = 'Automatic'
    }
    else{
        $failover = 'Manual'
    }
    $replicas += New-SqlAvailabilityReplica -Name $node -EndpointUrl "TCP://$($node):5022" -AvailabilityMode SynchronousCommit -FailoverMode $failover -AsTemplate -Version 12
}

New-SqlAvailabilityGroup -Name $AGName -Path "SQLSERVER:\SQL\$PrimaryNode\DEFAULT" -AvailabilityReplica $replicas 

$nodes | Where-Object {$_ -ne $PrimaryNode} | ForEach-Object {Join-SqlAvailabilityGroup -path "SQLSERVER:\SQL\$_\DEFAULT" -Name $AGName}

new-sqlavailabilitygrouplistener -Name $AGName -staticIP $IPs -Port 1433 -Path "SQLSERVER:\Sql\$PrimaryNode\DEFAULT\AvailabilityGroups\$AGName"