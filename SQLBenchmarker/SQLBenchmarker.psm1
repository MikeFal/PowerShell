#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

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
        ,[int]$DurationSec)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
        $ComputerName = $smo.$smo.ComputerNamePhysicalNetBIOS

        $Samples = [Math]::Ceiling($DurationSec/5)
        $output = New-Object System.Object
        $Counters = @('\SQLServer:SQL Statistics\Batch Requests/sec')

        $Txns = Get-Counter -ComputerName $ComputerName -Counter $Counters -SampleInterval 5 -MaxSamples $samples

        $Summary=$Txns.countersamples | Measure-Object -Property CookedValue -Minimum -Maximum -Average

        $output | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
        $output | Add-Member -type NoteProperty -name AvgTxnPerSecond -Value $Summary.Average
        $output | Add-Member -type NoteProperty -name MinTxnPerSecond -Value $Summary.Minimum
        $output | Add-Member -type NoteProperty -name MaxTxnPersecond -Value $Summary.Maximum


        return $Output
}

function Get-SQLIO{
    param([string]$InstanceName='localhost'
        ,[int]$DurationSec=5)

        $smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
        $ComputerName = $smo.ComputerNamePhysicalNetBIOS

        $Samples = [Math]::Ceiling($DurationSec/5)
        $output = @() 
        $drives = @()
        $counters = @()
        $files = Invoke-Sqlcmd -ServerInstance localhost -Database tempdb -Query 'SELECT physical_name FROM sys.master_files'

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

       $DiskInfo = Get-Counter -ComputerName $ComputerName -Counter $counters -SampleInterval 5 -MaxSamples $samples

        foreach($drive in $drives){
            $Reads = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*sec/Read'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
            $Writes = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*sec/Write'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum
            $IOPs = $DiskInfo.CounterSamples | where {$_.InstanceName -eq $drive -and $_.path -like '*Transfers/sec'} | Measure-Object -Property CookedValue -Average -Minimum -Maximum

            $row = New-Object System.Object
            $row | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
            $row | Add-Member -type NoteProperty -name Volume -Value $drives
            $row | Add-Member -type NoteProperty -name AvgReadLatencyMS -Value ($Reads.Average * 1000)
            $row | Add-Member -type NoteProperty -name MinReadLatencyMS -Value ($Reads.Minimum * 1000)
            $row | Add-Member -type NoteProperty -name MaxReadLatencyMS -Value ($Reads.Maximum * 1000)
            $row | Add-Member -type NoteProperty -name AvgWriteLatencyMS -Value ($Writes.Average * 1000)
            $row | Add-Member -type NoteProperty -name MinWriteLatencyMS -Value ($Writes.Minimum * 1000)
            $row | Add-Member -type NoteProperty -name MaxWriteLatencyMS -Value ($Writes.Maximum * 1000)
            $row | Add-Member -type NoteProperty -name AvgIOPs -Value $IOPs.Average 
            $row | Add-Member -type NoteProperty -name MinIOPs -Value $IOPs.Minimum
            $row | Add-Member -type NoteProperty -name MaxIOPs -Value $IOPs.Maximum

            $output += $row
        }

        return $output
}

