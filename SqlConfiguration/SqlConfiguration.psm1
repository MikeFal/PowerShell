#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$ErrorActionPreference = 'Inquire'

function Optimize-SQLMemory{
param([string]$InstanceName)

$srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName
$sqlhost = $srv.ComputerNamePhysicalNetBIOS

#set memory variables
$totalmem = (gwmi Win32_ComputerSystem -computername $sqlhost).TotalPhysicalMemory/1GB
$sqlmem = [math]::floor($totalmem)

#calculate memory
while($totalmem -gt 0){
     if($totalmem -gt 16){
         $sqlmem -= [math]::floor(($totalmem-16)/8)
         $totalmem=16
        }
     elseif($totalmem -gt 4){
         $sqlmem -= [math]::floor(($totalmem)/4)
         $totalmem = 4
        }
     else{
         $sqlmem -= 1
         $totalmem = 0
        }
    }
 $srv.Configuration.MaxServerMemory.ConfigValue = $sqlmem * 1024
 $srv.Configuration.MinServerMemory.ConfigValue = $sqlmem/2 * 1024
 $srv.Configuration.Alter()

}

function Set-DefaultDBDirectories{
param([string]$InstanceName,
      [string]$DefaultDB,
      [string]$DefaultLog,
      [string]$DefaultBackup)

    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName

    if (($DefaultDB)){$srv.DefaultFile = $DefaultDB;$srv.Alter()}
    if (($DefaultLog)){$srv.DefaultLog = $DefaultLog;$srv.Alter()}
    if (($DefaultBackup)){$srv.BackupDirectory = $DefaultBackup;$srv.Alter()}

    
    $svc = Get-Service $srv.ServiceName

    $svc.Stop()

    while($svc.status -ne 'Stopped'){$svc.Refresh();Write-Verbose "Waiting for $svc.name to stop"; Start-Sleep -s 1}
    $svc.Start()
    
}

function Set-MasterDB{
param([string]$InstanceName)

    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName

    if ($srv.Databases['master'].FileGroups['Primary'].Files['master'].Size -lt 102400){
        $srv.Databases['master'].FileGroups['Primary'].Files['master'].Size = 102400
        $srv.Databases['master'].FileGroups['Primary'].Files['master'].Growth = 102400
        $srv.Databases['master'].FileGroups['Primary'].Files['master'].GrowthType = 'KB'
        $srv.Databases['master'].FileGroups['Primary'].Files['master'].Alter()
        
    }

    if ($srv.Databases['master'].LogFiles['mastlog'].Size -lt 102400){
        $srv.Databases['master'].LogFiles['mastlog'].Size = 102400
        $srv.Databases['master'].LogFiles['mastlog'].Growth = 102400
        $srv.Databases['master'].LogFiles['mastlog'].GrowthType = 'KB'
        $srv.Databases['master'].LogFiles['mastlog'].Alter()
    }
}


function Set-MSDB{
param([string]$InstanceName,
        [int]$DataSizeKB = 2048000,
        [int]$DataGrowthKB = 512000,
        [int]$LogSizeKB = 204800,
        [int]$LogGrowthKB =102400)

    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName

    if ($srv.Databases['msdb'].FileGroups['Primary'].Files['msdbdata'].Size -lt $DataSizeKB){
        $srv.Databases['msdb'].FileGroups['Primary'].Files['msdbdata'].Size = $DataSizeKB
        $srv.Databases['msdb'].FileGroups['Primary'].Files['msdbdata'].Growth = $DataGrowthKB
        $srv.Databases['msdb'].FileGroups['Primary'].Files['msdbdata'].GrowthType = 'KB'
        $srv.Databases['msdb'].FileGroups['Primary'].Files['msdbdata'].Alter()
    }

    if ($srv.Databases['msdb'].LogFiles['msdblog'].Size -lt $LogSizeKB){
        $srv.Databases['msdb'].LogFiles['msdblog'].Size = $LogSizeKB
        $srv.Databases['msdb'].LogFiles['msdblog'].Growth = $LogGrowthKB
        $srv.Databases['msdb'].LogFiles['msdblog'].GrowthType = 'KB'
        $srv.Databases['msdb'].LogFiles['msdblog'].alter()
    }
}

function Set-TempDB{
    param([string]$InstanceName,
        [int]$CpuCount = 8,
        [int]$DataFileSizeMB = 32768)

    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName
    if($cpuCount -gt 8){$CpuCount = 8}

    $DataFileSizeSingle = [Math]::Floor(($DataFileSizeMB/$CpuCount) * 1024.0)
    $FilePath = $srv.Databases['TempDB'].FileGroups['Primary'].Files[0].FileName
    $FilePath = $FilePath.Substring(0,$FilePath.LastIndexOf('\'))
    $FileProc = 0
    while($FileProc -lt $CpuCount){
        $file=$srv.Databases['TempDB'].FileGroups['Primary'].Files[$FileProc]
        if($file){
            $file.Shrink(100,'Default')
            $file.Size = $DataFileSizeSingle
            $file.Growth = 524288
            $file.GrowthType = 'KB'
            $file.Alter()
        }
        else{
            $FG = $srv.Databases['TempDB'].FileGroups['Primary']
            $NewFile = New-Object -TypeName Microsoft.SqlServer.Management.Smo.DataFile ($FG, "tempdev$FileProc")
            $NewFile.FileName = Join-Path -Path $FilePath -ChildPath "tempdev$FileProc.ndf"
            $NewFile.Size = $DataFileSizeSingle
            $NewFile.Growth = 524288
            $NewFile.GrowthType = 'KB'
            $NewFile.MaxSize = -1
            $FG.Files.Add($NewFile)
            $FG.Alter()
        }
        $FileProc += 1
    }

    $LogFileSize = [Math]::Floor($DataFileSizeMB/4*1024.0)

    $logfile = $srv.Databases['TempDB'].LogFiles[0]
    $logfile.Shrink(100,'Default')
    $logfile.Growth = 524288
    $logfile.GrowthType = 'KB'
    $logfile.MaxSize = -1
    $logfile.Alter()

    if($LogFileSize -lt 8192000){
        $logfile.size = $LogFileSize
        $logfile.Alter()
    }
    else{
        while($logfile.Size -lt $LogFileSize){
            $logfile.size += 8192000
            $logfile.Alter()
        }
    }
}
            

function Set-SQLStartupParameters{
    param([string]$InstanceName,
        [string[]]$StartupParams)

    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName

    if($srv.InstanceName.Length -eq 0){
        $srvinstance = 'MSSQLSERVER'
    }
    else{
        $srvinstance = $srv.InstanceName
    }

    $regroot = 'HKLM:\Software\Microsoft\Microsoft SQL Server'
    $reginst = Get-ItemProperty "$regroot\Instance Names\SQL"
    $instname = $reginst.$srvinstance

    $sqlreg = "$regroot\$instname\MSSQLServer\Parameters"
    $reg = Get-ItemProperty $sqlreg
    foreach($param in $StartupParams){
        $argcount = ($reg.PsObject.Properties | Where-Object {$_.Name -like 'SQLArg*' }).Count
        $newparam = "SQLArg$argcount"
        Set-ItemProperty -Path $sqlreg -Name $newparam -Value $param 
    }
}