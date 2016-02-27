function Get-FreeDBSpace{
    [cmdletbinding()]
    param([parameter(ValueFromPipeline)][string[]] $InstanceName = 'localhost'
        ,[switch] $IncludeSystemDBs)
    BEGIN{
        $output = @()
    }

    PROCESS{
        $smo = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName

        try{
            if($IncludeSystemDBs){
                $dbs = $smo.Databases | Where-Object {$_.status -eq 'Normal'}
            } else {
                $dbs = $smo.Databases | Where-Object {$_.status -eq 'Normal' -and $_.IsSystemObject -eq 0}
            }
        foreach($db in $dbs){
                $output += ($db.FileGroups.Files | Select-Object @{n='Instance';e={$InstanceName}},@{n='Database';e={$db.Name}},Name,@{n='Type';e={'Data'}},UsedSpace,AvailableSpace,Size,@{n='PercUsed';e={[math]::round(($_.UsedSpace/$_.Size)*100,2)}})
                $output += ($db.LogFiles | Select-Object @{n='Instance';e={$InstanceName}},@{n='Database';e={$db.Name}},Name,@{n='Type';e={'Log'}},UsedSpace,@{n='AvailableSpace';e={$_.Size-$_.UsedSpace}},Size,@{n='PercUsed';e={[math]::round(($_.UsedSpace/$_.Size)*100,2)}})
            }
        }
        catch{
            $output += New-Object PSObject -Property @{'Instance'={$InstanceName};'Database'="An error occured retreiving database information for $InstanceName.";'PercUsed' = -1}
        }
    }

    END{
        return $output
    }
}