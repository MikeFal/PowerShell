#backup your logs
#get a collection of databases
$dbs = Invoke-Sqlcmd -ServerInstance localhost -Database tempdb -Query "SELECT name FROM sys.databases WHERE recovery_model_desc = 'FULL' and state_desc = 'ONLINE'"

#Get a formatted string for the datetime
$datestring =  (Get-Date -Format 'yyyyMMddHHmm')

#loop through the databases
foreach($db in $dbs.name){
    $dir = "C:\Backups\$db"
    #does the backup directory exist?  If not, create it
    if( -not (Test-Path $dir)){New-Item -ItemType Directory -path $dir}
    
    #Get a nice name and backup your database to it
    $filename = "$db-$datestring.trn"
    $backup=Join-Path -Path $dir -ChildPath $filename
    Backup-SqlDatabase -ServerInstance localhost -Database $db -BackupFile $backup -CompressionOption On -BackupAction Log
    #Delete old backups
    Get-ChildItem $dir\*.trn| Where {$_.LastWriteTime -lt (Get-Date).AddDays(-3)}|Remove-Item

}