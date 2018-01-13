#Enter-PSSession -VMName PALPATINE -Credential (Import-Clixml C:\temp\vmlab_domainadmin.xml)
#Create fileshare for witness
if(-not (Test-Path 'C:\QWitness')){
    New-Item -Path 'C:\QWitness' -ItemType Directory 
    New-SmbShare -name QWitness -Path 'C:\QWitness' -FullAccess Everyone
}

$StartTime = Get-Date

#Create FailoverCluster
Import-Module FailoverClusters
New-Cluster -Name 'ENDOR' -NoStorage -Node @('TARKIN','VADER') -StaticAddress 10.10.10.100 | Set-ClusterQuorum -FileShareWitness '\\PALPATINE\qwitness'

Start-Sleep -Seconds 60

ipconfig /flushdns

"Cluster Built...." | Out-Host

#Build AG Group

#Set initial variables
Import-Module SqlServer
$AGName = 'DEATHSTAR'
$PrimaryNode = 'TARKIN'

$replicas = @()
$cname = (Get-Cluster $PrimaryNode).name 
$nodes = (get-clusternode -Cluster $cname).name 


$nodes | ForEach-Object {Enable-SqlAlwaysOn -path "SQLSERVER:\SQL\$_\DEFAULT" -Force}

$sqlperms = @"
use [master];
GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM];
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM];
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM];

CREATE LOGIN [EMPIRE\sqlsvc] FROM WINDOWS;
GRANT CONNECT ON endpoint::[HADR_Endpoint] to [EMPIRE\sqlsvc];
"@

foreach($node in $nodes){
     $endpoint = New-SqlHadrEndpoint HADR_Endpoint -Port 5022 -Path SQLSERVER:\SQL\$node\DEFAULT
     Set-SqlHadrEndpoint -InputObject $endpoint -State "Started"
     $replicas += New-SqlAvailabilityReplica -Name $node -EndpointUrl "TCP://$($node):5022" -AvailabilityMode 'SynchronousCommit' -FailoverMode 'Automatic' -AsTemplate -Version 12
     Invoke-Sqlcmd -ServerInstance $node -Database master -Query $sqlperms
}


New-SqlAvailabilityGroup -Name $AGName -Path "SQLSERVER:\SQL\$PrimaryNode\DEFAULT" -AvailabilityReplica $replicas
$nodes | Where-Object {$_ -ne $PrimaryNode} | ForEach-Object {Join-SqlAvailabilityGroup -path "SQLSERVER:\SQL\$_\DEFAULT" -Name $AGName}

New-SqlAvailabilityGroupListener -Name $AGName -Port 1433 -Path "SQLSERVER:\Sql\$PrimaryNode\DEFAULT\AvailabilityGroups\$AGName"

"AG Built...." | Out-Host

#Install AdventureWorks
$restorefiles = @()
$restorefiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('AdventureWorks2014_Data','C:\DBFiles\Data\AdventureWorks2014_Data.mdf')
$restorefiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('AdventureWorks2014_Log','C:\DBFiles\Data\AdventureWorks2014_Log.ldf')

foreach ($node in $nodes){
    Restore-SqlDatabase -ServerInstance $node -Database AdventureWorks2014 -BackupFile '\\PALPATINE\Temp\AdventureWorks2014.FULL.bak' -RelocateFile $restorefiles -NoRecovery
}

$sqlprimary = @"
RESTORE DATABASE AdventureWorks2014 WITH RECOVERY;
ALTER AVAILABILITY GROUP [DEATHSTAR] ADD DATABASE [AdventureWorks2014];
"@
Invoke-Sqlcmd -ServerInstance $PrimaryNode -Database master -Query $sqlprimary -QueryTimeout 0

$sqlsecondary = "ALTER DATABASE [AdventureWorks2014] SET HADR AVAILABILITY GROUP = [DEATHSTAR];"
foreach($node in ($nodes | where-object {$_ -ne $primaryNode})){
    Invoke-Sqlcmd -ServerInstance $node -Database master -Query $sqlsecondary -QueryTimeout 0
}

"AdventureWorks2014 deployed...." | Out-Host

'AG BUILD TIME: [' + ((Get-Date) - $StartTime) + ']' | Out-Host
