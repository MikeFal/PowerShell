#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$ErrorActionPreference = 'Inquire'

function Set-SQLDefaultDatabases{
    param([string[]]$Instances = 'localhost'
    ,[string]$defaultdb = 'tempdb')

    foreach($InstanceName in $Instances){
        $smosrv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName
        if($smosrv.Databases.name -contains $defaultdb){
            foreach($login in $smosrv.Logins){
                Write-Verbose "Altering $login on $InstanceName to $defaultdb"
                $login.DefaultDatabase = $defaultdb
            }
        }
        else{
            Write-Warning "Database $defaultdb is not valid on $InstanceName."
        }
    }
}

Set-SQLDefaultDatabases -defaultdb tempdb -verbose