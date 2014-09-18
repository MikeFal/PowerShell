<#
.SYNOPSIS
   Builds a Powershell script for moving many database files from one
	 set of directories to another.
.DESCRIPTION
   Used to generate a Powershell script for moving many database files
	 from one location to another.  This will typically be used with a
	 large number of databases that need to be relocated.  Caveats for
	 this script include:
	 		-Destination for all files will be the same.
			-User that runs the script must have access to source and destination locations
			-This uses the 2008 R2 version of the SMO.

	The script generates a FileMover.ps1 script (by default in My
	Documents).  The reason for generating a separate script is so
	specific configurations can be edited/updated before actually
	execyting the move.

.PARAMETER <paramName>
   instance - Instance owning the databases to be moved
	 newdata - New data file location, no trailing '\'.  example: "C:\DBFiles\Data"
	 newlog - New log file location, no trailing '\'.  example: "C:\DBFiles\Log"
	 $outputfile - Full path and name of output file.  By default, FileMover.ps1 in My Documents.

.EXAMPLE
   .\Build-FileMover.ps1 -newdata "C:\DBFiles\Data" -newlog "C:\DBFiles\Log"
#>

param([parameter(Mandatory=$true)][string] $newdata,
			[parameter(Mandatory=$true)][string] $newlog,
			[string] $instance="localhost",
      [string] $outputfile=([Environment]::GetFolderPath("MyDocuments"))+"`\FileMover.ps1")

#load SMO
#Add-PSSnapin SqlServerCmdletSnapin100
#Add-PSSnapin SqlServerProviderSnapin100
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

#Create server object and output filename
$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $instance

#get your databases
$db_list=$server.Databases

#build initial script components
#"Add-PSSnapin SqlServerCmdletSnapin100" > $outputfile
#"Add-PSSnapin SqlServerProviderSnapin100" >> $outputfile
"[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') `"$instance`" | out-null" >> $outputfile
"`$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server " >> $outputfile

foreach($db_build in $db_list)
{
	#only process user databases
	if(!($db_build.IsSystemObject))
	{
		#script out all the file moves
		"#----------------------------------------------------------------------" >> $outputfile
		"`$db=`$server.Databases[`""+$db_build.Name+"`"]" >> $outputfile

		$dbchange = @()
		$robocpy =@()
		foreach ($fg in $db_build.Filegroups)
		{
			foreach($file in $fg.Files)
			{
				$shortfile=$file.Filename.Substring($file.Filename.LastIndexOf('\')+1)
				$oldloc=$file.Filename.Substring(0,$file.Filename.LastIndexOf('\'))
				$dbchange+="`$db.FileGroups[`""+$fg.Name+"`"].Files[`""+$file.Name+"`"].Filename=`"$newdata`\"+$shortfile+"`""
				$robocpy+="ROBOCOPY `"$oldloc`" `"$newdata`" $shortfile /copyall /mov"

			}
		}

		foreach($logfile in $db_build.LogFiles)
		{
			$shortfile=$logfile.Filename.Substring($logfile.Filename.LastIndexOf('\')+1)
			$oldloc=$logfile.Filename.Substring(0,$logfile.Filename.LastIndexOf('\'))
			$dbchange+="`$db.LogFiles[`""+$logfile.Name+"`"].Filename=`"$newlog`\"+$shortfile+"`""
			$robocpy+="ROBOCOPY `"$oldloc`" `"$newlog`" $shortfile"
		}

		$dbchange+="`$db.Alter()"
		$dbchange+="Invoke-Sqlcmd -Query `"ALTER DATABASE ["+$db_build.Name+"] SET OFFLINE WITH ROLLBACK IMMEDIATE;`" -ServerInstance `"$instance`" -Database `"master`""

		$dbchange >> $outputfile
		$robocpy >> $outputfile

		"Invoke-Sqlcmd -Query `"ALTER DATABASE ["+$db_build.Name+"] SET ONLINE;`" -ServerInstance `"$instance`" -Database `"master`""  >> $outputfile
	}
}