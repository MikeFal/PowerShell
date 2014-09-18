<#
.SYNOPSIS
   Provides a report of all SQL Services that are not running.  Uses CMS to provide a list of servers to check.
.DESCRIPTION
   Using the Central Managemetn Server as a listing for SQL Servers, the script will check all SQL services for each
	 server.  State will be checked and if state is not "Running", the service and server will be reported.
.PARAMETER $CMS (Mandatory)
   Name of the Central Management Server.
.PARAMETER $output
	Defines how report is returned:
		0 (default) - Format-Table output
		1 - Email to specified contact.
#>

param([parameter(Mandatory=$true)][string] $CMS,
			[int] $output=0)
$CMS=$CMS.replace("\", "%5C")

$srvlist = gci "SQLSERVER:\sqlregistration\Central Management Server Group\$CMSInst\" -Recurse | where {$_.ServerName -ne $null}

$report=@()

foreach ($server in $srvlist)
{
	try
	{
		if($server.ServerName.Contains("\"))
		{
			$sqlhost=$server.ServerName.Substring(0,$server.ServerName.IndexOf("\"))
			$instance=$server.ServerName.Substring($server.ServerName.IndexOf("\")+1)
			$svcs=gwmi Win32_service -computer $sqlhost | where {$_.name -like "*$instance*"}
		}
		else
		{
			$sqlhost=$server.ServerName.Substring(0,$server.ServerName.IndexOf("\"))
			$svcs=gwmi Win32_service -computer $sqlhost | where {$_.name -like "*SQLSERVER*"}
		}
		
		
		foreach ($svc in $svcs)
		{
			$output = New-Object System.Object
			$output | Add-Member -type NoteProperty -name Instance -value $sqlhost
			$output | Add-Member -type NoteProperty -name SvcName -value $svc.Name
			$output | Add-Member -type NoteProperty -name DisplayName -value $svc.DisplayName
			$output | Add-Member -type NoteProperty -name State -value $svc.State
			$report+=$output
		}
	}
	catch
	{
		$output = New-Object System.Object
		$output | Add-Member -type NoteProperty -name Instance -value $sqlhost
		$output | Add-Member -type NoteProperty -name SvcName -value "No_Service_Collected"
		$output | Add-Member -type NoteProperty -name DisplayName -value "No Service Collected - COLLECTION ERROR"
		$output | Add-Member -type NoteProperty -name State -value "ERROR"
		$report+=$output
	}
}

switch($output)
{
	0 {
			$report | Format-Table Instance,DisplayName,State
		}
	1 {
			#Set these for your environment
			$smtp="mailhost-mci.ghx.com"
			$from="SvcAlert@ghx.com"
			$to="mfal@ghx.com"
			
			if(($report | where {$_.State -ne "Running"}).Length -gt 0)
			{
				[string]$body=$report|where{$_.State -ne "Running"}| ConvertTo-HTML
				Send-MailMessage -To $to -from $from -subject "Service Monitor Report" -smtpserver $smtp -body $body -BodyAsHtml
			}
		}
	
	default {
			$report|where{$_.State -ne "Running"} | Format-Table Instance,DisplayName,State
		}
}