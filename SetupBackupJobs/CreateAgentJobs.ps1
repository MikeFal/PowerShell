param([string] $ServerInstance)
#Declare server for application
$smosrv = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerInstance
$jobs = @('BackupDBs-FULL','BackupDBs-LOGS')

foreach($job in $jobs){
    $j = New-Object Microsoft.SqlServer.Management.Smo.Agent.Job ($smosrv.JobServer,$job)

    $jstep = new-object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($j, 'Execute Script')
    $jstep.SubSystem = 'PowerShell'
    $jstep.Command = (Get-Content -Path ".\$job.ps1") -join "`r`n"
    $jstep.OnSuccessAction = 'QuitWithSuccess'
    $jstep.OnFailAction = 'QuitWithFailure'
  
    $jschedule = new-object Microsoft.SqlServer.Management.Smo.Agent.JobSchedule ($j, $job)
    

    if($job -eq 'BackupDBs-LOGS'){
        $runtime = New-TimeSpan -Hours 0
        $jschedule.FrequencyTypes = 'Daily'
        $jschedule.FrequencyInterval = 1
        $jschedule.FrequencySubDayTypes = 'Minute'
        $jschedule.FrequencySubDayInterval = 15
        $jschedule.ActiveStartTimeOfDay = $runtime
    } else {
        $runtime = New-TimeSpan -Hours 22
        $jschedule.FrequencyTypes = 'Daily'
        $jschedule.FrequencyInterval = 1
        $jschedule.FrequencySubDayTypes = 'Once'
        $jschedule.ActiveStartTimeOfDay = $runtime
    }
    $j.Create()
    $jstep.Create()
    $jschedule.Create()
    $j.ApplyToTargetServer($smosrv.Name)
}