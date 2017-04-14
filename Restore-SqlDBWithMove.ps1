function Restore-SqlDbWithMove{
[cmdletbinding()]
param([string]$ServerInstance = 'localhost'
				,[string]$BackupFile
        ,[string]$NewDataPath
        ,[string]$NewLogPath = $NewDataPath
        ,[string]$OutputPath = 'NoPath'
    )

#Validate paths
<#
If(-not (Test-Path $BackupFile)){
    Write-Error "Invalid Backup File: $BackupFile"
    return
}
If(-not (Test-Path $NewDataPath)){
    Write-Error "Invalid Data Path: $NewDataPath"
    return
}
If(-not (Test-Path $NewLogPath)){
    Write-Error "Invalid Log Path: $NewLogPath"
    return
}
If(-not (Test-Path $OutputPath) -and $OutputPath -ne 'NoPath'){
    Write-Error "Invalid Output Path: $OutputPath"
    return
}
#>

#initialize internal variables
$relocate = @()
$dbname = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database tempdb -Query "RESTORE HEADERONLY FROM DISK='$BackupFile';").DatabaseName
$dbfiles = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database tempdb -Query "RESTORE FILELISTONLY FROM DISK='$BackupFile';"

foreach($dbfile in $dbfiles){
    $DbFileName = $dbfile.PhysicalName | Split-Path -Leaf
    if($dbfile.Type -eq 'L'){
        $newfile = Join-Path -Path $NewLogPath -ChildPath $DbFileName
    } else {
        $newfile = Join-Path -Path $NewDataPath -ChildPath  $DbFileName
    }
    $relocate += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ($dbfile.LogicalName,$newfile)
}

If($OutputPath -ne 'NoPath'){
    $OutputFile = Join-Path $OutputPath -ChildPath "$dbname`_restore.sql"
    Restore-SqlDatabase -ServerInstance $ServerInstance -Database $dbname -RelocateFile $relocate -BackupFile "$BackupFile" -RestoreAction Database -Script | Out-File $OutputFile
} else {
    Restore-SqlDatabase -ServerInstance $ServerInstance -Database $dbname -RelocateFile $relocate -BackupFile "$BackupFile" -RestoreAction Database 
}
}