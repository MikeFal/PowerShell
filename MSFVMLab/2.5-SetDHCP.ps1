#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$WorkingDirectory = $LabConfig.WorkingDirectory
$Domain = $LabConfig.Domain

#Use DSC to deploy AD DC
$dc = ( $LabConfig.Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

$DomainCred = Import-Clixml "$WorkingDirectory\vmlab_domainadmin.xml"

Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\VMDSC.ps1 -DName "$using:Domain.com" -DCred $using:DomainCred} -Credential $DomainCred   