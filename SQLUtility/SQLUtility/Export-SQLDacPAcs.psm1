function Export-SQLDacPacs{
    param([string[]] $Instances = 'localhost',
              [string] $outputdirectory=([Environment]::GetFolderPath("MyDocuments"))
              )

#get the sqlpackage executable
$sqlpackage = (get-childitem C:\ -Recurse | Where-Object {$_.name -eq 'sqlpackage.exe'} |Sort-Object LastWriteTime | Select-Object -First 1).FullName

#declare a select query for databases
$dbsql = @"
SELECT name FROM sys.databases
where database_id >4 and state_desc = 'ONLINE'
"@

foreach($instance in $Instances){
    $dbs = Invoke-Sqlcmd -ServerInstance $instance -Database tempdb -Query $dbsql
    $datestring =  (Get-Date -Format 'yyyyMMddHHmm')
    $iname = $instance.Replace('\','_')

    foreach($db in $dbs.name){
        $outfile = Join-Path $outputdirectory -ChildPath "$iname-$db-$datestring.dacpac"
        $cmd = "& '$sqlpackage' /action:Extract /targetfile:'$outfile' /SourceServerName:$instance /SourceDatabaseName:$db"
        Invoke-Expression $cmd
        }

    }
}

