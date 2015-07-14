
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

function Get-SQLTxnCount{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec
		,[Switch] $Detail)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS

        $Samples = [Math]::Ceiling($DurationSec/5)
        $output = New-Object System.Object
        if($smo.InstanceName -gt 0){
            $Counters = @('\MSSQL`$'+$smo.InstanceName+':SQL Statistics\Batch Requests/sec')
        }
        else{
            $Counters = @('\SQLServer:SQL Statistics\Batch Requests/sec')
        }

        $Txns = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples $samples
        $Summary=$Txns.countersamples | Measure-Object -Property CookedValue -Minimum -Maximum -Average

        $output | Add-Member -type NoteProperty -name InstanceName -Value $smo.DomainInstanceName
        $output | Add-Member -type NoteProperty -name AvgTxnPerSecond -Value $Summary.Average
        $output | Add-Member -type NoteProperty -name MinTxnPerSecond -Value $Summary.Minimum
        $output | Add-Member -type NoteProperty -name MaxTxnPersecond -Value $Summary.Maximum

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
			$output | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
			
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
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS
 
		$Counters = @('\Processor(_Total)\% Processor Time','\Thread(*sqlservr*)\% Processor Time')

        $CPUStats = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples ([Math]::Ceiling($DurationSec/5))
        if($Detail){
			return $CPUStats.CounterSamples
		}
		else{
				    
			$OSCPU = $CPUStats.CounterSamples | where {$_.path -like '*\Processor*'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
			$output = New-Object System.Object
			$output | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
			
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
				$row | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
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

