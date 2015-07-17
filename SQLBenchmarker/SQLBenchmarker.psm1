
function Get-FileVolume{
    param([string]$PathName
    ,[string] $ComputerName='localhost')

    $check = $PathName.Substring(0,$PathName.LastIndexOf('\')+1)

    $volumes = (gwmi win32_volume -ComputerName $ComputerName| where {$_.drivetype -eq 3}|select name|out-string -stream).Trim()
    if($volumes -contains $check){
        
        return gwmi win32_volume -ComputerName $ComputerName| where {$_.name -eq $check}
    }
    else{
        return Get-FileVolume -PathName $check.Substring(0,$check.Length-1) -ComputerName $ComputerName

    }
}

function Get-SQLStatistics{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec
		,[Switch] $Detail)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
		$smo.ConnectionContext.Connect()

        $ComputerName = $smo.ComputerNamePhysicalNetBIOS

        $Samples = [Math]::Ceiling($DurationSec/5)
        $output = New-Object System.Object
        if($smo.InstanceName -gt 0){
            $Counters = @('\MSSQL`$'+$smo.InstanceName+':SQL Statistics\Batch Requests/sec','\MSSQL`$'+$smo.InstanceName+':General Statistics\User Connections')
        }
        else{
            $Counters = @('\SQLServer:SQL Statistics\Batch Requests/sec','\SQLServer:General Statistics\User Connections')
        }

        $Txns = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples $samples
        $TxnSummary=$Txns.countersamples | Where-Object {$_.path -like '*Batch Requests/sec'} | Measure-Object -Property CookedValue -Minimum -Maximum -Average
		$CxnSummary=$Txns.countersamples | Where-Object {$_.path -like '*User Connections'} | Measure-Object -Property CookedValue -Minimum -Maximum -Average

        #$output | Add-Member -type NoteProperty -name InstanceName -Value $smo.DomainInstanceName
        $output | Add-Member -type NoteProperty -name AvgTxnPerSecond -Value ("{0:N2}" -f $TxnSummary.Average)
        $output | Add-Member -type NoteProperty -name MinTxnPerSecond -Value ("{0:N2}" -f $TxnSummary.Minimum)
        $output | Add-Member -type NoteProperty -name MaxTxnPersecond -Value ("{0:N2}" -f $TxnSummary.Maximum)
		$output | Add-Member -type NoteProperty -name AvgUserCxnPerSecond -Value ("{0:N2}" -f $CxnSummary.Average)
        $output | Add-Member -type NoteProperty -name MinUserCxnPerSecond -Value ("{0:N2}" -f $CxnSummary.Minimum)
        $output | Add-Member -type NoteProperty -name MaxUserCxnPersecond -Value ("{0:N2}" -f $CxnSummary.Maximum)

		if($Detail){
			return $Txns.CounterSamples
		}
		else{
	        return $Output
		}
}

function Get-SQLMemoryStats{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec
		,[Switch] $Detail)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
		$smo.ConnectionContext.Connect()
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS
        
        if($smo.InstanceName -gt 0){
			$CounterName = '\MSSQL$'+$smo.InstanceName
        }
        else{
            $CounterName = '\SQLServer'
        }

		$Counters = $Counters = @("$CounterName`:Buffer Manager\Page Life Expectancy","$CounterName`:Buffer Manager\Buffer cache hit ratio","$CounterName`:Memory Manager\Total Server Memory (KB)","\Memory\Available MBytes")

        $MemStats = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples ([Math]::Ceiling($DurationSec/5))
        if($Detail){
			return $MemStats.CounterSamples
		}
		else{
				    
			$PLE = $MemStats.CounterSamples | where {$_.path -like '*Page Life Expectancy'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
			$BHR = $MemStats.CounterSamples | where {$_.path -like '*Buffer cache hit ratio'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
			$ServerMemory = $MemStats.CounterSamples | where {$_.path -like '*Total Server Memory (KB)'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
			$MBytes = $MemStats.CounterSamples | where {$_.path -like '*Available MBytes'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum

			$output = New-Object System.Object
			#$output | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
			
			$output | Add-Member -type NoteProperty -name AvgPLE -Value ("{0:N2}" -f $PLE.Average)
			$output | Add-Member -type NoteProperty -name MinPLE -Value ("{0:N2}" -f $PLE.Minimum)
			$output | Add-Member -type NoteProperty -name MaxPLE -Value ("{0:N2}" -f $PLE.Maximum)
			$output | Add-Member -type NoteProperty -name AvgBufferCacheHitRatio -Value ("{0:N2}" -f $BHR.Average)
			$output | Add-Member -type NoteProperty -name MinBufferCacheHitRatio -Value ("{0:N2}" -f $BHR.Minimum)
			$output | Add-Member -type NoteProperty -name MaxBufferCacheHitRatio -Value ("{0:N2}" -f $BHR.Maximum)
			$output | Add-Member -type NoteProperty -name AvgServerMemoryMBytes -Value ("{0:N2}" -f ($ServerMemory.Average/1024))
			$output | Add-Member -type NoteProperty -name MinServerMemoryMBytes -Value ("{0:N2}" -f ($ServerMemory.Minimum/1024))
			$output | Add-Member -type NoteProperty -name MaxServerMemoryMBytes -Value ("{0:N2}" -f ($ServerMemory.Maximum/1024))
			$output | Add-Member -type NoteProperty -name AvgAvailableMBytes -Value ("{0:N2}" -f $MBytes.Average)
			$output | Add-Member -type NoteProperty -name MinAvailableMBytes -Value ("{0:N2}" -f $MBytes.Minimum)
			$output | Add-Member -type NoteProperty -name MaxAvailableMBytes -Value ("{0:N2}" -f $MBytes.Maximum)

	        return $output
		}
}

function Get-SQLCPUStats{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec
		,[Switch] $Detail)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
		$smo.ConnectionContext.Connect()
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS
 
		$Counters = @('\Processor(_Total)\% Processor Time')

        $CPUStats = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples ([Math]::Ceiling($DurationSec/5))
        if($Detail){
			return $CPUStats.CounterSamples
		}
		else{
				    
			$OSCPU = $CPUStats.CounterSamples | where {$_.path -like '*\Processor*'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
			$output = New-Object System.Object
			#$output | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
			
			$output | Add-Member -type NoteProperty -name AvgOSCPU -Value ("{0:N2}" -f $OSCPU.Average)
			$output | Add-Member -type NoteProperty -name MinOSCPU -Value ("{0:N2}" -f $OSCPU.Minimum)
			$output | Add-Member -type NoteProperty -name MaxOSCPU -Value ("{0:N2}" -f $OSCPU.Maximum)
			
			return $output
		}
}
function Get-SQLIO{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec=5
		,[Switch]$Detail)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
		$smo.ConnectionContext.Connect()
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS

        $drives = @()
        $counters = @()
        $files = Invoke-Sqlcmd -ServerInstance $InstanceName -Database tempdb -Query 'SELECT physical_name FROM sys.master_files'

        foreach($file in $files.Physical_Name){
            [string]$new = (Get-FileVolume -PathName $file -ComputerName $ComputerName).name
            $new = $new.substring(0,$new.Length - 1)

            if($drives -notcontains $new){$drives += $new}
        }

        foreach($drive in $drives){
            $counters += "\LogicalDisk($drive)\Avg. Disk sec/Read"
            $counters += "\LogicalDisk($drive)\Avg. Disk sec/Write"
            $counters += "\LogicalDisk($drive)\Disk Transfers/sec"
        }

       $DiskInfo = Get-Counter -ComputerName $ComputerName -Counter $counters -SampleInterval 5 -MaxSamples ([Math]::Ceiling($DurationSec/5))

        if($Detail){
			return $DiskInfo.CounterSamples
		}
		else{
			$output = @() 
		    foreach($drive in $drives){
				$Reads = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*sec/Read'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
				$Writes = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*sec/Write'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
				$IOPs = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*Transfers/sec'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum

				$row = New-Object System.Object
				#$row | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
				$row | Add-Member -type NoteProperty -name Volume -Value $drive

				$row | Add-Member -type NoteProperty -name AvgReadLatencyMS -Value ("{0:N2}" -f ($Reads.Average * 1000))
				$row | Add-Member -type NoteProperty -name MinReadLatencyMS -Value ("{0:N2}" -f ($Reads.Minimum * 1000))
				$row | Add-Member -type NoteProperty -name MaxReadLatencyMS -Value ("{0:N2}" -f ($Reads.Maximum * 1000))
				$row | Add-Member -type NoteProperty -name AvgWriteLatencyMS -Value ("{0:N2}" -f ($Writes.Average * 1000))
				$row | Add-Member -type NoteProperty -name MinWriteLatencyMS -Value ("{0:N2}" -f ($Writes.Minimum * 1000))
				$row | Add-Member -type NoteProperty -name MaxWriteLatencyMS -Value ("{0:N2}" -f ($Writes.Maximum * 1000))
				$row | Add-Member -type NoteProperty -name AvgIOPs -Value ("{0:N2}" -f $IOPs.Average)
				$row | Add-Member -type NoteProperty -name MinIOPs -Value ("{0:N2}" -f $IOPs.Minimum)
				$row | Add-Member -type NoteProperty -name MaxIOPs -Value ("{0:N2}" -f $IOPs.Maximum)

				$output += $row
			}
	        return $output
		}
}

function Get-SQLWaitStats{
param([string]$InstanceName='localhost'
        ,[int]$DurationSec=5
	)

	$smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
	$smo.ConnectionContext.Connect()

	$tlbname = $tblname = 'WS_'+(([char[]]([char]'a'..[char]'z') + 0..9 | sort {get-random})[0..5] -join '').ToUpper()
	$sqlstart = "SELECT wait_type,waiting_tasks_count,wait_time_ms INTO $tblname FROM sys.dm_os_wait_stats;"
	$sqlend = @"
SELECT
    e.wait_type
    ,e.waiting_tasks_count - s.waiting_tasks_count waiting_tasks
    ,e.wait_time_ms - s.wait_time_ms wait_time_ms
FROM
    sys.dm_os_wait_stats e
    JOIN $tblname s ON e.wait_type = s.wait_type
WHERE e.[wait_type] NOT IN (
    N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
	N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
    N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
    N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
	N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
    N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
    N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT', 
	N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
    N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
    N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
    N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'REQUEST_FOR_DEADLOCK_SEARCH',
	N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
	N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
    N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
    N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
	N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
	N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_HOST_WAIT',
	N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
    N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
AND e.[waiting_tasks_count] > 0
"@

	$smo.Databases['tempdb'].ExecuteNonQuery($sqlstart)
	Start-Sleep -Seconds $DurationSec
	$output = ($smo.Databases['tempdb'].ExecuteWithResults($sqlend)).Tables[0]
	$smo.Databases['tempdb'].ExecuteNonQuery("DROP TABLE $tblname;")

	return $output | Sort-Object -Property wait_time_ms -Descending | Select-Object -First 10


}

function New-SQLBenchmarkReport{
param([string]$InstanceName='localhost'
		,[int]$DurationSec=5
		,[string]$OutputPath = [environment]::getfolderpath("mydocuments")
		,[Switch]$AutoOpen
	)

	$CPU = Start-Job {Get-SQLCPUStats -InstanceName $using:InstanceName -DurationSec $using:DurationSec}
	$IO = Start-Job {Get-SQLIO -InstanceName $using:InstanceName -DurationSec $using:DurationSec}
	$Memory = Start-Job {Get-SQLMemoryStats -InstanceName $using:InstanceName -DurationSec $using:DurationSec}
	$TxnCount = Start-Job {Get-SQLStatistics -InstanceName $using:InstanceName -DurationSec $using:DurationSec}
	$Waits = Start-Job {Get-SQLWaitStats -InstanceName $using:InstanceName -DurationSec $using:DurationSec}

	$start = Get-Date
	$secs = 0
	while((Get-Job | Where {$_.state -eq 'Running'} | Measure-Object).Count -gt 0){
		Write-Progress -Activity 'Running Benchmark...' -PercentComplete (($secs/$DurationSec)*100)
		Start-Sleep -Seconds 1
		if($secs -lt $DurationSec){$secs += 1}
	}

	$filename = Join-Path $OutputPath -ChildPath "Benchmark-$InstanceName-$($start.ToString('yyyyMMddHHmmss')).txt"

	$output = @($CPU,$IO,$Memory,$TxnCount,$Waits)

	"Benchmark report for $InstanceName" | Out-File $filename
	"Benchmark Runtime: $DurationSec seconds" | Out-File $filename -Append
	"Start Time: $($start.ToString('HH:mm:ss - MMM dd, yyyy'))" | Out-File $filename -Append

	"CPU Statistics" | Out-File $filename -Append
	"-------------------------------------------------" | Out-File $filename -Append
	$CPU |Receive-Job | Select-Object * -ExcludeProperty RunspaceId | Format-List | Out-File $filename -Append

	"Disk IO Statistics" | Out-File $filename -Append
	"-------------------------------------------------" | Out-File $filename -Append 
	$IO | Receive-Job | Select-Object * -ExcludeProperty RunspaceId | Format-Table -AutoSize | Out-File $filename -Append -Width 200

	"SQL Memory Statistics" | Out-File $filename -Append
	"-------------------------------------------------" | Out-File $filename -Append
	$Memory | Receive-Job| Select-Object * -ExcludeProperty RunspaceId | Format-List | Out-File $filename -Append

	"SQL Activity Statistics" | Out-File $filename -Append
	"-------------------------------------------------" | Out-File $filename -Append
	$TxnCount | Receive-Job| Select-Object * -ExcludeProperty RunspaceId | Format-List | Out-File $filename -Append
	$Waits | Receive-Job| Select-Object * -ExcludeProperty RunspaceId | Format-Table -AutoSize | Out-File $filename -Append

	if($AutoOpen){notepad $filename}
}