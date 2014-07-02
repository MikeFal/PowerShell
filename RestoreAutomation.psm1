<#
.SYNOPSIS
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>

#load assemblies

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

#processing functions
function Get-Restore{
 Param($db,
	$backupfile) 

$rs = new-object("Microsoft.SqlServer.Management.Smo.Restore")
$rs.Devices.AddDevice($backupfile.FullName, "File")
$rs.Database=$db
$rs.NoRecovery=$true
$rs.Action="Database"

return $rs
}#Get-Restore

function Get-Header{
 Param($rs,$srv)

$dt = $restore.ReadBackupHeader($srv)
return $dt.Rows[0]
}#Get-Header

function New-Restore{
param([parameter(Mandatory=$true)][string] $dir
,[parameter(Mandatory=$true)][string] $server
,[string] $database
,[string] $outputdir = ([Environment]::GetFolderPath("MyDocuments"))
,[string] $newdata
,[string] $newlog
,[Switch] $Execute
,[Switch] $NoRecovery)

$sqlout = @()
$smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $server

$full = gci $dir | where {$_.name -like "*.bak"} | Sort-Object LastWriteTime -desc | Select-Object -first 1
$diff = gci $dir | where {$_.name -like "*.dff"} | sort-object LastWriteTime -desc | select-object -first 1
$trns = gci $dir | where {$_.name -like "*.trn"} | sort-object LastWriteTime

#initialize and process full backup
$restore = Get-Restore $database $full
$hfull = Get-Header $restore $smosrv
if($database.Length -eq 0)
{
	$database = $hfull.DatabaseName
	$restore.Database=$database
}

$LSNCheck = $hfull.FirstLSN
$files = $restore.ReadFileList($smosrv)
foreach($file in $files){
	$pfile = $file.PhysicalName
	if($newdata -ne $null -and $file.Type -eq "D"){
		$pfile=$newdata + $pfile.Substring($pfile.LastIndexOf("\"))
	}
	
	if($newlog -ne $null -and $file.Type -eq "L"){
		$pfile=$newlog + $pfile.Substring($pfile.LastIndexOf("\"))
	}
	
	$newfile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile") ($file.LogicalName,$pfile)
	$restore.RelocateFiles.Add($newfile) | out-null
}

$sqlout += "/****************************************************"
$sqlout += "Restore Database Script Generated $(Get-Date)"
$sqlout += "Database: "+$database
$sqlout += "****************************************************/"
$sqlout += "--FULL RESTORE"
$sqlout += $restore.Script($smosrv)

#process differential backups
if($diff -ne $null){
	$restore = Get-Restore $database $diff
	$hdiff = Get-Header $restore $smosrv

	if($hdiff.DifferentialBaseLSN -eq $LSNCheck){
		$sqlout += "--DIFF RESTORE"
		$sqlout += $restore.Script($smosrv)
		$LSNCheck = $hdiff.LastLSN
	}
	else{
		$LSNCheck = $hfull.LastLSN
	}
}

#process transaction log backups
if($trns -ne $null){
	$sqlout += "--TRN LOG RESTORE"

	foreach ($trn in $trns){
		$restore = Get-Restore $database $trn
		$htrn = Get-Header $restore $smosrv
		if($htrn.FirstLSN -le $LSNCheck -and $htrn.LastLSN -ge $LSNCheck){
			$sqlout += $restore.Script($smosrv)
			$LSNCheck = $htrn.LastLSN
		}
	}
}

#Write final recovery line if necessary
if(!($NoRecovery)){
	$sqlout += "`r`n"
	$sqlout += "--COMPLETE RESTORE/ONLINE DB"
	$sqlout += "RESTORE DATABASE "+$database + " WITH RECOVERY"
}

#output script file
$sqlout | Out-File "$outputdir\restore_$database.sql"

#If called, execute script
if($Execute){
	sqlcmd -S "$server" -E -i "$outputdir\restore_$database.sql"
}
} #New-Restore

function Sync-DBUsers{
	param([parameter(Mandatory=$true)][string] $server
	,[parameter(Mandatory=$true)][string] $database)

    $smosrv=new-object ('Microsoft.SqlServer.Management.Smo.Server') $server

	$sql = "select d.name " + `
	"from sys.database_principals d " + `
	"join sys.server_principals s on d.name = s.name " + `
	"left join sys.server_principals s2 on d.sid = s2.sid " + `
	"where d.principal_id > 4 and d.type in (`'S`',`'U`',`'G`') and s2.sid is null"

	$orphans = $smosrv.Databases[$database].ExecuteWithResults($sql).Tables[0]

	foreach($user in $orphans){
		[string] $sql = "ALTER USER ["+$user.name+"] WITH LOGIN=["+$user.name+"]"
		Invoke-SQLCmd -ServerInstance $server -Database $database -Query $sql
	}
	$sql = "select d.name " + `
	"from sys.database_principals d " + `
	"left join sys.server_principals s2 on d.sid = s2.sid " + `
	"where d.principal_id > 4 and d.type in (`'S`',`'U`',`'G`') and s2.sid is null"
	
	$orphans = $smosrv.Databases[$database].ExecuteWithResults($sql).Tables[0]
	
	if($orphans -ne $null){
		Write-Output $orphans
	}
}#Sync-DBUsers

function Get-DBCCCheckDB{
	param([parameter(Mandatory=$true)][string] $server
	,[parameter(Mandatory=$true)][string] $database
    ,[Switch] $Full)

    $smosrv=new-object ('Microsoft.SqlServer.Management.Smo.Server') $server

    if($Full){$sql="DBCC CHECKDB($database) WITH TABLERESULTS"}
    else{$sql="DBCC CHECKDB($database) WITH PHYSICAL_ONLY,TABLERESULTS"}

	$results = $smosrv.Databases["tempdb"].ExecuteWithResults($sql).Tables[0]
	
	Write-Output $results
}#Get-DBCCCheckDB
