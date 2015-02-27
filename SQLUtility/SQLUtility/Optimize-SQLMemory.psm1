<#
.SYNOPSIS
 Configures a SQL Server instance per the Jonathan Kehayias' guidelines.
.DESCRIPTION
 This script will configure your SQL Server instance per the guidelines
 found in Jonathan Kehayias' blog post: http://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
 The rules are:
 - 1GB for initial OS reserve
 - +1GB per 4GB server RAM up to 16GB
 - +1GB per 8GB server RAM above 16
.PARAMETER
 -target SQL instance name, i.e. localhost\SQL2012, DBASERVER01
 -apply Switch parameter, call if you want to actually apply the changes. Otherwise, a report will be produced.
.EXAMPLE
 Optimize-SQLMemory -instance DBASERVER01 -apply
#>

param([parameter(Mandatory=$true)][string] $target
 , [Switch] $apply
 )

#load SMO
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

if($target.Contains("\")){
 $sqlhost = $target.Split("\") | Select -First 1
 }
else{
 $sqlhost = $target
 }

#set memory variables
$totalmem = (gwmi Win32_ComputerSystem -computername $sqlhost).TotalPhysicalMemory/1GB
$sqlmem = [math]::floor($totalmem)

#calculate memory
while($totalmem -gt 0){
 if($totalmem -gt 16){
 $sqlmem -= [math]::floor(($totalmem-16)/8)
 $totalmem=16
 }
 elseif($totalmem -gt 4){
 $sqlmem -= [math]::floor(($totalmem)/4)
 $totalmem = 4
 }
 else{
 $sqlmem -= 1
 $totalmem = 0
 }
}

#if not in debug mode, alter config. Otherwise report current and new values.
$srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $target
 "Instance:" + $target
 "Max Memory:" + $srv.Configuration.MaxServerMemory.ConfigValue/1024 + " -> " + $sqlmem
 "Min Memory:" + $srv.Configuration.MinServerMemory.ConfigValue/1024 + " -> " + $sqlmem/2
if($apply){
 $srv.Configuration.MaxServerMemory.ConfigValue = $sqlmem * 1024
 $srv.Configuration.MinServerMemory.ConfigValue = $sqlmem/2 * 1024
 $srv.Configuration.Alter()
 "Configuration Complete!"
 }