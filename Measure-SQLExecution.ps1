function Measure-SQLExecution{
    param($instancename
        ,$databasename = 'tempdb'
        ,[Parameter(ParameterSetName = 'SQLCmd',Mandatory=$true)]$sqlcmd
        ,[Parameter(ParameterSetName = 'SQLScript',Mandatory=$true)]$sqlscript)

    $output = New-Object System.Object
    $errval = $null

    $output | Add-Member -Type NoteProperty -Name InstanceName -Value $instancename
    $output | Add-Member -Type NoteProperty -Name DatabaseName -Value $databasename
    $output | Add-Member -Type NoteProperty -Name StartTime -Value (Get-Date)

    if($sqlscript){
        $output | Add-Member -Type NoteProperty -Name SQL -Value $sqlscript
        $sqlout = Invoke-Sqlcmd -ServerInstance $instancename -Database $databasename -InputFile $sqlscript -ErrorVariable errval
    }
    else{
        $output | Add-Member -Type NoteProperty -Name SQL -Value $sqlcmd
        $sqlout = Invoke-Sqlcmd -ServerInstance $instancename -Database $databasename -Query $sqlcmd -ErrorVariable errval
    }


    $output | Add-Member -Type NoteProperty -Name EndTime -Value (Get-Date)
    $output | Add-Member -Type NoteProperty -Name RunDuration -Value (New-TimeSpan -Start $output.StartTime -End $output.EndTime)
    $output | Add-Member -Type NoteProperty -Name Results -Value $sqlout
    $output | Add-Member -Type NoteProperty -Name Error -Value $errval

    return $output
}

#Measure-SQLExecution -instancename 'localhost' -databasename 'demoPartition' -sqlcmd 'exec usp_loadpartitiondata;'

$total = @()
$total += Measure-SQLExecution -instancename 'localhost' -databasename 'demoPartition' -sqlcmd 'exec usp_loadpartitiondata;'
$total += Measure-SQLExecution -instancename 'localhost' -databasename 'demoPartition' -sqlcmd 'exec usp_fragmentpartition;'
$total | Select-Object InstanceName,DatabaseName,StartTime,EndTime,SQL,RunDuration | Export-Csv -Path 'C:\Temp\ExecutionLog.csv' -NoTypeInformation
