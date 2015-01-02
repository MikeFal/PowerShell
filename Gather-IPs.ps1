<#
.SYNOPSIS
   Uses a text list of machine names and gathers IP v4 addresses for each, outputting the gathered values to a .csv file.
.DESCRIPTION
   This script consumes a basic text list (one machine per line) and uses Test-Connection (PoSH equivalent to ping) to
	 query the machine's IP address.  If the machine exists, the IP is recorded, otherwise a "not found" string is recorded.
	 The total output is spooled to a .csv document either in the user's My Documents (default) or a specified output directory.
	 
	 Output file will be Environment_IP_List_<datetimestamp>.csv
	 
	 Mike Fal (htp://www.mikefal.net) 2013-01-10
	 
.PARAMETER <paramName>
   -ServerList (mandatory) - Full path of server list text file
	 -OutputPath (optional) - Full path where .csv will be outputted.  NOTE: Do not declare a filename, filename will be created by script.
.EXAMPLE
   .\Gather-IPs.ps1 -ServerList foo.txt
	 .\Gather-IPs.ps1 -ServerList foo.txt -OutputPath "C:\bar"
#>

param(
	[Parameter(Mandatory=$true)] 
	[ValidateNotNullOrEmpty()]
	[string]
	$ServerList,
	[Parameter(Mandatory=$false)] 
	[string]
	$OutputPath=([Environment]::GetFolderPath("MyDocuments")))

if((Test-Path $OutputPath) -eq $false)
{
	throw "Invalid -OutputPath, please use a valid file path"
}

if(Test-Path $ServerList){
	$output=@()
	$machines=Get-Content $ServerList
	$filename=(Join-Path -Path $OutputPath -ChildPath("Environement_IP_List_"+(Get-Date -Format yyyyMMddHHmm)+".csv"))
	
	foreach($machine in $machines){
		$return=New-Object System.Object
		
		if(Test-Connection $machine -Quiet -Count 1){
			$ip = (Test-Connection $machine -count 1).IPV4Address.ToString()
		}
		else{
			$ip = "Machine not available"
		}
		
		$return | Add-Member -type NoteProperty -Name "Host" -Value $machine
		$return | Add-Member -type NoteProperty -Name "IP" -Value $ip
		
		$output+=$return
		}
	
	$output | Export-CSV -Path $filename -NoTypeInformation
}
else{
	throw "Invalid -ServerList, please use a valid file path"
}