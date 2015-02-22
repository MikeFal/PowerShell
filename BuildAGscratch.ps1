[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null

$AGName = 'TestAG1'
$PrimaryNode = 'SQLNODE1'
$FailoverNode = 'SQLNODE2'
$IPs = @('10.152.18.25','10.152.19.160','10.152.20.119')

$smoprimarynode = New-Object Microsoft.SqlServer.Management.Smo.Server $PrimaryNode
$smoag = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroup ($smoprimarynode,$AGName)


$cname = (Get-Cluster -name $PrimaryNode).name 
$nodes = (get-clusternode -Cluster $cname).name 
$secondaries = @()
foreach($node in $nodes){

        $smonode = New-Object Microsoft.SqlServer.Management.Smo.Server $Node

        #create endpoint
        if($smonode.Endpoints.Name -notcontains 'HADR_endpoint'){
            $EndPoint = New-Object Microsoft.SqlServer.Management.Smo.Endpoint($smonode, 'HADR_endpoint')
            $EndPoint.EndpointType = 'DatabaseMirroring'
            $EndPoint.ProtocolType = 'Tcp'
            $EndPoint.Protocol.Tcp.ListenerPort = 5022
            $EndPoint.Payload.DatabaseMirroring.ServerMirroringRole = 'All'
            $EndPoint.Payload.DatabaseMirroring.EndpointEncryption = 'Required'
            $EndPoint.Payload.DatabaseMirroring.EndpointEncryptionAlgorithm ='Aes'
            $EndPoint.Create()
            $EndPoint.Start()
        }
        
        $replica = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityReplica ($smoag,$node)
        $replica.EndpointURL = "TCP://$($node):5022"
        if($node -eq $FailoverNode){
            $replica.FailoverMode = 'Automatic'
        }
        else{
            $replica.FailoverMode = 'Manual'
        }
        $replica.AvailabilityMode = 'SynchronousCommit'
        $replica.ConnectionModeInPrimaryRole = 'AllowAllConnections'
        $replica.ConnectionModeInSecondaryRole = 'AllowAllConnections'
        $smoag.AvailabilityReplicas.Add($replica)

        if($node -ne $PrimaryNode){
            $secondaries += $smonode
        }
}

$smoag.Create()

foreach($secondary in $secondaries){
    $secondary.JoinAvailabilityGroup($AGName)
}

$listener = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListener($smoag,$AGName)
$listener.PortNumber = 1433

foreach($ip in $ips){
    $listenerip = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListenerIPAddress($listener)
    $listenerip.IsDHCP = $false
    $listenerip.IPAddress = $ip
    $listenerip.SubnetIP = $ip.Substring(0,$ip.LastIndexOf('.'))+'.0'
    $listenerip.SubnetMask = '255.255.255.0'
    $listener.AvailabilityGroupListenerIPAddresses.Add($listenerip)
}

$listener.Create()

