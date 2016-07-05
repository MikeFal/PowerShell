Import-module SQLPS -DisableNameChecking -Force

$backupfile = 'C:\TEMP\OPA2.0\OPA2.0\OPA2.0Analysis\SQL\OPAmanager.bak'
$restoreserver = 'localhost'
$restoredatabase = 'OPA'
$restorefiles = @()
$files = Invoke-Sqlcmd -ServerInstance $restoreserver -Database tempdb -Query "RESTORE FILELISTONLY FROM DISK='$backupfile'"

$newdata = 'C:\DBFiles\Data'
$newlog = 'C:\DBFiles\Log'

$restore = new-object 'Microsoft.SqlServer.Management.Smo.Restore';
$restore.Database = $restoredatabase
$restore.Devices.Add((new-object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $backupfile, 'File'))

foreach($file in $files){
    
    if($file.Type -eq 'L'){        
        $newpath = Join-Path $newlog $file.PhysicalName.Substring($file.PhysicalName.LastIndexOf('\')+1)
    } else {
        $newpath = Join-Path $newdata $file.PhysicalName.Substring($file.PhysicalName.LastIndexOf('\')+1)
    }
    $restore.RelocateFiles.Add((New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ($file.LogicalName,$newpath)))
}


#$restore.Script($restoreserver)

Restore-SqlDatabase -ServerInstance $restoreserver -Database $restoredatabase -BackupFile $backupfile -RelocateFile $restorefiles -RestoreAction Database -Script