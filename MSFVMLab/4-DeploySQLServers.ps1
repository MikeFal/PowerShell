#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$WorkingDirectory = $LabConfig.WorkingDirectory
$DomainCred = Import-Clixml "$WorkingDirectory\vmlab_domainadmin.xml"
$sqlsvccred = Import-Clixml "$WorkingDirectory\vmlab_sqlsvc.xml"

$dc = ( $LabConfig.Servers | Where-Object {$_.Class -eq 'DomainController'}).Name
$sqlnodes = ($LabConfig.servers | Where-Object {$_.Class -eq 'SQLServer'}).Name


#Prep SQL Machines with DSC
Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\SQLDSC.ps1 -SqlNodes $using:sqlnodes} -Credential $DomainCred 

#Install SQL
$installparams = "/SQLSVCACCOUNT='$($sqlsvccred.UserName)' " + `
                 "/SQLSVCPASSWORD='$($sqlsvccred.GetNetworkCredential().Password)'  " + `
                 "/AGTSVCACCOUNT='$($sqlsvccred.UserName)'  " + `
                 "/AGTSVCPASSWORD='$($sqlsvccred.GetNetworkCredential().Password)'  " + `
                 "/SAPWD='$($sqlsvccred.GetNetworkCredential().Password)'  " + `
                 "/SQLSYSADMINACCOUNTS='Domain Admins'"

$cmd = [ScriptBlock]::Create("& E:\setup.exe /CONFIGURATIONFILE='C:\TEMP\2016install.ini' $installparams /IACCEPTSQLSERVERLICENSETERMS")
Copy-VMFile -Name $sqlnodes -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\2016install.ini' -DestinationPath 'C:\TEMP\2016install.ini' -CreateFullPath -FileSource Host -Force
Invoke-Command -VMName $sqlnodes -ScriptBlock $cmd -Credential $DomainCred