[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')| Out-Null

function Set-SqlServiceAccount{
    param([string] $Instance
        ,[string] $account
        ,[string] $password
        ,[ValidateSet('SqlServer','SqlAgent')] $service = 'SqlServer'
    )
    

    $HostName = ($instance.Split('\'))[0]
    $InstanceName = ($instance.Split('\'))[1]

    $ServiceName = switch($service){
        'SqlServer'{if($InstanceName){"MSSQL`$$InstanceName"}else{'MSSQLSERVER'}}
        'SqlAgent'{if($InstanceName){"SQLAGENT`$$InstanceName"}else{'SQLSERVERAGENT'}}
    }

    $smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $HostName
    $wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $ServiceName}

    $wmisvc.SetServiceAccount($account,$password)
    Write-Warning "Please restart $ServiceName on $HostName for changes to take effect."
}


Set-SqlServiceAccount -Instance PICARD -account 'SDF\sqlsvc2' -password 'P@$$w0rd' -service SqlServer