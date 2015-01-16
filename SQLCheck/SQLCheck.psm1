function Test-SQLConnection{
    param([parameter(mandatory=$true)][string[]] $Instances)

    $return = @()
    foreach($InstanceName in $Instances){    
        $row = New-Object –TypeName PSObject –Prop @{'InstanceName'=$InstanceName;'StartupTime'=$null}
        try{
            $check=Invoke-Sqlcmd -ServerInstance $InstanceName -Database TempDB -Query "SELECT @@SERVERNAME as Name,Create_Date FROM sys.databases WHERE name = 'TempDB'" -ErrorAction Stop -ConnectionTimeout 3
            $row.InstanceName = $check.Name
            $row.StartupTime = $check.Create_Date
        }
        catch{
            #do nothing on the catch
        }
        finally{
            $return += $row
        }
    }
    return $return
}

function Test-SQLAGRole{
    param([parameter(mandatory=$true,ValueFromPipeline=$true)][string] $ComputerName)


    If(Test-SQLConnection -ComputerName $computerName){
        $smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ComputerName
        if($smosrv.AvailabilityGroups[0].PrimaryReplicaServerName -eq $smosrv.ComputerNamePhysicalNetBIOS){return "Primary"}
        else{"Secondary"}
    }
    else{
        return "Unreachable"
    }
}


function Test-SQLConnectionSMO{
    param([parameter(mandatory=$true)][string] $InstanceName)

    $smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
    $return = New-Object –TypeName PSObject –Prop @{'InstanceName'=$InstanceName;'StartupTime'=$null}
    try{
        $check=$smosrv.Databases['tempdb'].ExecuteWithResults('SELECT @@SERVERNAME')
        $return.InstanceName = $smosrv.Name
        $return.StartupTime = $smosrv.Databases['tempdb'].CreateDate
    }
    catch{
        #do nothing on the catch
    }

    return $return
}