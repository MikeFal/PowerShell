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

param([parameter(Mandatory=$true)][string] $dir,
		[parameter(Mandatory=$true)][string] $server)


#load assemblies
Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
$smosrv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $server


#get backup files
$files = gci $dir | where {$_.name -like "*.bak"}

$output=([Environment]::GetFolderPath("MyDocuments")) + "\attachdbs.sql"

"/*****************************************" > $output
"Attach script based off of backup files" >> $output
"*****************************************/" >> $output
foreach($file in $files){
	$rs=new-object("Microsoft.SqlServer.Management.Smo.Restore")
	$rs.Devices.AddDevice($file.FullName, "File")
	$hd=$rs.ReadBackupHeader($smosrv)
	$dbname=$hd.Rows[0].DatabaseName
	
	$dbfiles=$rs.ReadFileList($smosrv)
	
	"CREATE DATABASE $dbname ON" >> $output
	$filewrite=@()
	foreach($dbfile in $dbfiles){
		$filewrite+="(FILENAME='"+$dbfile.PhysicalName+"')"
	}
	
	$filewrite -join ",`n" >> $output
	
	"FOR ATTACH; `n--------------------------" >> $output
	}


