function Copy-SQLAgentJob{
    param([string]$Source
    ,[string[]]$Targets
    ,[string]$JobName)

    #Load assemblies
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    $smosource = New-Object Microsoft.SqlServer.Management.Smo.Server $Source
    
    $JobScript = $smosource.JobServer.Jobs[$JobName].Script()

    foreach($Target in $Targets){
        $smotarget = New-Object Microsoft.SqlServer.Management.Smo.Server $Target
        if($smotarget.JobServer.Jobs.Name -notcontains $JobName){
            $smotarget.Databases['msdb'].ExecuteNonQuery($JobScript)
        }
    }
}

Copy-SQLAgentJob -Source 'SHION' -Targets 'SHION\ALBEDO' -JobName 'Backup Databases - Powershell'