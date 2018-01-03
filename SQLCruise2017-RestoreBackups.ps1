#Get collection of files to loop through
$db = Get-ChildItem '\\TARKIN\C$\Backups' -Recurse | Where-Object {$_.Extension -eq '.bak'}

#Use foreach to loop through each file in the array
foreach($d in $db){
    #Run a 'RESTORE HEADERONLY...' to get info on the database to restore (mostly name)
    $header = Invoke-Sqlcmd -ServerInstance TARKIN -Database tempdb "RESTORE HEADERONLY FROM DISK='$($d.FullName)'"

    #Restore the database
    Restore-SqlDatabase -ServerInstance TARKIN -Database $header.DatabaseName -BackupFile $d -Script
}

#Get-Help Restore-SqlDatabase