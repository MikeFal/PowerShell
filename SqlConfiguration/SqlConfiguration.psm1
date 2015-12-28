#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$ErrorActionPreference = 'Inquire'

function Set-SQLMemory{
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

    Write-Verbose 'Service should be restarted for all changes to take effect.'
    
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
    [cmdletbinding(SupportsShouldProcess=$true)]
    param([string[]] $Instance
        ,[string[]] $StartupParameters
    )
    [bool]$SystemPaths = $false
    
    #Loop through and change instances
    foreach($i in $Instance){
        #Parse host and instance names
        $HostName = ($i.Split('\'))[0]
        $InstanceName = ($i.Split('\'))[1]

        #Get service account names, set service account for change
        $ServiceName = if($InstanceName){"MSSQL`$$InstanceName"}else{'MSSQLSERVER'}

        #Use wmi to change account
        $smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $HostName
        $wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $ServiceName}

        Write-Verbose "Old Parameters for $i :"
        Write-Verbose $wmisvc.StartupParameters

        #Wrangle updated params with existing startup params (-d,-e,-l)
        $oldparams = $wmisvc.StartupParameters -split ';'
        $newparams = @()
        foreach($param in $StartupParameters){
            if($param.Substring(0,2) -match '-d|-e|-l'){
                $SystemPaths = $true
                $newparams += $param
                $oldparams = $oldparams | Where-Object {$_.Substring(0,2) -ne $param.Substring(0,2)}
            }
            else{
                $newparams += $param
            }
        }

        $newparams += $oldparams | Where-Object {$_.Substring(0,2) -match '-d|-e|-l'}
        $paramstring = ($newparams | Sort-Object) -join ';'

        Write-Verbose "New Parameters for $i :"
        Write-Verbose $paramstring

        #If not -WhatIf, apply the change. Otherwise display an informational message.
        if($PSCmdlet.ShouldProcess($i,$paramstring)){
            $wmisvc.StartupParameters = $paramstring
            $wmisvc.Alter()

            Write-Warning "Startup Parameters for $i updated. You will need to restart the service for these changes to take effect."
            If($SystemPaths){Write-Warning "You have changed the system paths for $i. Please make sure the paths are valid before restarting the service"}
        }
    }
}

function Set-SQLMaxdop{
    param([string]$InstanceName)

    
    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $InstanceName
    $cores = (Get-WmiObject Win32_Processor -ComputerName $srv.ComputerNamePhysicalNetBIOS).NumberOfLogicalProcessors
    if($cores -gt 8) {
        $maxdop = 8
        }
    else {
        $maxdop = [Math]::Ceiling($cores/2)
        }
    $srv.Configuration.MaxDegreeOfParallelism.ConfigValue = $maxdop
    $srv.Configuration.Alter()
}

function Test-SQLConfiguration{
    param([string]$InstanceName='localhost'
        ,[Parameter(Mandatory=$true)][PSObject] $Configs
        )
    $smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
    $output = @()

    foreach($config in $configs){
        if($config.DesiredValue -ne $smosrv.Configuration.$($config.Name).RunValue){
            $output += New-Object PSObject -Property (@{'Configuration'=$config.Name;
                                                    'DesiredValue'=$config.DesiredValue;
                                                    'CurrentValue'=$smosrv.Configuration.$($config.Name).RunValue})
        }
    }

    return $output
}

function Set-SQLConfiguration{
    param([string]$InstanceName='localhost'
        ,[Parameter(Mandatory=$true)][PSObject] $Configs
        )
    $smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
    $output = @()

    foreach($config in $configs){
        if($config.DesiredValue -ne $smosrv.Configuration.$($config.Name).RunValue){

            $row = New-Object PSObject -Property (@{'Configuration'=$config.Name;
                                                    'DesiredValue'=$config.DesiredValue;
                                                    'CurrentValue'=$smosrv.Configuration.$($config.Name).RunValue})
            $smosrv.Configuration.$($config.Name).ConfigValue = $Config.DesiredValue
            $smosrv.Configuration.Alter()
            $row | Add-Member -MemberType NoteProperty -Name 'ConfiguredValue' -Value $smosrv.Configuration.$($config.Name).RunValue
            $output += $row
            if($smosrv.Configuration.$($config.Name).IsDynamic -eq $false){$reboot=$true}
        }
    }

    if($reboot){Write-Warning 'Altered configurations contain some that are not dynamic. Instance restart is required to apply.'}

    return $output

}

function Get-SQLConfiguration{
    param([string]$InstanceName='localhost'
            ,[string[]] $Filter
        )
    $smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
    $output = @()
    if($Filter){
        $configs = $smosrv.Configuration | Get-Member -MemberType Properties | Where-Object {$Filter.Contains($_.Name)}
    }
    else{
        $configs = $smosrv.Configuration | Get-Member -MemberType Properties | Where-Object {$_.Name -ne 'Properties'}
    }

    foreach($config in $configs){
        $output += New-Object PSObject -Property ([Ordered]@{'Name'=$config.Name;
                                                    'DesiredValue'=$smosrv.Configuration.$($config.Name).RunValue})
    }

    return $output
}