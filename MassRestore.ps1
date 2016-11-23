$files = ls \\GLWASSQL\Backup2\GLWASSQL\ -Directory -Filter '*FULL*' -Recurse | 
    Where-Object {$_.FullName -notmatch 'master|model|msdb|SSISDB|Images'} | 
    ForEach-Object {Get-ChildItem $_.FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 1} |
    Sort-Object Size 
"--Restore Script Generated $(Get-Date -Format 'MMM dd yyyy - HH:mm:ss')" | Out-File C:\UpSearch\SQLProdFullRestore.sql

foreach($file in $files){
    $relocate = @()
    $dbname = (Invoke-Sqlcmd -ServerInstance SQLPROD -Database tempdb -Query "RESTORE HEADERONLY FROM DISK='$($file.FullName)';").DatabaseName
    $dbfiles = Invoke-Sqlcmd -ServerInstance SQLPROD -Database tempdb -Query "RESTORE FILELISTONLY FROM DISK='$($file.FullName)';"
    foreach($dbfile in $dbfiles){
        if($dbfile.Type -eq 'L'){
            $newfile = Join-Path -Path 'E:\SQLServer\Log' -ChildPath $($dbfile.PhysicalName.SubString($dbfile.PhysicalName.LastIndexOf('\')))
        } else {
            $newfile = Join-Path -Path 'E:\SQLServer\Data' -ChildPath $($dbfile.PhysicalName.SubString($dbfile.PhysicalName.LastIndexOf('\')))
        }
        $relocate += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ($dbfile.LogicalName,$newfile)
    }
    Restore-SqlDatabase -ServerInstance SQLPROD -Database $dbname -RelocateFile $relocate -NoRecovery -BackupFile "$($file.FullName)" -RestoreAction Database -Script | Out-File C:\UpSearch\SQLProdFullRestore.sql -Append
}
